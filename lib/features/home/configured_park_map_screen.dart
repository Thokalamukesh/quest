import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../shared/external_link.dart';
import '../../shared/wonderla_palette.dart';
import '../ai_assistant/wonderla_ai_sheet.dart';
import '../cms/cms_api.dart';
import '../park_map/models/map_place.dart';
import '../park_map/models/park_discovery_item.dart';
import '../park_map/models/park_map_config.dart';
import '../park_map/services/location_service.dart';
import '../park_map/services/open_street_map_service.dart';
import '../park_map/services/saved_places_store.dart';
import '../park_map/widgets/dining_menu_sheet.dart';
import '../park_map/widgets/park_filter_bar.dart';
import '../park_map/widgets/park_map_marker.dart';
import '../park_map/widgets/park_place_detail_sheet.dart';
import 'visitor_home.dart';

const _mapNavy = wonderlaCobalt;
const _mapInk = wonderlaNavy;
const _mapCanvas = wonderlaCream;

enum _ParkSortMode { featured, shortestWait, nearest }

/// Interactive Wonderla park map and attractions discovery experience.
/// Preserves existing park config, GPS proximity checks, OSRM walking
/// directions, and CMS-configured directions while adding multi-select filters,
/// custom category markers, My Day saved places, and Genkit AI assistance.
class ConfiguredParkMapScreen extends StatefulWidget {
  const ConfiguredParkMapScreen({
    super.key,
    required this.config,
    required this.baseUrl,
    this.initialPosition,
    this.api,
    this.initialFocusPlaceName,
    this.autoStartDirections = false,
    this.initialFocusPlace,
    this.initialDirectionsUrl,
    this.initialDirectionsNote,
  });

  final Map<String, dynamic> config;
  final String baseUrl;
  final Position? initialPosition;
  final CmsApi? api;
  final String? initialFocusPlaceName;
  final bool autoStartDirections;
  final Map<String, dynamic>? initialFocusPlace;
  final String? initialDirectionsUrl;
  final String? initialDirectionsNote;

  @override
  State<ConfiguredParkMapScreen> createState() =>
      _ConfiguredParkMapScreenState();
}

class _ConfiguredParkMapScreenState extends State<ConfiguredParkMapScreen> {
  final _controller = MapController();
  final _sheetController = DraggableScrollableController();
  final _location = LocationService();
  final _routingService = OpenStreetMapService();
  final _searchController = TextEditingController();

  StreamSubscription<Position>? _positionSubscription;
  Future<void>? _locationTask;

  late Map<String, dynamic> _parkConfig;
  late ParkDiscoveryCatalog _catalog;
  LatLng? _center;
  LatLng? _visitorPosition;
  ParkDiscoveryItem? _selected;
  ParkDiscoveryItem? _activeDirectionsItem;
  WalkingRoute? _route;
  final RouteMode _routeMode = RouteMode.walking;

  // Filter & sort state (updated locally with zero API/map reloads).
  final Set<ParkDiscoveryCategory> _selectedCategories = {};
  String? _selectedZone;
  bool _savedOnly = false;
  bool _shortWaitOnly = false;
  bool _directionsReadyOnly = false;
  bool _kioskBookingOnly = false;
  _ParkSortMode _sortMode = _ParkSortMode.featured;

  bool _gpsLoading = false;
  bool _refreshing = false;
  bool _routing = false;
  bool _mapReady = false;
  bool _mapExpanded = false;
  bool _showMarkerLabels = false;
  double _currentZoom = 16.0;
  int _routeRequestId = 0;
  String? _locationMessage;
  String? _routeError;

  String get _parkSlug => _parkConfig['slug']?.toString().trim() ?? 'park';

  Map<String, dynamic> get _map =>
      Map<String, dynamic>.from(_parkConfig['parkMap'] as Map? ?? const {});

  String get _parkIdentity => [
    _parkConfig['slug'],
    _parkConfig['name'],
    _parkConfig['location'],
    _parkConfig['city'],
    _parkConfig['title'],
  ].whereType<Object>().join(' ').toLowerCase();

  bool get _isBengaluruPark {
    if (RegExp(r'\b(bengaluru|bangalore)\b').hasMatch(_parkIdentity)) {
      return true;
    }
    if (RegExp(
      r'\b(kochi|cochin|hyderabad|bhubaneswar|chennai)\b',
    ).hasMatch(_parkIdentity)) {
      return false;
    }
    final lat = double.tryParse('${_map['centerLat']}');
    final lng = double.tryParse('${_map['centerLng']}');
    return lat != null &&
        lng != null &&
        Geolocator.distanceBetween(
              lat,
              lng,
              wonderlaBengaluruLatitude,
              wonderlaBengaluruLongitude,
            ) <
            5000;
  }

  LatLng? get _configuredCenter {
    final identity = _parkIdentity;
    for (final entry in wonderlaParkCoordinates.entries) {
      final aliases = switch (entry.key) {
        'bengaluru' => const ['bengaluru', 'bangalore'],
        'kochi' => const ['kochi', 'cochin'],
        _ => [entry.key],
      };
      if (aliases.any(identity.contains)) {
        return LatLng(entry.value.$1, entry.value.$2);
      }
    }
    final lat = double.tryParse('${_map['centerLat']}');
    final lng = double.tryParse('${_map['centerLng']}');
    if (lat != null &&
        lng != null &&
        lat >= -90 &&
        lat <= 90 &&
        lng >= -180 &&
        lng <= 180) {
      return LatLng(lat, lng);
    }
    for (final item in _catalog.items) {
      if (item.position != null) return item.position;
    }
    if (_parkConfig['slug'] == 'bengaluru') {
      return const LatLng(
        wonderlaBengaluruLatitude,
        wonderlaBengaluruLongitude,
      );
    }
    return null;
  }

  int get _activeFilterCount =>
      _selectedCategories.length +
      (_selectedZone != null ? 1 : 0) +
      (_savedOnly ? 1 : 0) +
      (_shortWaitOnly ? 1 : 0) +
      (_directionsReadyOnly ? 1 : 0) +
      (_kioskBookingOnly ? 1 : 0);

  bool get _hasAnyActiveFilter =>
      _activeFilterCount > 0 || _searchController.text.trim().isNotEmpty;

  List<ParkDiscoveryItem> get _filteredItems {
    var results = _catalog.filter(
      query: _searchController.text,
      categories: _selectedCategories,
      zoneName: _selectedZone,
      shortWaitOnly: _shortWaitOnly,
      directionsReadyOnly: _directionsReadyOnly,
      kioskBookingOnly: _kioskBookingOnly,
    );
    if (_savedOnly) {
      results = results
          .where((item) => SavedPlacesStore.instance.isSaved(_parkSlug, item.name))
          .toList(growable: false);
    }
    if (_sortMode == _ParkSortMode.shortestWait) {
      results = [...results]
        ..sort((a, b) {
          final aw = a.waitTimeMinutes ?? 9999;
          final bw = b.waitTimeMinutes ?? 9999;
          return aw.compareTo(bw);
        });
    } else if (_sortMode == _ParkSortMode.nearest && _visitorPosition != null) {
      final from = _visitorPosition!;
      results = [...results]
        ..sort((a, b) {
          final ad = a.position == null
              ? double.infinity
              : Geolocator.distanceBetween(
                  from.latitude,
                  from.longitude,
                  a.position!.latitude,
                  a.position!.longitude,
                );
          final bd = b.position == null
              ? double.infinity
              : Geolocator.distanceBetween(
                  from.latitude,
                  from.longitude,
                  b.position!.latitude,
                  b.position!.longitude,
                );
          return ad.compareTo(bd);
        });
    }
    return results;
  }

  @override
  void initState() {
    super.initState();
    _parkConfig = Map<String, dynamic>.from(widget.config);
    SavedPlacesStore.instance.addListener(_onSavedChanged);
    _rebuildCatalog();
    _center = _configuredCenter;

    final initialPosition = widget.initialPosition;
    if (initialPosition != null) {
      final point = LatLng(initialPosition.latitude, initialPosition.longitude);
      if (_isNearPark(point)) {
        _visitorPosition = point;
        _watchVisitorPosition();
      } else {
        _locationMessage =
            'You are outside the park area. Showing the park map.';
      }
    }

    final focusName = widget.initialFocusPlaceName?.trim() ?? '';
    if (focusName.isNotEmpty) {
      _applyInitialFocus(focusName);
    }
  }

  void _onSavedChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant ConfiguredParkMapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.config, widget.config) ||
        oldWidget.baseUrl != widget.baseUrl) {
      _parkConfig = Map<String, dynamic>.from(widget.config);
      _rebuildCatalog();
      _center = _configuredCenter;
    }
  }

  void _rebuildCatalog() {
    _catalog = ParkDiscoveryCatalog.fromParkConfig(
      _parkConfig,
      baseUrl: widget.baseUrl,
      isBengaluruPark: _isBengaluruPark,
    );
  }

  Future<void> _refreshParkConfig() async {
    if (_refreshing) return;
    final slug = _parkConfig['slug']?.toString() ?? '';
    if (slug.isEmpty) return;
    setState(() => _refreshing = true);
    try {
      final api = widget.api ?? CmsApi(baseUrl: widget.baseUrl);
      final latest = await api.park(slug);
      if (!mounted) return;
      setState(() {
        _parkConfig = latest;
        _rebuildCatalog();
        if (_selected != null) {
          final currentId = _selected!.id;
          _selected = _catalog.items.cast<ParkDiscoveryItem?>().firstWhere(
            (i) => i?.id == currentId,
            orElse: () => _selected,
          );
        }
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _routeError = 'Could not refresh live wait times right now.',
        );
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  ParkDiscoveryItem? _resolveTargetItem({
    required String placeName,
    Map<String, dynamic>? rawPlace,
    String? directionsUrl,
    String? directionsNote,
  }) {
    final targetNorm = ParkDiscoveryCatalog.normalizePlaceName(placeName);
    ParkDiscoveryItem? match;
    for (final item in _catalog.items) {
      final norm = ParkDiscoveryCatalog.normalizePlaceName(item.name);
      if (norm == targetNorm ||
          norm.startsWith('$targetNorm ') ||
          targetNorm.startsWith('$norm ')) {
        match = item;
        break;
      }
    }

    if (match != null) {
      final mergedUrl =
          (directionsUrl?.trim().isNotEmpty == true)
          ? directionsUrl!.trim()
          : match.directionsUrl;
      final mergedNote =
          (directionsNote?.trim().isNotEmpty == true)
          ? directionsNote!.trim()
          : match.directionsNote;
      final mergedPos =
          match.position ??
          ParkDiscoveryCatalog.parseCoordinatesFromDirectionsUrl(mergedUrl);
      if (mergedUrl == match.directionsUrl &&
          mergedNote == match.directionsNote &&
          mergedPos == match.position) {
        return match;
      }
      return ParkDiscoveryItem(
        id: match.id,
        name: match.name,
        rawCategory: match.rawCategory,
        category: match.category,
        icon: match.icon,
        rawPlace: match.rawPlace,
        searchIndex: match.searchIndex,
        position: mergedPos,
        mapX: match.mapX,
        mapY: match.mapY,
        imageUrl: match.imageUrl,
        description: match.description,
        cuisine: match.cuisine,
        tags: match.tags,
        waitTimeMinutes: match.waitTimeMinutes,
        minHeight: match.minHeight,
        operatingStatus: match.operatingStatus,
        lastServiceDate: match.lastServiceDate,
        serviceChecks: match.serviceChecks,
        sessionTimeSlots: match.sessionTimeSlots,
        sessionDurationMinutes: match.sessionDurationMinutes,
        kioskBookingEnabled: match.kioskBookingEnabled,
        menuItems: match.menuItems,
        zoneName: match.zoneName,
        address: match.address,
        directionsUrl: mergedUrl,
        directionsNote: mergedNote,
        rawRide: match.rawRide,
        rawDining: match.rawDining,
        rawWaitTime: match.rawWaitTime,
        rawWaveSession: match.rawWaveSession,
        rawMaintenance: match.rawMaintenance,
        osmPlace: match.osmPlace,
      );
    }

    // Check CMS dining outlets so restaurants not separately added to parkMap.places
    // still open directions cleanly when a visitor taps Map!
    final diningList = (_parkConfig['dining'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e));
    for (final outlet in diningList) {
      final norm = ParkDiscoveryCatalog.normalizePlaceName(
        outlet['name']?.toString() ?? '',
      );
      if (norm == targetNorm ||
          norm.startsWith('$targetNorm ') ||
          targetNorm.startsWith('$norm ')) {
        return ParkDiscoveryCatalog.fromDiningEntry(
          outlet,
          config: _parkConfig,
          baseUrl: widget.baseUrl,
          isBengaluruPark: _isBengaluruPark,
        );
      }
    }

    if (rawPlace != null) {
      if (rawPlace.containsKey('cuisine') || rawPlace.containsKey('items')) {
        return ParkDiscoveryCatalog.fromDiningEntry(
          rawPlace,
          config: _parkConfig,
          baseUrl: widget.baseUrl,
          isBengaluruPark: _isBengaluruPark,
        );
      }
      return ParkDiscoveryCatalog.fromRideEntry(
        rawPlace,
        config: _parkConfig,
        baseUrl: widget.baseUrl,
      );
    }

    if (placeName.trim().isNotEmpty) {
      final cleanUrl = directionsUrl?.trim();
      final cleanNote = directionsNote?.trim();
      return ParkDiscoveryItem(
        id: 'focus-$targetNorm',
        name: placeName.trim(),
        rawCategory: 'Destination',
        category: ParkDiscoveryCategory.attractions,
        icon: Icons.place_rounded,
        rawPlace: {'name': placeName.trim()},
        searchIndex: placeName.toLowerCase(),
        position: ParkDiscoveryCatalog.parseCoordinatesFromDirectionsUrl(
          cleanUrl,
        ),
        directionsUrl: cleanUrl?.isNotEmpty == true ? cleanUrl : null,
        directionsNote: cleanNote?.isNotEmpty == true ? cleanNote : null,
      );
    }
    return null;
  }

  void _applyInitialFocus(String focusName) {
    final match = _resolveTargetItem(
      placeName: focusName,
      rawPlace: widget.initialFocusPlace,
      directionsUrl: widget.initialDirectionsUrl,
      directionsNote: widget.initialDirectionsNote,
    );
    if (match == null) return;
    _selected = match;
    if (match.position != null) {
      _center = match.position;
    }
    if (widget.autoStartDirections) {
      _activeDirectionsItem = match;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _startDirectionsTo(match);
      });
    }
  }

  void _watchVisitorPosition() {
    _positionSubscription ??= _location.watchPosition().listen(
      (position) {
        if (!mounted) return;
        final next = LatLng(position.latitude, position.longitude);
        setState(() {
          _visitorPosition = _isNearPark(next) ? next : null;
          _locationMessage = _visitorPosition == null
              ? 'You are outside the park area. Showing the park map.'
              : null;
        });
        if (_visitorPosition == null &&
            _mapReady &&
            _configuredCenter != null) {
          _controller.move(_configuredCenter!, 16);
        }
      },
      onError: (_) {
        if (mounted) {
          setState(() => _locationMessage = 'Live location updates stopped.');
        }
      },
    );
  }

  bool _isNearPark(LatLng point) {
    final park = _configuredCenter;
    if (park == null) return false;
    return Geolocator.distanceBetween(
          point.latitude,
          point.longitude,
          park.latitude,
          park.longitude,
        ) <=
        1500;
  }

  @override
  void dispose() {
    SavedPlacesStore.instance.removeListener(_onSavedChanged);
    _positionSubscription?.cancel();
    _searchController.dispose();
    _sheetController.dispose();
    _routingService.dispose();
    super.dispose();
  }

  Future<void> _locateVisitor() {
    final pending = _locationTask;
    if (pending != null) return pending;

    late final Future<void> task;
    task = _fetchVisitorLocation().whenComplete(() {
      if (identical(_locationTask, task)) _locationTask = null;
    });
    _locationTask = task;
    return task;
  }

  Future<void> _fetchVisitorLocation() async {
    if (mounted) {
      setState(() {
        _gpsLoading = true;
        _locationMessage = null;
      });
    }
    final result = await _location.currentPosition();
    if (!mounted) return;
    final position = result.position;
    setState(() {
      _gpsLoading = false;
      _locationMessage = result.message;
      if (position != null) {
        _visitorPosition = LatLng(position.latitude, position.longitude);
        if (!_isNearPark(_visitorPosition!)) {
          _visitorPosition = null;
          _locationMessage =
              'You are outside the park area. Showing the park map.';
        }
        if (_visitorPosition != null) _watchVisitorPosition();
      }
    });
    if (position != null &&
        _isNearPark(LatLng(position.latitude, position.longitude)) &&
        _mapReady) {
      _controller.move(LatLng(position.latitude, position.longitude), 17);
    } else if (position != null && _mapReady && _configuredCenter != null) {
      _controller.move(_configuredCenter!, 16);
    }
  }

  void _resetMapView() {
    final target = _configuredCenter;
    if (target != null && _mapReady) {
      _controller.rotate(0);
      _controller.move(target, 16);
    }
  }

  void _zoomBy(double delta) {
    if (!_mapReady) return;
    final nextZoom = (_currentZoom + delta).clamp(14.5, 19.0);
    _controller.move(_controller.camera.center, nextZoom);
  }

  void _clearAllFilters() {
    _searchController.clear();
    setState(() {
      _selectedCategories.clear();
      _selectedZone = null;
      _savedOnly = false;
      _shortWaitOnly = false;
      _directionsReadyOnly = false;
      _kioskBookingOnly = false;
    });
  }

  void _toggleCategory(ParkDiscoveryCategory category) {
    setState(() {
      if (!_selectedCategories.add(category)) {
        _selectedCategories.remove(category);
      }
    });
  }

  Future<void> _openFilterSheet() async {
    final result = await showParkFilterSheet(
      context,
      catalog: _catalog,
      currentSearchQuery: _searchController.text,
      initial: ParkFilterSelection(
        categories: _selectedCategories,
        zoneName: _selectedZone,
        shortWaitOnly: _shortWaitOnly,
        directionsReadyOnly: _directionsReadyOnly,
        kioskBookingOnly: _kioskBookingOnly,
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _selectedCategories
        ..clear()
        ..addAll(result.categories);
      _selectedZone = result.zoneName;
      _shortWaitOnly = result.shortWaitOnly;
      _directionsReadyOnly = result.directionsReadyOnly;
      _kioskBookingOnly = result.kioskBookingOnly;
    });
  }

  void _onSelectItem(ParkDiscoveryItem item, {bool openSheet = true}) {
    FocusScope.of(context).unfocus();
    setState(() {
      _selected = item;
      _routeError = null;
    });
    if (item.position != null && _mapReady) {
      _controller.move(item.position!, 17.8);
    }
    if (openSheet) {
      _openItemDetailSheet(item);
    }
  }

  void _openItemDetailSheet(ParkDiscoveryItem item) {
    showParkPlaceDetailSheet(
      context,
      item: item,
      parkSlug: _parkSlug,
      distanceLabel: _distanceToVisitor(item),
      routing: _routing,
      onDirections: item.hasDirections ? () => _startDirectionsTo(item) : null,
      onViewDetails: _canViewDetails(item) ? () => _openDetailsScreen(item) : null,
      viewDetailsLabel: item.isDining
          ? 'View Menu'
          : item.isWaterActivity
          ? 'Water Activities'
          : item.isRide
          ? 'View Ride Details'
          : 'Explore Section',
    );
  }

  bool _canViewDetails(ParkDiscoveryItem item) =>
      item.isDining || item.isRide || item.isWaterActivity;

  void _openDetailsScreen(ParkDiscoveryItem item) {
    if (item.rawDining != null) {
      showWonderlaDiningMenuSheet(
        context,
        outlet: item.rawDining!,
        resolveUrl: (path) =>
            ParkDiscoveryCatalog.resolveMediaUrl(path, widget.baseUrl),
        onLocateOnMap: () => _startDirectionsTo(item),
      );
      return;
    }
    final api = widget.api ?? CmsApi(baseUrl: widget.baseUrl);
    final String title;
    final String? initialTab;
    if (item.isDining) {
      title = 'DINING & MENU';
      initialTab = null;
    } else if (item.rawWaveSession != null) {
      title = 'RIDES & WATER ACTIVITIES';
      initialTab = 'Water activities';
    } else {
      title = 'RIDES & WATER ACTIVITIES';
      initialTab = 'Rides';
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VisitorSectionScreen(
          title: title,
          config: _parkConfig,
          api: api,
          initialTab: initialTab,
        ),
      ),
    );
  }

  String? _effectiveDirectionsUrl(ParkDiscoveryItem item) {
    final explicit = item.directionsUrl?.trim() ?? '';
    if (explicit.isNotEmpty) return explicit;
    final pos = item.position;
    if (pos != null) {
      return 'https://www.google.com/maps/dir/?api=1&destination=${pos.latitude},${pos.longitude}&travelmode=walking';
    }
    return null;
  }

  Future<void> _openExternalDirections(ParkDiscoveryItem item) async {
    final url = _effectiveDirectionsUrl(item);
    if (url == null) return;
    final launched = await openExternalUrl(url);
    if (!launched && mounted) {
      await Clipboard.setData(ClipboardData(text: url));
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Directions link copied to clipboard.'),
          ),
        );
    }
  }

  void _openAiAssistant() {
    showWonderlaAiAssistantSheet(
      context,
      parkConfig: _parkConfig,
      baseUrl: widget.baseUrl,
      onOpenPlaceOnMap: (place) {
        final target = _resolveTargetItem(
          placeName: place.name,
          directionsUrl: place.directionsUrl,
          directionsNote: place.directions,
        );
        if (target == null) return;
        if (place.prefersDirections) {
          _startDirectionsTo(target);
        } else {
          _onSelectItem(target);
        }
      },
    );
  }

  void _startDirectionsTo(ParkDiscoveryItem item) {
    _routeRequestId++;
    setState(() {
      _selected = item;
      _activeDirectionsItem = item;
      _route = null;
      _routeError = null;
      _routing = false;
    });
    final position = item.position;
    if (position == null) {
      if (!item.hasDirections) {
        setState(
          () => _routeError =
              'Add directions or GPS coordinates for "${item.name}" in CMS Admin to enable guided directions.',
        );
      }
      return;
    }
    if (_mapReady) _controller.move(position, 18);
    _requestDirections(item);
  }

  Future<void> _requestDirections(ParkDiscoveryItem item) async {
    final requestId = ++_routeRequestId;
    final destination = item.position;
    if (destination == null) {
      setState(
        () => _routeError =
            'Add this place’s latitude and longitude in the CMS to get directions.',
      );
      return;
    }
    if (_visitorPosition == null || !_isNearPark(_visitorPosition!)) {
      await _locateVisitor();
      if (!mounted || requestId != _routeRequestId) return;
      if (_visitorPosition == null) {
        if (mounted) {
          setState(
            () => _routeError =
                _locationMessage ??
                'Allow location access to get walking directions.',
          );
        }
        return;
      }
    }
    if (!mounted) return;
    setState(() {
      _routing = true;
      _routeError = null;
    });
    try {
      final route = await _routingService.findWalkingRoute(
        from: _visitorPosition!,
        to: destination,
        mode: _routeMode,
      );
      if (!mounted || requestId != _routeRequestId) return;
      setState(() {
        _route = route;
        _routing = false;
      });
      if (_mapReady && route.points.isNotEmpty) {
        _fitRoute(route);
      }
    } catch (error) {
      if (!mounted || requestId != _routeRequestId) return;
      setState(() {
        _routing = false;
        _routeError = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _fitRoute(WalkingRoute route) {
    if (!_mapReady || route.points.isEmpty) return;
    _controller.fitCamera(
      CameraFit.coordinates(
        coordinates: route.points,
        padding: const EdgeInsets.fromLTRB(36, 130, 72, 90),
        maxZoom: 18,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleItems = _filteredItems;
    return Scaffold(
      backgroundColor: _mapCanvas,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 760;
          if (isWide) {
            return SafeArea(
              child: Row(
                children: [
                  Expanded(
                    flex: 13,
                    child: _mapStage(visibleItems, isWide: true),
                  ),
                  SizedBox(
                    width: (constraints.maxWidth * 0.35).clamp(320.0, 410.0),
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          left: BorderSide(color: wonderlaBorder),
                        ),
                      ),
                      child: _discoveryPanelContent(
                        visibleItems,
                        isWide: true,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return Stack(
            fit: StackFit.expand,
            children: [
              _mapStage(visibleItems, isWide: false),
              if (!_mapExpanded)
                DraggableScrollableSheet(
                  controller: _sheetController,
                  initialChildSize: 0.30,
                  minChildSize: 0.14,
                  maxChildSize: 0.84,
                  snap: true,
                  snapSizes: const [0.14, 0.30, 0.62, 0.84],
                  builder: (context, scrollController) => Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(26),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x28102454),
                          blurRadius: 24,
                          offset: Offset(0, -6),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _discoveryPanelContent(
                      visibleItems,
                      isWide: false,
                      scrollController: scrollController,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _mapStage(
    List<ParkDiscoveryItem> visibleItems, {
    required bool isWide,
  }) {
    final topPadding = MediaQuery.paddingOf(context).top;
    final overlayTop = isWide ? 12.0 : topPadding + 10.0;
    final controlsTop =
        overlayTop + (_catalog.availableCategories.isEmpty ? 62.0 : 108.0);
    final bottomOffset = isWide || _mapExpanded ? 16.0 : 210.0;

    return Stack(
      fit: StackFit.expand,
      children: [
        _liveMap(visibleItems),

        // Top floating search & category filter chips overlay
        Positioned(
          top: overlayTop,
          left: 0,
          right: 0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: ParkFloatingSearchHeader(
                  controller: _searchController,
                  onBack: () => Navigator.of(context).maybePop(),
                  onChanged: (_) => setState(() {}),
                  onClear: () {
                    _searchController.clear();
                    setState(() {});
                  },
                  onOpenFilters: _catalog.items.isNotEmpty
                      ? _openFilterSheet
                      : null,
                  activeFilterCount: _activeFilterCount,
                ),
              ),
              if (_catalog.availableCategories.isNotEmpty) ...[
                const SizedBox(height: 8),
                ParkCategoryFilterBar(
                  availableCategories: _catalog.availableCategories,
                  categoryCounts: _catalog.categoryCounts,
                  selectedCategories: _selectedCategories,
                  totalCount: _catalog.items.length,
                  savedOnly: _savedOnly,
                  savedCount: SavedPlacesStore.instance.savedCount(_parkSlug),
                  onToggleSavedOnly: () =>
                      setState(() => _savedOnly = !_savedOnly),
                  onSelectAll: () => setState(() {
                    _selectedCategories.clear();
                    _savedOnly = false;
                  }),
                  onToggleCategory: _toggleCategory,
                  hasAnyActiveFilter: _hasAnyActiveFilter,
                  onClearAll: _clearAllFilters,
                ),
              ],
            ],
          ),
        ),

        // Right-edge floating map controls
        Positioned(
          top: controlsTop,
          right: 12,
          child: Column(
            children: [
              _mapControlButton(
                icon: Icons.my_location_rounded,
                tooltip: 'Center on my live location',
                loading: _gpsLoading,
                active: _visitorPosition != null,
                onTap: _locateVisitor,
              ),
              const SizedBox(height: 8),
              _mapControlButton(
                icon: Icons.center_focus_strong_rounded,
                tooltip: 'Reset park map view',
                onTap: _resetMapView,
              ),
              const SizedBox(height: 8),
              _zoomControlGroup(),
              if (!isWide) ...[
                const SizedBox(height: 8),
                _mapControlButton(
                  icon: _mapExpanded
                      ? Icons.fullscreen_exit_rounded
                      : Icons.fullscreen_rounded,
                  tooltip: _mapExpanded ? 'Show park list' : 'Full-screen map',
                  active: _mapExpanded,
                  onTap: () => setState(() => _mapExpanded = !_mapExpanded),
                ),
              ],
            ],
          ),
        ),

        if (_routing)
          Positioned(
            top: controlsTop - 4,
            left: 12,
            right: 68,
            child: const ClipRRect(
              borderRadius: BorderRadius.all(Radius.circular(8)),
              child: LinearProgressIndicator(
                color: wonderlaCobalt,
                minHeight: 3.5,
              ),
            ),
          ),

        if (_routeError != null)
          Positioned(
            top: controlsTop,
            left: 12,
            right: 66,
            child: _routeNotice(_routeError!),
          )
        else if (_locationMessage != null && !_gpsLoading)
          Positioned(
            top: controlsTop,
            left: 12,
            right: 66,
            child: _locationBanner(),
          ),

        if (_route != null)
          Positioned(
            left: 12,
            bottom: bottomOffset + 62,
            child: _routeSummary(_route!),
          ),

        Positioned(
          left: 12,
          bottom: bottomOffset,
          child: WonderlaAiFab(
            compact: !isWide,
            onTap: _openAiAssistant,
          ),
        ),
      ],
    );
  }

  Widget _liveMap(List<ParkDiscoveryItem> visibleItems) {
    final initialCenter = _center;
    if (initialCenter == null) return _noCoordinates();

    final mappedItems = visibleItems
        .where((item) => item.position != null)
        .toList(growable: false);
    final showLabels = _showMarkerLabels || mappedItems.length <= 5;

    return FlutterMap(
      key: const ValueKey('wonderla-live-map'),
      mapController: _controller,
      options: MapOptions(
        initialCenter: initialCenter,
        initialZoom: 16,
        minZoom: 14.5,
        maxZoom: 19,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all,
        ),
        onMapReady: () {
          _mapReady = true;
          final route = _route;
          if (route != null) {
            _fitRoute(route);
          } else if (_selected?.position case final selectedPoint?) {
            _controller.move(selectedPoint, 17.5);
          } else if (_visitorPosition case final position?) {
            _controller.move(position, 17);
          }
        },
        onPositionChanged: (camera, _) {
          _currentZoom = camera.zoom;
          final shouldShow = camera.zoom >= 16.8;
          if (shouldShow != _showMarkerLabels && mounted) {
            setState(() => _showMarkerLabels = shouldShow);
          }
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'maps_wonderla_flutter',
          tileDisplay: const TileDisplay.instantaneous(),
        ),
        if (_route case final route?)
          PolylineLayer(
            polylines: [
              Polyline(
                points: route.points,
                color: wonderlaBlue,
                strokeWidth: 7.5,
                borderColor: Colors.white,
                borderStrokeWidth: 2.2,
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            for (final item in mappedItems)
              Marker(
                point: item.position!,
                width: 118,
                height: (showLabels || item.id == _selected?.id) ? 76 : 56,
                alignment: Alignment.topCenter,
                child: WonderlaMapPin(
                  item: item,
                  selected: item.id == _selected?.id,
                  showLabel: showLabels,
                  onTap: () => _onSelectItem(item),
                ),
              ),
            if (_selected != null &&
                _selected!.position != null &&
                !mappedItems.any((i) => i.id == _selected!.id))
              Marker(
                point: _selected!.position!,
                width: 118,
                height: 76,
                alignment: Alignment.topCenter,
                child: WonderlaMapPin(
                  item: _selected!,
                  selected: true,
                  showLabel: true,
                  onTap: () => _onSelectItem(_selected!),
                ),
              ),
            if (_visitorPosition case final point? when _isNearPark(point))
              Marker(
                point: point,
                width: 42,
                height: 42,
                child: const WonderlaUserLocationPin(),
              ),
          ],
        ),
        const RichAttributionWidget(
          alignment: AttributionAlignment.bottomRight,
          showFlutterMapAttribution: false,
          attributions: [
            TextSourceAttribution('© OpenStreetMap contributors'),
          ],
        ),
      ],
    );
  }

  Widget _mapControlButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    bool loading = false,
    bool active = false,
  }) => Material(
    color: active ? wonderlaNavy : Colors.white,
    elevation: 4,
    shadowColor: const Color(0x30102454),
    shape: const CircleBorder(),
    child: SizedBox(
      width: 44,
      height: 44,
      child: IconButton(
        tooltip: tooltip,
        onPressed: loading ? null : onTap,
        icon: loading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: active ? Colors.white : wonderlaCobalt,
                ),
              )
            : Icon(
                icon,
                color: active ? wonderlaGold : wonderlaCobalt,
                size: 21,
              ),
      ),
    ),
  );

  Widget _zoomControlGroup() => Material(
    color: Colors.white,
    elevation: 4,
    shadowColor: const Color(0x30102454),
    borderRadius: BorderRadius.circular(22),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 42,
          height: 38,
          child: IconButton(
            tooltip: 'Zoom in',
            padding: EdgeInsets.zero,
            onPressed: () => _zoomBy(0.8),
            icon: const Icon(Icons.add_rounded, color: wonderlaNavy, size: 20),
          ),
        ),
        Container(width: 24, height: 1, color: wonderlaBorder),
        SizedBox(
          width: 42,
          height: 38,
          child: IconButton(
            tooltip: 'Zoom out',
            padding: EdgeInsets.zero,
            onPressed: () => _zoomBy(-0.8),
            icon: const Icon(
              Icons.remove_rounded,
              color: wonderlaNavy,
              size: 20,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _discoveryPanelContent(
    List<ParkDiscoveryItem> visibleItems, {
    required bool isWide,
    ScrollController? scrollController,
  }) {
    final query = _searchController.text.trim();
    final showSortBar =
        _route == null &&
        (_catalog.hasAnyWaitTimes || _visitorPosition != null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isWide)
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 9, bottom: 4),
              width: 38,
              height: 4.5,
              decoration: BoxDecoration(
                color: wonderlaBorder,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(16, isWide ? 14 : 6, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      query.isEmpty ? 'Explore this park' : 'Search results',
                      style: const TextStyle(
                        color: _mapInk,
                        fontSize: 17.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${visibleItems.length} ${visibleItems.length == 1 ? 'place' : 'places'} available',
                      style: const TextStyle(
                        color: wonderlaMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.baseUrl.isNotEmpty)
                IconButton(
                  tooltip: 'Refresh live wait times',
                  constraints: const BoxConstraints.tightFor(
                    width: 34,
                    height: 34,
                  ),
                  padding: EdgeInsets.zero,
                  onPressed: _refreshing ? null : _refreshParkConfig,
                  icon: _refreshing
                      ? const SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: wonderlaCobalt,
                          ),
                        )
                      : const Icon(
                          Icons.refresh_rounded,
                          size: 19,
                          color: wonderlaCobalt,
                        ),
                ),
              const SizedBox(width: 4),
              _locationStatus(),
            ],
          ),
        ),
        if (showSortBar)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _sortChip('Featured', _ParkSortMode.featured),
                if (_catalog.hasAnyWaitTimes)
                  _sortChip('Shortest wait', _ParkSortMode.shortestWait),
                if (_visitorPosition != null)
                  _sortChip('Nearest', _ParkSortMode.nearest),
              ],
            ),
          ),
        if (_selected != null && _activeDirectionsItem == null && _route == null)
          _selectedBanner(_selected!),
        Expanded(
          child: (_activeDirectionsItem != null || _route != null)
              ? _directionsPanel(
                  item: _activeDirectionsItem ?? _selected,
                  route: _route,
                  scrollController: scrollController,
                )
              : visibleItems.isEmpty
              ? _emptyFilterState(query)
              : ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(12, 2, 12, 18),
                  itemCount: visibleItems.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) =>
                      _discoveryPlaceCard(visibleItems[index]),
                ),
        ),
      ],
    );
  }

  Widget _sortChip(String label, _ParkSortMode mode) {
    final active = _sortMode == mode;
    return InkWell(
      onTap: () => setState(() => _sortMode = mode),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
        decoration: BoxDecoration(
          color: active ? wonderlaNavy : wonderlaCream,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: active ? wonderlaNavy : wonderlaBorder),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : wonderlaNavy,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _emptyFilterState(String query) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _hasAnyActiveFilter
                  ? Icons.filter_alt_off_rounded
                  : Icons.map_outlined,
              color: wonderlaMuted,
              size: 34,
            ),
            const SizedBox(height: 8),
            Text(
              query.isNotEmpty
                  ? 'No places match “$query”.'
                  : _hasAnyActiveFilter
                  ? 'No places match the active filters.'
                  : 'No park locations are available yet.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: wonderlaNavy,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (_hasAnyActiveFilter) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _clearAllFilters,
                icon: const Icon(Icons.close_rounded, size: 17),
                label: const Text('Clear all filters'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _selectedBanner(ParkDiscoveryItem item) => Container(
    width: double.infinity,
    margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [wonderlaNavy, wonderlaCobalt],
      ),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: wonderlaGold,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(item.icon, color: wonderlaNavy, size: 19),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 13.5,
                ),
              ),
              Text(
                [
                  item.category.label,
                  if (item.waitTimeMinutes != null)
                    '${item.waitTimeMinutes} min wait',
                ].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .88),
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: wonderlaGold,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: const Size(0, 32),
          ),
          onPressed: () => _openItemDetailSheet(item),
          child: const Text(
            'Details',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
          ),
        ),
        IconButton(
          tooltip: 'Clear selection',
          constraints: const BoxConstraints.tightFor(width: 32, height: 32),
          padding: EdgeInsets.zero,
          onPressed: () => setState(() => _selected = null),
          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
        ),
      ],
    ),
  );

  Widget _discoveryPlaceCard(ParkDiscoveryItem item) {
    final selected = _selected?.id == item.id;
    final distance = _distanceToVisitor(item);
    final saved = SavedPlacesStore.instance.isSaved(_parkSlug, item.name);
    final completed = SavedPlacesStore.instance.isCompleted(
      _parkSlug,
      item.name,
    );
    return Material(
      color: selected ? const Color(0xFFF0F5FF) : Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: () => _onSelectItem(item),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? wonderlaCobalt : wonderlaBorder,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              _itemThumbnail(item),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _mapInk,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (saved) ...[
                          const SizedBox(width: 5),
                          const Icon(
                            Icons.favorite_rounded,
                            size: 13.5,
                            color: wonderlaFlagRed,
                          ),
                        ],
                        if (completed) ...[
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.check_circle_rounded,
                            size: 13.5,
                            color: wonderlaSuccess,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: item.category.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            [
                              item.category.label,
                              ?item.cuisine,
                              ?distance,
                            ].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: wonderlaMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (item.kioskBookingEnabled) ...[
                      const SizedBox(height: 4),
                      const Row(
                        children: [
                          Icon(
                            Icons.confirmation_number_outlined,
                            size: 13,
                            color: wonderlaCobalt,
                          ),
                          SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Kiosk slot booking',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: wonderlaCobalt,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (item.waitTimeMinutes != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3.5,
                      ),
                      decoration: BoxDecoration(
                        color: wonderlaWaitTimeColor(item.waitTimeMinutes!),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${item.waitTimeMinutes}m',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  if (item.hasGpsCoordinates)
                    Padding(
                      padding: EdgeInsets.only(
                        top: item.waitTimeMinutes != null ? 5 : 0,
                      ),
                      child: _routing && selected
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              Icons.directions_walk_rounded,
                              color: selected ? _mapNavy : wonderlaCobalt,
                              size: 19,
                            ),
                    )
                  else if (item.waitTimeMinutes == null)
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: wonderlaMuted,
                      size: 20,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _itemThumbnail(ParkDiscoveryItem item) {
    final fallback = Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: item.category.tintColor,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(item.icon, color: item.category.color, size: 22),
    );
    if (item.imageUrl.isEmpty) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(13),
      child: SizedBox(
        width: 46,
        height: 46,
        child: Image.network(
          item.imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => fallback,
        ),
      ),
    );
  }

  Widget _locationStatus() {
    final live = _visitorPosition != null;
    final outsidePark =
        _locationMessage?.contains('outside the park area') ?? false;
    final color = _gpsLoading
        ? wonderlaWarning
        : live
        ? wonderlaSuccess
        : wonderlaMuted;
    final label = _gpsLoading
        ? 'Locating'
        : live
        ? 'In park'
        : outsidePark
        ? 'Park map'
        : 'GPS off';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_gpsLoading)
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            )
          else
            Icon(Icons.my_location_rounded, size: 13.5, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  String? _distanceToVisitor(ParkDiscoveryItem item) {
    final from = _visitorPosition;
    final to = item.position;
    if (from == null || to == null) return null;
    final meters = Geolocator.distanceBetween(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );
    return '${_formatDistance(meters)} away';
  }

  Widget _routeSummary(WalkingRoute route) {
    final distance = _formatDistance(route.distanceMeters);
    final minutes = (route.durationSeconds / 60).ceil();
    return Material(
      color: wonderlaNavy,
      elevation: 6,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.directions_walk_rounded,
              color: wonderlaGold,
              size: 19,
            ),
            const SizedBox(width: 7),
            Text(
              '$distance · about $minutes min',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _directionsPanel({
    ParkDiscoveryItem? item,
    WalkingRoute? route,
    ScrollController? scrollController,
  }) {
    final externalUrl = item == null ? null : _effectiveDirectionsUrl(item);
    final cmsNote = item?.directionsNote?.trim() ?? '';
    final distance = route == null ? null : _formatDistance(route.distanceMeters);
    final minutes = route == null ? null : (route.durationSeconds / 60).ceil();

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(14, 2, 14, 20),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [wonderlaNavy, wonderlaCobalt],
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: wonderlaGold,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(
                      item?.icon ?? Icons.directions_rounded,
                      color: wonderlaNavy,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'DIRECTIONS TO',
                          style: TextStyle(
                            color: wonderlaGold,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                        Text(
                          item?.name ?? 'Destination',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 15.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Clear directions',
                    onPressed: () => setState(() {
                      _route = null;
                      _activeDirectionsItem = null;
                      _selected = null;
                      _routeError = null;
                    }),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                ],
              ),
              if (cmsNote.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.signpost_outlined,
                        color: wonderlaGold,
                        size: 17,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          cmsNote,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (externalUrl != null && item != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: wonderlaGold,
                      foregroundColor: wonderlaNavy,
                      minimumSize: const Size(0, 42),
                    ),
                    onPressed: () => _openExternalDirections(item),
                    icon: const Icon(Icons.open_in_new_rounded, size: 17),
                    label: const Text('Open in Google Maps'),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (_routing)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: wonderlaCobalt,
                  ),
                ),
                SizedBox(width: 10),
                Text(
                  'Finding walking path…',
                  style: TextStyle(
                    color: wonderlaMuted,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        if (route != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F0FE),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(
                  route.mode == RouteMode.walking
                      ? Icons.directions_walk_rounded
                      : Icons.directions_car_rounded,
                  color: _mapNavy,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$distance · about $minutes min ${route.mode == RouteMode.walking ? 'walk' : 'drive'}',
                    style: const TextStyle(
                      color: _mapInk,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          for (var index = 0; index < route.steps.length; index++)
            ListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              leading: CircleAvatar(
                radius: 14,
                backgroundColor: wonderlaCream,
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: _mapNavy,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              title: Text(
                route.steps[index].instruction,
                style: const TextStyle(fontSize: 13, color: _mapInk),
              ),
              trailing: Text(
                _formatDistance(route.steps[index].distanceMeters),
                style: const TextStyle(fontSize: 11, color: wonderlaMuted),
              ),
            ),
        ] else if (!_routing && cmsNote.isEmpty && externalUrl == null)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: wonderlaCream,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: wonderlaBorder),
            ),
            child: const Text(
              'Add a walking directions note, Google Maps link, or GPS coordinates for this place in Admin CMS to display step-by-step directions here.',
              style: TextStyle(color: wonderlaMuted, fontSize: 12.5, height: 1.4),
            ),
          ),
      ],
    );
  }

  String _formatDistance(double meters) => meters >= 1000
      ? '${(meters / 1000).toStringAsFixed(1)} km'
      : '${meters.round()} m';

  Widget _routeNotice(String message) => Material(
    color: Colors.white,
    elevation: 4,
    borderRadius: BorderRadius.circular(14),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: wonderlaCobalt, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: wonderlaNavy, fontSize: 12),
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _routeError = null),
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close_rounded, size: 17),
          ),
        ],
      ),
    ),
  );

  Widget _locationBanner() => Material(
    color: Colors.white.withValues(alpha: .96),
    elevation: 3,
    borderRadius: BorderRadius.circular(14),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: wonderlaCobalt, size: 17),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _visitorPosition == null
                  ? 'The park map is open. ${_locationMessage ?? 'Allow location access to show your live position and get directions.'}'
                  : _locationMessage ?? 'Live location is unavailable.',
              style: const TextStyle(color: wonderlaNavy, fontSize: 11.5),
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _locationMessage = null),
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints.tightFor(width: 28, height: 28),
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.close_rounded, size: 16),
          ),
        ],
      ),
    ),
  );

  Widget _noCoordinates() => Container(
    color: wonderlaWhite,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_searching, color: _mapNavy, size: 44),
            const SizedBox(height: 10),
            Text(
              _gpsLoading
                  ? 'Finding your location…'
                  : 'Map coordinates are needed',
              style: const TextStyle(
                color: _mapInk,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Set the park latitude and longitude in CMS, or allow location access.',
              textAlign: TextAlign.center,
              style: TextStyle(color: wonderlaNavy),
            ),
          ],
        ),
      ),
    ),
  );
}
