import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../shared/wonderla_palette.dart';
import 'models/map_place.dart';
import 'models/park_discovery_item.dart';
import 'models/park_map_config.dart';
import 'models/wonderla_location_catalog.dart';
import 'services/location_service.dart';
import 'services/open_street_map_service.dart';
import 'widgets/park_filter_bar.dart';
import 'widgets/park_map_marker.dart';
import 'widgets/park_place_detail_sheet.dart';

/// Standalone Wonderla Bengaluru OpenStreetMap explorer with live GPS,
/// Overpass in-park place discovery, Nominatim submit search, OSRM walking
/// routes with automatic off-route recalculation, and multi-select filtering.
class ParkMapScreen extends StatefulWidget {
  const ParkMapScreen({super.key});

  @override
  State<ParkMapScreen> createState() => _ParkMapScreenState();
}

class _ParkMapScreenState extends State<ParkMapScreen> {
  static const _park = LatLng(
    wonderlaBengaluruLatitude,
    wonderlaBengaluruLongitude,
  );
  static const _navy = wonderlaCobalt;
  static const _ink = wonderlaNavy;

  final _map = MapController();
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  final _location = LocationService();
  final _osm = OpenStreetMapService();
  StreamSubscription<Position>? _positionSubscription;

  Position? _position;
  List<MapPlace> _places = [...wonderlaFeaturedLocations];
  List<MapPlace> _searchResults = [];
  late ParkDiscoveryCatalog _catalog;
  ParkDiscoveryItem? _selected;
  WalkingRoute? _route;
  final Set<ParkDiscoveryCategory> _selectedCategories = {};

  bool _loadingPlaces = true;
  bool _locating = false;
  bool _routing = false;
  bool _tileFailed = false;
  bool _searching = false;
  bool _isMapExpanded = false;
  bool _showMarkerLabels = false;
  double _currentZoom = 16.5;
  int _tileRevision = 0;
  int _routeRequestId = 0;
  int _searchRequestId = 0;
  String? _placesError;
  String? _locationError;
  String? _routeError;
  String? _searchError;
  Future<void>? _locationTask;
  DateTime? _lastAutomaticReroute;

  @override
  void initState() {
    super.initState();
    _rebuildCatalog();
    _searchFocus.addListener(_onSearchFocusChanged);
    _loadParkPlaces();
    _locateUser(follow: false);
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _search.dispose();
    _searchFocus.dispose();
    _osm.dispose();
    super.dispose();
  }

  void _rebuildCatalog() {
    final unique = <String, MapPlace>{};
    for (final place in [..._places, ..._searchResults]) {
      unique.putIfAbsent(place.name.trim().toLowerCase(), () => place);
    }
    _catalog = ParkDiscoveryCatalog.fromMapPlaces(
      unique.values.toList(growable: false),
    );
  }

  Future<void> _loadParkPlaces() async {
    setState(() {
      _loadingPlaces = true;
      _placesError = null;
    });
    try {
      final places = await _osm.loadParkPlaces(center: _park);
      if (!mounted) return;
      final byId = {for (final place in places) place.id: place};
      final featured = wonderlaFeaturedLocations.map(
        (place) => byId.remove(place.id) ?? place,
      );
      setState(() {
        _places = [...featured, ...byId.values];
        _rebuildCatalog();
        _loadingPlaces = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _placesError =
            'In-park locations could not load. Check your connection and retry.';
        _loadingPlaces = false;
      });
    }
  }

  Future<void> _locateUser({bool follow = true}) async {
    final pending = _locationTask;
    if (pending != null) {
      await pending;
      if (follow) _centerOnUser();
      return;
    }

    late final Future<void> task;
    task = _fetchLocation().whenComplete(() {
      if (identical(_locationTask, task)) _locationTask = null;
    });
    _locationTask = task;
    await task;
    if (follow) _centerOnUser();
  }

  Future<void> _fetchLocation() async {
    setState(() {
      _locating = true;
      _locationError = null;
    });
    final result = await _location.currentPosition();
    if (!mounted) return;
    if (result.position == null) {
      setState(() {
        _locating = false;
        _locationError = result.message;
      });
      return;
    }

    setState(() {
      _position = result.position;
      _locating = false;
      _locationError = null;
    });
    _positionSubscription ??= _location.watchPosition().listen(
      (position) {
        if (!mounted) return;
        setState(() => _position = position);
        _checkForReroute(position);
      },
      onError: (_) {
        if (mounted) {
          setState(() => _locationError = 'Live location updates stopped.');
        }
      },
    );
  }

  void _centerOnUser() {
    final position = _position;
    if (position == null) return;
    _map.move(LatLng(position.latitude, position.longitude), 17);
  }

  void _resetMapView() {
    _map.rotate(0);
    _map.move(_park, 16.5);
  }

  void _zoomBy(double delta) {
    final nextZoom = (_currentZoom + delta).clamp(16.0, 19.0);
    _map.move(_map.camera.center, nextZoom);
  }

  void _onSearchFocusChanged() {
    if (mounted) setState(() {});
  }

  void _checkForReroute(Position position) {
    final route = _route;
    final destination = _selected?.osmPlace;
    if (route == null ||
        destination == null ||
        _routing ||
        position.accuracy > 50) {
      return;
    }

    final nearestDistance = _distanceFromRoute(position, route.points);
    final deviationLimit = math.max(50.0, position.accuracy * 1.5 + 10);
    if (nearestDistance < deviationLimit) return;
    final lastReroute = _lastAutomaticReroute;
    if (lastReroute != null &&
        DateTime.now().difference(lastReroute) < const Duration(seconds: 15)) {
      return;
    }
    _lastAutomaticReroute = DateTime.now();
    _requestRoute(
      from: LatLng(position.latitude, position.longitude),
      to: destination,
    );
  }

  double _distanceFromRoute(Position position, List<LatLng> points) {
    if (points.isEmpty) return double.infinity;
    if (points.length == 1) {
      return Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        points.first.latitude,
        points.first.longitude,
      );
    }

    const metersPerDegree = 111320.0;
    final longitudeScale =
        metersPerDegree * math.cos(position.latitude * math.pi / 180);
    var nearestDistanceSquared = double.infinity;
    for (var i = 0; i < points.length - 1; i++) {
      final first = points[i];
      final second = points[i + 1];
      final ax = (first.longitude - position.longitude) * longitudeScale;
      final ay = (first.latitude - position.latitude) * metersPerDegree;
      final bx = (second.longitude - position.longitude) * longitudeScale;
      final by = (second.latitude - position.latitude) * metersPerDegree;
      final dx = bx - ax;
      final dy = by - ay;
      final lengthSquared = dx * dx + dy * dy;
      final projection = lengthSquared == 0
          ? 0.0
          : (-(ax * dx + ay * dy) / lengthSquared).clamp(0.0, 1.0);
      final nearestX = ax + projection * dx;
      final nearestY = ay + projection * dy;
      final distanceSquared = nearestX * nearestX + nearestY * nearestY;
      if (distanceSquared < nearestDistanceSquared) {
        nearestDistanceSquared = distanceSquared;
      }
    }
    return math.sqrt(nearestDistanceSquared);
  }

  bool get _hasAnyActiveFilter =>
      _selectedCategories.isNotEmpty || _search.text.trim().isNotEmpty;

  List<ParkDiscoveryItem> get _visibleItems => _catalog.filter(
    query: _search.text,
    categories: _selectedCategories,
  );

  Future<void> _submitSearch(String value) async {
    final query = value.trim();
    if (query.isEmpty || _searching) return;
    final requestId = ++_searchRequestId;
    FocusScope.of(context).unfocus();
    setState(() {
      _searching = true;
      _searchError = null;
      _searchResults = [];
      _rebuildCatalog();
    });
    try {
      final results = await _osm.searchParkPlaces(query: query, near: _park);
      if (!mounted || requestId != _searchRequestId) return;
      setState(() {
        _searchResults = results;
        _rebuildCatalog();
        _searching = false;
      });
    } catch (_) {
      if (!mounted || requestId != _searchRequestId) return;
      setState(() {
        _searching = false;
        _searchError =
            'Could not search right now. Check your connection and retry.';
      });
    }
  }

  void _onSearchChanged(String value) {
    _searchRequestId++;
    setState(() {
      _searchResults = [];
      _rebuildCatalog();
      _searchError = null;
      _searching = false;
    });
  }

  void _clearAllFilters() {
    _search.clear();
    _searchRequestId++;
    setState(() {
      _selectedCategories.clear();
      _searchResults = [];
      _rebuildCatalog();
      _searchError = null;
      _searching = false;
    });
  }

  Future<void> _openFilterSheet() async {
    final result = await showParkFilterSheet(
      context,
      catalog: _catalog,
      currentSearchQuery: _search.text,
      initial: ParkFilterSelection(categories: _selectedCategories),
    );
    if (result == null || !mounted) return;
    setState(() {
      _selectedCategories
        ..clear()
        ..addAll(result.categories);
    });
  }

  void _select(ParkDiscoveryItem item, {bool openSheet = true}) {
    _searchFocus.unfocus();
    _routeRequestId++;
    _lastAutomaticReroute = null;
    setState(() {
      _selected = item;
      _route = null;
      _routeError = null;
      _routing = false;
    });
    if (item.position != null) {
      _map.move(item.position!, 18);
    }
    if (openSheet) {
      final dist = _distanceTo(item);
      showParkPlaceDetailSheet(
        context,
        item: item,
        distanceLabel: dist == null ? null : '${_distanceLabel(dist)} away',
        routing: _routing,
        onDirections: () => _directionsTo(item),
      );
    }
  }

  void _clearDestination() {
    _routeRequestId++;
    _lastAutomaticReroute = null;
    setState(() {
      _selected = null;
      _route = null;
      _routeError = null;
      _routing = false;
    });
    _map.move(_park, 16.5);
  }

  Future<void> _directionsTo(ParkDiscoveryItem item) async {
    _select(item, openSheet: false);
    await _showRoute();
  }

  Future<void> _showRoute() async {
    final destination = _selected?.osmPlace;
    if (destination == null || _routing) return;
    if (_position == null) {
      await _locateUser(follow: false);
      if (_position == null) {
        if (mounted) {
          setState(() {
            _routeError =
                _locationError ?? 'Enable location to get directions.';
          });
        }
        return;
      }
    }

    final position = _position!;
    await _requestRoute(
      from: LatLng(position.latitude, position.longitude),
      to: destination,
    );
  }

  Future<void> _requestRoute({
    required LatLng from,
    required MapPlace to,
  }) async {
    if (_routing) return;
    final requestId = ++_routeRequestId;
    setState(() {
      _routing = true;
      _route = null;
      _routeError = null;
    });
    try {
      final route = await _osm.findWalkingRoute(from: from, to: to.position);
      if (!mounted || requestId != _routeRequestId) return;
      setState(() {
        _route = route;
        _routing = false;
        _routeError = null;
      });
      if (route.points.isNotEmpty) {
        _map.fitCamera(
          CameraFit.coordinates(
            coordinates: route.points,
            padding: const EdgeInsets.all(24),
            maxZoom: 18.5,
          ),
        );
      }
    } catch (_) {
      if (!mounted || requestId != _routeRequestId) return;
      setState(() {
        _routing = false;
        _routeError =
            'Route updated unsuccessfully. Check signal and try again.';
      });
    }
  }

  double? _distanceTo(ParkDiscoveryItem item) {
    final position = _position;
    final dest = item.position;
    if (position == null || dest == null) return null;
    return Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      dest.latitude,
      dest.longitude,
    );
  }

  String _distanceLabel(double meters) => meters < 1000
      ? '${meters.round()} m'
      : '${(meters / 1000).toStringAsFixed(1)} km';

  void _onTileError(TileImage tile, Object error, StackTrace? stackTrace) {
    if (mounted && !_tileFailed) setState(() => _tileFailed = true);
  }

  @override
  Widget build(BuildContext context) {
    final visibleItems = _visibleItems;
    return Scaffold(
      backgroundColor: wonderlaCream,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 720;
          if (isWide) {
            return SafeArea(
              child: Row(
                children: [
                  Expanded(
                    flex: 13,
                    child: _mapPanel(visibleItems, isWide: true),
                  ),
                  SizedBox(
                    width: (constraints.maxWidth * 0.35).clamp(320.0, 410.0),
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(left: BorderSide(color: wonderlaBorder)),
                      ),
                      child: _locationsPanel(visibleItems, isWide: true),
                    ),
                  ),
                ],
              ),
            );
          }

          return Stack(
            fit: StackFit.expand,
            children: [
              _mapPanel(visibleItems, isWide: false),
              if (!_isMapExpanded)
                DraggableScrollableSheet(
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
                    child: _locationsPanel(
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

  Widget _mapPanel(
    List<ParkDiscoveryItem> visibleItems, {
    required bool isWide,
  }) {
    final topPadding = MediaQuery.paddingOf(context).top;
    final overlayTop = isWide ? 12.0 : topPadding + 10.0;
    final controlsTop =
        overlayTop + (_catalog.availableCategories.isEmpty ? 62.0 : 108.0);
    final bottomOffset = isWide || _isMapExpanded ? 18.0 : 210.0;
    final showLabels = _showMarkerLabels || visibleItems.length <= 6;

    return Stack(
      fit: StackFit.expand,
      children: [
        FlutterMap(
          key: const ValueKey('wonderla-osm-map'),
          mapController: _map,
          options: MapOptions(
            initialCenter: _park,
            initialZoom: 16.5,
            minZoom: 16,
            maxZoom: 19,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all,
            ),
            onPositionChanged: (camera, _) {
              _currentZoom = camera.zoom;
              final shouldShow = camera.zoom >= 17.0;
              if (shouldShow != _showMarkerLabels && mounted) {
                setState(() => _showMarkerLabels = shouldShow);
              }
            },
          ),
          children: [
            TileLayer(
              key: ValueKey(_tileRevision),
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'maps_wonderla_flutter',
              maxNativeZoom: 19,
              errorTileCallback: _onTileError,
            ),
            if (_route != null)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _route!.points,
                    strokeWidth: 7,
                    color: wonderlaBlue,
                    borderStrokeWidth: 2,
                    borderColor: Colors.white,
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                ...visibleItems.where((i) => i.position != null).map(
                  (item) => Marker(
                    point: item.position!,
                    width: 118,
                    height: (showLabels || item.id == _selected?.id) ? 76 : 56,
                    alignment: Alignment.topCenter,
                    child: WonderlaMapPin(
                      item: item,
                      selected: item.id == _selected?.id,
                      showLabel: showLabels,
                      onTap: () => _select(item),
                    ),
                  ),
                ),
                if (_selected != null &&
                    _selected!.position != null &&
                    !visibleItems.any((item) => item.id == _selected!.id))
                  Marker(
                    point: _selected!.position!,
                    width: 118,
                    height: 76,
                    alignment: Alignment.topCenter,
                    child: WonderlaMapPin(
                      item: _selected!,
                      selected: true,
                      showLabel: true,
                      onTap: () => _select(_selected!),
                    ),
                  ),
                if (_position != null)
                  Marker(
                    point: LatLng(_position!.latitude, _position!.longitude),
                    width: 44,
                    height: 44,
                    child: const WonderlaUserLocationPin(useMascot: true),
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
        ),

        // Floating Search + Filter Bar
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
                  controller: _search,
                  focusNode: _searchFocus,
                  onBack: Navigator.of(context).canPop()
                      ? () => Navigator.of(context).maybePop()
                      : null,
                  onChanged: _onSearchChanged,
                  onSubmitted: _submitSearch,
                  onClear: () {
                    _search.clear();
                    _onSearchChanged('');
                  },
                  searching: _searching,
                  onOpenFilters: _openFilterSheet,
                  activeFilterCount: _selectedCategories.length,
                ),
              ),
              if (_catalog.availableCategories.isNotEmpty) ...[
                const SizedBox(height: 8),
                ParkCategoryFilterBar(
                  availableCategories: _catalog.availableCategories,
                  categoryCounts: _catalog.categoryCounts,
                  selectedCategories: _selectedCategories,
                  totalCount: _catalog.items.length,
                  onSelectAll: () => setState(_selectedCategories.clear),
                  onToggleCategory: (category) => setState(() {
                    if (!_selectedCategories.add(category)) {
                      _selectedCategories.remove(category);
                    }
                  }),
                  hasAnyActiveFilter: _hasAnyActiveFilter,
                  onClearAll: _clearAllFilters,
                ),
              ],
            ],
          ),
        ),

        // Floating Map Controls
        Positioned(
          top: controlsTop,
          right: 12,
          child: Column(
            children: [
              _mapAction(
                Icons.my_location_rounded,
                _locateUser,
                loading: _locating,
                active: _position != null,
                tooltip: 'Show my live location',
              ),
              const SizedBox(height: 8),
              _mapAction(
                Icons.center_focus_strong_rounded,
                _resetMapView,
                tooltip: 'Reset park map view',
              ),
              const SizedBox(height: 8),
              Material(
                color: Colors.white,
                elevation: 4,
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
                        onPressed: () => _zoomBy(0.7),
                        icon: const Icon(
                          Icons.add_rounded,
                          color: wonderlaNavy,
                          size: 20,
                        ),
                      ),
                    ),
                    Container(width: 24, height: 1, color: wonderlaBorder),
                    SizedBox(
                      width: 42,
                      height: 38,
                      child: IconButton(
                        tooltip: 'Zoom out',
                        padding: EdgeInsets.zero,
                        onPressed: () => _zoomBy(-0.7),
                        icon: const Icon(
                          Icons.remove_rounded,
                          color: wonderlaNavy,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (!isWide) ...[
                const SizedBox(height: 8),
                _mapAction(
                  _isMapExpanded
                      ? Icons.fullscreen_exit_rounded
                      : Icons.fullscreen_rounded,
                  () => setState(() => _isMapExpanded = !_isMapExpanded),
                  active: _isMapExpanded,
                  tooltip: _isMapExpanded
                      ? 'Show locations list'
                      : 'Expand map',
                ),
              ],
            ],
          ),
        ),

        if (_tileFailed)
          Positioned(
            left: 12,
            right: 68,
            top: controlsTop,
            child: _tileNotice(),
          ),
        if (_locationError != null && !_tileFailed)
          Positioned(
            left: 12,
            right: 68,
            top: controlsTop,
            child: _inlineNotice(_locationError!, Icons.my_location_rounded),
          ),
        if (_route != null)
          Positioned(left: 16, bottom: bottomOffset, child: _routeSummary()),
        if (_routing)
          Positioned(
            left: 14,
            bottom: bottomOffset,
            child: Material(
              color: Colors.white,
              elevation: 4,
              borderRadius: BorderRadius.circular(14),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 9),
                    Text(
                      'Updating route from your location…',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _mapAction(
    IconData icon,
    VoidCallback action, {
    bool loading = false,
    bool active = false,
    required String tooltip,
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
        onPressed: loading ? null : action,
        icon: loading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: active ? Colors.white : _navy,
                ),
              )
            : Icon(icon, color: active ? wonderlaGold : _navy, size: 21),
      ),
    ),
  );

  Widget _locationsPanel(
    List<ParkDiscoveryItem> visibleItems, {
    required bool isWide,
    ScrollController? scrollController,
  }) {
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
                      _search.text.trim().isEmpty
                          ? 'Explore Wonderla'
                          : 'Search results',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                      ),
                    ),
                    Text(
                      '${visibleItems.length} ${visibleItems.length == 1 ? 'place' : 'places'} available',
                      style: const TextStyle(
                        fontSize: 12,
                        color: wonderlaMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (_selected != null)
                IconButton(
                  tooltip: 'Clear selected destination',
                  onPressed: _clearDestination,
                  icon: const Icon(Icons.close_rounded, color: _navy),
                )
              else if (_loadingPlaces)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                IconButton(
                  tooltip: 'Refresh park locations',
                  onPressed: _loadParkPlaces,
                  icon: const Icon(Icons.refresh_rounded, color: _navy),
                ),
            ],
          ),
        ),
        if (_routeError != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: _inlineNotice(_routeError!, Icons.directions_walk_rounded),
          ),
        Expanded(
          child: _placesContent(
            visibleItems,
            scrollController: scrollController,
          ),
        ),
      ],
    );
  }

  Widget _placesContent(
    List<ParkDiscoveryItem> places, {
    ScrollController? scrollController,
  }) {
    if (_loadingPlaces && _places.isEmpty && _search.text.trim().isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: _navy),
            SizedBox(height: 12),
            Text(
              'Loading locations inside the park…',
              style: TextStyle(color: wonderlaNavy),
            ),
          ],
        ),
      );
    }
    if (_placesError != null &&
        _places.isEmpty &&
        _search.text.trim().isEmpty) {
      return _emptyState(
        icon: Icons.wifi_off_rounded,
        title: 'Park locations are unavailable',
        message: _placesError!,
        action: 'Try again',
        onAction: _loadParkPlaces,
      );
    }
    if (_searching && places.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: _navy),
            SizedBox(height: 10),
            Text(
              'Searching nearby locations…',
              style: TextStyle(color: wonderlaNavy),
            ),
          ],
        ),
      );
    }
    if (places.isEmpty) {
      return _emptyState(
        icon: _search.text.isEmpty
            ? Icons.map_outlined
            : Icons.search_off_rounded,
        title: _search.text.isEmpty
            ? 'No matching places'
            : 'No matching places',
        message: _search.text.isEmpty
            ? 'Adjust or clear your active filters to see mapped locations inside Wonderla.'
            : _searchError ?? 'Try another name or search nearby locations.',
        action: _search.text.trim().isNotEmpty && _searchError == null
            ? 'Search nearby'
            : _hasAnyActiveFilter
            ? 'Clear all filters'
            : null,
        onAction: _search.text.trim().isNotEmpty && _searchError == null
            ? () => _submitSearch(_search.text)
            : _hasAnyActiveFilter
            ? _clearAllFilters
            : null,
      );
    }
    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 18),
      itemCount: places.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _placeRow(places[index]),
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String message,
    String? action,
    VoidCallback? onAction,
  }) => Center(
    child: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: wonderlaNavy, size: 36),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700, color: _ink),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: wonderlaNavy,
                fontSize: 12,
                height: 1.4,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(action),
              ),
            ],
          ],
        ),
      ),
    ),
  );

  Widget _placeRow(ParkDiscoveryItem item) {
    final isSelected = item.id == _selected?.id;
    final distance = _distanceTo(item);
    return Material(
      color: isSelected ? const Color(0xFFF0F5FF) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => _select(item),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(11, 10, 8, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? wonderlaCobalt : wonderlaBorder,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: item.category.tintColor,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(item.icon, color: item.category.color, size: 22),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: _ink,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${item.category.label}${distance == null ? '' : '  ·  ${_distanceLabel(distance)}'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: wonderlaMuted,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Directions to ${item.name}',
                onPressed: _routing ? null : () => _directionsTo(item),
                icon: _routing && isSelected
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.directions_rounded, color: _navy),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _routeSummary() => Material(
    elevation: 6,
    color: wonderlaNavy,
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      onTap: _showDirections,
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
            const SizedBox(width: 8),
            Text(
              '${_distanceLabel(_route!.distanceMeters)}  ·  ${(_route!.durationSeconds / 60).ceil()} min',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded, color: wonderlaGold),
          ],
        ),
      ),
    ),
  );

  void _showDirections() {
    final route = _route;
    if (route == null) return;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .55,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Text(
                  'Walking directions',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  itemCount: route.steps.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, indent: 66),
                  itemBuilder: (context, index) {
                    final step = route.steps[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: wonderlaCream,
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: _navy,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      title: Text(step.instruction),
                      trailing: Text(
                        _distanceLabel(step.distanceMeters),
                        style: const TextStyle(color: wonderlaNavy),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tileNotice() => _inlineNotice(
    'Map tiles could not connect. Check internet or device DNS.',
    Icons.wifi_off_rounded,
    action: TextButton(
      onPressed: () => setState(() {
        _tileFailed = false;
        _tileRevision++;
      }),
      child: const Text('Retry'),
    ),
  );

  Widget _inlineNotice(String text, IconData icon, {Widget? action}) =>
      Material(
        color: Colors.white,
        elevation: 4,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          child: Row(
            children: [
              Icon(icon, color: wonderlaCobalt, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(text, style: const TextStyle(fontSize: 11.5))),
              ?action,
            ],
          ),
        ),
      );
}
