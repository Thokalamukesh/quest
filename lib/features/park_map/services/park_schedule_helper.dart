import 'package:flutter/material.dart';

/// Represents an upcoming real event or water activity session parsed from
/// the park's CMS `events` or `waveRainDance` arrays.
class UpcomingParkActivity {
  const UpcomingParkActivity({
    required this.title,
    required this.timeLabel,
    required this.isWaterActivity,
    required this.minutesUntilStart,
    this.durationMinutes,
  });

  final String title;
  final String timeLabel;
  final bool isWaterActivity;
  final int minutesUntilStart;
  final int? durationMinutes;

  String get countdownLabel {
    if (minutesUntilStart <= 0) return 'Starting now';
    if (minutesUntilStart < 60) return 'In $minutesUntilStart min';
    final hours = minutesUntilStart ~/ 60;
    final mins = minutesUntilStart % 60;
    return mins == 0 ? 'In ${hours}h' : 'In ${hours}h ${mins}m';
  }
}

class ShortestWaitHighlight {
  const ShortestWaitHighlight({required this.title, required this.minutes});

  final String title;
  final int minutes;
}

/// Pure helpers that derive live schedule highlights strictly from the park's
/// real CMS configuration (`events`, `waveRainDance`, `liveWaitTimes`).
abstract final class ParkScheduleHelper {
  /// Returns the next upcoming event or water activity for today (or the
  /// earliest scheduled session if all today's sessions have already passed).
  static UpcomingParkActivity? nextActivity(
    Map<String, dynamic> config, {
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    final currentMinutes = clock.hour * 60 + clock.minute;
    final candidates = <({UpcomingParkActivity item, int slotMinutes})>[];

    final events = config['events'];
    if (events is List) {
      for (final raw in events.whereType<Map>()) {
        final title = (raw['title'] ?? raw['name'] ?? '').toString().trim();
        final timeStr = raw['time']?.toString().trim() ?? '';
        final parsed = parseTimeOfDayMinutes(timeStr);
        if (title.isEmpty || parsed == null) continue;
        candidates.add((
          item: UpcomingParkActivity(
            title: title,
            timeLabel: timeStr,
            isWaterActivity: false,
            minutesUntilStart: parsed - currentMinutes,
          ),
          slotMinutes: parsed,
        ));
      }
    }

    final waves = config['waveRainDance'];
    if (waves is List) {
      for (final raw in waves.whereType<Map>()) {
        final title = (raw['title'] ?? raw['name'] ?? '').toString().trim();
        final slots = raw['timeSlot'];
        final duration = raw['rideDuration'] is num
            ? (raw['rideDuration'] as num).round()
            : int.tryParse('${raw['rideDuration']}');
        if (title.isEmpty || slots is! List) continue;
        for (final slot in slots) {
          final timeStr = slot.toString().trim();
          final parsed = parseTimeOfDayMinutes(timeStr);
          if (parsed == null) continue;
          candidates.add((
            item: UpcomingParkActivity(
              title: title,
              timeLabel: timeStr,
              isWaterActivity: true,
              minutesUntilStart: parsed - currentMinutes,
              durationMinutes: duration,
            ),
            slotMinutes: parsed,
          ));
        }
      }
    }

    if (candidates.isEmpty) return null;

    // Prefer upcoming sessions (including those that started within last 10m).
    final upcoming = candidates
        .where((c) => c.slotMinutes >= currentMinutes - 10)
        .toList()
      ..sort((a, b) => a.slotMinutes.compareTo(b.slotMinutes));

    if (upcoming.isNotEmpty) return upcoming.first.item;

    // All sessions finished for today: show tomorrow's first session.
    candidates.sort((a, b) => a.slotMinutes.compareTo(b.slotMinutes));
    final first = candidates.first;
    return UpcomingParkActivity(
      title: first.item.title,
      timeLabel: first.item.timeLabel,
      isWaterActivity: first.item.isWaterActivity,
      minutesUntilStart: (24 * 60 - currentMinutes) + first.slotMinutes,
      durationMinutes: first.item.durationMinutes,
    );
  }

  /// Finds the index of the next upcoming time slot in a list of formatted
  /// session strings (e.g. `["12:00 PM", "01:00 PM", "02:00 PM"]`).
  static int? nextSlotIndex(List<String> slots, {DateTime? now}) {
    final clock = now ?? DateTime.now();
    final currentMinutes = clock.hour * 60 + clock.minute;
    int? bestIndex;
    int? bestSlotMinutes;
    for (var i = 0; i < slots.length; i++) {
      final parsed = parseTimeOfDayMinutes(slots[i]);
      if (parsed == null || parsed < currentMinutes - 10) continue;
      if (bestSlotMinutes == null || parsed < bestSlotMinutes) {
        bestSlotMinutes = parsed;
        bestIndex = i;
      }
    }
    return bestIndex;
  }

  /// Finds the ride with the shortest real live wait time in `liveWaitTimes`.
  static ShortestWaitHighlight? shortestWait(Map<String, dynamic> config) {
    final waits = config['liveWaitTimes'];
    if (waits is! List) return null;
    ShortestWaitHighlight? best;
    for (final raw in waits.whereType<Map>()) {
      final title = (raw['title'] ?? raw['name'] ?? '').toString().trim();
      final minutes = raw['time'] is num
          ? (raw['time'] as num).round()
          : int.tryParse('${raw['time']}');
      if (title.isEmpty || minutes == null || minutes < 0) continue;
      if (best == null || minutes < best.minutes) {
        best = ShortestWaitHighlight(title: title, minutes: minutes);
      }
    }
    return best;
  }

  /// Parses strings like `"12:00 PM"`, `"04:30 PM"`, `"7:00 pm"`, `"14:30"`
  /// into minutes since midnight. Returns null if unparseable.
  static int? parseTimeOfDayMinutes(String raw) {
    final match = RegExp(
      r'^(\d{1,2})(?::(\d{2}))?\s*(AM|PM)?$',
      caseSensitive: false,
    ).firstMatch(raw.trim());
    if (match == null) return null;
    var hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2) ?? '0');
    final period = match.group(3)?.toUpperCase();
    if (hour == null || minute == null || minute < 0 || minute > 59) {
      return null;
    }
    if (period != null) {
      if (hour < 1 || hour > 12) return null;
      if (period == 'AM') {
        hour = hour == 12 ? 0 : hour;
      } else {
        hour = hour == 12 ? 12 : hour + 12;
      }
    } else if (hour < 0 || hour > 23) {
      return null;
    }
    return hour * 60 + minute;
  }

  static IconData iconFor(UpcomingParkActivity activity) =>
      activity.isWaterActivity
      ? Icons.waves_rounded
      : Icons.celebration_rounded;
}
