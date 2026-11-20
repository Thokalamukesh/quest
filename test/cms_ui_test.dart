import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:maps_wonderla_flutter/features/cms/cms_api.dart';
import 'package:maps_wonderla_flutter/features/cms/cms_screen.dart';
import 'package:maps_wonderla_flutter/shared/wonderla_palette.dart';

class _FakeCmsApi extends CmsApi {
  _FakeCmsApi() : super(baseUrl: 'https://demo.wonderla.com');

  int saveParkCalls = 0;
  String? savedApiKey;
  final List<Map<String, dynamic>> createdUsers = [];

  final List<Map<String, dynamic>> _parks = [
    {
      'slug': 'bengaluru',
      'name': 'Wonderla Bengaluru',
      'location': 'Mysore Road, Bengaluru',
      'active': true,
    },
    {
      'slug': 'kochi',
      'name': 'Wonderla Kochi',
      'location': 'Pallikkara, Kochi',
      'active': false,
    },
  ];

  final Map<String, Map<String, dynamic>> _parkConfigs = {
    'bengaluru': {
      'slug': 'bengaluru',
      'name': 'Wonderla Bengaluru',
      'location': 'Mysore Road, Bengaluru',
      'active': true,
      'logoUrl': '',
      'heroImageUrl': '',
      'heroVideoUrl': '',
      'rides': [
        {
          'title': 'Recoil',
          'description': 'Reverse looping coaster',
          'tags': ['High Thrill', 'Dry Ride'],
          'kioskBookingEnabled': true,
        },
        {
          'title': 'Flash Tower',
          'description': '40m vertical drop tower',
          'tags': ['Thrill'],
          'kioskBookingEnabled': false,
        },
      ],
      'events': [
        {
          'title': 'Laser Fountain Show',
          'time': '6:30 PM',
          'description': 'Musical fountain spectacle',
        },
      ],
      'dining': [
        {
          'name': 'Waves Restaurant',
          'cuisine': 'South Indian & Multi-cuisine',
          'description': 'Family dining near wave pool',
          'items': [
            {'name': 'Masala Dosa', 'price': '₹180', 'veg': true},
            {'name': 'Chicken Biryani', 'price': '₹320', 'veg': false},
          ],
        },
      ],
      'liveWaitTimes': [
        {'title': 'Recoil', 'time': 25, 'description': 'Fast track open'},
      ],
      'waveRainDance': [
        {
          'title': 'Wave Pool',
          'timeSlot': ['11:30 AM', '2:00 PM'],
          'rideDuration': 30,
        },
      ],
      'safetyHygiene': [
        {'title': 'Swimwear policy', 'description': 'Nylon or Lycra required'},
      ],
      'maintenanceLog': [
        {
          'ride': 'Recoil',
          'lastService': '15/11/2026',
          'checks': 'Daily harness & brake inspection',
        },
      ],
      'rideGuidelines': [
        {
          'title': 'Recoil Height Rule',
          'description': 'Riders must meet height requirement',
          'minHeight': '140 cm',
        },
      ],
      'parkMap': {
        'centerLat': 12.8343,
        'centerLng': 77.401,
        'img': '',
        'description': 'Illustrated map of Wonderla Bengaluru',
        'places': [
          {
            'name': 'Recoil Coaster',
            'category': 'Ride',
            'x': 45,
            'y': 35,
            'lat': 12.8348,
            'lng': 77.4014,
          },
          {
            'name': 'Wave Pool Deck',
            'category': 'Water ride',
            'x': 60,
            'y': 55,
          },
        ],
        'zones': [
          {'name': 'Thrill Zone', 'description': 'High-intensity dry rides'},
        ],
      },
    },
    'kochi': {
      'slug': 'kochi',
      'name': 'Wonderla Kochi',
      'location': 'Pallikkara, Kochi',
      'active': false,
      'rides': <Map<String, dynamic>>[],
      'events': <Map<String, dynamic>>[],
      'dining': <Map<String, dynamic>>[],
      'liveWaitTimes': <Map<String, dynamic>>[],
      'waveRainDance': <Map<String, dynamic>>[],
      'safetyHygiene': <Map<String, dynamic>>[],
      'maintenanceLog': <Map<String, dynamic>>[],
      'rideGuidelines': <Map<String, dynamic>>[],
      'parkMap': {
        'img': '',
        'description': '',
        'places': <Map<String, dynamic>>[],
        'zones': <Map<String, dynamic>>[],
      },
    },
  };

  final List<Map<String, dynamic>> _users = [
    {'username': 'superadmin', 'role': 'superadmin'},
    {
      'username': 'blr_editor',
      'role': 'park',
      'parkSlug': 'bengaluru',
      'permissions': ['Rides', 'Live wait times'],
    },
  ];

  @override
  Future<Map<String, dynamic>> session() async => {'authenticated': false};

  @override
  Future<List<Map<String, dynamic>>> parks() async =>
      _parks.map((p) => Map<String, dynamic>.from(p)).toList();

  @override
  Future<Map<String, dynamic>> park(String slug) async =>
      Map<String, dynamic>.from(_parkConfigs[slug]!);

  @override
  Future<Map<String, dynamic>> savePark(
    String slug,
    Map<String, dynamic> config,
  ) async {
    saveParkCalls++;
    _parkConfigs[slug] = Map<String, dynamic>.from(config);
    return Map<String, dynamic>.from(config);
  }

  @override
  Future<Map<String, dynamic>> mapSettings() async => {
    'apiKey': savedApiKey ?? '',
  };

  @override
  Future<void> saveMapSettings(String apiKey) async {
    savedApiKey = apiKey;
  }

  @override
  Future<List<Map<String, dynamic>>> users() async =>
      _users.map((u) => Map<String, dynamic>.from(u)).toList();

  @override
  Future<void> createUser(Map<String, dynamic> user) async {
    createdUsers.add(user);
    _users.add(Map<String, dynamic>.from(user));
  }

  @override
  Future<Map<String, dynamic>> siteUrl() async => {
    'origin': 'https://quest-backend.vercel.app',
  };
}

Widget _wrapApp(Widget child) =>
    MaterialApp(theme: buildWonderlaTheme(), home: child);

void main() {
  testWidgets('CMS login screen collapses server URL and validates inputs', (
    tester,
  ) async {
    final api = _FakeCmsApi();
    await tester.pumpWidget(_wrapApp(CmsScreen(api: api)));
    await tester.pumpAndSettle();

    expect(find.text('PARK OPERATIONS CMS'), findsOneWidget);
    expect(find.text('Server: demo.wonderla.com'), findsOneWidget);
    expect(find.text('Backend website URL'), findsNothing);

    await tester.tap(find.text('Change'));
    await tester.pumpAndSettle();
    expect(find.text('Backend website URL'), findsOneWidget);

    await tester.ensureVisible(find.text('Sign in to CMS'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign in to CMS'));
    await tester.pumpAndSettle();
    expect(find.text('Enter your username.'), findsOneWidget);
    expect(find.text('Enter your password.'), findsOneWidget);
  });

  testWidgets(
    'CMS dashboard shows overview KPIs, tracks unsaved changes, and filters collections',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final api = _FakeCmsApi();
      await tester.pumpWidget(
        _wrapApp(
          CmsScreen(
            api: api,
            initialUser: const {'username': 'superadmin', 'role': 'superadmin'},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Overview hero + KPI grid + collapsible explore images
      expect(find.text('Wonderla Bengaluru'), findsWidgets);
      expect(find.text('1/2'), findsOneWidget);
      expect(find.text('Pins GPS walking ready'), findsOneWidget);
      expect(find.text('0 / 9 set'), findsOneWidget);
      expect(find.text('Saved'), findsOneWidget);

      // Edit park display name -> Unsaved changes badge appears
      await tester.enterText(
        find.byKey(const ValueKey('bengaluru_park_name')),
        'Wonderla Bengaluru Updated',
      );
      await tester.pumpAndSettle();
      expect(find.text('Unsaved changes'), findsOneWidget);

      // Save changes clears dirty state
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(api.saveParkCalls, 1);
      expect(find.text('Saved'), findsOneWidget);

      // Navigate to Rides and test instant search filtering + Kiosk badge
      await tester.tap(find.text('Rides').first);
      await tester.pumpAndSettle();
      expect(find.text('Recoil'), findsOneWidget);
      expect(find.text('Flash Tower'), findsOneWidget);
      expect(find.text('Kiosk booking'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'Recoil');
      await tester.pumpAndSettle();
      expect(find.text('Reverse looping coaster'), findsOneWidget);
      expect(find.text('Flash Tower'), findsNothing);
      expect(find.text('1 of 2'), findsOneWidget);
    },
  );

  testWidgets(
    'CMS API key Save button and Users Create button reactively enable on input',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final api = _FakeCmsApi();
      await tester.pumpWidget(
        _wrapApp(
          CmsScreen(
            api: api,
            initialUser: const {'username': 'superadmin', 'role': 'superadmin'},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Test Google Maps API key card button reactivity fix
      final mapsNav = find.text('Google Maps settings');
      await tester.scrollUntilVisible(
        mapsNav,
        140,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(mapsNav.first);
      await tester.pumpAndSettle();
      await tester.tap(mapsNav.first);
      await tester.pumpAndSettle();
      expect(find.text('Not configured'), findsOneWidget);

      final saveKeyButtonFinder = find.widgetWithText(
        FilledButton,
        'Save API key',
      );
      expect(
        tester.widget<FilledButton>(saveKeyButtonFinder).onPressed,
        isNull,
      );

      await tester.enterText(find.byType(TextField).first, 'AIzaSyTestKey123');
      await tester.pumpAndSettle();
      expect(
        tester.widget<FilledButton>(saveKeyButtonFinder).onPressed,
        isNotNull,
      );

      await tester.tap(saveKeyButtonFinder);
      await tester.pumpAndSettle();
      expect(api.savedApiKey, 'AIzaSyTestKey123');
      expect(find.text('Configured'), findsOneWidget);

      // Test Users manager Create user button reactivity fix
      final usersNav = find.text('Users');
      await tester.scrollUntilVisible(
        usersNav,
        140,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(usersNav.first);
      await tester.pumpAndSettle();
      await tester.tap(usersNav.first);
      await tester.pumpAndSettle();
      expect(find.text('blr_editor'), findsOneWidget);

      final createUserBtnFinder = find.widgetWithText(
        FilledButton,
        'Create user',
      );
      expect(
        tester.widget<FilledButton>(createUserBtnFinder).onPressed,
        isNull,
      );

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'kochi_ops');
      await tester.enterText(fields.at(1), 'secret99');
      await tester.pumpAndSettle();
      expect(
        tester.widget<FilledButton>(createUserBtnFinder).onPressed,
        isNotNull,
      );

      await tester.ensureVisible(createUserBtnFinder);
      await tester.pumpAndSettle();
      await tester.tap(createUserBtnFinder);
      await tester.pumpAndSettle();
      expect(api.createdUsers.length, 1);
      expect(find.text('kochi_ops'), findsOneWidget);
    },
  );

  testWidgets(
    'CMS map place category chips, inline QR studio, and mobile viewport render cleanly',
    (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final api = _FakeCmsApi();
      await tester.pumpWidget(
        _wrapApp(
          CmsScreen(
            api: api,
            initialUser: const {'username': 'superadmin', 'role': 'superadmin'},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Overview renders cleanly on 375px phone width
      expect(find.text('Wonderla Bengaluru'), findsWidgets);

      // Scroll horizontal mobile section picker to Park map & places
      final mapChip = find.text('Park map & places · 2');
      await tester.scrollUntilVisible(
        mapChip,
        160,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(mapChip);
      await tester.pumpAndSettle();
      await tester.tap(mapChip);
      await tester.pumpAndSettle();

      expect(find.text('1 / 2 GPS walking ready'), findsOneWidget);
      await tester.ensureVisible(find.text('Add place'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add place'));
      await tester.pumpAndSettle();

      // Quick category chip fills category input
      final waterRideChip = find.widgetWithText(ChoiceChip, 'Water ride');
      expect(waterRideChip, findsOneWidget);
      await tester.ensureVisible(waterRideChip);
      await tester.pumpAndSettle();
      await tester.tap(waterRideChip);
      await tester.pumpAndSettle();
      expect(tester.widget<ChoiceChip>(waterRideChip).selected, isTrue);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Scroll to Site URL & QR codes and check inline QR preview
      final qrChip = find.text('Site URL & QR codes');
      await tester.scrollUntilVisible(
        qrChip,
        160,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(qrChip);
      await tester.pumpAndSettle();
      await tester.tap(qrChip);
      await tester.pumpAndSettle();

      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text('Download PNG'), findsOneWidget);
      expect(find.text('Copy link'), findsOneWidget);
    },
  );
}
