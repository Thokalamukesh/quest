part of 'cms_screen.dart';

class _RecordEditor extends StatefulWidget {
  const _RecordEditor({
    required this.title,
    required this.values,
    required this.schema,
    required this.api,
    required this.parkSlug,
    this.manageMenu = false,
  });

  final String title;
  final Map<String, dynamic> values;
  final List<(String, String)> schema;
  final CmsApi api;
  final String parkSlug;
  final bool manageMenu;

  @override
  State<_RecordEditor> createState() => _RecordEditorState();
}

class _RecordEditorState extends State<_RecordEditor> {
  static const _mapPlaceCategories = [
    'Ride',
    'Family ride',
    'Kids ride',
    'Water ride',
    'Dining',
    'Facility',
    'Entrance',
    'Attraction',
  ];

  late final Map<String, dynamic> _values = Map<String, dynamic>.from(
    widget.values,
  );
  final _controllers = <String, TextEditingController>{};
  String? _coordinateError;

  bool get _isMapPlaceEditor =>
      widget.schema.any((field) => field.$1 == 'lat') &&
      widget.schema.any((field) => field.$1 == 'lng');

  bool get _hasEnteredValidCoordinates {
    final lat = double.tryParse(_controllers['lat']?.text.trim() ?? '');
    final lng = double.tryParse(_controllers['lng']?.text.trim() ?? '');
    return lat != null &&
        lng != null &&
        lat.isFinite &&
        lng.isFinite &&
        lat >= -90 &&
        lat <= 90 &&
        lng >= -180 &&
        lng <= 180;
  }

  Widget _coordinatesEditor() {
    final gpsReady = _hasEnteredValidCoordinates;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: wonderlaCream,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: gpsReady
              ? wonderlaSuccess.withValues(alpha: 0.35)
              : wonderlaBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                gpsReady
                    ? Icons.directions_walk_rounded
                    : Icons.location_on_outlined,
                color: gpsReady ? wonderlaSuccess : _brandNavy,
                size: 19,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'GPS walking directions',
                  style: TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
              _CmsPillBadge(
                label: gpsReady ? 'GPS ready' : 'Optional',
                foreground: gpsReady ? wonderlaSuccess : wonderlaMuted,
                background: gpsReady
                    ? const Color(0xFFECF9F2)
                    : wonderlaWhite,
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Right-click the spot in Google Maps (or long-press on mobile) to copy its latitude & longitude. Visitors can then get walking directions directly to this pin.',
            style: TextStyle(color: wonderlaMuted, fontSize: 12.5, height: 1.4),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final fields = [
                ('lat', 'Latitude', 'e.g. 12.8343'),
                ('lng', 'Longitude', 'e.g. 77.4010'),
              ];
              final children = fields
                  .map(
                    (field) => TextField(
                      controller: _controllers[field.$1],
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      onChanged: (_) => setState(() => _coordinateError = null),
                      decoration: InputDecoration(
                        labelText: field.$2,
                        hintText: field.$3,
                        isDense: true,
                      ),
                    ),
                  )
                  .toList();
              if (constraints.maxWidth < 400) {
                return Column(
                  children: [
                    children[0],
                    const SizedBox(height: 10),
                    children[1],
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: children[0]),
                  const SizedBox(width: 10),
                  Expanded(child: children[1]),
                ],
              );
            },
          ),
          if (_coordinateError != null) ...[
            const SizedBox(height: 10),
            _CmsAlertBanner(
              message: _coordinateError!,
              tone: _CmsBannerTone.error,
            ),
          ],
        ],
      ),
    );
  }

  bool _validateCoordinates() {
    final latitudeText = _controllers['lat']?.text.trim() ?? '';
    final longitudeText = _controllers['lng']?.text.trim() ?? '';
    String? error;
    if (latitudeText.isEmpty != longitudeText.isEmpty) {
      error = 'Enter both latitude and longitude.';
    } else if (latitudeText.isNotEmpty) {
      final latitude = double.tryParse(latitudeText);
      final longitude = double.tryParse(longitudeText);
      if (latitude == null ||
          longitude == null ||
          !latitude.isFinite ||
          !longitude.isFinite) {
        error = 'Enter valid numeric coordinates.';
      } else if (latitude < -90 || latitude > 90) {
        error = 'Latitude must be between −90 and 90.';
      } else if (longitude < -180 || longitude > 180) {
        error = 'Longitude must be between −180 and 180.';
      }
    }
    setState(() => _coordinateError = error);
    return error == null;
  }

  Future<void> _pickServiceDate() async {
    final now = DateTime.now();
    final current = _controllers['lastService']?.text.trim() ?? '';
    final parts = current.split('/');
    final parsed = parts.length == 3
        ? DateTime.tryParse('${parts[2]}-${parts[1]}-${parts[0]}')
        : DateTime.tryParse(current);
    final picked = await showDatePicker(
      context: context,
      initialDate: parsed ?? now,
      firstDate: DateTime(1990),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null || !mounted) return;
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    _controllers['lastService']?.text =
        '${twoDigits(picked.day)}/${twoDigits(picked.month)}/${picked.year}';
    setState(() {});
  }

  void _save() {
    if (_isMapPlaceEditor && !_validateCoordinates()) return;
    for (final (key, _) in widget.schema) {
      final c = _controllers[key];
      if (c == null) continue;
      final raw = c.text.trim();
      if (key == 'tags' || key == 'timeSlot') {
        _values[key] = raw.isEmpty
            ? <String>[]
            : raw
                  .split(',')
                  .map((s) => s.trim())
                  .where((s) => s.isNotEmpty)
                  .toList();
      } else if ({
        'time',
        'rideDuration',
        'x',
        'y',
        'lat',
        'lng',
      }.contains(key)) {
        if (raw.isNotEmpty) {
          _values[key] = num.tryParse(raw) ?? raw;
        } else if (key == 'lat' || key == 'lng') {
          _values.remove(key);
        }
      } else {
        _values[key] = raw;
      }
    }
    Navigator.pop(context, _values);
  }

  @override
  void initState() {
    super.initState();
    for (final (key, _) in widget.schema) {
      if (key == 'img' ||
          key == 'avatarImage' ||
          _values[key] is bool ||
          key == 'kioskBookingEnabled' ||
          key == 'veg') {
        continue;
      }
      final v = _values[key];
      _controllers[key] = TextEditingController(
        text: v is List ? v.join(', ') : v?.toString() ?? '',
      );
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  String? _hintFor(String key) => switch (key) {
    'tags' => 'e.g. Thrill, Dry Ride, Fast Track (comma separated)',
    'timeSlot' => 'e.g. 11:30 AM, 2:00 PM, 4:30 PM (comma separated)',
    'x' => '0 to 100 (left to right)',
    'y' => '0 to 100 (top to bottom)',
    'minHeight' => 'e.g. 120 cm',
    'directions' =>
        'e.g. Walk past Dome Plaza and turn left beside Wave Pool',
    'directionsUrl' => 'https://maps.google.com/?q=12.8343,77.4010',
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 580,
          maxHeight: screenHeight * 0.88,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(22, 18, 14, 16),
              decoration: const BoxDecoration(
                color: wonderlaWhite,
                border: Border(bottom: BorderSide(color: wonderlaBorder)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF4FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      widget.manageMenu
                          ? Icons.restaurant_menu_rounded
                          : _isMapPlaceEditor
                          ? Icons.pin_drop_outlined
                          : Icons.edit_note_rounded,
                      color: _brandNavy,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        color: _ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: wonderlaMuted),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_isMapPlaceEditor) _coordinatesEditor(),
                    for (final (key, label) in widget.schema)
                      if (_isMapPlaceEditor && (key == 'lat' || key == 'lng'))
                        const SizedBox.shrink()
                      else if (key == 'img' || key == 'avatarImage')
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _ImagePickerField(
                            api: widget.api,
                            parkSlug: widget.parkSlug,
                            label: label,
                            value: _values[key]?.toString() ?? '',
                            onChanged: (v) => setState(() => _values[key] = v),
                          ),
                        )
                      else if (_values[key] is bool ||
                          key == 'kioskBookingEnabled' ||
                          key == 'veg')
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Material(
                            color: wonderlaCream,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: const BorderSide(color: wonderlaBorder),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: SwitchListTile(
                              title: Text(
                                label,
                                style: const TextStyle(
                                  color: _ink,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              value: _values[key] == true,
                              onChanged: (v) =>
                                  setState(() => _values[key] = v),
                            ),
                          ),
                        )
                      else if (key == 'lastService')
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: TextField(
                            controller: _controllers[key],
                            readOnly: true,
                            onTap: _pickServiceDate,
                            decoration: InputDecoration(
                              labelText: label,
                              hintText: 'Choose a service date',
                              suffixIcon: const Icon(
                                Icons.calendar_today_outlined,
                              ),
                            ),
                          ),
                        )
                      else ...[
                        Padding(
                          padding: EdgeInsets.only(
                            bottom: (_isMapPlaceEditor && key == 'category')
                                ? 8
                                : 14,
                          ),
                          child: TextField(
                            controller: _controllers[key],
                            onChanged: _isMapPlaceEditor && key == 'category'
                                ? (_) => setState(() {})
                                : null,
                            keyboardType:
                                {
                                  'time',
                                  'rideDuration',
                                  'x',
                                  'y',
                                  'lat',
                                  'lng',
                                }.contains(key)
                                ? const TextInputType.numberWithOptions(
                                    decimal: true,
                                  )
                                : TextInputType.multiline,
                            maxLines: {
                              'description',
                              'checks',
                              'directions',
                            }.contains(key)
                                ? 3
                                : 1,
                            decoration: InputDecoration(
                              labelText: label,
                              hintText: _hintFor(key),
                            ),
                          ),
                        ),
                        if (_isMapPlaceEditor && key == 'category')
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (final category in _mapPlaceCategories)
                                  ChoiceChip(
                                    label: Text(
                                      category,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color:
                                            (_controllers['category']?.text
                                                    .trim()
                                                    .toLowerCase() ==
                                                category.toLowerCase())
                                            ? wonderlaWhite
                                            : _ink,
                                      ),
                                    ),
                                    selected:
                                        _controllers['category']?.text
                                            .trim()
                                            .toLowerCase() ==
                                        category.toLowerCase(),
                                    visualDensity: VisualDensity.compact,
                                    onSelected: (_) => setState(() {
                                      _controllers['category']?.text = category;
                                    }),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    if (widget.manageMenu) _menuItemsEditor(),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
              decoration: const BoxDecoration(
                color: wonderlaCream,
                border: Border(top: BorderSide(color: wonderlaBorder)),
              ),
              child: Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 10,
                runSpacing: 8,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Save item'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuItemsEditor() {
    final items = List<Map<String, dynamic>>.from(
      (_values['items'] as List? ?? []).map(
        (e) => Map<String, dynamic>.from(e as Map),
      ),
    );
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: wonderlaCream,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: wonderlaBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Menu dishes',
                  style: TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
              _CmsPillBadge(
                label: '${items.length} ${items.length == 1 ? 'dish' : 'dishes'}',
                foreground: _brandNavy,
                background: wonderlaWhite,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Text(
                'No dishes added yet. Add menu items with prices and veg markers.',
                style: TextStyle(color: wonderlaMuted, fontSize: 12.5),
              ),
            )
          else
            for (var i = 0; i < items.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: wonderlaWhite,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: wonderlaBorder),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    dense: true,
                    leading: _vegMarker(items[i]['veg'] == true),
                    title: Text(
                      items[i]['name']?.toString().trim().isNotEmpty == true
                          ? items[i]['name'].toString()
                          : 'Untitled dish',
                      style: const TextStyle(
                        color: _ink,
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                    subtitle: Text(
                      items[i]['veg'] == true ? 'Vegetarian' : 'Non-vegetarian',
                      style: const TextStyle(
                        color: wonderlaMuted,
                        fontSize: 12,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if ((items[i]['price']?.toString().trim() ?? '')
                            .isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: _CmsPillBadge(
                              label: items[i]['price'].toString(),
                              foreground: _ink,
                              background: wonderlaCream,
                            ),
                          ),
                        IconButton(
                          tooltip: 'Edit dish',
                          onPressed: () => _editDish(i, items),
                          icon: const Icon(
                            Icons.edit_outlined,
                            size: 18,
                            color: _brandNavy,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Remove dish',
                          onPressed: () => setState(() {
                            items.removeAt(i);
                            _values['items'] = items;
                          }),
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                            color: wonderlaFlagRed,
                          ),
                        ),
                      ],
                    ),
                    onTap: () => _editDish(i, items),
                  ),
                ),
              ),
          OutlinedButton.icon(
            onPressed: () => _editDish(null, items),
            style: OutlinedButton.styleFrom(backgroundColor: wonderlaWhite),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add menu item'),
          ),
        ],
      ),
    );
  }

  Widget _vegMarker(bool isVeg) {
    final color = isVeg ? wonderlaSuccess : wonderlaFlagRed;
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: wonderlaWhite,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Center(
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }

  Future<void> _editDish(int? index, List<Map<String, dynamic>> items) async {
    final initial = index == null
        ? <String, dynamic>{'name': '', 'price': '', 'veg': false, 'img': ''}
        : Map<String, dynamic>.from(items[index]);
    final values = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _RecordEditor(
        title: index == null ? 'Add dish' : 'Edit dish',
        values: initial,
        schema: const [
          ('name', 'Dish name'),
          ('price', 'Price'),
          ('veg', 'Vegetarian'),
          ('img', 'Dish image'),
        ],
        api: widget.api,
        parkSlug: widget.parkSlug,
      ),
    );
    if (values == null) return;
    setState(() {
      if (index == null) {
        items.add(values);
      } else {
        items[index] = values;
      }
      _values['items'] = items;
    });
  }
}
