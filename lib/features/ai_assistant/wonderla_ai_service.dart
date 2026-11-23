import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Actionable park place suggested by a Genkit tool call so visitors can jump
/// straight to map pins or CMS-configured directions.
class AiSuggestedPlace {
  const AiSuggestedPlace({
    required this.name,
    required this.category,
    this.imageUrl,
    this.subtitle,
    this.badge,
    this.directions,
    this.directionsUrl,
    this.action = 'map',
  });

  final String name;
  final String category;
  final String? imageUrl;
  final String? subtitle;
  final String? badge;
  final String? directions;
  final String? directionsUrl;
  final String action;

  bool get prefersDirections =>
      action == 'directions' ||
      (directions != null && directions!.trim().isNotEmpty) ||
      (directionsUrl != null && directionsUrl!.trim().isNotEmpty);

  factory AiSuggestedPlace.fromJson(Map<String, dynamic> json) =>
      AiSuggestedPlace(
        name: json['name']?.toString() ?? '',
        category: json['category']?.toString() ?? 'Place',
        imageUrl: json['imageUrl']?.toString(),
        subtitle: json['subtitle']?.toString(),
        badge: json['badge']?.toString(),
        directions: json['directions']?.toString(),
        directionsUrl: json['directionsUrl']?.toString(),
        action: json['action']?.toString() ?? 'map',
      );
}

sealed class AiStreamEvent {
  const AiStreamEvent();
}

class AiToolStatusEvent extends AiStreamEvent {
  const AiToolStatusEvent({required this.tool, required this.label});
  final String tool;
  final String label;
}

class AiTextChunkEvent extends AiStreamEvent {
  const AiTextChunkEvent(this.text);
  final String text;
}

class AiPlacesEvent extends AiStreamEvent {
  const AiPlacesEvent(this.places);
  final List<AiSuggestedPlace> places;
}

class AiDoneEvent extends AiStreamEvent {
  const AiDoneEvent({required this.mode});
  final String mode;
}

class AiErrorEvent extends AiStreamEvent {
  const AiErrorEvent(this.message);
  final String message;
}

class AiHistoryTurn {
  const AiHistoryTurn({required this.role, required this.text});
  final String role;
  final String text;

  Map<String, String> toJson() => {'role': role, 'text': text};
}

/// Streams tool-calling AI responses from the Next.js Genkit endpoint
/// (`POST /qr-code/api/ai/chat`) with an automatic on-device park-tools
/// streaming fallback so the concierge always stays responsive.
class WonderlaAiService {
  WonderlaAiService({
    required this.baseUrl,
    this.streamOverride,
  });

  final String baseUrl;
  final Stream<AiStreamEvent> Function({
    required String parkSlug,
    required String message,
    required List<AiHistoryTurn> history,
    required Map<String, dynamic> parkConfig,
  })?
  streamOverride;

  Stream<AiStreamEvent> ask({
    required String parkSlug,
    required String message,
    required Map<String, dynamic> parkConfig,
    List<AiHistoryTurn> history = const [],
  }) {
    if (streamOverride != null) {
      return streamOverride!(
        parkSlug: parkSlug,
        message: message,
        history: history,
        parkConfig: parkConfig,
      );
    }
    return _askStream(
      parkSlug: parkSlug,
      message: message,
      parkConfig: parkConfig,
      history: history,
    );
  }

  Stream<AiStreamEvent> _askStream({
    required String parkSlug,
    required String message,
    required Map<String, dynamic> parkConfig,
    List<AiHistoryTurn> history = const [],
  }) async* {
    final cleanBase = baseUrl.trim().replaceAll(RegExp(r'/$'), '');
    if (cleanBase.isNotEmpty) {
      final client = http.Client();
      var streamedFromServer = false;
      try {
        final uri = Uri.parse('$cleanBase/qr-code/api/ai/chat');
        final request = http.Request('POST', uri)
          ..headers['Content-Type'] = 'application/json'
          ..headers['Accept'] = 'application/x-ndjson, application/json'
          ..body = jsonEncode({
            'parkSlug': parkSlug,
            'message': message,
            'history': history.map((h) => h.toJson()).toList(),
          });

        final response = await client
            .send(request)
            .timeout(const Duration(seconds: 20));
        if (response.statusCode >= 200 && response.statusCode < 300) {
          final lines = response.stream
              .transform(utf8.decoder)
              .transform(const LineSplitter());
          await for (final line in lines) {
            final trimmed = line.trim();
            if (trimmed.isEmpty) continue;
            final decoded = jsonDecode(trimmed);
            if (decoded is! Map) continue;
            final map = Map<String, dynamic>.from(decoded);
            final type = map['type']?.toString();
            switch (type) {
              case 'status':
                streamedFromServer = true;
                yield AiToolStatusEvent(
                  tool: map['tool']?.toString() ?? 'tool',
                  label: map['label']?.toString() ?? 'Checking park data…',
                );
              case 'chunk':
                final text = map['text']?.toString() ?? '';
                if (text.isNotEmpty) {
                  streamedFromServer = true;
                  yield AiTextChunkEvent(text);
                }
              case 'places':
                final items = (map['items'] as List? ?? const [])
                    .whereType<Map>()
                    .map(
                      (e) => AiSuggestedPlace.fromJson(
                        Map<String, dynamic>.from(e),
                      ),
                    )
                    .where((p) => p.name.isNotEmpty)
                    .toList(growable: false);
                if (items.isNotEmpty) {
                  streamedFromServer = true;
                  yield AiPlacesEvent(items);
                }
              case 'done':
                streamedFromServer = true;
                yield AiDoneEvent(mode: map['mode']?.toString() ?? 'genkit');
              case 'error':
                if (!streamedFromServer) break;
                yield AiErrorEvent(
                  map['message']?.toString() ?? 'AI request interrupted.',
                );
            }
          }
          if (streamedFromServer) return;
        }
      } catch (_) {
        // Fall through to resilient local tool-calling stream below.
      } finally {
        client.close();
      }
    }

    yield* _localToolCallingStream(message: message, parkConfig: parkConfig);
  }

  static String _pickVariant(String seed, List<String> options) {
    var hash = 0;
    for (final code in seed.codeUnits) {
      hash = (hash * 31 + code) & 0x7fffffff;
    }
    return options[hash % options.length];
  }

  /// Generates playful, Wonderla-only mascot banter for casual, personal, or
  /// silly questions (e.g. "Hi Chiku had your lunch?") instead of dumping tools.
  static String? tryChikuBanterReply({
    required String message,
    required Map<String, dynamic> parkConfig,
  }) {
    final lower = message.toLowerCase().trim();
    final parkName = parkConfig['name']?.toString().trim().isNotEmpty == true
        ? parkConfig['name'].toString().trim()
        : 'Wonderla';
    final diningList = _mapList(parkConfig['dining']);
    final ridesList = _mapList(parkConfig['rides']);
    final waveList = _mapList(parkConfig['waveRainDance']);
    final sampleDining =
        diningList.firstOrNull?['name']?.toString().trim().isNotEmpty == true
        ? diningList.first['name'].toString().trim()
        : 'Park View Restaurant';
    final sampleThrill =
        ridesList.firstOrNull?['title']?.toString().trim().isNotEmpty == true
        ? ridesList.first['title'].toString().trim()
        : 'Recoil';
    final sampleWater =
        waveList.firstOrNull?['title']?.toString().trim().isNotEmpty == true
        ? waveList.first['title'].toString().trim()
        : 'Wave Pool';

    final hasExplicitParkRequest = RegExp(
      r'(plan|itinerary|schedule|next \d|suggest|recommend|wait|queue|shortest|ride|coaster|kid|child|height|\d{2,3}\s*cm|direction|map|route|how to reach|where is|where can i|menu|veg|non-veg|restaurant|dining|biryani|price|wave pool|rain disco|show|event|timing|ticket|locker|swimwear|safety|guideline|maintenance)',
    ).hasMatch(lower);

    final asksChikuPersonalMeal =
        RegExp(
          r'(had your|have you had|did you eat|did u eat|had lunch|had breakfast|had dinner|had food|had tea|had coffee|u had|you eaten|are you hungry|eat anything|eating anything)',
        ).hasMatch(lower) &&
        !RegExp(
          r'(where|best|suggest|recommend|veg|menu|restaurant|direction|map|near)',
        ).hasMatch(lower);

    if (asksChikuPersonalMeal) {
      return _pickVariant(lower, [
        "Haha, I tried sneaking a crispy dosa near **$sampleWater**, got splashed by a giant wave, and now I'm running purely on **$sampleThrill** adrenaline! 😄 If *you're* hungry though, **$sampleDining** at **$parkName** has great food — want veg or non-veg suggestions?",
        "I had two loops of **$sampleThrill** for starters and a splash of **$sampleWater** for dessert — mascot diet! 😂 Seriously though, if your tummy's rumbling, ask me for the best food or directions to **$sampleDining** inside **$parkName**!",
      ]);
    }

    if (hasExplicitParkRequest) return null;

    if (RegExp(r'(joke|make me laugh|funny|comedy|laugh)').hasMatch(lower)) {
      return _pickVariant(lower, [
        "Why did the roller coaster at **$parkName** win Employee of the Month? Because it had way too many ups and downs and STILL never lost its track! 🎢😄 Want me to check which thrill ride has the shortest wait right now?",
        "Why did I bring sunglasses to the **$sampleWater**? Because **$parkName** rides are *way* too cool! 😎 Ready to plan your next rides or grab a bite at **$sampleDining**?",
      ]);
    }

    if (RegExp(
      r'(marry|married|wife|husband|girlfriend|boyfriend|\bgf\b|\bbf\b|single|love you|kiss|date me)',
    ).hasMatch(lower)) {
      return "Haha, slow down! My mascot heart is already taken by **$sampleThrill**, cotton candy, and the **$sampleWater**! 🎢💛 Let's channel that energy into a super fun day at **$parkName** — want a 3-hour ride plan?";
    }

    if (RegExp(r'(tired|sleepy|bored|boring|exhausted|hot|sweating)').hasMatch(lower)) {
      return "Feeling low on battery at **$parkName**? Two official Chiku prescriptions: cool off at **$sampleWater** or wake right up on **$sampleThrill**! ⚡ Want me to check live wait times or nearby snack spots?";
    }

    if (RegExp(
      r'(who are you|what is your name|your name|how old|your age|birthday|are you real|are you a bot|are you ai|where do you live|favorite ride|can you swim)',
    ).hasMatch(lower)) {
      return "I'm **Chiku**, **$parkName**'s unofficial Chief Fun Officer! 🎢 I live somewhere between **$sampleThrill** and **$sampleWater**, and my superpower is knowing live wait times, kid-height rides, yummy park food, and map directions. What should we explore first?";
    }

    if (RegExp(
      r'(thank|thx|awesome|super|nice|cute|good job|good boy|great|cool|bye|goodbye|see you|tata)',
    ).hasMatch(lower)) {
      return "Aww, you're making my mascot ears blush! 😄 Have an unforgettable, splash-filled day at **$parkName** — tap **Ask Chiku** anytime you need rides, queues, food, or directions! 🎢✨";
    }

    if (RegExp(
      r"^(hi+|hey+|hello+|hlo+|yo+|namaste|hola|sup|wassup|what'?s up|good morning|good afternoon|good evening|how are you|how r u|how are u|chiku|chicku)[\s!.,?]*((chiku|chicku|buddy|bro|friend|there|how are you|how r u)[\s!.,?]*)*$",
    ).hasMatch(lower)) {
      return _pickVariant(lower, [
        "Heyy! **Chiku** reporting live from **$parkName** with 100% roller-coaster energy! 🎢 Ask me to plan your rides, filter by kid height (like **110 cm**), find short queues, or guide you to **$sampleDining**!",
        "Hi there! I just survived a giant splash at **$sampleWater** and I'm ready to be your **$parkName** guide! 😄 Want thrill rides, family picks, live wait times, or tasty food directions?",
      ]);
    }

    return null;
  }

  Stream<AiStreamEvent> _localToolCallingStream({
    required String message,
    required Map<String, dynamic> parkConfig,
  }) async* {
    final banter = tryChikuBanterReply(
      message: message,
      parkConfig: parkConfig,
    );
    if (banter != null) {
      final words = RegExp(r'\S+\s*')
          .allMatches(banter)
          .map((m) => m.group(0)!)
          .toList();
      for (var i = 0; i < words.length; i += 4) {
        final end = (i + 4).clamp(0, words.length);
        yield AiTextChunkEvent(words.sublist(i, end).join());
        await Future<void>.delayed(const Duration(milliseconds: 16));
      }
      yield const AiDoneEvent(mode: 'local_tools');
      return;
    }

    final lower = message.toLowerCase();
    final parkName = parkConfig['name']?.toString().trim().isNotEmpty == true
        ? parkConfig['name'].toString().trim()
        : 'Wonderla';

    final heightMatch = RegExp(
      r'(\d{2,3})\s*(?:cm|centimeter)',
      caseSensitive: false,
    ).firstMatch(lower);
    final heightCm = heightMatch == null
        ? null
        : int.tryParse(heightMatch.group(1) ?? '');
    final hoursMatch = RegExp(
      r'(\d+)\s*(?:hr|hour)',
      caseSensitive: false,
    ).firstMatch(lower);
    final hours = hoursMatch == null
        ? null
        : (int.tryParse(hoursMatch.group(1) ?? '') ?? 3).clamp(1, 8);

    final asksPlan = RegExp(
      r'(plan|itinerary|today|schedule|next \d|suggest|recommend|start)',
    ).hasMatch(lower);
    final asksRides =
        RegExp(
          r'(ride|coaster|kid|child|thrill|water|height|cm)',
        ).hasMatch(lower) ||
        asksPlan;
    final asksWait =
        RegExp(
          r'(wait|queue|crowd|shortest|fast|quick|busy)',
        ).hasMatch(lower) ||
        asksPlan;
    final asksFood = RegExp(
      r'(food|eat|dining|restaurant|lunch|breakfast|veg|biryani|dosa|menu|snack|hungry)',
    ).hasMatch(lower);
    final asksMap = RegExp(
      r'(map|direction|where|locate|route|find|how to reach|how do i get|way to)',
    ).hasMatch(lower);
    final asksShows =
        RegExp(
          r'(wave|rain|show|event|parade|laser|timing|time)',
        ).hasMatch(lower) ||
        asksPlan;

    final rides = _mapList(parkConfig['rides']);
    final waits = _mapList(parkConfig['liveWaitTimes']);
    final dining = _mapList(parkConfig['dining']);
    final waves = _mapList(parkConfig['waveRainDance']);
    final events = _mapList(parkConfig['events']);
    final mapPlaces = _mapList((parkConfig['parkMap'] as Map?)?['places']);

    final places = <String, AiSuggestedPlace>{};
    final parts = <String>[];

    if (asksPlan) {
      parts.add(
        "Let's plan your ${hours != null ? 'next $hours hours' : 'day'} at **$parkName**! First, I'm checking available attractions, live wait times, and operating status.",
      );
    }

    final matchingRides = <Map<String, dynamic>>[];
    if (asksRides) {
      yield AiToolStatusEvent(
        tool: 'getParkRidesAndStatus',
        label: heightCm != null
            ? 'Checking rides safe for $heightCm cm & operating status…'
            : 'Checking available attractions & operating status…',
      );
      await Future<void>.delayed(const Duration(milliseconds: 90));

      for (final ride in rides) {
        final minCm = _estimateMinHeightCm(ride);
        if (heightCm == null || minCm <= heightCm) {
          final title = (ride['title'] ?? ride['name'] ?? '').toString();
          final wait = _findWait(waits, title);
          matchingRides.add({...ride, '_wait': wait, '_minCm': minCm});
        }
      }
      matchingRides.sort(
        (a, b) =>
            ((a['_wait'] as int?) ?? 999).compareTo((b['_wait'] as int?) ?? 999),
      );
      for (final r in matchingRides.take(3)) {
        final name = (r['title'] ?? r['name'] ?? '').toString();
        if (name.isNotEmpty) {
          final w = r['_wait'] as int?;
          places[name.toLowerCase()] = AiSuggestedPlace(
            name: name,
            category: 'Ride',
            imageUrl: r['img']?.toString(),
            subtitle: r['description']?.toString(),
            badge: w != null ? '$w min wait' : 'Ride',
            directions: r['directions']?.toString(),
            directionsUrl: r['directionsUrl']?.toString(),
            action: 'directions',
          );
        }
      }
    }

    final sortedWaits = [...waits]
      ..sort(
        (a, b) => (num.tryParse('${a['time']}') ?? 999).compareTo(
          num.tryParse('${b['time']}') ?? 999,
        ),
      );
    if (asksWait) {
      yield const AiToolStatusEvent(
        tool: 'getLiveWaitTimes',
        label: 'Checking live ride wait times…',
      );
      await Future<void>.delayed(const Duration(milliseconds: 70));
      for (final w in sortedWaits.take(3)) {
        final name = w['title']?.toString() ?? '';
        if (name.isNotEmpty && !places.containsKey(name.toLowerCase())) {
          final matchedRide = rides.firstWhere(
            (r) =>
                (r['title'] ?? r['name'] ?? '').toString().toLowerCase() ==
                name.toLowerCase(),
            orElse: () => const <String, dynamic>{},
          );
          places[name.toLowerCase()] = AiSuggestedPlace(
            name: name,
            category: 'Ride',
            imageUrl:
                w['img']?.toString().trim().isNotEmpty == true
                ? w['img']?.toString()
                : matchedRide['img']?.toString(),
            subtitle: w['description']?.toString(),
            badge: '${w['time']} min wait',
            directions: matchedRide['directions']?.toString(),
            directionsUrl: matchedRide['directionsUrl']?.toString(),
            action: 'directions',
          );
        }
      }
    }

    if (asksShows) {
      yield const AiToolStatusEvent(
        tool: 'getWaterAndEventSchedule',
        label: 'Checking Wave Pool, Rain Disco & show timings…',
      );
      await Future<void>.delayed(const Duration(milliseconds: 60));
      for (final w in waves.take(2)) {
        final name = w['title']?.toString() ?? '';
        if (name.isNotEmpty && !places.containsKey(name.toLowerCase())) {
          final slots = (w['timeSlot'] as List? ?? const []).join(', ');
          places[name.toLowerCase()] = AiSuggestedPlace(
            name: name,
            category: 'Water Ride',
            imageUrl: w['img']?.toString(),
            subtitle: slots.isNotEmpty ? 'Sessions: $slots' : 'Water session',
            badge: 'Water Ride',
            action: 'map',
          );
        }
      }
    }

    final matchedDining = <Map<String, dynamic>>[];
    if (asksFood) {
      final vegOnly = RegExp(r'(pure veg|\bveg\b|vegetarian)').hasMatch(lower);
      yield AiToolStatusEvent(
        tool: 'getDiningAndMenus',
        label: vegOnly
            ? 'Searching vegetarian restaurants & menus…'
            : 'Checking park restaurants & menus…',
      );
      await Future<void>.delayed(const Duration(milliseconds: 70));
      for (final d in dining) {
        final items = _mapList(d['items']);
        if (vegOnly && !items.any((i) => i['veg'] == true)) continue;
        matchedDining.add(d);
      }
      for (final d in matchedDining.take(3)) {
        final name = d['name']?.toString() ?? '';
        if (name.isNotEmpty) {
          final items = _mapList(d['items']);
          final isPureVeg =
              items.isNotEmpty && items.every((i) => i['veg'] == true);
          places[name.toLowerCase()] = AiSuggestedPlace(
            name: name,
            category: 'Dining',
            imageUrl: d['img']?.toString(),
            subtitle: d['cuisine']?.toString() ?? d['description']?.toString(),
            badge: isPureVeg ? 'Pure Veg' : 'Dining',
            directions: d['directions']?.toString(),
            directionsUrl: d['directionsUrl']?.toString(),
            action: 'directions',
          );
        }
      }
    }

    if (asksMap) {
      yield const AiToolStatusEvent(
        tool: 'getParkMapAndDirections',
        label: 'Looking up park map pins & CMS directions…',
      );
      await Future<void>.delayed(const Duration(milliseconds: 70));
      final candidates = [
        for (final d in dining)
          AiSuggestedPlace(
            name: d['name']?.toString() ?? '',
            category: 'Dining',
            imageUrl: d['img']?.toString(),
            subtitle: d['cuisine']?.toString() ?? d['directions']?.toString(),
            badge: 'Dining',
            directions: d['directions']?.toString(),
            directionsUrl: d['directionsUrl']?.toString(),
            action: 'directions',
          ),
        for (final p in mapPlaces)
          AiSuggestedPlace(
            name: p['name']?.toString() ?? '',
            category: p['category']?.toString() ?? 'Place',
            imageUrl: p['avatarImage']?.toString(),
            subtitle: p['directions']?.toString(),
            badge: p['category']?.toString() ?? 'Place',
            directions: p['directions']?.toString(),
            directionsUrl: p['directionsUrl']?.toString(),
            action: 'directions',
          ),
      ];
      final directHits = candidates
          .where((c) => c.name.isNotEmpty && lower.contains(c.name.toLowerCase()))
          .toList();
      final chosen = directHits.isNotEmpty
          ? directHits.take(3)
          : candidates.take(3);
      for (final p in chosen) {
        places[p.name.toLowerCase()] = p;
      }
    }

    if (heightCm != null && matchingRides.isNotEmpty) {
      final list = matchingRides
          .take(5)
          .map((r) {
            final title = (r['title'] ?? r['name'] ?? '').toString();
            final w = r['_wait'] as int?;
            final desc = r['description']?.toString() ?? '';
            return '• **$title**${w != null ? ' (~$w min wait)' : ''} — $desc';
          })
          .join('\n');
      parts.add(
        '\n**Rides suitable for $heightCm cm** (${matchingRides.length} operating):\n$list',
      );
    }

    if (asksPlan) {
      final slotCount = hours ?? 3;
      final plan = <String>[];
      if (matchingRides.isNotEmpty) {
        final r1 = matchingRides[0]['title'] ?? matchingRides[0]['name'];
        final r2 = matchingRides.length > 1
            ? (matchingRides[1]['title'] ?? matchingRides[1]['name'])
            : null;
        plan.add(
          '• **Hour 1 — Easy Start:** Begin with **$r1**${r2 != null ? ' and **$r2**' : ''} while queues are light.',
        );
      }
      if (slotCount >= 2) {
        if (waves.isNotEmpty) {
          final w = waves.first;
          final slots = (w['timeSlot'] as List? ?? const []).take(2).join(', ');
          plan.add(
            '• **Hour 2 — Splash Break:** Cool down at **${w['title']}**${slots.isNotEmpty ? ' ($slots)' : ''}.',
          );
        } else if (matchingRides.length > 2) {
          plan.add(
            '• **Hour 2 — Midday Highlights:** Ride **${matchingRides[2]['title']}**.',
          );
        }
      }
      if (slotCount >= 3) {
        final foodName = dining.isNotEmpty
            ? dining.first['name']?.toString()
            : 'the food court';
        final showText = events.isNotEmpty
            ? ' and catch **${events.first['title']}** (${events.first['time']})'
            : '';
        plan.add(
          '• **Hour 3 — Refuel & Showtime:** Grab lunch at **$foodName**$showText.',
        );
      }
      if (plan.isNotEmpty) {
        parts.add('\n**Suggested $slotCount-Hour Plan:**\n${plan.join('\n')}');
      }
    } else if (asksWait && sortedWaits.isNotEmpty && heightCm == null) {
      final waitList = sortedWaits
          .take(5)
          .map((w) => '• **${w['title']}** — **${w['time']} min**')
          .join('\n');
      parts.add('**Shortest Live Wait Times:**\n$waitList');
    }

    if (matchedDining.isNotEmpty) {
      final diningList = matchedDining.take(4).map((d) {
        final dir = d['directions']?.toString().trim() ?? '';
        return '• **${d['name']}** (${d['cuisine'] ?? 'Dining'})${dir.isNotEmpty ? ' — Directions: $dir' : ''}';
      }).join('\n');
      parts.add('\n**Recommended Restaurants:**\n$diningList');
    }

    if (asksShows && !asksPlan && (waves.isNotEmpty || events.isNotEmpty)) {
      final lines = [
        for (final w in waves)
          '• **${w['title']}**: ${(w['timeSlot'] as List? ?? const []).join(', ')} (${w['rideDuration'] ?? 20} min)',
        for (final e in events)
          '• **${e['title']}** at **${e['time']}** — ${e['description'] ?? ''}',
      ];
      parts.add('**Timings & Shows:**\n${lines.join('\n')}');
    }

    if (asksMap && places.isNotEmpty) {
      parts.add(
        '\n**Directions Ready:** Tap any destination chip below to open directions directly on the map.',
      );
    }

    if (parts.isEmpty) {
      parts.add(
        _pickVariant(lower, [
          "Haha, you stumped me! My little mascot brain is 99% roller-coaster loops and 1% Wave Pool splashes — I only know **$parkName** secrets! 🎢 Ask me to plan your rides, check live wait times, find kid-safe rides (like **110 cm**), or guide you to park restaurants!",
          "Whoa, that's way above my roller-coaster pay grade! 😄 I'm **Chiku**, and I only talk **$parkName** — thrill rides, water splashes, shortest queues, yummy park food, and map directions. What shall we do next?",
        ]),
      );
    }

    final fullText = parts.join('\n').trim();
    final words = RegExp(r'\S+\s*').allMatches(fullText).map((m) => m.group(0)!).toList();
    for (var i = 0; i < words.length; i += 4) {
      final end = (i + 4).clamp(0, words.length);
      yield AiTextChunkEvent(words.sublist(i, end).join());
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }

    if (places.isNotEmpty) {
      yield AiPlacesEvent(places.values.take(4).toList(growable: false));
    }
    yield const AiDoneEvent(mode: 'local_tools');
  }

  static List<Map<String, dynamic>> _mapList(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);
  }

  static int _estimateMinHeightCm(Map<String, dynamic> ride) {
    final explicit = RegExp(
      r'(\d{2,3})\s*cm',
      caseSensitive: false,
    ).firstMatch(ride['minHeight']?.toString() ?? '');
    if (explicit != null) {
      return int.tryParse(explicit.group(1) ?? '') ?? 105;
    }
    final text =
        '${ride['title'] ?? ''} ${ride['description'] ?? ''} ${(ride['tags'] as List? ?? const []).join(' ')}'
            .toLowerCase();
    if (RegExp(
      r'(kiddie|kids|mini|carousel|flying jumbo|magic mushroom|funky monkey|toy train)',
    ).hasMatch(text)) {
      return 85;
    }
    if (RegExp(
      r'(lazy river|jungle lagoon|wave pool|fun racers|uphill racers|family|crazy cars|rain disco)',
    ).hasMatch(text)) {
      return 100;
    }
    if (RegExp(
      r'(recoil|drop loop|boomerang|harakiri|mission interstellar|maverick|g-fall|drop zone|high thrill|roller coaster)',
    ).hasMatch(text)) {
      return 135;
    }
    return 105;
  }

  static int? _findWait(List<Map<String, dynamic>> waits, String rideTitle) {
    final target = rideTitle.toLowerCase().trim();
    for (final w in waits) {
      final t = w['title']?.toString().toLowerCase().trim() ?? '';
      if (t == target || t.contains(target) || target.contains(t)) {
        return num.tryParse('${w['time']}')?.round();
      }
    }
    return null;
  }
}
