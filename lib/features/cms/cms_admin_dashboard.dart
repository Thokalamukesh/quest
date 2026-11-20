part of 'cms_screen.dart';

class _CmsNavGroup {
  const _CmsNavGroup(this.label, this.items);
  final String label;
  final List<(String, IconData)> items;
}

class _AdminDashboard extends StatefulWidget {
  const _AdminDashboard({
    required this.api,
    required this.user,
    required this.onLogout,
  });

  final CmsApi api;
  final Map<String, dynamic> user;
  final VoidCallback onLogout;

  @override
  State<_AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<_AdminDashboard> {
  static const _superOnlySections = {
    'Parks',
    'Users',
    'Google Maps settings',
    'Site URL & QR codes',
  };

  static const _navGroups = [
    _CmsNavGroup('OVERVIEW & HOME', [
      ('Park overview', LucideIcons.chartNoAxesCombined),
      ('Home cards', LucideIcons.layoutGrid),
      ('Parks', LucideIcons.building2),
    ]),
    _CmsNavGroup('PARK CONTENT', [
      ('Rides', LucideIcons.ferrisWheel),
      ('Events', LucideIcons.calendarDays),
      ('Dining & menus', LucideIcons.utensils),
      ('Live wait times', LucideIcons.timer),
      ('Wave pool & rain dance', LucideIcons.waves),
      ('Safety & hygiene', LucideIcons.shieldCheck),
      ('Maintenance log', LucideIcons.wrench),
      ('Ride guidelines', LucideIcons.ruler),
    ]),
    _CmsNavGroup('MAP & PLACES', [
      ('Park map & places', LucideIcons.mapPinned),
      ('Google Maps settings', LucideIcons.map),
    ]),
    _CmsNavGroup('ADMIN & QR', [
      ('Users', LucideIcons.users),
      ('Site URL & QR codes', LucideIcons.qrCode),
    ]),
  ];

  final _sections = const [
    ('Park overview', LucideIcons.chartNoAxesCombined),
    ('Home cards', LucideIcons.layoutGrid),
    ('Parks', LucideIcons.building2),
    ('Rides', LucideIcons.ferrisWheel),
    ('Events', LucideIcons.calendarDays),
    ('Dining & menus', LucideIcons.utensils),
    ('Live wait times', LucideIcons.timer),
    ('Wave pool & rain dance', LucideIcons.waves),
    ('Safety & hygiene', LucideIcons.shieldCheck),
    ('Maintenance log', LucideIcons.wrench),
    ('Ride guidelines', LucideIcons.ruler),
    ('Park map & places', LucideIcons.mapPinned),
    ('Google Maps settings', LucideIcons.map),
    ('Users', LucideIcons.users),
    ('Site URL & QR codes', LucideIcons.qrCode),
  ];

  final _listKeys = const {
    'Rides': 'rides',
    'Events': 'events',
    'Dining & menus': 'dining',
    'Live wait times': 'liveWaitTimes',
    'Wave pool & rain dance': 'waveRainDance',
    'Safety & hygiene': 'safetyHygiene',
    'Maintenance log': 'maintenanceLog',
    'Ride guidelines': 'rideGuidelines',
  };

  final _schemas = const <String, List<(String, String)>>{
    'Rides': [
      ('title', 'Ride name'),
      ('description', 'Description'),
      ('img', 'Ride image'),
      ('tags', 'Tags (comma separated)'),
      ('kioskBookingEnabled', 'Enable kiosk booking'),
    ],
    'Events': [
      ('title', 'Event name'),
      ('time', 'Time'),
      ('description', 'Description'),
      ('img', 'Event image'),
      ('tags', 'Tags (comma separated)'),
    ],
    'Dining & menus': [
      ('name', 'Outlet name'),
      ('cuisine', 'Cuisine'),
      ('description', 'Description'),
      ('img', 'Outlet image'),
      ('directionsUrl', 'Directions URL'),
      ('tags', 'Tags (comma separated)'),
    ],
    'Live wait times': [
      ('title', 'Ride name'),
      ('time', 'Wait time in minutes'),
      ('description', 'Description'),
      ('img', 'Ride image'),
    ],
    'Wave pool & rain dance': [
      ('title', 'Attraction name'),
      ('timeSlot', 'Session times (comma separated)'),
      ('rideDuration', 'Duration in minutes'),
      ('img', 'Image'),
    ],
    'Safety & hygiene': [
      ('title', 'Information title'),
      ('description', 'Description'),
      ('img', 'Image'),
    ],
    'Maintenance log': [
      ('ride', 'Ride'),
      ('lastService', 'Last service date (dd/mm/yyyy)'),
      ('checks', 'Checks performed'),
    ],
    'Ride guidelines': [
      ('title', 'Guideline title'),
      ('description', 'Description'),
      ('minHeight', 'Minimum height'),
    ],
  };

  final _collectionSearchController = TextEditingController();
  final _mapSearchController = TextEditingController();

  List<Map<String, dynamic>> _parks = [];
  Map<String, dynamic>? _config;
  Map<String, dynamic>? _mapSettings;
  String? _siteOrigin;
  List<Map<String, dynamic>> _users = [];
  String? _selectedSlug;
  String _section = 'Park overview';
  String _collectionSearch = '';
  String _mapSearch = '';
  bool _loading = true;
  bool _saving = false;
  bool _dirty = false;
  String? _error;
  String? _notice;

  bool get _super => widget.user['role'] == 'superadmin';
  List<String> get _permissions => List<String>.from(
    widget.user['permissions'] as List? ?? const <String>[],
  );

  bool _canAccess(String section) =>
      _super ||
      _permissions.contains('all') ||
      _permissions.contains(section) ||
      (section == 'Home cards' && _permissions.contains('Home card labels'));

  bool _isSectionVisible(String name) =>
      _super || (_canAccess(name) && !_superOnlySections.contains(name));

  bool get _canSave =>
      _config != null &&
      _canAccess(_section) &&
      _section != 'Users' &&
      _section != 'Google Maps settings' &&
      _section != 'Site URL & QR codes';

  @override
  void initState() {
    super.initState();
    if (!_super && !_canAccess(_section)) {
      _section = _sections
          .map((section) => section.$1)
          .firstWhere(_canAccess, orElse: () => 'Park overview');
    }
    _loadAll();
  }

  @override
  void dispose() {
    _collectionSearchController.dispose();
    _mapSearchController.dispose();
    super.dispose();
  }

  void _markDirty() {
    if (!_dirty) {
      _dirty = true;
      _notice = null;
    }
  }

  int? _sectionBadgeCount(String title) {
    if (title == 'Parks') return _parks.length;
    if (_config == null) return null;
    if (_listKeys.containsKey(title)) {
      return (_config![_listKeys[title]!] as List?)?.length ?? 0;
    }
    if (title == 'Park map & places') {
      final map = _config!['parkMap'] as Map?;
      return (map?['places'] as List?)?.length ?? 0;
    }
    return null;
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _parks = await widget.api.parks();
      if (_super) {
        final slug =
            _selectedSlug ??
            (_parks.isNotEmpty ? _parks.first['slug'] as String : null);
        if (slug != null) await _loadPark(slug);
      } else {
        final slug = widget.user['parkSlug'] as String?;
        if (slug != null) await _loadPark(slug);
      }
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadPark(String slug) async {
    final config = await widget.api.park(slug);
    if (mounted) {
      setState(() {
        _config = config;
        _selectedSlug = slug;
        _dirty = false;
        _collectionSearch = '';
        _mapSearch = '';
        _collectionSearchController.clear();
        _mapSearchController.clear();
      });
    }
  }

  Future<bool> _confirmDiscardOrSaveBeforeParkSwitch() async {
    if (!_dirty) return true;
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unsaved park changes'),
        content: Text(
          'You have unsaved edits for ${_config?['name'] ?? 'this park'}. Save them before switching parks?',
          style: const TextStyle(color: wonderlaMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'discard'),
            style: TextButton.styleFrom(foregroundColor: wonderlaFlagRed),
            child: const Text('Discard'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'save'),
            child: const Text('Save & switch'),
          ),
        ],
      ),
    );
    if (choice == 'save') {
      await _savePark();
      return _error == null;
    }
    return choice == 'discard';
  }

  Future<void> _switchPark(String slug, {String? targetSection}) async {
    if (slug == _selectedSlug) {
      if (targetSection != null) await _changeSection(targetSection);
      return;
    }
    final proceed = await _confirmDiscardOrSaveBeforeParkSwitch();
    if (!proceed || !mounted) return;
    setState(() {
      _loading = true;
      _error = null;
      _notice = null;
    });
    try {
      await _loadPark(slug);
      if (targetSection != null && mounted) {
        await _changeSection(targetSection);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadUsers() async {
    try {
      _users = await widget.api.users();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _savePark() async {
    if (_config == null || !_canAccess(_section)) return;
    setState(() {
      _saving = true;
      _error = null;
      _notice = null;
    });
    try {
      _config = await widget.api.savePark(_selectedSlug!, _config!);
      _parks = await widget.api.parks();
      _dirty = false;
      _notice = 'Park content saved successfully.';
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: wonderlaNavy,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              content: const Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    color: wonderlaGold,
                    size: 18,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Park changes saved and live.',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          );
      }
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _changeSection(String value) async {
    if (!_canAccess(value)) return;
    setState(() {
      _section = value;
      _error = null;
      _notice = null;
      _collectionSearch = '';
      _mapSearch = '';
      _collectionSearchController.clear();
      _mapSearchController.clear();
    });
    if (value == 'Google Maps settings') await _loadMapSettings();
    if (value == 'Users') await _loadUsers();
    if (value == 'Site URL & QR codes') await _loadSiteOrigin();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 980;
    final compact = width < 720;
    final narrow = width < 390;
    final canPop = Navigator.canPop(context);

    return Scaffold(
      backgroundColor: wonderlaCream,
      appBar: AppBar(
        backgroundColor: wonderlaWhite,
        surfaceTintColor: wonderlaWhite,
        toolbarHeight: 66,
        shape: const Border(bottom: BorderSide(color: wonderlaBorder)),
        title: Row(
          children: [
            Image.asset(
              'assets/images/wonderla_logo.webp',
              width: narrow ? 92 : 114,
              height: 40,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Text(
                'WONDERLA',
                style: TextStyle(
                  color: _ink,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ),
            if (!narrow) ...[
              const SizedBox(width: 10),
              const _CmsPillBadge(
                label: 'CMS',
                foreground: wonderlaNavy,
                background: wonderlaGold,
              ),
            ],
            if (wide && _config != null) ...[
              const SizedBox(width: 14),
              Container(width: 1, height: 22, color: wonderlaBorder),
              const SizedBox(width: 14),
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _config!['active'] == true
                            ? wonderlaSuccess
                            : wonderlaMuted,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _config!['name']?.toString() ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (_config != null && !compact)
            IconButton(
              tooltip: 'Show park QR code',
              onPressed: () => _showParkQr({
                'slug': _selectedSlug ?? '',
                'name': _config?['name'] ?? 'Park',
              }),
              icon: const Icon(Icons.qr_code_2_rounded, color: _brandNavy),
            ),
          if (_canSave && !compact) ...[
            if (_dirty)
              const Padding(
                padding: EdgeInsets.only(right: 10),
                child: _CmsPillBadge(
                  label: 'Unsaved changes',
                  foreground: wonderlaWarning,
                  background: Color(0xFFFFF8E6),
                  icon: Icons.circle,
                ),
              )
            else
              const Padding(
                padding: EdgeInsets.only(right: 10),
                child: _CmsPillBadge(
                  label: 'Saved',
                  foreground: wonderlaSuccess,
                  background: Color(0xFFECF9F2),
                  icon: Icons.check_rounded,
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: FilledButton.icon(
                onPressed: _saving ? null : _savePark,
                style: FilledButton.styleFrom(
                  backgroundColor: _dirty ? _brandNavy : wonderlaNavy,
                  minimumSize: const Size(0, 42),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_outlined, size: 18),
                label: Text(_saving ? 'Saving…' : 'Save changes'),
              ),
            ),
          ],
          if (_canSave && compact)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
              child: FilledButton.icon(
                onPressed: _saving ? null : _savePark,
                style: FilledButton.styleFrom(
                  backgroundColor: _dirty ? _brandNavy : wonderlaNavy,
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                icon: _saving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_outlined, size: 17),
                label: Text(_saving ? 'Saving' : 'Save'),
              ),
            ),
          const SizedBox(width: 4),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'guide') {
                Navigator.maybePop(context);
              } else if (value == 'qr' && _config != null) {
                _showParkQr({
                  'slug': _selectedSlug ?? '',
                  'name': _config?['name'] ?? 'Park',
                });
              } else if (value == 'logout') {
                widget.onLogout();
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.user['username']}',
                      style: const TextStyle(
                        color: _ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      _super ? 'Superadmin' : 'Park editor',
                      style: const TextStyle(
                        color: wonderlaMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              if (_config != null && compact)
                const PopupMenuItem(
                  value: 'qr',
                  child: Row(
                    children: [
                      Icon(Icons.qr_code_2_rounded, size: 18),
                      SizedBox(width: 10),
                      Text('Park QR code'),
                    ],
                  ),
                ),
              if (canPop)
                const PopupMenuItem(
                  value: 'guide',
                  child: Row(
                    children: [
                      Icon(Icons.map_outlined, size: 18),
                      SizedBox(width: 10),
                      Text('Back to visitor guide'),
                    ],
                  ),
                ),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(
                      Icons.logout_rounded,
                      size: 18,
                      color: wonderlaFlagRed,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Sign out',
                      style: TextStyle(color: wonderlaFlagRed),
                    ),
                  ],
                ),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.only(right: 12, left: 4),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFFEEF4FF),
                child: Text(
                  _userInitials,
                  style: const TextStyle(
                    color: _brandNavy,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      drawer: wide ? null : Drawer(width: 290, child: _nav()),
      body: Row(
        children: [
          if (wide)
            Container(
              width: 274,
              decoration: const BoxDecoration(
                color: wonderlaWhite,
                border: Border(right: BorderSide(color: wonderlaBorder)),
              ),
              child: _nav(),
            ),
          Expanded(
            child: Column(
              children: [
                if (!wide) _mobileSectionPicker(),
                if (_dirty && _canSave && compact) _unsavedMobileBanner(),
                Expanded(child: _body()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String get _userInitials {
    final name = widget.user['username']?.toString().trim() ?? 'A';
    return name.isEmpty ? 'A' : name.substring(0, 1).toUpperCase();
  }

  Widget _unsavedMobileBanner() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    decoration: const BoxDecoration(
      color: Color(0xFFFFF8E6),
      border: Border(bottom: BorderSide(color: Color(0xFFF6D98B))),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.edit_notifications_outlined,
          size: 18,
          color: wonderlaWarning,
        ),
        const SizedBox(width: 8),
        const Expanded(
          child: Text(
            'You have unsaved park edits',
            style: TextStyle(
              color: wonderlaWarning,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
        TextButton(
          onPressed: _saving ? null : _savePark,
          style: TextButton.styleFrom(
            foregroundColor: _brandNavy,
            visualDensity: VisualDensity.compact,
          ),
          child: Text(
            _saving ? 'Saving…' : 'Save now',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ),
  );

  Widget _nav() {
    final canPop = Navigator.canPop(context);
    return Container(
      color: wonderlaWhite,
      child: SafeArea(
        bottom: true,
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [wonderlaNavy, wonderlaCobalt],
                          ),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Icon(
                          Icons.dashboard_customize_outlined,
                          color: wonderlaGold,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'WONDERLA CMS',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: wonderlaMuted,
                                letterSpacing: 1.1,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              _super ? 'Superadmin portal' : 'Park editor',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: _ink,
                                fontSize: 14.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (_super)
                    _parkDropDown()
                  else if (_config != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: wonderlaCream,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: wonderlaBorder),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.park_outlined,
                            color: _brandNavy,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _config!['name']?.toString() ?? 'Park',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: _ink,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                ),
                                if ((_config!['location']?.toString() ?? '')
                                    .isNotEmpty)
                                  Text(
                                    _config!['location'].toString(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: wonderlaMuted,
                                      fontSize: 11.5,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 14),
                children: [
                  for (final group in _navGroups) ...[
                    if (group.items.any((item) => _isSectionVisible(item.$1)))
                      ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                          child: Text(
                            group.label,
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: wonderlaMuted,
                              letterSpacing: 1.0,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        for (final (name, icon) in group.items)
                          if (_isSectionVisible(name)) _navItem(name, icon),
                      ],
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (canPop)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.maybePop(context),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 38),
                          foregroundColor: _ink,
                        ),
                        icon: const Icon(Icons.arrow_back_rounded, size: 16),
                        label: const Text(
                          'Visitor guide',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 17,
                        backgroundColor: const Color(0xFFEEF4FF),
                        child: Text(
                          _userInitials,
                          style: const TextStyle(
                            color: _brandNavy,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${widget.user['username']}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _ink,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              _super ? 'Superadmin' : 'Park editor',
                              style: const TextStyle(
                                color: wonderlaMuted,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Sign out',
                        onPressed: widget.onLogout,
                        icon: const Icon(
                          Icons.logout_rounded,
                          size: 19,
                          color: wonderlaMuted,
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
    );
  }

  Widget _parkDropDown() => DropdownButtonFormField<String>(
    key: ValueKey('park-switcher-${_selectedSlug ?? 'none'}-${_parks.length}'),
    initialValue: _parks.any((p) => p['slug'] == _selectedSlug)
        ? _selectedSlug
        : null,
    isExpanded: true,
    decoration: InputDecoration(
      labelText: 'Active park',
      filled: true,
      fillColor: wonderlaCream,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: wonderlaBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: wonderlaBorder),
      ),
    ),
    items: [
      for (final p in _parks)
        DropdownMenuItem(
          value: p['slug'] as String,
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: p['active'] == true ? wonderlaSuccess : wonderlaMuted,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  p['name'] as String,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ],
          ),
        ),
    ],
    onChanged: (slug) {
      if (slug != null) _switchPark(slug);
    },
  );

  Widget _navItem(String title, IconData icon) {
    final selected = _section == title;
    final count = _sectionBadgeCount(title);
    return Builder(
      builder: (tileContext) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Material(
          color: selected ? _brandNavy : Colors.transparent,
          borderRadius: BorderRadius.circular(13),
          child: InkWell(
            borderRadius: BorderRadius.circular(13),
            hoverColor: selected
                ? _brandNavy
                : wonderlaCobalt.withValues(alpha: 0.06),
            onTap: () {
              _changeSection(title);
              final scaffold = Scaffold.maybeOf(tileContext);
              if (scaffold?.isDrawerOpen ?? false) scaffold?.closeDrawer();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: selected ? wonderlaGold : wonderlaMuted,
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w600,
                        color: selected ? wonderlaWhite : _ink,
                      ),
                    ),
                  ),
                  if (count != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? wonderlaWhite.withValues(alpha: 0.18)
                            : wonderlaCream,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: selected ? wonderlaWhite : wonderlaMuted,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _mobileSectionPicker() => Container(
    height: 58,
    decoration: const BoxDecoration(
      color: wonderlaWhite,
      border: Border(bottom: BorderSide(color: wonderlaBorder)),
    ),
    child: ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(
        dragDevices: {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.trackpad,
        },
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        children: [
          for (final (title, icon) in _sections)
            if (_isSectionVisible(title))
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  avatar: Icon(
                    icon,
                    size: 16,
                    color: _section == title ? wonderlaGold : _brandNavy,
                  ),
                  label: Text(
                    _sectionBadgeCount(title) != null
                        ? '$title · ${_sectionBadgeCount(title)}'
                        : title,
                    style: TextStyle(
                      color: _section == title ? wonderlaWhite : _ink,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                  selected: _section == title,
                  selectedColor: _brandNavy,
                  backgroundColor: wonderlaCream,
                  side: BorderSide(
                    color: _section == title ? _brandNavy : wonderlaBorder,
                  ),
                  showCheckmark: false,
                  onSelected: (_) => _changeSection(title),
                ),
              ),
        ],
      ),
    ),
  );

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _brandNavy));
    }
    if (_error != null && _config == null && _section != 'Parks') {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: _CmsAlertBanner(
              message: _error!,
              tone: _CmsBannerTone.error,
              actionLabel: 'Retry',
              onAction: _loadAll,
            ),
          ),
        ),
      );
    }

    final isPhone = MediaQuery.sizeOf(context).width < 600;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1120),
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            isPhone ? 16 : 28,
            isPhone ? 16 : 24,
            isPhone ? 16 : 28,
            40,
          ),
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  'PARK CMS',
                  style: TextStyle(
                    color: _brandNavy,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.9,
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: wonderlaMuted,
                ),
                Text(
                  _config?['name']?.toString() ?? 'No park selected',
                  style: const TextStyle(color: wonderlaMuted, fontSize: 12.5),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: wonderlaMuted,
                ),
                Text(
                  _section,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _section,
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _sectionSubtitle,
                        style: const TextStyle(
                          color: wonderlaMuted,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_section == 'Parks' && _super) ...[
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _addPark,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('New park'),
                  ),
                ],
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              _CmsAlertBanner(
                message: _error!,
                tone: _CmsBannerTone.error,
                actionLabel: 'Retry',
                onAction: _loadAll,
                onDismiss: () => setState(() => _error = null),
              ),
            ],
            if (_notice != null) ...[
              const SizedBox(height: 14),
              _CmsAlertBanner(
                message: _notice!,
                tone: _CmsBannerTone.success,
                onDismiss: () => setState(() => _notice = null),
              ),
            ],
            const SizedBox(height: 20),
            if (_section == 'Park overview' && _canAccess('Park overview'))
              ScrollReveal(child: _overview()),
            if (_section == 'Home cards' && _canAccess(_section))
              ScrollReveal(child: _homeCardLabelsPage()),
            if (_section == 'Parks') ScrollReveal(child: _parksPage()),
            if (_listKeys.containsKey(_section) && _canAccess(_section))
              ScrollReveal(child: _collectionPage()),
            if (_section == 'Park map & places' && _canAccess(_section))
              ScrollReveal(child: _mapPage()),
            if (_section == 'Google Maps settings')
              ScrollReveal(child: _googleMapSettings()),
            if (_section == 'Users') ScrollReveal(child: _usersPage()),
            if (_section == 'Site URL & QR codes' &&
                (_super || _permissions.isEmpty))
              ScrollReveal(child: _siteUrlPage()),
            if (!_canAccess(_section))
              const _EmptyCard(
                'No access assigned',
                'Ask an administrator to assign at least one section to your account.',
                icon: Icons.lock_outline_rounded,
              ),
          ],
        ),
      ),
    );
  }

  String get _sectionSubtitle => switch (_section) {
    'Park overview' =>
      'Monitor park health, update brand identity, media, and publishing status.',
    'Home cards' => 'Add, rename, show, hide, or reorder visitor home cards.',
    'Parks' =>
      'Create parks and control which destinations appear in the visitor directory.',
    'Park map & places' =>
      'Manage map artwork, zones, and GPS pins for live walking directions.',
    'Google Maps settings' =>
      'Manage the Google Maps browser key used by the website map.',
    'Users' => 'Create park editors or full-access superadmins.',
    'Site URL & QR codes' =>
      'Preview, copy, and download high-resolution QR codes for park signage.',
    _ => 'Search, add, and update what visitors see in this section.',
  };

  Widget _overview() {
    if (_config == null) {
      return _EmptyCard(
        'No park selected',
        'Create a park to start managing visitor attractions, dining, and maps.',
        icon: Icons.park_outlined,
        actionLabel: _super ? 'Create first park' : null,
        onAction: _super ? _addPark : null,
      );
    }
    final cfg = _config!;
    final exploreFields = const <(String, String)>[
      ('exploreParkMapImageUrl', 'Park map'),
      ('exploreRidesImageUrl', 'Rides & events'),
      ('exploreEventsImageUrl', 'Events'),
      ('exploreDiningImageUrl', 'Dining & menu'),
      ('exploreWaitTimesImageUrl', 'Live wait times'),
      ('exploreGuidelinesImageUrl', 'Ride guidelines'),
      ('exploreWaveImageUrl', 'Wave pool & rain dance'),
      ('exploreSafetyImageUrl', 'Safety & hygiene'),
      ('exploreMaintenanceImageUrl', 'Maintenance log'),
    ];
    final exploreConfiguredCount = exploreFields
        .where((f) => (cfg[f.$1]?.toString().trim() ?? '').isNotEmpty)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _parkHeroBanner(cfg),
        const SizedBox(height: 18),
        _overviewKpiGrid(cfg),
        const SizedBox(height: 18),
        Card(
          color: wonderlaWhite,
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF4FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.edit_note_rounded,
                        color: _brandNavy,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Park identity & publishing',
                            style: TextStyle(
                              color: _ink,
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                            ),
                          ),
                          Text(
                            'Shown on the visitor welcome screen and park selector.',
                            style: TextStyle(
                              color: wonderlaMuted,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _statusBadge(cfg['active'] == true),
                  ],
                ),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final nameField = _textField(
                      'Park display name',
                      cfg['name']?.toString() ?? '',
                      (v) => setState(() {
                        cfg['name'] = v;
                        _markDirty();
                      }),
                      fieldKey: 'park_name',
                    );
                    final locationField = _textField(
                      'Location',
                      cfg['location']?.toString() ?? '',
                      (v) => setState(() {
                        cfg['location'] = v;
                        _markDirty();
                      }),
                      fieldKey: 'park_location',
                    );
                    if (constraints.maxWidth >= 620) {
                      return Row(
                        children: [
                          Expanded(child: nameField),
                          const SizedBox(width: 14),
                          Expanded(child: locationField),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        nameField,
                        const SizedBox(height: 14),
                        locationField,
                      ],
                    );
                  },
                ),
                if (_super) ...[
                  const SizedBox(height: 16),
                  Material(
                    color: wonderlaCream,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: const BorderSide(color: wonderlaBorder),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: SwitchListTile(
                      title: const Text(
                        'Published in visitor park directory',
                        style: TextStyle(
                          color: _ink,
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                        ),
                      ),
                      subtitle: const Text(
                        'Hidden parks remain editable in CMS but will not appear to visitors.',
                        style: TextStyle(fontSize: 12.5),
                      ),
                      value: cfg['active'] == true,
                      onChanged: (v) => setState(() {
                        cfg['active'] = v;
                        _markDirty();
                      }),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          color: wonderlaWhite,
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF4FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.perm_media_outlined,
                        color: _brandNavy,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Brand & welcome banner media',
                            style: TextStyle(
                              color: _ink,
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                            ),
                          ),
                          Text(
                            'Logo and hero visuals shown at the top of the visitor home screen.',
                            style: TextStyle(
                              color: wonderlaMuted,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final logoPicker = _ImagePickerField(
                      api: widget.api,
                      parkSlug: _selectedSlug!,
                      label: 'Park logo',
                      value: cfg['logoUrl']?.toString() ?? '',
                      onChanged: (v) => setState(() {
                        cfg['logoUrl'] = v;
                        _markDirty();
                      }),
                    );
                    final heroPicker = _ImagePickerField(
                      api: widget.api,
                      parkSlug: _selectedSlug!,
                      label: 'Welcome banner image',
                      value: cfg['heroImageUrl']?.toString() ?? '',
                      onChanged: (v) => setState(() {
                        cfg['heroImageUrl'] = v;
                        _markDirty();
                      }),
                    );
                    if (constraints.maxWidth >= 740) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: logoPicker),
                          const SizedBox(width: 16),
                          Expanded(child: heroPicker),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        logoPicker,
                        const SizedBox(height: 14),
                        heroPicker,
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                _VideoPickerField(
                  api: widget.api,
                  parkSlug: _selectedSlug!,
                  label: 'Welcome banner video (optional — replaces banner image)',
                  value: cfg['heroVideoUrl']?.toString() ?? '',
                  onChanged: (v) => setState(() {
                    cfg['heroVideoUrl'] = v;
                    _markDirty();
                  }),
                  onUploaded: (_) => _savePark(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          color: wonderlaWhite,
          clipBehavior: Clip.antiAlias,
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(
                horizontal: 22,
                vertical: 8,
              ),
              childrenPadding: const EdgeInsets.fromLTRB(22, 4, 22, 22),
              leading: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF4FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.photo_library_outlined,
                  color: _brandNavy,
                  size: 20,
                ),
              ),
              title: const Text(
                'Explore the Park card images',
                style: TextStyle(
                  color: _ink,
                  fontWeight: FontWeight.w800,
                  fontSize: 16.5,
                ),
              ),
              subtitle: const Text(
                'Customize cover photos for each visitor home shortcut card.',
                style: TextStyle(color: wonderlaMuted, fontSize: 12.5),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _CmsPillBadge(
                    label: '$exploreConfiguredCount / ${exploreFields.length} set',
                    foreground: exploreConfiguredCount == exploreFields.length
                        ? wonderlaSuccess
                        : _brandNavy,
                    background: exploreConfiguredCount == exploreFields.length
                        ? const Color(0xFFECF9F2)
                        : const Color(0xFFEEF4FF),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.expand_more_rounded, color: wonderlaMuted),
                ],
              ),
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 14),
                  child: _CmsAlertBanner(
                    tone: _CmsBannerTone.info,
                    message:
                        'Uploaded explore card photos auto-save for this park immediately.',
                  ),
                ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final twoCols = constraints.maxWidth >= 720;
                    if (!twoCols) {
                      return Column(
                        children: [
                          for (final (key, label) in exploreFields)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: _ImagePickerField(
                                api: widget.api,
                                parkSlug: _selectedSlug!,
                                label: label,
                                value: cfg[key]?.toString() ?? '',
                                onChanged: (v) => setState(() {
                                  cfg[key] = v;
                                  _markDirty();
                                }),
                                onUploaded: (_) => _savePark(),
                              ),
                            ),
                        ],
                      );
                    }
                    final rows = <Widget>[];
                    for (var i = 0; i < exploreFields.length; i += 2) {
                      final left = exploreFields[i];
                      final right = i + 1 < exploreFields.length
                          ? exploreFields[i + 1]
                          : null;
                      rows.add(
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _ImagePickerField(
                                  api: widget.api,
                                  parkSlug: _selectedSlug!,
                                  label: left.$2,
                                  value: cfg[left.$1]?.toString() ?? '',
                                  onChanged: (v) => setState(() {
                                    cfg[left.$1] = v;
                                    _markDirty();
                                  }),
                                  onUploaded: (_) => _savePark(),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: right == null
                                    ? const SizedBox.shrink()
                                    : _ImagePickerField(
                                        api: widget.api,
                                        parkSlug: _selectedSlug!,
                                        label: right.$2,
                                        value: cfg[right.$1]?.toString() ?? '',
                                        onChanged: (v) => setState(() {
                                          cfg[right.$1] = v;
                                          _markDirty();
                                        }),
                                        onUploaded: (_) => _savePark(),
                                      ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return Column(children: rows);
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _parkHeroBanner(Map<String, dynamic> cfg) {
    final active = cfg['active'] == true;
    final logoUrl = cfg['logoUrl']?.toString().trim() ?? '';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [wonderlaNavy, wonderlaCobalt],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: wonderlaNavy.withValues(alpha: 0.14),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 520;
          final info = Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: wonderlaWhite,
                  borderRadius: BorderRadius.circular(16),
                ),
                clipBehavior: Clip.antiAlias,
                child: logoUrl.isEmpty
                    ? const Icon(
                        Icons.park_rounded,
                        color: _brandNavy,
                        size: 28,
                      )
                    : Image.network(
                        _absoluteImage(logoUrl),
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.park_rounded,
                          color: _brandNavy,
                          size: 28,
                        ),
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          cfg['name']?.toString().isNotEmpty == true
                              ? cfg['name'].toString()
                              : 'Untitled park',
                          style: const TextStyle(
                            color: wonderlaWhite,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        _CmsPillBadge(
                          label: active ? 'Published' : 'Hidden',
                          foreground: active ? wonderlaNavy : wonderlaWhite,
                          background: active
                              ? wonderlaGold
                              : wonderlaWhite.withValues(alpha: 0.2),
                          borderColor: Colors.transparent,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${cfg['location'] ?? 'Location not set'} · /qr-code/${_selectedSlug ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: wonderlaWhite.withValues(alpha: 0.84),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
          final qrButton = FilledButton.icon(
            onPressed: () => _showParkQr({
              'slug': _selectedSlug ?? '',
              'name': cfg['name'] ?? 'Park',
            }),
            style: FilledButton.styleFrom(
              backgroundColor: wonderlaGold,
              foregroundColor: wonderlaNavy,
              minimumSize: const Size(0, 42),
            ),
            icon: const Icon(Icons.qr_code_2_rounded, size: 18),
            label: const Text('Park QR'),
          );
          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [info, const SizedBox(height: 14), qrButton],
            );
          }
          return Row(
            children: [
              Expanded(child: info),
              const SizedBox(width: 14),
              qrButton,
            ],
          );
        },
      ),
    );
  }

  Widget _overviewKpiGrid(Map<String, dynamic> cfg) {
    final rides = (cfg['rides'] as List?) ?? const [];
    final kioskRides = rides
        .whereType<Map>()
        .where((r) => r['kioskBookingEnabled'] == true)
        .length;
    final dining = (cfg['dining'] as List?) ?? const [];
    final totalDishes = dining
        .whereType<Map>()
        .fold<int>(0, (sum, d) => sum + ((d['items'] as List?)?.length ?? 0));
    final waitTimes = (cfg['liveWaitTimes'] as List?) ?? const [];
    final events = (cfg['events'] as List?) ?? const [];
    final places = ((cfg['parkMap'] as Map?)?['places'] as List?) ?? const [];
    final gpsReady = places
        .whereType<Map>()
        .where((p) => _hasValidMapCoordinates(Map<String, dynamic>.from(p)))
        .length;
    final wave = (cfg['waveRainDance'] as List?) ?? const [];
    final safety = (cfg['safetyHygiene'] as List?) ?? const [];
    final guidelines = (cfg['rideGuidelines'] as List?) ?? const [];

    final cards = [
      if (_canAccess('Rides'))
        (
          'Rides',
          '${rides.length}',
          '$kioskRides with kiosk booking',
          LucideIcons.ferrisWheel,
          _brandNavy,
        ),
      if (_canAccess('Live wait times'))
        (
          'Live wait times',
          '${waitTimes.length}',
          'Live queue entries',
          LucideIcons.timer,
          wonderlaWarning,
        ),
      if (_canAccess('Dining & menus'))
        (
          'Dining & menus',
          '${dining.length}',
          '$totalDishes menu dishes',
          LucideIcons.utensils,
          const Color(0xFF0E7490),
        ),
      if (_canAccess('Events'))
        (
          'Events',
          '${events.length}',
          'Park shows & events',
          LucideIcons.calendarDays,
          const Color(0xFF7C3AED),
        ),
      if (_canAccess('Park map & places'))
        (
          'Park map & places',
          '$gpsReady/${places.length}',
          'Pins GPS walking ready',
          LucideIcons.mapPinned,
          wonderlaSuccess,
        ),
      if (_canAccess('Wave pool & rain dance'))
        (
          'Wave pool & rain dance',
          '${wave.length}',
          'Scheduled sessions',
          LucideIcons.waves,
          wonderlaBlue,
        ),
      if (_canAccess('Safety & hygiene'))
        (
          'Safety & hygiene',
          '${safety.length}',
          'Visitor advisories',
          LucideIcons.shieldCheck,
          wonderlaSuccess,
        ),
      if (_canAccess('Ride guidelines'))
        (
          'Ride guidelines',
          '${guidelines.length}',
          'Height & safety rules',
          LucideIcons.ruler,
          wonderlaNavy,
        ),
    ];

    if (cards.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth >= 900
            ? 4
            : constraints.maxWidth >= 560
            ? 3
            : 2;
        const spacing = 12.0;
        final tileWidth = (constraints.maxWidth - (spacing * (cols - 1))) / cols;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final (section, value, sub, icon, accent) in cards)
              SizedBox(
                width: tileWidth,
                child: Material(
                  color: wonderlaWhite,
                  borderRadius: BorderRadius.circular(18),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => _changeSection(section),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: wonderlaBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(icon, size: 17, color: accent),
                              ),
                              const Spacer(),
                              const Icon(
                                Icons.arrow_outward_rounded,
                                size: 15,
                                color: wonderlaMuted,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            value,
                            style: const TextStyle(
                              color: _ink,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              height: 1.05,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            section,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _ink,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            sub,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: wonderlaMuted,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _homeCardLabelsPage() {
    if (_config == null) {
      return const _EmptyCard(
        'No park selected',
        'Select a park to manage its visitor home cards.',
        icon: Icons.grid_view_outlined,
      );
    }
    final labels = Map<String, dynamic>.from(
      (_config!['homeCardLabels'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
    _config!['homeCardLabels'] = labels;
    final shortcuts = _homeShortcutSettings();
    _config!['homeShortcuts'] = shortcuts;
    final visibleCount = shortcuts.where((s) => s['visible'] != false).length;
    final presentKeys = shortcuts.map((item) => item['key']).toSet();
    final available = HomeShortcutCatalog.definitions
        .where((item) => !presentKeys.contains(item.keyName))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          color: wonderlaWhite,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Visitor home shortcuts',
                            style: TextStyle(
                              color: _ink,
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Drag handles to reorder cards, rename labels, or toggle visibility.',
                            style: TextStyle(
                              color: wonderlaMuted,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _CmsPillBadge(
                      label: '$visibleCount visible',
                      foreground: wonderlaSuccess,
                      background: const Color(0xFFECF9F2),
                    ),
                  ],
                ),
                if (available.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Add a shortcut card',
                    style: TextStyle(
                      color: _ink,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final item in available)
                        ActionChip(
                          avatar: const Icon(
                            Icons.add_rounded,
                            size: 16,
                            color: _brandNavy,
                          ),
                          label: Text(
                            item.label,
                            style: const TextStyle(
                              color: _ink,
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                            ),
                          ),
                          backgroundColor: wonderlaCream,
                          side: const BorderSide(color: wonderlaBorder),
                          onPressed: () => _addHomeShortcut(item.keyName),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        if (shortcuts.isEmpty)
          const _EmptyCard(
            'No home cards selected',
            'Add a shortcut card above to display sections on the visitor home screen.',
            icon: Icons.grid_view_outlined,
          )
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: shortcuts.length,
            onReorderItem: _reorderHomeShortcut,
            itemBuilder: (context, index) => Padding(
              key: ValueKey('home-shortcut-wrap-${shortcuts[index]['key']}'),
              padding: const EdgeInsets.only(bottom: 10),
              child: _homeShortcutRow(
                index: index,
                setting: shortcuts[index],
                labels: labels,
              ),
            ),
          ),
      ],
    );
  }

  List<Map<String, dynamic>> _homeShortcutSettings() {
    final saved = _config!['homeShortcuts'];
    if (saved is List) {
      final seen = <String>{};
      return saved
          .whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(entry))
          .where((entry) {
            final key = entry['key']?.toString() ?? '';
            return HomeShortcutCatalog.byKey(key) != null && seen.add(key);
          })
          .map(
            (entry) => {
              'key': entry['key'],
              'visible': entry['visible'] != false,
            },
          )
          .toList();
    }

    final oldVisibility = _config!['homeCardVisibility'] as Map?;
    final keys = [...HomeShortcutCatalog.defaultKeys];
    for (final key in const ['liveWaitTimes', 'wavePool']) {
      if (oldVisibility?[key] == true) keys.add(key);
    }
    return keys.map((key) {
      final legacyKey = key == 'rides' || key == 'events' ? 'ridesEvents' : key;
      final visible = oldVisibility?[key] ?? oldVisibility?[legacyKey];
      return {'key': key, 'visible': visible is bool ? visible : true};
    }).toList();
  }

  void _addHomeShortcut(String key) {
    final settings = List<Map<String, dynamic>>.from(
      (_config!['homeShortcuts'] as List).map(
        (entry) => Map<String, dynamic>.from(entry as Map),
      ),
    );
    if (settings.any((entry) => entry['key'] == key)) return;
    setState(() {
      settings.add({'key': key, 'visible': true});
      _config!['homeShortcuts'] = settings;
      _markDirty();
    });
  }

  void _reorderHomeShortcut(int oldIndex, int newIndex) {
    final settings = List<Map<String, dynamic>>.from(
      (_config!['homeShortcuts'] as List).map(
        (entry) => Map<String, dynamic>.from(entry as Map),
      ),
    );
    setState(() {
      final moved = settings.removeAt(oldIndex);
      settings.insert(newIndex, moved);
      _config!['homeShortcuts'] = settings;
      _markDirty();
    });
  }

  void _removeHomeShortcut(String key) {
    final settings = List<Map<String, dynamic>>.from(
      (_config!['homeShortcuts'] as List).map(
        (entry) => Map<String, dynamic>.from(entry as Map),
      ),
    );
    setState(() {
      settings.removeWhere((entry) => entry['key'] == key);
      _config!['homeShortcuts'] = settings;
      _markDirty();
    });
  }

  Widget _homeShortcutRow({
    required int index,
    required Map<String, dynamic> setting,
    required Map<String, dynamic> labels,
  }) {
    final key = setting['key']?.toString() ?? '';
    final definition = HomeShortcutCatalog.byKey(key);
    if (definition == null) return const SizedBox.shrink();
    final visible = setting['visible'] != false;
    final editor = TextFormField(
      key: ValueKey('${_selectedSlug}_shortcut_$key'),
      initialValue: labels[key]?.toString() ?? '',
      maxLength: 24,
      textCapitalization: TextCapitalization.words,
      onChanged: (value) => setState(() {
        labels[key] = value;
        _markDirty();
      }),
      decoration: InputDecoration(
        labelText: 'Custom card name',
        hintText: definition.label,
        helperText: 'Leave blank to use "${definition.label}".',
        counterText: '',
        isDense: true,
      ),
    );
    final dragHandle = ReorderableDragStartListener(
      index: index,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: wonderlaCream,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(
          Icons.drag_indicator_rounded,
          color: wonderlaMuted,
          size: 20,
        ),
      ),
    );
    final removeButton = IconButton(
      tooltip: 'Remove shortcut',
      onPressed: () => _removeHomeShortcut(key),
      icon: const Icon(Icons.close_rounded, color: wonderlaMuted),
    );
    final visibilitySwitch = Switch.adaptive(
      value: visible,
      onChanged: (value) => setState(() {
        setting['visible'] = value;
        _markDirty();
      }),
    );

    return Card(
      key: ValueKey('home-shortcut-$key'),
      color: wonderlaWhite,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 580;
          final iconBadge = Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF4FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(definition.icon, color: _brandNavy, size: 18),
          );
          if (compact) {
            return Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      dragHandle,
                      const SizedBox(width: 10),
                      iconBadge,
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          definition.label,
                          style: const TextStyle(
                            color: _ink,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      removeButton,
                    ],
                  ),
                  const SizedBox(height: 12),
                  editor,
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Show on visitor home',
                          style: TextStyle(
                            color: _ink,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      visibilitySwitch,
                    ],
                  ),
                ],
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                dragHandle,
                const SizedBox(width: 10),
                iconBadge,
                const SizedBox(width: 12),
                Expanded(child: editor),
                const SizedBox(width: 14),
                _CmsPillBadge(
                  label: visible ? 'Visible' : 'Hidden',
                  foreground: visible ? wonderlaSuccess : wonderlaMuted,
                  background: visible
                      ? const Color(0xFFECF9F2)
                      : wonderlaCream,
                ),
                const SizedBox(width: 6),
                visibilitySwitch,
                removeButton,
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _parksPage() {
    if (_parks.isEmpty) {
      return _EmptyCard(
        'No parks yet',
        'Create your first Wonderla park to begin publishing rides, maps, and QR guides.',
        icon: Icons.park_outlined,
        actionLabel: _super ? 'Create a park' : null,
        onAction: _super ? _addPark : null,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final p in _parks)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _parkDirectoryCard(p),
          ),
      ],
    );
  }

  Widget _parkDirectoryCard(Map<String, dynamic> p) {
    final slug = p['slug']?.toString() ?? '';
    final isCurrent = slug == _selectedSlug;
    final active = p['active'] == true;
    return Card(
      color: wonderlaWhite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(wonderlaCardRadius),
        side: BorderSide(
          color: isCurrent ? _brandNavy : wonderlaBorder,
          width: isCurrent ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(wonderlaCardRadius),
        onTap: () => _switchPark(slug, targetSection: 'Park overview'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isCurrent
                      ? _brandNavy
                      : const Color(0xFFEEF4FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.park_outlined,
                  color: isCurrent ? wonderlaGold : _brandNavy,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          p['name']?.toString() ?? 'Untitled park',
                          style: const TextStyle(
                            color: _ink,
                            fontWeight: FontWeight.w800,
                            fontSize: 15.5,
                          ),
                        ),
                        _statusBadge(active),
                        if (isCurrent)
                          const _CmsPillBadge(
                            label: 'Selected',
                            foreground: _brandNavy,
                            background: Color(0xFFEEF4FF),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${p['location'] ?? 'Location not set'} · /qr-code/$slug',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: wonderlaMuted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Wrap(
                spacing: 4,
                children: [
                  IconButton(
                    tooltip: 'Show & download QR code',
                    onPressed: () => _showParkQr(p),
                    icon: const Icon(Icons.qr_code_2_rounded, color: _brandNavy),
                  ),
                  if (_super)
                    IconButton(
                      tooltip: 'Delete park',
                      onPressed: () => _deletePark(p),
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: wonderlaFlagRed,
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

  Widget _collectionPage() {
    if (_config == null) {
      return const _EmptyCard(
        'Choose a park',
        'Select a park to edit its content.',
      );
    }
    final key = _listKeys[_section]!;
    final items = List<Map<String, dynamic>>.from(
      (_config![key] as List? ?? []).map(
        (e) => Map<String, dynamic>.from(e as Map),
      ),
    );
    final query = _collectionSearch.trim().toLowerCase();
    final filtered = <(int, Map<String, dynamic>)>[
      for (var i = 0; i < items.length; i++)
        if (query.isEmpty || _matchesItemQuery(items[i], query)) (i, items[i]),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final searchField = TextField(
              controller: _collectionSearchController,
              onChanged: (v) => setState(() => _collectionSearch = v),
              decoration: InputDecoration(
                hintText: 'Search ${_section.toLowerCase()}…',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _collectionSearch.isNotEmpty
                    ? IconButton(
                        tooltip: 'Clear search',
                        onPressed: () => setState(() {
                          _collectionSearch = '';
                          _collectionSearchController.clear();
                        }),
                        icon: const Icon(Icons.close_rounded, size: 18),
                      )
                    : null,
                isDense: true,
              ),
            );
            final addBtn = FilledButton.icon(
              onPressed: () => _editItem(key, null),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text('Add ${_singularSectionLabel(_section)}'),
            );
            final countBadge = _CmsPillBadge(
              label: query.isEmpty
                  ? '${items.length} ${items.length == 1 ? 'item' : 'items'}'
                  : '${filtered.length} of ${items.length}',
              foreground: _brandNavy,
              background: const Color(0xFFEEF4FF),
            );
            if (constraints.maxWidth >= 620) {
              return Row(
                children: [
                  Expanded(child: searchField),
                  const SizedBox(width: 12),
                  countBadge,
                  const SizedBox(width: 12),
                  addBtn,
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                searchField,
                const SizedBox(height: 10),
                Row(
                  children: [
                    countBadge,
                    const Spacer(),
                    addBtn,
                  ],
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        if (items.isEmpty)
          _EmptyCard(
            'Nothing here yet',
            'Add the first item. Visitors will see these details right inside the Wonderla guide.',
            icon: _iconFor(_section),
            actionLabel: 'Add ${_singularSectionLabel(_section)}',
            onAction: () => _editItem(key, null),
          )
        else if (filtered.isEmpty)
          _EmptyCard(
            'No matching items',
            'No ${_section.toLowerCase()} matched "$_collectionSearch".',
            icon: Icons.search_off_rounded,
            actionLabel: 'Clear search',
            onAction: () => setState(() {
              _collectionSearch = '';
              _collectionSearchController.clear();
            }),
          )
        else
          for (final (originalIndex, item) in filtered)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _collectionItemCard(key, originalIndex, item),
            ),
        if (_section == 'Dining & menus' && items.isNotEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: _CmsAlertBanner(
              tone: _CmsBannerTone.info,
              message:
                  'Tip: click Edit on any dining outlet to manage individual dishes, prices, and veg/non-veg indicators.',
            ),
          ),
      ],
    );
  }

  bool _matchesItemQuery(Map<String, dynamic> item, String query) {
    final fields = [
      item['title'],
      item['name'],
      item['ride'],
      item['description'],
      item['cuisine'],
      item['checks'],
      item['minHeight'],
      if (item['tags'] is List) (item['tags'] as List).join(' '),
    ];
    return fields.any(
      (f) => f != null && f.toString().toLowerCase().contains(query),
    );
  }

  String _singularSectionLabel(String section) => switch (section) {
    'Rides' => 'ride',
    'Events' => 'event',
    'Dining & menus' => 'outlet',
    'Live wait times' => 'wait time',
    'Wave pool & rain dance' => 'session',
    'Safety & hygiene' => 'advisory',
    'Maintenance log' => 'log entry',
    'Ride guidelines' => 'guideline',
    _ => 'item',
  };

  Widget _collectionItemCard(
    String configKey,
    int index,
    Map<String, dynamic> item,
  ) {
    final badges = _itemMetadataBadges(item);
    final subtitle = _itemDescription(item);
    return Card(
      color: wonderlaWhite,
      child: InkWell(
        borderRadius: BorderRadius.circular(wonderlaCardRadius),
        onTap: () => _editItem(configKey, index),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _thumbnail(item['img']?.toString()),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _itemTitle(item),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _ink,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        if (subtitle.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: wonderlaMuted,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Edit',
                        onPressed: () => _editItem(configKey, index),
                        icon: const Icon(
                          Icons.edit_outlined,
                          size: 20,
                          color: _brandNavy,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Delete',
                        onPressed: () =>
                            _deleteCollectionItem(configKey, index),
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 20,
                          color: wonderlaFlagRed,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (badges.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(spacing: 6, runSpacing: 6, children: badges),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _itemDescription(Map<String, dynamic> item) =>
      (item['description'] ?? item['checks'] ?? '').toString().trim();

  List<Widget> _itemMetadataBadges(Map<String, dynamic> item) {
    final badges = <Widget>[];

    if (_section == 'Live wait times' && item['time'] != null) {
      final mins = num.tryParse('${item['time']}');
      final Color fg;
      final Color bg;
      if (mins == null || mins <= 15) {
        fg = wonderlaSuccess;
        bg = const Color(0xFFECF9F2);
      } else if (mins <= 35) {
        fg = wonderlaWarning;
        bg = const Color(0xFFFFF8E6);
      } else {
        fg = wonderlaFlagRed;
        bg = const Color(0xFFFDF0F2);
      }
      badges.add(
        _CmsPillBadge(
          label: mins != null ? '$mins min wait' : '${item['time']}',
          foreground: fg,
          background: bg,
          icon: Icons.timer_outlined,
        ),
      );
    }

    if (_section == 'Rides' && item['kioskBookingEnabled'] == true) {
      badges.add(
        const _CmsPillBadge(
          label: 'Kiosk booking',
          foreground: _brandNavy,
          background: Color(0xFFEEF4FF),
          icon: Icons.confirmation_number_outlined,
        ),
      );
    }

    if (_section == 'Events' &&
        (item['time']?.toString().trim().isNotEmpty ?? false)) {
      badges.add(
        _CmsPillBadge(
          label: item['time'].toString(),
          foreground: wonderlaNavy,
          background: wonderlaGold.withValues(alpha: 0.3),
          icon: Icons.schedule_rounded,
        ),
      );
    }

    if (_section == 'Dining & menus') {
      final cuisine = item['cuisine']?.toString().trim() ?? '';
      if (cuisine.isNotEmpty) {
        badges.add(
          _CmsPillBadge(
            label: cuisine,
            foreground: const Color(0xFF0E7490),
            background: const Color(0xFFECFEFF),
          ),
        );
      }
      final dishCount = (item['items'] as List?)?.length ?? 0;
      badges.add(
        _CmsPillBadge(
          label: '$dishCount ${dishCount == 1 ? 'dish' : 'dishes'}',
          foreground: _ink,
          background: wonderlaCream,
          icon: Icons.restaurant_menu_rounded,
        ),
      );
    }

    if (_section == 'Wave pool & rain dance') {
      final duration = item['rideDuration']?.toString().trim() ?? '';
      if (duration.isNotEmpty) {
        badges.add(
          _CmsPillBadge(
            label: '$duration min',
            foreground: _brandNavy,
            background: const Color(0xFFEEF4FF),
            icon: Icons.timelapse_rounded,
          ),
        );
      }
      if (item['timeSlot'] is List) {
        for (final slot in (item['timeSlot'] as List).take(3)) {
          badges.add(
            _CmsPillBadge(
              label: slot.toString(),
              foreground: _ink,
              background: wonderlaCream,
            ),
          );
        }
      }
    }

    if (_section == 'Maintenance log' &&
        (item['lastService']?.toString().trim().isNotEmpty ?? false)) {
      badges.add(
        _CmsPillBadge(
          label: 'Serviced ${item['lastService']}',
          foreground: _brandNavy,
          background: const Color(0xFFEEF4FF),
          icon: Icons.calendar_today_outlined,
        ),
      );
    }

    if (_section == 'Ride guidelines' &&
        (item['minHeight']?.toString().trim().isNotEmpty ?? false)) {
      badges.add(
        _CmsPillBadge(
          label: 'Min height: ${item['minHeight']}',
          foreground: wonderlaWarning,
          background: const Color(0xFFFFF8E6),
          icon: Icons.height_rounded,
        ),
      );
    }

    if (item['tags'] is List) {
      for (final tag in (item['tags'] as List).take(3)) {
        final text = tag.toString().trim();
        if (text.isNotEmpty) {
          badges.add(
            _CmsPillBadge(
              label: text,
              foreground: wonderlaMuted,
              background: wonderlaCream,
            ),
          );
        }
      }
    }
    return badges;
  }

  Widget _mapPage() {
    if (_config == null) {
      return const _EmptyCard(
        'Choose a park',
        'Select a park before managing its map.',
        icon: Icons.map_outlined,
      );
    }
    final map = Map<String, dynamic>.from(_config!['parkMap'] as Map);
    final places = List<Map<String, dynamic>>.from(
      (map['places'] as List? ?? []).map(
        (e) => Map<String, dynamic>.from(e as Map),
      ),
    );
    final zones = List<Map<String, dynamic>>.from(
      (map['zones'] as List? ?? []).map(
        (e) => Map<String, dynamic>.from(e as Map),
      ),
    );
    final gpsReadyCount = places.where(_hasValidMapCoordinates).length;
    final mapQuery = _mapSearch.trim().toLowerCase();
    final filteredPlaces = <(int, Map<String, dynamic>)>[
      for (var i = 0; i < places.length; i++)
        if (mapQuery.isEmpty ||
            (places[i]['name']?.toString().toLowerCase().contains(mapQuery) ??
                false) ||
            (places[i]['category']?.toString().toLowerCase().contains(
                  mapQuery,
                ) ??
                false))
          (i, places[i]),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _CmsPillBadge(
              label: '${places.length} map places',
              foreground: _brandNavy,
              background: const Color(0xFFEEF4FF),
              icon: Icons.place_outlined,
            ),
            _CmsPillBadge(
              label: '$gpsReadyCount / ${places.length} GPS walking ready',
              foreground:
                  places.isNotEmpty && gpsReadyCount == places.length
                  ? wonderlaSuccess
                  : wonderlaWarning,
              background:
                  places.isNotEmpty && gpsReadyCount == places.length
                  ? const Color(0xFFECF9F2)
                  : const Color(0xFFFFF8E6),
              icon: Icons.directions_walk_rounded,
            ),
            _CmsPillBadge(
              label: '${zones.length} zones',
              foreground: _ink,
              background: wonderlaWhite,
              icon: Icons.layers_outlined,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          color: wonderlaWhite,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Park map artwork & center',
                  style: TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Configure the park center coordinates and illustrated map overlay.',
                  style: TextStyle(color: wonderlaMuted, fontSize: 13),
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final latField = _textField(
                      'Park center latitude',
                      map['centerLat']?.toString() ?? '',
                      (v) => setState(() {
                        map['centerLat'] = double.tryParse(v) ?? v;
                        _config!['parkMap'] = map;
                        _markDirty();
                      }),
                      fieldKey: 'map_center_lat',
                    );
                    final lngField = _textField(
                      'Park center longitude',
                      map['centerLng']?.toString() ?? '',
                      (v) => setState(() {
                        map['centerLng'] = double.tryParse(v) ?? v;
                        _config!['parkMap'] = map;
                        _markDirty();
                      }),
                      fieldKey: 'map_center_lng',
                    );
                    if (constraints.maxWidth >= 520) {
                      return Row(
                        children: [
                          Expanded(child: latField),
                          const SizedBox(width: 12),
                          Expanded(child: lngField),
                        ],
                      );
                    }
                    return Column(
                      children: [latField, const SizedBox(height: 12), lngField],
                    );
                  },
                ),
                const SizedBox(height: 14),
                _ImagePickerField(
                  api: widget.api,
                  parkSlug: _selectedSlug!,
                  label: 'Map artwork image',
                  value: map['img']?.toString() ?? '',
                  onChanged: (v) => setState(() {
                    map['img'] = v;
                    _config!['parkMap'] = map;
                    _markDirty();
                  }),
                ),
                const SizedBox(height: 14),
                _textField(
                  'Map description',
                  map['description']?.toString() ?? '',
                  (v) => setState(() {
                    map['description'] = v;
                    _config!['parkMap'] = map;
                    _markDirty();
                  }),
                  maxLines: 3,
                  fieldKey: 'map_description',
                ),
              ],
            ),
          ),
        ),
        _subsectionHeader(
          'Map places',
          'Pin rides, dining, and facilities. Add GPS coordinates for turn-by-turn walking routes.',
          'Add place',
          () => _editMapPlace(map, null),
        ),
        if (places.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextField(
              controller: _mapSearchController,
              onChanged: (v) => setState(() => _mapSearch = v),
              decoration: InputDecoration(
                hintText: 'Filter map places by name or category…',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _mapSearch.isNotEmpty
                    ? IconButton(
                        tooltip: 'Clear filter',
                        onPressed: () => setState(() {
                          _mapSearch = '';
                          _mapSearchController.clear();
                        }),
                        icon: const Icon(Icons.close_rounded, size: 18),
                      )
                    : null,
                isDense: true,
              ),
            ),
          ),
        ],
        if (places.isEmpty)
          _EmptyCard(
            'No map places pinned yet',
            'Add rides, restaurants, restrooms, or entrances so visitors can explore them on the map.',
            icon: Icons.pin_drop_outlined,
            actionLabel: 'Add first map place',
            onAction: () => _editMapPlace(map, null),
          )
        else if (filteredPlaces.isEmpty)
          _EmptyCard(
            'No matching map places',
            'No pins matched "$_mapSearch".',
            icon: Icons.search_off_rounded,
            actionLabel: 'Clear filter',
            onAction: () => setState(() {
              _mapSearch = '';
              _mapSearchController.clear();
            }),
          )
        else
          for (final (i, place) in filteredPlaces)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _mapPlaceCard(map, places, i, place),
            ),
        _subsectionHeader(
          'Map zones',
          'Highlight themed areas and descriptions across the park.',
          'Add zone',
          () => _editMapZone(map, null),
        ),
        if (zones.isEmpty)
          const _EmptyCard(
            'No map zones yet',
            'Optional: group parts of the park into themed zones for visitors.',
            icon: Icons.layers_outlined,
          )
        else
          for (var i = 0; i < zones.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                color: wonderlaWhite,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF4FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.layers_outlined,
                      color: _brandNavy,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    zones[i]['name']?.toString() ?? 'Untitled zone',
                    style: const TextStyle(
                      color: _ink,
                      fontWeight: FontWeight.w800,
                      fontSize: 14.5,
                    ),
                  ),
                  subtitle: Text(
                    zones[i]['description']?.toString() ?? '',
                    style: const TextStyle(color: wonderlaMuted, fontSize: 13),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Edit zone',
                        onPressed: () => _editMapZone(map, i),
                        icon: const Icon(
                          Icons.edit_outlined,
                          size: 20,
                          color: _brandNavy,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Delete zone',
                        onPressed: () => _deleteMapEntry(
                          map: map,
                          items: zones,
                          index: i,
                          collectionKey: 'zones',
                          label: zones[i]['name']?.toString() ?? 'map zone',
                        ),
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 20,
                          color: wonderlaFlagRed,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: _saving
              ? null
              : () {
                  map['places'] = places;
                  map['zones'] = zones;
                  _config!['parkMap'] = map;
                  _savePark();
                },
          icon: const Icon(Icons.save_outlined, size: 18),
          label: Text(_saving ? 'Saving…' : 'Save map configuration'),
        ),
        const SizedBox(height: 12),
        const _CmsAlertBanner(
          tone: _CmsBannerTone.info,
          message:
              'Saving updates this park’s visitor interactive map and pins. The built-in Bengaluru walking map remains available separately.',
        ),
      ],
    );
  }

  Widget _mapPlaceCard(
    Map<String, dynamic> map,
    List<Map<String, dynamic>> places,
    int index,
    Map<String, dynamic> place,
  ) {
    final gpsReady = _hasValidMapCoordinates(place);
    return Card(
      color: wonderlaWhite,
      child: InkWell(
        borderRadius: BorderRadius.circular(wonderlaCardRadius),
        onTap: () => _editMapPlace(map, index),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: gpsReady
                          ? const Color(0xFFECF9F2)
                          : const Color(0xFFEEF4FF),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      gpsReady
                          ? Icons.directions_walk_rounded
                          : Icons.place_outlined,
                      color: gpsReady ? wonderlaSuccess : _brandNavy,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      place['name']?.toString().isNotEmpty == true
                          ? place['name'].toString()
                          : 'Untitled place',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Edit place',
                    onPressed: () => _editMapPlace(map, index),
                    icon: const Icon(
                      Icons.edit_outlined,
                      size: 20,
                      color: _brandNavy,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Delete place',
                    onPressed: () => _deleteMapEntry(
                      map: map,
                      items: places,
                      index: index,
                      collectionKey: 'places',
                      label: place['name']?.toString() ?? 'map place',
                    ),
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      size: 20,
                      color: wonderlaFlagRed,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _CmsPillBadge(
                    label: place['category']?.toString().isNotEmpty == true
                        ? place['category'].toString()
                        : 'Place',
                    foreground: _brandNavy,
                    background: const Color(0xFFEEF4FF),
                  ),
                  _CmsPillBadge(
                    label: 'X ${place['x'] ?? 0}% · Y ${place['y'] ?? 0}%',
                    foreground: wonderlaMuted,
                    background: wonderlaCream,
                  ),
                  _CmsPillBadge(
                    label: gpsReady
                        ? 'GPS walking ready'
                        : 'Artwork pin only',
                    foreground: gpsReady ? wonderlaSuccess : wonderlaWarning,
                    background: gpsReady
                        ? const Color(0xFFECF9F2)
                        : const Color(0xFFFFF8E6),
                    icon: gpsReady
                        ? Icons.check_circle_outline_rounded
                        : Icons.info_outline_rounded,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loadMapSettings() async {
    try {
      _mapSettings = await widget.api.mapSettings();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Widget _googleMapSettings() => _ApiKeyCard(
    api: widget.api,
    configured: (_mapSettings?['apiKey']?.toString() ?? '').isNotEmpty,
    onSaved: () async {
      await _loadMapSettings();
    },
  );

  Widget _usersPage() => _UsersManager(
    api: widget.api,
    users: _users,
    parks: _parks,
    currentUsername: widget.user['username']?.toString() ?? '',
    reload: _loadUsers,
  );

  Future<void> _downloadParkQrPng(String url, String slug) async {
    final data = await QrPainter(
      data: url,
      version: QrVersions.auto,
    ).toImageData(1024, format: ImageByteFormat.png);
    if (data == null) return;
    await downloadQrPng(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      'wonderla-$slug-qr.png',
    );
  }

  Future<void> _copyUrl(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: wonderlaNavy,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            content: const Text('Park QR link copied to clipboard.'),
          ),
        );
    }
  }

  Widget _siteUrlPage() {
    final origin = _siteOrigin ?? widget.api.baseUrl;
    final slug = _selectedSlug ?? '';
    final parkName = _config?['name']?.toString() ?? 'Selected park';
    final url = '$origin/qr-code/$slug';

    final qrPreviewCard = Card(
      color: wonderlaWhite,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            const _CmsPillBadge(
              label: 'PRINT-READY QR PREVIEW',
              foreground: wonderlaNavy,
              background: wonderlaGold,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: wonderlaWhite,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: wonderlaBorder, width: 1.5),
              ),
              child: QrImageView(
                data: url,
                version: QrVersions.auto,
                size: 196,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: wonderlaNavy,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: wonderlaNavy,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              parkName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _ink,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '/qr-code/$slug',
              style: const TextStyle(color: wonderlaMuted, fontSize: 12.5),
            ),
          ],
        ),
      ),
    );

    final detailsCard = Card(
      color: wonderlaWhite,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Park QR destination',
              style: TextStyle(
                color: _ink,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Visitors who scan printed park signage open this route directly in the guide.',
              style: TextStyle(color: wonderlaMuted, fontSize: 13.5),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: wonderlaCream,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: wonderlaBorder),
              ),
              child: SelectableText(
                url,
                style: const TextStyle(
                  color: _brandNavy,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: () => _downloadParkQrPng(url, slug),
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: const Text('Download PNG'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _copyUrl(url),
                  icon: const Icon(Icons.copy_rounded, size: 17),
                  label: const Text('Copy link'),
                ),
                OutlinedButton.icon(
                  onPressed: _loadSiteOrigin,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Refresh URL'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const _CmsAlertBanner(
              tone: _CmsBannerTone.info,
              message:
                  'Keep this web fallback URL on printed signage. Configure Android App Links and iOS Universal Links on the same domain so installed apps open QR scans natively.',
            ),
          ],
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 780) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 280, child: qrPreviewCard),
              const SizedBox(width: 18),
              Expanded(child: detailsCard),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [qrPreviewCard, const SizedBox(height: 16), detailsCard],
        );
      },
    );
  }

  Future<void> _showParkQr(Map<String, dynamic> park) async {
    final slug = park['slug']?.toString() ?? '';
    final origin = await _resolveSiteOrigin();
    if (!mounted) return;
    final url = '$origin/qr-code/$slug';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: wonderlaGold,
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(
                Icons.qr_code_2_rounded,
                color: wonderlaNavy,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text('${park['name'] ?? 'Park'} QR code')),
          ],
        ),
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: wonderlaWhite,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: wonderlaBorder),
                ),
                child: QrImageView(
                  data: url,
                  version: QrVersions.auto,
                  size: 210,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: wonderlaNavy,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: wonderlaNavy,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: wonderlaCream,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SelectableText(
                  url,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _brandNavy,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
          OutlinedButton.icon(
            onPressed: () => _copyUrl(url),
            icon: const Icon(Icons.copy_rounded, size: 17),
            label: const Text('Copy link'),
          ),
          FilledButton.icon(
            onPressed: () async {
              await _downloadParkQrPng(url, slug);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text('Download PNG'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadSiteOrigin() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final origin = await _resolveSiteOrigin();
      if (mounted) setState(() => _notice = 'QR links use $origin.');
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<String> _resolveSiteOrigin() async {
    if (_siteOrigin != null) return _siteOrigin!;
    try {
      final value = await widget.api.siteUrl();
      final uri = Uri.tryParse(value['origin']?.toString() ?? '');
      if (uri != null &&
          uri.hasAuthority &&
          {'http', 'https'}.contains(uri.scheme)) {
        _siteOrigin = uri.origin;
        return _siteOrigin!;
      }
    } catch (_) {
      // Fall back to the configured API host when site metadata is unavailable.
    }
    return widget.api.baseUrl;
  }

  Future<void> _addPark() async {
    final values = await _simpleForm('Create new park', [
      ('name', 'Park name'),
      ('location', 'Location'),
    ]);
    if (values == null || values['name']!.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      final result = await widget.api.createPark(
        values['name']!.trim(),
        values['location']!.trim(),
      );
      _parks = await widget.api.parks();
      await _loadPark(result['slug'] as String);
      setState(() {
        _section = 'Park overview';
        _notice =
            'Park created. Add content and images, then click Save changes.';
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deletePark(Map<String, dynamic> p) async {
    final yes = await _confirm(
      'Delete ${p['name']}?',
      'This permanently deletes this park and all of its visitor content.',
    );
    if (!yes) return;
    try {
      await widget.api.deletePark(p['slug'] as String);
      _parks = await widget.api.parks();
      _config = null;
      _selectedSlug = null;
      _dirty = false;
      if (_parks.isNotEmpty) await _loadPark(_parks.first['slug'] as String);
      setState(() => _notice = 'Park deleted.');
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _deleteCollectionItem(String key, int index) async {
    final items = _config?[key] as List?;
    if (items == null || index < 0 || index >= items.length) return;
    final title = _itemTitle(Map<String, dynamic>.from(items[index] as Map));
    final yes = await _confirm(
      'Delete "$title"?',
      'This item will be permanently removed once you save your park changes.',
    );
    if (!yes || !mounted) return;
    setState(() {
      items.removeAt(index);
      _markDirty();
    });
  }

  Future<void> _deleteMapEntry({
    required Map<String, dynamic> map,
    required List<Map<String, dynamic>> items,
    required int index,
    required String collectionKey,
    required String label,
  }) async {
    final yes = await _confirm(
      'Delete "$label"?',
      'This map item will be removed when you save the map configuration.',
    );
    if (!yes || !mounted || index < 0 || index >= items.length) return;
    setState(() {
      items.removeAt(index);
      map[collectionKey] = items;
      _config!['parkMap'] = map;
      _markDirty();
    });
  }

  Future<void> _editItem(String configKey, int? index) async {
    final list = _config![configKey] as List;
    final existing = index == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(list[index] as Map);
    final schema =
        _schemas[_section] ??
        const [('title', 'Title'), ('description', 'Description')];
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _RecordEditor(
        title: index == null
            ? 'Add ${_singularSectionLabel(_section)}'
            : 'Edit ${_singularSectionLabel(_section)}',
        values: existing,
        schema: schema,
        api: widget.api,
        parkSlug: _selectedSlug!,
        manageMenu: _section == 'Dining & menus',
      ),
    );
    if (result == null) return;
    setState(() {
      if (index == null) {
        list.add(result);
      } else {
        list[index] = result;
      }
      _markDirty();
    });
  }

  Future<void> _editMapPlace(Map<String, dynamic> map, int? index) async {
    final values = List<Map<String, dynamic>>.from(
      (map['places'] as List? ?? []).map(
        (e) => Map<String, dynamic>.from(e as Map),
      ),
    );
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _RecordEditor(
        title: index == null ? 'Add map place' : 'Edit map place',
        values: index == null ? {} : values[index],
        schema: const [
          ('name', 'Place name'),
          ('category', 'Category'),
          ('x', 'Horizontal position %'),
          ('y', 'Vertical position %'),
          ('lat', 'Latitude'),
          ('lng', 'Longitude'),
          ('avatarImage', 'Place icon image'),
        ],
        api: widget.api,
        parkSlug: _selectedSlug!,
      ),
    );
    if (result == null) return;
    setState(() {
      if (index == null) {
        values.add(result);
      } else {
        values[index] = result;
      }
      map['places'] = values;
      _config!['parkMap'] = map;
      _markDirty();
    });
  }

  Future<void> _editMapZone(Map<String, dynamic> map, int? index) async {
    final values = List<Map<String, dynamic>>.from(
      (map['zones'] as List? ?? []).map(
        (e) => Map<String, dynamic>.from(e as Map),
      ),
    );
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _RecordEditor(
        title: index == null ? 'Add map zone' : 'Edit map zone',
        values: index == null ? {} : values[index],
        schema: const [('name', 'Zone name'), ('description', 'Description')],
        api: widget.api,
        parkSlug: _selectedSlug!,
      ),
    );
    if (result == null) return;
    setState(() {
      if (index == null) {
        values.add(result);
      } else {
        values[index] = result;
      }
      map['zones'] = values;
      _config!['parkMap'] = map;
      _markDirty();
    });
  }

  Future<Map<String, String>?> _simpleForm(
    String title,
    List<(String, String)> schema,
  ) async {
    final formKey = GlobalKey<FormState>();
    final controllers = {
      for (final (key, _) in schema) key: TextEditingController(),
    };
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 420,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (key, label) in schema)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextFormField(
                      controller: controllers[key],
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(labelText: label),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Enter the $label.'
                          : null,
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (!(formKey.currentState?.validate() ?? false)) return;
              Navigator.pop(ctx, {
                for (final key in controllers.keys)
                  key: controllers[key]!.text.trim(),
              });
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
    for (final c in controllers.values) {
      c.dispose();
    }
    return result;
  }

  Future<bool> _confirm(String title, String content) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFFDF0F2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  color: wonderlaFlagRed,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(title)),
            ],
          ),
          content: Text(content, style: const TextStyle(color: wonderlaMuted)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: wonderlaFlagRed),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      ) ??
      false;

  Widget _subsectionHeader(
    String title,
    String subtitle,
    String buttonLabel,
    VoidCallback add,
  ) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 22, 2, 10),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: _ink,
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(color: wonderlaMuted, fontSize: 12.5),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        FilledButton.tonalIcon(
          onPressed: add,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFEEF4FF),
            foregroundColor: _brandNavy,
            minimumSize: const Size(0, 40),
          ),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: Text(buttonLabel),
        ),
      ],
    ),
  );

  Widget _textField(
    String label,
    String value,
    ValueChanged<String> changed, {
    int maxLines = 1,
    String? fieldKey,
  }) => TextFormField(
    key: ValueKey('${_selectedSlug ?? 'none'}_${fieldKey ?? label}'),
    initialValue: value,
    maxLines: maxLines,
    onChanged: changed,
    decoration: InputDecoration(labelText: label, isDense: true),
  );

  Widget _statusBadge(bool active) => _CmsPillBadge(
    label: active ? 'Published' : 'Hidden',
    foreground: active ? wonderlaSuccess : wonderlaMuted,
    background: active ? const Color(0xFFECF9F2) : wonderlaCream,
    icon: active ? Icons.public_rounded : Icons.visibility_off_outlined,
  );

  Widget _thumbnail(String? url) => Container(
    width: 58,
    height: 58,
    decoration: BoxDecoration(
      color: wonderlaCream,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: wonderlaBorder),
    ),
    clipBehavior: Clip.antiAlias,
    child: url == null || url.trim().isEmpty
        ? Icon(_iconFor(_section), color: _brandNavy, size: 24)
        : Image.network(
            _absoluteImage(url.trim()),
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) =>
                const Icon(Icons.broken_image_outlined, color: wonderlaMuted),
          ),
  );

  String _absoluteImage(String path) => Uri.tryParse(path)?.hasScheme == true
      ? path
      : '${widget.api.baseUrl}${path.startsWith('/') ? '' : '/'}$path';

  String _itemTitle(Map<String, dynamic> item) =>
      (item['title'] ?? item['name'] ?? item['ride'] ?? 'Untitled').toString();

  IconData _iconFor(String key) => switch (key) {
    'Rides' => Icons.attractions_outlined,
    'Events' => Icons.event_outlined,
    'Dining & menus' => Icons.restaurant_outlined,
    'Live wait times' => Icons.timer_outlined,
    'Wave pool & rain dance' => Icons.waves_outlined,
    'Safety & hygiene' => Icons.health_and_safety_outlined,
    'Maintenance log' => Icons.build_outlined,
    'Ride guidelines' => Icons.straighten_outlined,
    _ => Icons.list_alt,
  };
}
