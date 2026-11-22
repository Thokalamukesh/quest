part of 'visitor_home.dart';

class VisitorSectionScreen extends StatefulWidget {
  const VisitorSectionScreen({
    super.key,
    required this.title,
    required this.config,
    required this.api,
    this.initialTab,
  });
  final String title;
  final Map<String, dynamic> config;
  final CmsApi api;
  final String? initialTab;
  @override
  State<VisitorSectionScreen> createState() => _VisitorSectionScreenState();
}

class _VisitorSectionScreenState extends State<VisitorSectionScreen> {
  late Map<String, dynamic> _config;
  late List<ParkDiscoveryItem> _rideItems;
  late Map<ParkDiscoveryCategory, int> _rideCategoryCounts;
  late List<ParkDiscoveryCategory> _rideAvailableCategories;

  final _rideSearchController = TextEditingController();
  final _diningSearchController = TextEditingController();
  final Set<ParkDiscoveryCategory> _selectedRideCategories = {};

  bool _savedRidesOnly = false;
  bool _vegDiningOnly = false;
  bool _waitSortAscending = true;
  bool _loading = false;
  String? _error;
  late String _rideTab;

  String get _parkSlug => _config['slug']?.toString().trim() ?? 'park';

  @override
  void initState() {
    super.initState();
    _config = Map<String, dynamic>.from(widget.config);
    _rideTab = widget.initialTab ?? 'Rides';
    SavedPlacesStore.instance.addListener(_onSavedChanged);
    _rebuildRideCache();
  }

  void _onSavedChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    SavedPlacesStore.instance.removeListener(_onSavedChanged);
    _rideSearchController.dispose();
    _diningSearchController.dispose();
    super.dispose();
  }

  void _rebuildRideCache() {
    final rides = _list('rides');
    _rideItems = rides
        .map(
          (ride) => ParkDiscoveryCatalog.fromRideEntry(
            ride,
            config: _config,
            baseUrl: widget.api.baseUrl,
          ),
        )
        .toList(growable: false);
    final counts = <ParkDiscoveryCategory, int>{};
    for (final item in _rideItems) {
      counts[item.category] = (counts[item.category] ?? 0) + 1;
    }
    _rideCategoryCounts = counts;
    _rideAvailableCategories = ParkDiscoveryCategory.values
        .where(counts.containsKey)
        .toList(growable: false);
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _config = await widget.api.park(widget.config['slug'] as String);
      _rebuildRideCache();
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  void _openParkMap({
    String? focusPlaceName,
    bool autoStartDirections = false,
    Map<String, dynamic>? focusPlace,
    String? directionsUrl,
    String? directionsNote,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ConfiguredParkMapScreen(
          config: _config,
          baseUrl: widget.api.baseUrl,
          api: widget.api,
          initialFocusPlaceName: focusPlaceName,
          autoStartDirections: autoStartDirections,
          initialFocusPlace: focusPlace,
          initialDirectionsUrl: directionsUrl,
          initialDirectionsNote: directionsNote,
        ),
      ),
    );
  }

  void _openRideSheet(ParkDiscoveryItem item) {
    showParkPlaceDetailSheet(
      context,
      item: item,
      parkSlug: _parkSlug,
      onLocateOnMap: () => _openParkMap(
        focusPlaceName: item.name,
        autoStartDirections: true,
        focusPlace: item.rawRide,
        directionsUrl: item.directionsUrl,
        directionsNote: item.directionsNote,
      ),
    );
  }

  String _url(String? value) {
    if (value == null || value.isEmpty) return '';
    if (Uri.tryParse(value)?.hasScheme == true) return value;
    return '${widget.api.baseUrl}${value.startsWith('/') ? '' : '/'}$value';
  }

  List<Map<String, dynamic>> _list(String key) =>
      List<Map<String, dynamic>>.from(
        (_config[key] as List? ?? []).map(
          (e) => Map<String, dynamic>.from(e as Map),
        ),
      );
  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[
      if (['RIDES & WATER ACTIVITIES', 'DINING & MENU'].contains(widget.title))
        IconButton(
          tooltip: 'Open Park Map',
          onPressed: _openParkMap,
          icon: const Icon(Icons.map_outlined),
        ),
      if (['RIDES & WATER ACTIVITIES', 'MAINTENANCE LOG'].contains(widget.title))
        IconButton(
          tooltip: 'Refresh',
          onPressed: _refresh,
          icon: const Icon(Icons.refresh_rounded),
        ),
    ];

    return Scaffold(
      backgroundColor: _pale,
      appBar: AppBar(
        backgroundColor: wonderlaWhite,
        foregroundColor: wonderlaNavy,
        surfaceTintColor: wonderlaWhite,
        toolbarHeight: 68,
        title: Text(
          widget.title,
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
        ),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        actions: actions.isEmpty ? null : actions,
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
          children: [
            if (_error != null) _notice(_error!, error: true),
            if (_loading) const LinearProgressIndicator(color: _navy),
            ..._content(),
          ],
        ),
      ),
    );
  }

  List<Widget> _content() => switch (widget.title) {
    'RIDES & WATER ACTIVITIES' => _ridesEvents(),
    'EVENTS' => _events(),
    'DINING & MENU' => _dining(),
    'RIDE GUIDELINES' => _guidelines(),
    'SAFETY & HYGIENE' => _safety(),
    'MAINTENANCE LOG' => _maintenance(),
    _ => [const SizedBox.shrink()],
  };

  List<Widget> _ridesEvents() {
    final tabLabels = ['Rides', 'Water activities', 'Live wait time'];
    final tabs = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final tab in tabLabels)
          ChoiceChip(
            label: Text(tab),
            selected: _rideTab == tab,
            showCheckmark: false,
            selectedColor: _navy,
            backgroundColor: Colors.white,
            labelStyle: TextStyle(
              color: _rideTab == tab ? Colors.white : wonderlaNavy,
              fontWeight: FontWeight.w700,
            ),
            onSelected: (_) => setState(() => _rideTab = tab),
          ),
      ],
    );

    final query = _rideSearchController.text.trim().toLowerCase();
    final savedCount = SavedPlacesStore.instance.savedCount(_parkSlug);
    final hasFilter =
        _selectedRideCategories.isNotEmpty ||
        _savedRidesOnly ||
        query.isNotEmpty;
    final filteredRides = _rideItems
        .where((item) {
          if (_savedRidesOnly &&
              !SavedPlacesStore.instance.isSaved(_parkSlug, item.name)) {
            return false;
          }
          if (_selectedRideCategories.isNotEmpty &&
              !_selectedRideCategories.contains(item.category)) {
            return false;
          }
          if (query.isNotEmpty && !item.searchIndex.contains(query)) {
            return false;
          }
          return true;
        })
        .toList(growable: false);

    return [
      tabs,
      const SizedBox(height: 14),
      if (_rideTab == 'Live wait time') ..._waitTimes(),
      if (_rideTab == 'Water activities') ..._wave(),
      if (_rideTab == 'Rides' && _rideItems.isEmpty) _empty('Rides'),
      if (_rideTab == 'Rides' && _rideItems.isNotEmpty) ...[
        ParkFloatingSearchHeader(
          controller: _rideSearchController,
          hintText: 'Search rides, thrill level, themes…',
          onChanged: (_) => setState(() {}),
          onClear: () {
            _rideSearchController.clear();
            setState(() {});
          },
        ),
        if (_rideAvailableCategories.length > 1 ||
            hasFilter ||
            savedCount > 0) ...[
          const SizedBox(height: 10),
          ParkCategoryFilterBar(
            availableCategories: _rideAvailableCategories,
            categoryCounts: _rideCategoryCounts,
            selectedCategories: _selectedRideCategories,
            totalCount: _rideItems.length,
            savedOnly: _savedRidesOnly,
            savedCount: savedCount,
            onToggleSavedOnly: () =>
                setState(() => _savedRidesOnly = !_savedRidesOnly),
            padding: EdgeInsets.zero,
            onSelectAll: () => setState(() {
              _selectedRideCategories.clear();
              _savedRidesOnly = false;
            }),
            onToggleCategory: (category) => setState(() {
              if (!_selectedRideCategories.add(category)) {
                _selectedRideCategories.remove(category);
              }
            }),
            hasAnyActiveFilter: hasFilter,
            onClearAll: () {
              _rideSearchController.clear();
              setState(() {
                _selectedRideCategories.clear();
                _savedRidesOnly = false;
              });
            },
          ),
        ],
        const SizedBox(height: 14),
        if (filteredRides.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: Column(
              children: [
                const Icon(
                  Icons.filter_alt_off_rounded,
                  color: wonderlaMuted,
                  size: 36,
                ),
                const SizedBox(height: 8),
                const Text(
                  'No rides match your current search or filters.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: wonderlaNavy,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () {
                    _rideSearchController.clear();
                    setState(() {
                      _selectedRideCategories.clear();
                      _savedRidesOnly = false;
                    });
                  },
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('Clear all filters'),
                ),
              ],
            ),
          )
        else
          for (final item in filteredRides) _rideDiscoveryCard(item),
      ],
    ];
  }

  Widget _rideDiscoveryCard(ParkDiscoveryItem item) {
    final saved = SavedPlacesStore.instance.isSaved(_parkSlug, item.name);
    final completed = SavedPlacesStore.instance.isCompleted(
      _parkSlug,
      item.name,
    );
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: wonderlaBorder),
      ),
      child: InkWell(
        onTap: () => _openRideSheet(item),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _thumb(
                item.rawRide?['img']?.toString(),
                size: 108,
                fallbackIcon: item.icon,
                tint: item.category.tintColor,
                iconColor: item.category.color,
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: item.category.tintColor,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      item.icon,
                                      size: 13,
                                      color: item.category.color,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      item.category.shortLabel,
                                      style: TextStyle(
                                        color: item.category.color,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (item.waitTimeMinutes != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: wonderlaWaitTimeColor(
                                      item.waitTimeMinutes!,
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Text(
                                    '${item.waitTimeMinutes} min wait',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: saved
                              ? 'Remove from My Day'
                              : 'Save to My Day',
                          constraints: const BoxConstraints.tightFor(
                            width: 32,
                            height: 32,
                          ),
                          padding: EdgeInsets.zero,
                          onPressed: () => SavedPlacesStore.instance
                              .toggleSaved(_parkSlug, item.name),
                          icon: Icon(
                            saved
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            size: 19,
                            color: saved ? wonderlaFlagRed : wonderlaMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            item.name.toUpperCase(),
                            style: const TextStyle(
                              color: _navy,
                              fontWeight: FontWeight.w900,
                              fontSize: 17.5,
                              height: 1.12,
                            ),
                          ),
                        ),
                        if (completed) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.check_circle_rounded,
                            color: wonderlaSuccess,
                            size: 17,
                          ),
                        ],
                      ],
                    ),
                    if (item.description.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        item.description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: wonderlaNavy,
                          fontSize: 13.5,
                          height: 1.35,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    _tags(item.tags),
                    if (item.kioskBookingEnabled) const _BookingCallout(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _events() => [
    if (_list('events').isEmpty) _empty('Events'),
    for (final item in _list('events')) _mediaCard(item, event: true),
  ];

  bool _isPureVegOutlet(Map<String, dynamic> outlet) {
    final cuisine = (outlet['cuisine']?.toString() ?? '').toLowerCase();
    final tags = (outlet['tags'] is List)
        ? (outlet['tags'] as List).join(' ').toLowerCase()
        : '';
    if (cuisine.contains('pure veg') ||
        cuisine.contains('vegetarian') ||
        tags.contains('vegetarian')) {
      return true;
    }
    final items = outlet['items'];
    if (items is List && items.isNotEmpty) {
      return items.whereType<Map>().every((it) => it['veg'] == true);
    }
    return false;
  }

  List<Widget> _dining() {
    final outlets = _list('dining');
    final query = _diningSearchController.text.trim().toLowerCase();
    final filteredOutlets = outlets
        .where((outlet) {
          if (_vegDiningOnly && !_isPureVegOutlet(outlet)) return false;
          if (query.isNotEmpty) {
            final haystack = [
              outlet['name'],
              outlet['cuisine'],
              outlet['description'],
              if (outlet['tags'] is List) (outlet['tags'] as List).join(' '),
            ].whereType<Object>().join(' ').toLowerCase();
            if (!haystack.contains(query)) return false;
          }
          return true;
        })
        .toList(growable: false);

    return [
      Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [wonderlaNavy, wonderlaCobalt],
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.restaurant_rounded, color: wonderlaGold),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'A GOOD DAY NEEDS GOOD FOOD',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .35,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${outlets.length} ${outlets.length == 1 ? 'place' : 'places'} to eat around the park',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .84),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      if (outlets.isNotEmpty) ...[
        ParkFloatingSearchHeader(
          controller: _diningSearchController,
          hintText: 'Search restaurants, cuisines, snacks…',
          onChanged: (_) => setState(() {}),
          onClear: () {
            _diningSearchController.clear();
            setState(() {});
          },
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: Text('All dining (${outlets.length})'),
              selected: !_vegDiningOnly,
              showCheckmark: false,
              selectedColor: wonderlaNavy,
              backgroundColor: Colors.white,
              labelStyle: TextStyle(
                color: !_vegDiningOnly ? Colors.white : wonderlaNavy,
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
              onSelected: (_) => setState(() => _vegDiningOnly = false),
            ),
            ChoiceChip(
              avatar: Icon(
                Icons.eco_rounded,
                size: 16,
                color: _vegDiningOnly ? Colors.white : wonderlaSuccess,
              ),
              label: const Text('Pure Veg'),
              selected: _vegDiningOnly,
              showCheckmark: false,
              selectedColor: wonderlaSuccess,
              backgroundColor: Colors.white,
              labelStyle: TextStyle(
                color: _vegDiningOnly ? Colors.white : wonderlaNavy,
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
              onSelected: (_) =>
                  setState(() => _vegDiningOnly = !_vegDiningOnly),
            ),
          ],
        ),
        const SizedBox(height: 14),
      ],
      if (outlets.isEmpty)
        _empty('Dining options')
      else if (filteredOutlets.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 28),
          child: Column(
            children: [
              const Icon(
                Icons.restaurant_menu_rounded,
                color: wonderlaMuted,
                size: 36,
              ),
              const SizedBox(height: 8),
              const Text(
                'No restaurants match your filter.',
                style: TextStyle(
                  color: wonderlaNavy,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () {
                  _diningSearchController.clear();
                  setState(() => _vegDiningOnly = false);
                },
                icon: const Icon(Icons.close_rounded, size: 18),
                label: const Text('Clear filters'),
              ),
            ],
          ),
        )
      else
        for (final outlet in filteredOutlets)
          Card(
            color: Colors.white,
            margin: const EdgeInsets.only(bottom: 13),
            clipBehavior: Clip.antiAlias,
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: wonderlaBorder),
            ),
            child: InkWell(
              onTap: () => _diningDetail(outlet),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: SizedBox(
                        width: 108,
                        height: 118,
                        child: outlet['img']?.toString().isNotEmpty == true
                            ? Image.network(
                                _url(outlet['img']?.toString()),
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    _diningImageFallback(),
                              )
                            : _diningImageFallback(),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if ((outlet['cuisine']?.toString() ?? '').isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                outlet['cuisine'].toString(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFFB45309),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          const SizedBox(height: 7),
                          Text(
                            outlet['name']?.toString() ?? 'Dining',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _navy,
                              fontWeight: FontWeight.w900,
                              fontSize: 17,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            outlet['description']?.toString() ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: wonderlaMuted,
                              height: 1.35,
                              fontSize: 12.5,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Text(
                                'VIEW MENU',
                                style: TextStyle(
                                  color: wonderlaCobalt,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: .5,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.arrow_forward_rounded,
                                color: wonderlaCobalt,
                                size: 15,
                              ),
                              const Spacer(),
                              InkWell(
                                onTap: () => _openParkMap(
                                  focusPlaceName: outlet['name']?.toString(),
                                  autoStartDirections: true,
                                  focusPlace: outlet,
                                  directionsUrl:
                                      outlet['directionsUrl']?.toString(),
                                  directionsNote:
                                      outlet['directions']?.toString(),
                                ),
                                borderRadius: BorderRadius.circular(12),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 3,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.directions_rounded,
                                        size: 14,
                                        color: wonderlaCobalt,
                                      ),
                                      SizedBox(width: 3),
                                      Text(
                                        'Map',
                                        style: TextStyle(
                                          color: wonderlaCobalt,
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
    ];
  }

  Widget _diningImageFallback() => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFEF3C7), Color(0xFFFDE68A)],
      ),
    ),
    alignment: Alignment.center,
    child: const Icon(
      Icons.restaurant_rounded,
      color: Color(0xFFD97706),
      size: 32,
    ),
  );

  Future<void> _diningDetail(Map<String, dynamic> outlet) =>
      showWonderlaDiningMenuSheet(
        context,
        outlet: outlet,
        resolveUrl: _url,
        onLocateOnMap: () => _openParkMap(
          focusPlaceName: outlet['name']?.toString(),
          autoStartDirections: true,
          focusPlace: outlet,
          directionsUrl: outlet['directionsUrl']?.toString(),
          directionsNote: outlet['directions']?.toString(),
        ),
      );

  List<Widget> _waitTimes() {
    final items = _list('liveWaitTimes')
      ..sort((a, b) {
        final am = num.tryParse('${a['time']}') ?? 0;
        final bm = num.tryParse('${b['time']}') ?? 0;
        return _waitSortAscending ? am.compareTo(bm) : bm.compareTo(am);
      });
    return [
      Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current ride queues',
                  style: TextStyle(
                    color: _navy,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Pull down to refresh the latest wait times.',
                  style: TextStyle(color: wonderlaMuted, fontSize: 12.5),
                ),
              ],
            ),
          ),
          if (items.length > 1)
            ActionChip(
              avatar: Icon(
                _waitSortAscending
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                size: 16,
                color: wonderlaCobalt,
              ),
              label: Text(
                _waitSortAscending ? 'Shortest' : 'Longest',
                style: const TextStyle(
                  color: wonderlaNavy,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              backgroundColor: Colors.white,
              onPressed: () =>
                  setState(() => _waitSortAscending = !_waitSortAscending),
            ),
        ],
      ),
      const SizedBox(height: 12),
      if (items.isEmpty) _empty('Live wait times'),
      for (final item in items) _waitTimeCard(item),
    ];
  }

  Widget _waitTimeCard(Map<String, dynamic> item) {
    final minutes = (num.tryParse('${item['time']}') ?? 0).round();
    final title = item['title']?.toString() ?? '';
    final badgeColor = wonderlaWaitTimeColor(minutes);

    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: wonderlaBorder),
      ),
      child: InkWell(
        onTap: () {
          final discovery = ParkDiscoveryCatalog.fromRideEntry(
            item,
            config: _config,
            baseUrl: widget.api.baseUrl,
          );
          _openRideSheet(discovery);
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _thumb(item['img']?.toString(), size: 70),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _navy,
                        fontSize: 16.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item['description']?.toString() ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: wonderlaMuted,
                        fontSize: 12.5,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      '$minutes min',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    wonderlaWaitTimeCrowdLabel(minutes),
                    style: TextStyle(
                      color: badgeColor,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _guidelines() => [
    for (final item in _list('rideGuidelines'))
      _textCard(
        item['title']?.toString() ?? '',
        item['description']?.toString() ?? '',
        icon: Icons.straighten_rounded,
        trailing: item['minHeight']?.toString(),
      ),
  ];

  List<Widget> _wave() {
    final sessions = _list('waveRainDance');
    return [
      if (sessions.isEmpty) _empty('Water activities'),
      for (final item in sessions) _waveActivityCard(item),
    ];
  }

  Widget _waveActivityCard(Map<String, dynamic> item) {
    final title = item['title']?.toString() ?? '';
    final duration = item['rideDuration'] ?? 0;
    final slots = List<String>.from(item['timeSlot'] as List? ?? const []);
    final nextIndex = ParkScheduleHelper.nextSlotIndex(slots);

    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: wonderlaBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _wideImage(
            item['img']?.toString(),
            fallbackIcon: Icons.waves_rounded,
            fallbackColors: const [Color(0xFF0369A1), Color(0xFF0EA5E9)],
            badgeText: '$duration min session',
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: _navy,
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Duration: $duration minutes per session',
                            style: const TextStyle(
                              color: wonderlaMuted,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 36),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 6,
                        ),
                      ),
                      onPressed: () => _openParkMap(
                        focusPlaceName: title,
                        autoStartDirections: true,
                      ),
                      icon: const Icon(Icons.map_outlined, size: 15),
                      label: const Text(
                        'Map',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                if (slots.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'DAILY SESSIONS',
                    style: TextStyle(
                      color: wonderlaMuted,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.7,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var i = 0; i < slots.length; i++)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: i == nextIndex
                                ? wonderlaCobalt
                                : wonderlaCream,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: i == nextIndex
                                  ? wonderlaCobalt
                                  : wonderlaBorder,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (i == nextIndex) ...[
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: const BoxDecoration(
                                    color: wonderlaGold,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],
                              Text(
                                i == nextIndex
                                    ? '${slots[i]} · Next'
                                    : slots[i],
                                style: TextStyle(
                                  color: i == nextIndex
                                      ? Colors.white
                                      : wonderlaNavy,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _safety() => [
    for (final item in _list('safetyHygiene'))
      _mediaCard(
        item,
        fallbackIcon: Icons.shield_outlined,
        tint: const Color(0xFFE6F5EE),
        iconColor: wonderlaSuccess,
      ),
  ];
  List<Widget> _maintenance() {
    final entries = _list('maintenanceLog');
    if (entries.isEmpty) return [_empty('Maintenance log')];
    return [
      Row(
        children: [
          const Expanded(
            child: Text(
              'Service records',
              style: TextStyle(
                color: _navy,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Chip(
            label: Text(
              '${entries.length} ${entries.length == 1 ? 'record' : 'records'}',
            ),
            backgroundColor: Colors.white,
          ),
        ],
      ),
      const SizedBox(height: 10),
      for (final item in entries) _maintenanceRow(item),
    ];
  }

  Widget _maintenanceRow(Map<String, dynamic> item) {
    final ride = item['ride']?.toString() ?? '';
    final service = item['lastService']?.toString() ?? '';
    final checks = item['checks']?.toString() ?? '';
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: wonderlaBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: wonderlaWhite,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.build_outlined, color: _navy),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    ride.isEmpty ? 'Park equipment' : ride,
                    style: const TextStyle(
                      color: _navy,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Wrap(
              spacing: 22,
              runSpacing: 12,
              children: [
                _maintenanceInfo(
                  Icons.event_available_outlined,
                  'Last service',
                  service,
                ),
                _maintenanceInfo(
                  Icons.checklist_rounded,
                  'Work completed',
                  checks,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _maintenanceInfo(IconData icon, String label, String value) =>
      SizedBox(
        width: 220,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 17, color: wonderlaNavy),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: wonderlaNavy,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value.isEmpty ? 'Not recorded' : value,
                    style: const TextStyle(
                      color: _navy,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _mediaCard(
    Map<String, dynamic> item, {
    bool event = false,
    IconData? fallbackIcon,
    Color? tint,
    Color? iconColor,
  }) => Card(
    color: Colors.white,
    margin: const EdgeInsets.only(bottom: 14),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: const BorderSide(color: wonderlaBorder),
    ),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _thumb(
            item['img']?.toString(),
            size: 98,
            fallbackIcon:
                fallbackIcon ??
                (event
                    ? Icons.celebration_rounded
                    : Icons.local_activity_outlined),
            tint:
                tint ??
                (event ? const Color(0xFFFFF4D6) : const Color(0xFFE8F0FE)),
            iconColor: iconColor ?? (event ? wonderlaNavy : wonderlaCobalt),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (event && item['time'] != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 7),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4.5,
                    ),
                    decoration: BoxDecoration(
                      color: wonderlaGold,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.schedule_rounded,
                          size: 13,
                          color: wonderlaNavy,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          item['time'].toString(),
                          style: const TextStyle(
                            color: wonderlaNavy,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                Text(
                  (item['title'] ?? item['name'] ?? '')
                      .toString()
                      .toUpperCase(),
                  style: const TextStyle(
                    color: _navy,
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  item['description']?.toString() ?? '',
                  style: const TextStyle(
                    color: wonderlaMuted,
                    fontSize: 13.5,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                _tags(item['tags']),
                if (item['kioskBookingEnabled'] == true)
                  const _BookingCallout(),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _textCard(
    String title,
    String description, {
    required IconData icon,
    String? trailing,
  }) => Card(
    color: Colors.white,
    margin: const EdgeInsets.only(bottom: 12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: const BorderSide(color: wonderlaBorder),
    ),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F0FE),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: wonderlaCobalt, size: 26),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: _navy,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    if (trailing != null && trailing.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: wonderlaGold,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          trailing,
                          style: const TextStyle(
                            color: wonderlaNavy,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  description,
                  style: const TextStyle(
                    color: wonderlaMuted,
                    fontSize: 13.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _thumb(
    String? path, {
    double size = 100,
    IconData fallbackIcon = Icons.local_activity_outlined,
    Color tint = const Color(0xFFE8F0FE),
    Color iconColor = wonderlaCobalt,
  }) {
    Widget fallback() => Container(
      color: tint,
      alignment: Alignment.center,
      child: Icon(fallbackIcon, color: iconColor, size: size * 0.34),
    );
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(16),
      ),
      child: path == null || path.isEmpty
          ? fallback()
          : Image.network(
              _url(path),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => fallback(),
            ),
    );
  }

  Widget _wideImage(
    String? path, {
    IconData fallbackIcon = Icons.waves_rounded,
    List<Color> fallbackColors = const [wonderlaNavy, wonderlaCobalt],
    String? badgeText,
  }) {
    Widget fallbackBanner() => Container(
      height: 124,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: fallbackColors,
        ),
      ),
      child: Stack(
        children: [
          Center(
            child: Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .16),
                shape: BoxShape.circle,
                border: Border.all(
                  color: wonderlaGold.withValues(alpha: .7),
                  width: 1.8,
                ),
              ),
              child: Icon(fallbackIcon, color: Colors.white, size: 30),
            ),
          ),
          if (badgeText != null && badgeText.isNotEmpty)
            Positioned(
              left: 14,
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4.5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .94),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  badgeText,
                  style: const TextStyle(
                    color: wonderlaNavy,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    if (path == null || path.isEmpty) return fallbackBanner();
    return Stack(
      children: [
        Image.network(
          _url(path),
          height: 180,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => fallbackBanner(),
        ),
        if (badgeText != null && badgeText.isNotEmpty)
          Positioned(
            left: 14,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
              decoration: BoxDecoration(
                color: wonderlaNavy.withValues(alpha: .88),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                badgeText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }
  Widget _tags(dynamic raw) {
    final tags = raw is List
        ? raw.map((e) => e.toString()).toList()
        : <String>[];
    if (tags.isEmpty) return const SizedBox(height: 4);
    return Wrap(
      spacing: 6,
      runSpacing: 5,
      children: [
        for (final tag in tags)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _navy,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              tag,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }

  Widget _empty(String title) => Padding(
    padding: const EdgeInsets.all(26),
    child: Column(
      children: [
        const Icon(Icons.inbox_outlined, color: _navy, size: 34),
        const SizedBox(height: 8),
        Text(
          '$title will be available soon.',
          style: const TextStyle(color: wonderlaNavy),
        ),
      ],
    ),
  );
  Widget _notice(String message, {bool error = false}) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: error ? wonderlaWhite : wonderlaWhite,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      message,
      style: TextStyle(color: error ? wonderlaNavy : wonderlaNavy),
    ),
  );
}

class _BookingCallout extends StatelessWidget {
  const _BookingCallout();
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: wonderlaWhite,
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: wonderlaNavy),
    ),
    child: const Row(
      children: [
        Icon(Icons.confirmation_number_outlined, color: _navy),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'Book a ride slot at park kiosks',
            style: TextStyle(color: _navy, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ),
  );
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(26),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, color: _navy, size: 42),
          const SizedBox(height: 12),
          const Text(
            'Park guide could not load',
            style: TextStyle(
              color: _navy,
              fontWeight: FontWeight.w900,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: wonderlaNavy),
          ),
          const SizedBox(height: 15),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        ],
      ),
    ),
  );
}
