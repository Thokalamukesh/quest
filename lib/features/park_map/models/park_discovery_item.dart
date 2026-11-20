import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../shared/wonderla_palette.dart';
import 'map_place.dart';
import 'wonderla_location_catalog.dart';

/// Supported park discovery categories with Wonderla-branded styling.
/// Only categories backed by real records in the active park are displayed.
enum ParkDiscoveryCategory {
  thrillRides(
    label: 'Thrill Rides',
    shortLabel: 'Thrill',
    icon: LucideIcons.ferrisWheel,
    color: wonderlaCobalt,
    tintColor: Color(0xFFE8F0FE),
  ),
  familyRides(
    label: 'Family Rides',
    shortLabel: 'Family',
    icon: Icons.groups_rounded,
    color: Color(0xFF0D9488),
    tintColor: Color(0xFFE6F7F5),
  ),
  kidsRides(
    label: 'Kids Rides',
    shortLabel: 'Kids',
    icon: Icons.child_care_rounded,
    color: Color(0xFFEA580C),
    tintColor: Color(0xFFFFF1E6),
  ),
  waterRides(
    label: 'Water Rides',
    shortLabel: 'Water',
    icon: LucideIcons.waves,
    color: Color(0xFF0284C7),
    tintColor: Color(0xFFE6F6FE),
  ),
  restaurants(
    label: 'Restaurants',
    shortLabel: 'Dining',
    icon: LucideIcons.utensils,
    color: Color(0xFFD97706),
    tintColor: Color(0xFFFEF3C7),
  ),
  foodAndBeverages(
    label: 'Food & Beverages',
    shortLabel: 'Food',
    icon: Icons.local_cafe_rounded,
    color: Color(0xFFC2410C),
    tintColor: Color(0xFFFFEDD5),
  ),
  restrooms(
    label: 'Restrooms',
    shortLabel: 'Restrooms',
    icon: Icons.wc_rounded,
    color: Color(0xFF475569),
    tintColor: Color(0xFFF1F5F9),
  ),
  facilities(
    label: 'Facilities',
    shortLabel: 'Facility',
    icon: Icons.local_hospital_rounded,
    color: wonderlaSuccess,
    tintColor: Color(0xFFE6F5EE),
  ),
  attractions(
    label: 'Attractions',
    shortLabel: 'Attraction',
    icon: Icons.auto_awesome_rounded,
    color: wonderlaNavy,
    tintColor: Color(0xFFEAF0FA),
  );

  const ParkDiscoveryCategory({
    required this.label,
    required this.shortLabel,
    required this.icon,
    required this.color,
    required this.tintColor,
  });

  final String label;
  final String shortLabel;
  final IconData icon;
  final Color color;
  final Color tintColor;
}

/// Enriched, immutable view model for a park map destination or attraction.
/// Preserves the exact original raw maps and identifiers from the CMS/OSM API.
class ParkDiscoveryItem {
  const ParkDiscoveryItem({
    required this.id,
    required this.name,
    required this.rawCategory,
    required this.category,
    required this.icon,
    required this.rawPlace,
    required this.searchIndex,
    this.position,
    this.mapX,
    this.mapY,
    this.imageUrl = '',
    this.description = '',
    this.cuisine,
    this.tags = const [],
    this.waitTimeMinutes,
    this.minHeight,
    this.operatingStatus,
    this.lastServiceDate,
    this.serviceChecks,
    this.sessionTimeSlots = const [],
    this.sessionDurationMinutes,
    this.kioskBookingEnabled = false,
    this.menuItems = const [],
    this.zoneName,
    this.address,
    this.rawRide,
    this.rawDining,
    this.rawWaitTime,
    this.rawWaveSession,
    this.rawMaintenance,
    this.osmPlace,
  });

  final String id;
  final String name;
  final String rawCategory;
  final ParkDiscoveryCategory category;
  final IconData icon;
  final Map<String, dynamic> rawPlace;
  final String searchIndex;

  final LatLng? position;
  final double? mapX;
  final double? mapY;
  final String imageUrl;
  final String description;
  final String? cuisine;
  final List<String> tags;
  final int? waitTimeMinutes;
  final String? minHeight;
  final String? operatingStatus;
  final String? lastServiceDate;
  final String? serviceChecks;
  final List<String> sessionTimeSlots;
  final int? sessionDurationMinutes;
  final bool kioskBookingEnabled;
  final List<Map<String, dynamic>> menuItems;
  final String? zoneName;
  final String? address;

  final Map<String, dynamic>? rawRide;
  final Map<String, dynamic>? rawDining;
  final Map<String, dynamic>? rawWaitTime;
  final Map<String, dynamic>? rawWaveSession;
  final Map<String, dynamic>? rawMaintenance;
  final MapPlace? osmPlace;

  bool get hasGpsCoordinates => position != null;
  bool get hasIllustratedCoords =>
      mapX != null && mapY != null && mapX! >= 0 && mapX! <= 100 && mapY! >= 0 && mapY! <= 100;
  bool get isDining =>
      rawDining != null ||
      category == ParkDiscoveryCategory.restaurants ||
      category == ParkDiscoveryCategory.foodAndBeverages;
  bool get isWaterActivity =>
      rawWaveSession != null || category == ParkDiscoveryCategory.waterRides;
  bool get isRide =>
      rawRide != null ||
      category == ParkDiscoveryCategory.thrillRides ||
      category == ParkDiscoveryCategory.familyRides ||
      category == ParkDiscoveryCategory.kidsRides ||
      category == ParkDiscoveryCategory.waterRides;
}

class ParkZoneInfo {
  const ParkZoneInfo({required this.name, required this.description});

  final String name;
  final String description;
}

/// Pre-indexed, cached catalog of a park's real map places and cross-referenced
/// ride, wait-time, dining, maintenance, and water-activity metadata.
class ParkDiscoveryCatalog {
  ParkDiscoveryCatalog({
    required this.items,
    required this.zones,
    required this.mapImageUrl,
    required this.mapDescription,
  }) : categoryCounts = _computeCategoryCounts(items),
       availableCategories = _computeAvailableCategories(items);

  final List<ParkDiscoveryItem> items;
  final List<ParkZoneInfo> zones;
  final String mapImageUrl;
  final String mapDescription;
  final Map<ParkDiscoveryCategory, int> categoryCounts;
  final List<ParkDiscoveryCategory> availableCategories;

  bool get hasIllustratedMap =>
      mapImageUrl.isNotEmpty && items.any((item) => item.hasIllustratedCoords);
  bool get hasAnyWaitTimes => items.any((item) => item.waitTimeMinutes != null);
  bool get hasAnyKioskBooking => items.any((item) => item.kioskBookingEnabled);
  bool get hasMixedCoordinates =>
      items.any((item) => item.hasGpsCoordinates) &&
      items.any((item) => !item.hasGpsCoordinates);

  /// Fast, allocation-light local filtering with zero API calls.
  List<ParkDiscoveryItem> filter({
    String query = '',
    Set<ParkDiscoveryCategory> categories = const {},
    String? zoneName,
    bool shortWaitOnly = false,
    bool directionsReadyOnly = false,
    bool kioskBookingOnly = false,
  }) {
    final normalizedQuery = query.trim().toLowerCase();
    final normalizedZone = zoneName?.trim().toLowerCase();
    return items
        .where((item) {
          if (categories.isNotEmpty && !categories.contains(item.category)) {
            return false;
          }
          if (normalizedZone != null && normalizedZone.isNotEmpty) {
            final itemZone = item.zoneName?.toLowerCase() ?? '';
            if (itemZone != normalizedZone) return false;
          }
          if (shortWaitOnly &&
              (item.waitTimeMinutes == null || item.waitTimeMinutes! > 15)) {
            return false;
          }
          if (directionsReadyOnly && !item.hasGpsCoordinates) {
            return false;
          }
          if (kioskBookingOnly && !item.kioskBookingEnabled) {
            return false;
          }
          if (normalizedQuery.isNotEmpty &&
              !item.searchIndex.contains(normalizedQuery)) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
  }

  /// Builds a cached discovery catalog directly from a CMS park configuration.
  factory ParkDiscoveryCatalog.fromParkConfig(
    Map<String, dynamic> config, {
    required String baseUrl,
    required bool isBengaluruPark,
  }) {
    final parkMap = Map<String, dynamic>.from(
      config['parkMap'] as Map? ?? const {},
    );
    final rawPlaces = _mapList(parkMap['places']);
    final rides = _mapList(config['rides']);
    final dining = _mapList(config['dining']);
    final waitTimes = _mapList(config['liveWaitTimes']);
    final waveSessions = _mapList(config['waveRainDance']);
    final maintenance = _mapList(config['maintenanceLog']);
    final guidelines = _mapList(config['rideGuidelines']);
    final rawZones = _mapList(parkMap['zones']);

    final zones = rawZones
        .map(
          (z) => ParkZoneInfo(
            name: z['name']?.toString().trim() ?? '',
            description: z['description']?.toString().trim() ?? '',
          ),
        )
        .where((z) => z.name.isNotEmpty)
        .toList(growable: false);

    final ridesByName = _indexByName(rides, const ['title', 'name']);
    final diningByName = _indexByName(dining, const ['name', 'title']);
    final waitsByName = _indexByName(waitTimes, const ['title', 'name']);
    final wavesByName = _indexByName(waveSessions, const ['title', 'name']);
    final maintByName = _indexByName(maintenance, const ['ride', 'title', 'name']);
    final guidelinesByName = _indexByName(guidelines, const ['title', 'ride', 'name']);

    final items = <ParkDiscoveryItem>[];
    for (var index = 0; index < rawPlaces.length; index++) {
      final place = rawPlaces[index];
      final name = place['name']?.toString().trim() ?? 'Park place';
      final rawCategory = place['category']?.toString().trim() ?? 'Park place';
      final norm = normalizePlaceName(name);

      final matchedRide = _lookupFuzzy(ridesByName, norm);
      final matchedDining = _lookupFuzzy(diningByName, norm);
      final matchedWait = _lookupFuzzy(waitsByName, norm);
      final matchedWave = _lookupFuzzy(wavesByName, norm);
      final matchedMaint = _lookupFuzzy(maintByName, norm);
      final matchedGuideline = _lookupFuzzy(guidelinesByName, norm);

      final category = classifyPlace(
        name: name,
        rawCategory: rawCategory,
        matchedRide: matchedRide,
        matchedDining: matchedDining,
        matchedWave: matchedWave,
      );

      final position = _resolvePosition(
        place,
        isBengaluruPark: isBengaluruPark,
      );
      final mapX = _tryDouble(place['x']);
      final mapY = _tryDouble(place['y']);

      final imagePath = _firstNonEmpty([
        place['avatarImage']?.toString(),
        place['img']?.toString(),
        matchedRide?['img']?.toString(),
        matchedDining?['img']?.toString(),
        matchedWait?['img']?.toString(),
        matchedWave?['img']?.toString(),
      ]);
      final imageUrl = resolveMediaUrl(imagePath, baseUrl);

      final description = _firstNonEmpty([
        place['description']?.toString(),
        matchedRide?['description']?.toString(),
        matchedDining?['description']?.toString(),
        matchedWait?['description']?.toString(),
      ]);

      final tags = <String>[
        ..._stringList(place['tags']),
        ..._stringList(matchedRide?['tags']),
        ..._stringList(matchedDining?['tags']),
      ];
      final uniqueTags = {for (final t in tags) t.toLowerCase(): t}.values
          .toList(growable: false);

      final waitMinutes =
          _tryInt(place['waitTime']) ?? _tryInt(matchedWait?['time']);

      final minHeight = _firstNonEmptyOrNull([
        place['minHeight']?.toString(),
        matchedRide?['minHeight']?.toString(),
        matchedGuideline?['minHeight']?.toString(),
      ]);

      final operatingStatus = _firstNonEmptyOrNull([
        place['status']?.toString(),
        matchedRide?['status']?.toString(),
      ]);

      final lastServiceDate = _firstNonEmptyOrNull([
        matchedMaint?['lastService']?.toString(),
      ]);
      final serviceChecks = _firstNonEmptyOrNull([
        matchedMaint?['checks']?.toString(),
      ]);

      final timeSlots = _stringList(matchedWave?['timeSlot']);
      final sessionDuration = _tryInt(matchedWave?['rideDuration']);

      final kioskBookingEnabled =
          place['kioskBookingEnabled'] == true ||
          matchedRide?['kioskBookingEnabled'] == true;

      final menuItems = _mapList(matchedDining?['items']);
      final cuisine = _firstNonEmptyOrNull([
        matchedDining?['cuisine']?.toString(),
      ]);

      final zoneName = _resolveZoneName(
        explicitZone: place['zone']?.toString(),
        category: category,
        zones: zones,
      );

      final stableId = _firstNonEmpty([
        place['id']?.toString(),
        place['rideId']?.toString(),
        place['productId']?.toString(),
        '$norm-$index',
      ]);

      final searchParts = [
        name,
        rawCategory,
        category.label,
        description,
        cuisine ?? '',
        zoneName ?? '',
        ...uniqueTags,
      ].join(' ').toLowerCase();

      items.add(
        ParkDiscoveryItem(
          id: stableId,
          name: name,
          rawCategory: rawCategory,
          category: category,
          icon: resolveMarkerIcon(
            category: category,
            name: name,
            rawCategory: rawCategory,
          ),
          rawPlace: place,
          searchIndex: searchParts,
          position: position,
          mapX: mapX,
          mapY: mapY,
          imageUrl: imageUrl,
          description: description,
          cuisine: cuisine,
          tags: uniqueTags,
          waitTimeMinutes: waitMinutes,
          minHeight: minHeight,
          operatingStatus: operatingStatus,
          lastServiceDate: lastServiceDate,
          serviceChecks: serviceChecks,
          sessionTimeSlots: timeSlots,
          sessionDurationMinutes: sessionDuration,
          kioskBookingEnabled: kioskBookingEnabled,
          menuItems: menuItems,
          zoneName: zoneName,
          rawRide: matchedRide,
          rawDining: matchedDining,
          rawWaitTime: matchedWait,
          rawWaveSession: matchedWave,
          rawMaintenance: matchedMaint,
        ),
      );
    }

    return ParkDiscoveryCatalog(
      items: items,
      zones: zones,
      mapImageUrl: resolveMediaUrl(parkMap['img']?.toString(), baseUrl),
      mapDescription: parkMap['description']?.toString().trim() ?? '',
    );
  }

  /// Builds a discovery item directly from a ride entry in `config['rides']`
  /// so Attractions Discovery cards share the same rich detail sheet as the map.
  static ParkDiscoveryItem fromRideEntry(
    Map<String, dynamic> ride, {
    required Map<String, dynamic> config,
    required String baseUrl,
  }) {
    final title = (ride['title'] ?? ride['name'] ?? 'Ride').toString().trim();
    final norm = normalizePlaceName(title);
    final waitTimes = _indexByName(
      _mapList(config['liveWaitTimes']),
      const ['title', 'name'],
    );
    final waves = _indexByName(
      _mapList(config['waveRainDance']),
      const ['title', 'name'],
    );
    final maint = _indexByName(
      _mapList(config['maintenanceLog']),
      const ['ride', 'title', 'name'],
    );
    final parkMap = Map<String, dynamic>.from(
      config['parkMap'] as Map? ?? const {},
    );
    final places = _indexByName(
      _mapList(parkMap['places']),
      const ['name', 'title'],
    );

    final matchedPlace = _lookupFuzzy(places, norm);
    final matchedWait = _lookupFuzzy(waitTimes, norm);
    final matchedWave = _lookupFuzzy(waves, norm);
    final matchedMaint = _lookupFuzzy(maint, norm);

    final rawCategory =
        matchedPlace?['category']?.toString().trim() ??
        inferRideCategoryLabel(ride);
    final category = classifyPlace(
      name: title,
      rawCategory: rawCategory,
      matchedRide: ride,
      matchedWave: matchedWave,
    );

    final imageUrl = resolveMediaUrl(
      _firstNonEmpty([
        ride['img']?.toString(),
        matchedWait?['img']?.toString(),
        matchedPlace?['avatarImage']?.toString(),
      ]),
      baseUrl,
    );

    final tags = _stringList(ride['tags']);
    final waitMinutes = _tryInt(matchedWait?['time']);

    return ParkDiscoveryItem(
      id: _firstNonEmpty([
        ride['id']?.toString(),
        ride['rideId']?.toString(),
        ride['productId']?.toString(),
        norm,
      ]),
      name: title,
      rawCategory: rawCategory,
      category: category,
      icon: resolveMarkerIcon(
        category: category,
        name: title,
        rawCategory: rawCategory,
      ),
      rawPlace: matchedPlace ?? ride,
      searchIndex: '$title $rawCategory ${category.label} ${ride['description'] ?? ''} ${tags.join(' ')}'
          .toLowerCase(),
      position: matchedPlace == null
          ? null
          : _resolvePosition(matchedPlace, isBengaluruPark: true),
      mapX: matchedPlace == null ? null : _tryDouble(matchedPlace['x']),
      mapY: matchedPlace == null ? null : _tryDouble(matchedPlace['y']),
      imageUrl: imageUrl,
      description: ride['description']?.toString().trim() ?? '',
      tags: tags,
      waitTimeMinutes: waitMinutes,
      minHeight: _firstNonEmptyOrNull([
        ride['minHeight']?.toString(),
        matchedPlace?['minHeight']?.toString(),
      ]),
      operatingStatus: _firstNonEmptyOrNull([ride['status']?.toString()]),
      lastServiceDate: _firstNonEmptyOrNull([
        matchedMaint?['lastService']?.toString(),
      ]),
      serviceChecks: _firstNonEmptyOrNull([
        matchedMaint?['checks']?.toString(),
      ]),
      sessionTimeSlots: _stringList(matchedWave?['timeSlot']),
      sessionDurationMinutes: _tryInt(matchedWave?['rideDuration']),
      kioskBookingEnabled: ride['kioskBookingEnabled'] == true,
      rawRide: ride,
      rawWaitTime: matchedWait,
      rawWaveSession: matchedWave,
      rawMaintenance: matchedMaint,
    );
  }

  /// Builds a discovery catalog from OpenStreetMap `MapPlace` objects
  /// used by the standalone Bengaluru `ParkMapScreen`.
  factory ParkDiscoveryCatalog.fromMapPlaces(List<MapPlace> places) {
    final items = places
        .map((place) {
          final category = classifyOsmPlace(place);
          return ParkDiscoveryItem(
            id: place.id,
            name: place.name,
            rawCategory: place.kind,
            category: category,
            icon: place.icon,
            rawPlace: {
              'id': place.id,
              'name': place.name,
              'category': place.kind,
              'lat': place.position.latitude,
              'lng': place.position.longitude,
            },
            searchIndex:
                '${place.name} ${place.kind} ${category.label} ${place.address ?? ''}'
                    .toLowerCase(),
            position: place.position,
            address: place.address,
            osmPlace: place,
          );
        })
        .toList(growable: false);

    return ParkDiscoveryCatalog(
      items: items,
      zones: const [],
      mapImageUrl: '',
      mapDescription: '',
    );
  }

  static String normalizePlaceName(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

  static String resolveMediaUrl(String? value, String baseUrl) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return '';
    if (Uri.tryParse(trimmed)?.hasScheme == true) return trimmed;
    final cleanBase = baseUrl.trim().replaceAll(RegExp(r'/$'), '');
    if (cleanBase.isEmpty) return '';
    return '$cleanBase${trimmed.startsWith('/') ? '' : '/'}$trimmed';
  }

  static String inferRideCategoryLabel(Map<String, dynamic> ride) {
    final text =
        '${ride['title'] ?? ''} ${ride['description'] ?? ''} ${_stringList(ride['tags']).join(' ')}'
            .toLowerCase();
    if (_containsAny(text, const [
      'water',
      'wave',
      'river',
      'lagoon',
      'splash',
      'rain',
      'slide',
      'floats',
      'rubber mat',
    ])) {
      return 'Water ride';
    }
    if (_containsAny(text, const [
      'kiddie',
      'children',
      'mini ferris',
      'toy train',
      'mini drop',
      'carousel',
      'flying elephant',
      'garden theme',
    ])) {
      return 'Kids ride';
    }
    if (_containsAny(text, const ['family', 'gentle'])) {
      return 'Family ride';
    }
    return 'Thrill ride';
  }

  static ParkDiscoveryCategory classifyPlace({
    required String name,
    required String rawCategory,
    Map<String, dynamic>? matchedRide,
    Map<String, dynamic>? matchedDining,
    Map<String, dynamic>? matchedWave,
  }) {
    final cat = rawCategory.trim().toLowerCase();
    final lowerName = name.trim().toLowerCase();
    final rideTags = _stringList(matchedRide?['tags']).join(' ').toLowerCase();
    final rideDesc = (matchedRide?['description']?.toString() ?? '').toLowerCase();

    if (_containsAny(cat, const ['restroom', 'toilet', 'washroom', 'wc']) ||
        _containsAny(lowerName, const ['restroom', 'toilet', 'washroom'])) {
      return ParkDiscoveryCategory.restrooms;
    }

    if (matchedWave != null ||
        _containsAny(cat, const ['water', 'pool', 'rain', 'splash']) ||
        _containsAny(lowerName, const [
          'wave pool',
          'lazy river',
          'rain disco',
          'rain dance',
        ])) {
      return ParkDiscoveryCategory.waterRides;
    }

    if (_containsAny(cat, const ['kid', 'child', 'kiddie']) ||
        _containsAny(rideTags, const [
          'kiddie',
          'kids',
          'mini ferris',
          'toy train',
          'mini drop',
          'garden theme',
          'flying elephants',
        ]) ||
        _containsAny(rideDesc, const ['for children', 'gives children'])) {
      return ParkDiscoveryCategory.kidsRides;
    }

    if (_containsAny(cat, const ['family']) ||
        _containsAny(rideTags, const ['family fun', 'carousel'])) {
      return ParkDiscoveryCategory.familyRides;
    }

    if (matchedDining != null ||
        _containsAny(cat, const [
          'restaurant',
          'dining',
          'food',
          'beverage',
          'cafe',
          'snack',
          'drink',
          'buffet',
        ])) {
      if (_containsAny(cat, const [
            'food & beverage',
            'beverage',
            'cafe',
            'snack',
            'drink',
            'street food',
          ]) ||
          _containsAny(lowerName, const [
            'food court',
            'cafe',
            'coffee',
            'snack',
            'beverage',
            'chaat',
            'ice cream',
            'juice',
            'grill',
          ])) {
        return ParkDiscoveryCategory.foodAndBeverages;
      }
      return ParkDiscoveryCategory.restaurants;
    }

    if (_containsAny(cat, const [
          'facility',
          'first aid',
          'medical',
          'entrance',
          'exit',
          'parking',
          'locker',
          'info',
          'service',
          'shop',
          'hall',
          'stay',
          'hotel',
        ]) ||
        _containsAny(lowerName, const [
          'first aid',
          'entrance',
          'exit',
          'parking',
          'locker',
          'multipurpose hall',
        ])) {
      return ParkDiscoveryCategory.facilities;
    }

    if (matchedRide != null ||
        _containsAny(cat, const ['thrill', 'coaster', 'ride'])) {
      return ParkDiscoveryCategory.thrillRides;
    }

    return ParkDiscoveryCategory.attractions;
  }

  static ParkDiscoveryCategory classifyOsmPlace(MapPlace place) {
    final lowerName = place.name.toLowerCase();
    final lowerKind = place.kind.toLowerCase();
    if (_containsAny(lowerKind, const ['toilet', 'restroom', 'wc']) ||
        _containsAny(lowerName, const ['toilet', 'restroom', 'washroom'])) {
      return ParkDiscoveryCategory.restrooms;
    }
    if (_containsAny(lowerName, const ['wave pool', 'lazy river', 'water', 'pool', 'rain'])) {
      return ParkDiscoveryCategory.waterRides;
    }
    if (place.category == PlaceCategory.food) {
      if (_containsAny(lowerKind, const ['cafe', 'fast food', 'food court']) ||
          _containsAny(lowerName, const ['cafe', 'coffee', 'food court', 'snack'])) {
        return ParkDiscoveryCategory.foodAndBeverages;
      }
      return ParkDiscoveryCategory.restaurants;
    }
    if (place.category == PlaceCategory.facility ||
        place.category == PlaceCategory.stay) {
      return ParkDiscoveryCategory.facilities;
    }
    if (place.category == PlaceCategory.attraction) {
      return ParkDiscoveryCategory.thrillRides;
    }
    return ParkDiscoveryCategory.attractions;
  }

  static IconData resolveMarkerIcon({
    required ParkDiscoveryCategory category,
    required String name,
    required String rawCategory,
  }) {
    final text = '$name $rawCategory'.toLowerCase();
    if (category == ParkDiscoveryCategory.facilities) {
      if (text.contains('entrance') || text.contains('exit')) {
        return Icons.login_rounded;
      }
      if (text.contains('parking')) return Icons.local_parking_rounded;
      if (text.contains('locker')) return Icons.lock_outline_rounded;
      if (text.contains('hall')) return Icons.meeting_room_rounded;
      if (text.contains('first aid') ||
          text.contains('medical') ||
          text.contains('hospital')) {
        return Icons.local_hospital_rounded;
      }
      return Icons.info_outline_rounded;
    }
    if (category == ParkDiscoveryCategory.waterRides && text.contains('wave')) {
      return Icons.pool_rounded;
    }
    return category.icon;
  }

  static LatLng? _resolvePosition(
    Map<String, dynamic> place, {
    required bool isBengaluruPark,
  }) {
    final lat = _tryDouble(place['lat']);
    final lng = _tryDouble(place['lng']);
    if (lat != null &&
        lng != null &&
        lat >= -90 &&
        lat <= 90 &&
        lng >= -180 &&
        lng <= 180) {
      return LatLng(lat, lng);
    }
    if (isBengaluruPark) {
      final name = normalizePlaceName(place['name']?.toString() ?? '');
      if (name.isEmpty) return null;
      for (final known in wonderlaFeaturedLocations) {
        final knownName = normalizePlaceName(known.name);
        if (name == knownName || knownName.startsWith('$name ')) {
          return known.position;
        }
      }
    }
    return null;
  }

  static String? _resolveZoneName({
    required String? explicitZone,
    required ParkDiscoveryCategory category,
    required List<ParkZoneInfo> zones,
  }) {
    final trimmed = explicitZone?.trim() ?? '';
    if (trimmed.isNotEmpty) return trimmed;
    if (zones.isEmpty) return null;
    for (final zone in zones) {
      final lower = zone.name.toLowerCase();
      if (category == ParkDiscoveryCategory.waterRides &&
          lower.contains('water')) {
        return zone.name;
      }
      if (category == ParkDiscoveryCategory.kidsRides &&
          lower.contains('kid')) {
        return zone.name;
      }
      if ((category == ParkDiscoveryCategory.thrillRides ||
              category == ParkDiscoveryCategory.familyRides) &&
          lower.contains('land')) {
        return zone.name;
      }
    }
    return null;
  }

  static Map<ParkDiscoveryCategory, int> _computeCategoryCounts(
    List<ParkDiscoveryItem> items,
  ) {
    final counts = <ParkDiscoveryCategory, int>{};
    for (final item in items) {
      counts[item.category] = (counts[item.category] ?? 0) + 1;
    }
    return counts;
  }

  static List<ParkDiscoveryCategory> _computeAvailableCategories(
    List<ParkDiscoveryItem> items,
  ) {
    final present = items.map((e) => e.category).toSet();
    return ParkDiscoveryCategory.values
        .where(present.contains)
        .toList(growable: false);
  }

  static Map<String, Map<String, dynamic>> _indexByName(
    List<Map<String, dynamic>> list,
    List<String> keys,
  ) {
    final map = <String, Map<String, dynamic>>{};
    for (final entry in list) {
      for (final key in keys) {
        final raw = entry[key]?.toString().trim() ?? '';
        if (raw.isNotEmpty) {
          map.putIfAbsent(normalizePlaceName(raw), () => entry);
          break;
        }
      }
    }
    return map;
  }

  static Map<String, dynamic>? _lookupFuzzy(
    Map<String, Map<String, dynamic>> index,
    String normalizedName,
  ) {
    if (normalizedName.isEmpty) return null;
    final exact = index[normalizedName];
    if (exact != null) return exact;
    for (final entry in index.entries) {
      if (entry.key.startsWith('$normalizedName ') ||
          normalizedName.startsWith('${entry.key} ')) {
        return entry.value;
      }
    }
    return null;
  }

  static List<Map<String, dynamic>> _mapList(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);
  }

  static List<String> _stringList(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
  }

  static double? _tryDouble(dynamic raw) {
    if (raw == null) return null;
    if (raw is num) return raw.isFinite ? raw.toDouble() : null;
    final parsed = double.tryParse(raw.toString());
    return parsed != null && parsed.isFinite ? parsed : null;
  }

  static int? _tryInt(dynamic raw) {
    if (raw == null) return null;
    if (raw is int) return raw;
    if (raw is num) return raw.round();
    return int.tryParse(raw.toString().trim());
  }

  static String _firstNonEmpty(List<String?> candidates) {
    for (final c in candidates) {
      final trimmed = c?.trim() ?? '';
      if (trimmed.isNotEmpty) return trimmed;
    }
    return '';
  }

  static String? _firstNonEmptyOrNull(List<String?> candidates) {
    final found = _firstNonEmpty(candidates);
    return found.isEmpty ? null : found;
  }

  static bool _containsAny(String value, List<String> needles) {
    for (final needle in needles) {
      if (value.contains(needle)) return true;
    }
    return false;
  }
}
