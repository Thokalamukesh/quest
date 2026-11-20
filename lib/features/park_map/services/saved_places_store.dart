import 'package:flutter/foundation.dart';

/// Lightweight in-memory store for a visitor's "My Day" saved rides, dining,
/// and completed ride checklist, scoped per park slug.
class SavedPlacesStore extends ChangeNotifier {
  SavedPlacesStore._();

  static final SavedPlacesStore instance = SavedPlacesStore._();

  final Map<String, Set<String>> _savedByPark = {};
  final Map<String, Set<String>> _completedByPark = {};

  String _norm(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

  Set<String> savedKeys(String parkSlug) =>
      Set.unmodifiable(_savedByPark[parkSlug] ?? const <String>{});

  Set<String> completedKeys(String parkSlug) =>
      Set.unmodifiable(_completedByPark[parkSlug] ?? const <String>{});

  int savedCount(String parkSlug) => _savedByPark[parkSlug]?.length ?? 0;

  bool isSaved(String parkSlug, String placeName) {
    final key = _norm(placeName);
    if (key.isEmpty) return false;
    return _savedByPark[parkSlug]?.contains(key) ?? false;
  }

  bool isCompleted(String parkSlug, String placeName) {
    final key = _norm(placeName);
    if (key.isEmpty) return false;
    return _completedByPark[parkSlug]?.contains(key) ?? false;
  }

  bool toggleSaved(String parkSlug, String placeName) {
    final key = _norm(placeName);
    if (key.isEmpty) return false;
    final set = _savedByPark.putIfAbsent(parkSlug, () => <String>{});
    final added = set.add(key);
    if (!added) set.remove(key);
    notifyListeners();
    return added;
  }

  bool toggleCompleted(String parkSlug, String placeName) {
    final key = _norm(placeName);
    if (key.isEmpty) return false;
    final set = _completedByPark.putIfAbsent(parkSlug, () => <String>{});
    final added = set.add(key);
    if (!added) set.remove(key);
    notifyListeners();
    return added;
  }

  void clearPark(String parkSlug) {
    _savedByPark.remove(parkSlug);
    _completedByPark.remove(parkSlug);
    notifyListeners();
  }
}
