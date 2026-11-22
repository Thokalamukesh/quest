import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Actionable park place suggested by a Genkit tool call so visitors can jump
/// straight to map pins or CMS-configured directions.
class AiSuggestedPlace {
  const AiSuggestedPlace({
    required this.name,
    required this.category,
    this.directions,
    this.directionsUrl,
    this.action = 'map',
  });

  final String name;
  final String category;
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

  Stream<AiStreamEvent> _localToolCallingStream({
    required String message,
    required Map<String, dynamic> parkConfig,
  }) async* {
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
          r'(ride|coaster|kid|child|thrill|water|height|cm|\bdo\b)',
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
          places[name.toLowerCase()] = AiSuggestedPlace(
            name: name,
            category: 'Ride',
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
    }

    if (asksShows) {
      yield const AiToolStatusEvent(
        tool: 'getWaterAndEventSchedule',
        label: 'Checking Wave Pool, Rain Disco & show timings…',
      );
      await Future<void>.delayed(const Duration(milliseconds: 60));
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
          places[name.toLowerCase()] = AiSuggestedPlace(
            name: name,
            category: 'Dining',
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
            directions: d['directions']?.toString(),
            directionsUrl: d['directionsUrl']?.toString(),
            action: 'directions',
          ),
        for (final p in mapPlaces)
          AiSuggestedPlace(
            name: p['name']?.toString() ?? '',
            category: p['category']?.toString() ?? 'Place',
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
        "Hi! I'm **Chiku**, your **$parkName** buddy! Ask me things like **\"Which rides for my 110 cm kid & plan next 3 hours?\"**, **\"Shortest wait rides\"**, or **\"Directions to Park View Restaurant\"**.",
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
