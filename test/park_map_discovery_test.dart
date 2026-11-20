import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:maps_wonderla_flutter/features/cms/cms_api.dart';
import 'package:maps_wonderla_flutter/features/home/configured_park_map_screen.dart';
import 'package:maps_wonderla_flutter/features/home/visitor_home.dart';
import 'package:maps_wonderla_flutter/features/park_map/models/park_discovery_item.dart';
import 'package:maps_wonderla_flutter/features/park_map/widgets/park_filter_bar.dart';
import 'package:maps_wonderla_flutter/features/park_map/widgets/park_map_marker.dart';

Map<String, dynamic> _sampleParkConfig() => {
  'slug': 'bengaluru',
  'name': 'Wonderla Bengaluru',
  'location': 'Bengaluru, Karnataka',
  'active': true,
  'rides': [
    {
      'id': 'ride-recoil',
      'img': '',
      'title': 'Recoil',
      'description': "India's first reverse-looping roller coaster!",
      'tags': ['Roller Coaster', 'High Thrill'],
      'kioskBookingEnabled': true,
      'minHeight': '140 cm',
    },
    {
      'id': 'ride-lazy-river',
      'img': '',
      'title': 'Lazy River',
      'description': 'Drift through a calm river.',
      'tags': ['Relaxing Drift', 'Rubber Floats'],
    },
    {
      'id': 'ride-kiddies-wheel',
      'img': '',
      'title': 'Kiddies Wheel',
      'description': 'A miniature giant wheel for children.',
      'tags': ['Mini Ferris', 'Gentle Thrill'],
    },
  ],
  'liveWaitTimes': [
    {'img': '', 'title': 'Recoil', 'description': 'Roller coaster.', 'time': 35},
    {'img': '', 'title': 'Lazy River', 'description': 'Calm river.', 'time': 10},
  ],
  'waveRainDance': [
    {
      'img': '',
      'title': 'Wave Pool',
      'timeSlot': ['12:00 PM', '01:00 PM'],
      'rideDuration': 20,
    },
  ],
  'maintenanceLog': [
    {'ride': 'Recoil', 'lastService': '11/10/2026', 'checks': '7'},
  ],
  'dining': [
    {
      'img': '',
      'name': 'Park View Restaurant',
      'cuisine': 'Traditional Breakfast',
      'description': 'Fluffy idlis and crispy dosas.',
      'tags': ['Breakfast'],
      'items': [
        {'name': 'Masala Dosa', 'price': '₹150', 'veg': true, 'img': ''},
      ],
    },
  ],
  'parkMap': {
    'img': '',
    'description': 'Interactive park map',
    'zones': [
      {'name': 'Land Zone', 'description': 'High-thrill rides'},
      {'name': 'Water Zone', 'description': 'Water rides and wave pool'},
    ],
    'places': [
      {
        'name': 'Recoil',
        'category': 'Ride',
        'x': 77,
        'y': 30,
        'lat': 12.832685,
        'lng': 77.401272,
      },
      {'name': 'Wave Pool', 'category': 'Water rides', 'x': 17, 'y': 46},
      {'name': 'Lazy River', 'category': 'Water rides', 'x': 49, 'y': 57},
      {'name': 'Park View Restaurant', 'category': 'Dining', 'x': 11, 'y': 27},
      {'name': 'First Aid', 'category': 'Facility', 'x': 48, 'y': 37},
    ],
  },
};

void main() {
  test(
    'ParkDiscoveryCatalog maps only real categories and preserves API metadata',
    () {
      final config = _sampleParkConfig();
      final catalog = ParkDiscoveryCatalog.fromParkConfig(
        config,
        baseUrl: 'http://localhost:3000',
        isBengaluruPark: true,
      );

      expect(catalog.items.length, 5);
      // Only categories backed by actual places appear (no Restrooms or Kids Rides here).
      expect(catalog.availableCategories, containsAll([
        ParkDiscoveryCategory.thrillRides,
        ParkDiscoveryCategory.waterRides,
        ParkDiscoveryCategory.restaurants,
        ParkDiscoveryCategory.facilities,
      ]));
      expect(
        catalog.availableCategories,
        isNot(contains(ParkDiscoveryCategory.restrooms)),
      );

      final recoil = catalog.items.firstWhere((i) => i.name == 'Recoil');
      expect(recoil.waitTimeMinutes, 35);
      expect(recoil.kioskBookingEnabled, isTrue);
      expect(recoil.minHeight, '140 cm');
      expect(recoil.lastServiceDate, '11/10/2026');
      expect(recoil.serviceChecks, '7');
      expect(recoil.rawRide?['id'], 'ride-recoil');
      expect(recoil.hasGpsCoordinates, isTrue);

      final parkView = catalog.items.firstWhere(
        (i) => i.name == 'Park View Restaurant',
      );
      expect(parkView.category, ParkDiscoveryCategory.restaurants);
      expect(parkView.menuItems.length, 1);
      expect(parkView.cuisine, 'Traditional Breakfast');

      // Multi-select filter combines Thrill + Restaurants accurately.
      final filtered = catalog.filter(
        categories: {
          ParkDiscoveryCategory.thrillRides,
          ParkDiscoveryCategory.restaurants,
        },
      );
      expect(filtered.map((e) => e.name), ['Recoil', 'Park View Restaurant']);
    },
  );

  testWidgets(
    'ConfiguredParkMapScreen supports multi-select filters, search, clear-all, and ride info bottom sheet',
    (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final config = _sampleParkConfig();

      await tester.pumpWidget(
        MaterialApp(
          home: ConfiguredParkMapScreen(
            config: config,
            baseUrl: 'http://localhost:3000',
            api: CmsApi(baseUrl: 'http://localhost:3000'),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.text('5 places available'), findsOneWidget);
      expect(find.byType(WonderlaMapPin), findsNWidgets(3)); // Recoil, Wave Pool, Lazy River have verified GPS

      final filterBar = find.byType(ParkCategoryFilterBar);

      // Only categories present in data are rendered; Restrooms is NOT fabricated.
      expect(
        find.descendant(of: filterBar, matching: find.text('Thrill Rides')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: filterBar, matching: find.text('Water Rides')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: filterBar, matching: find.text('Restaurants')),
        findsOneWidget,
      );
      // Scroll horizontal filter bar to reveal Facilities chip.
      await tester.drag(filterBar, const Offset(-260, 0));
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: filterBar, matching: find.text('Facilities')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: filterBar, matching: find.text('Restrooms')),
        findsNothing,
      );
      await tester.drag(filterBar, const Offset(260, 0));
      await tester.pumpAndSettle();

      // Filter by Water Rides -> dynamically updates list and map pins.
      await tester.tap(
        find.descendant(of: filterBar, matching: find.text('Water Rides')),
      );
      await tester.pump();
      expect(find.text('2 places available'), findsOneWidget);
      expect(find.byType(WonderlaMapPin), findsNWidgets(2));
      expect(find.text('Clear all'), findsOneWidget);

      // Multi-select: add Thrill Rides -> 3 places visible (2 water + 1 thrill).
      await tester.tap(
        find.descendant(of: filterBar, matching: find.text('Thrill Rides')),
      );
      await tester.pump();
      expect(find.text('3 places available'), findsOneWidget);
      expect(find.byType(WonderlaMapPin), findsNWidgets(3));

      // Tap Clear all -> resets back to all 5 places.
      await tester.tap(find.text('Clear all'));
      await tester.pump();
      expect(find.text('5 places available'), findsOneWidget);

      // Search filters results immediately.
      await tester.enterText(find.byType(TextField), 'Recoil');
      await tester.pump();
      expect(find.text('1 place available'), findsOneWidget);

      // Tap Recoil marker/card to open the Ride Information Bottom Sheet.
      await tester.tap(find.byType(WonderlaMapPin).first);
      await tester.pumpAndSettle();

      // Verify ride info bottom sheet renders real wait time, height, service, and kiosk booking callout.
      expect(find.textContaining('35 min wait'), findsWidgets);
      expect(find.text('140 cm'), findsOneWidget);
      expect(find.text('11/10/2026 · 7 checks'), findsOneWidget);
      expect(find.text('Book a ride slot at park kiosks'), findsOneWidget);
      expect(find.text('View Ride Details'), findsOneWidget);

      // Tap View Ride Details -> navigates to existing VisitorSectionScreen.
      await tester.tap(find.text('View Ride Details'));
      await tester.pumpAndSettle();
      expect(find.text('RIDES & WATER ACTIVITIES'), findsOneWidget);
      expect(find.text('RECOIL'), findsOneWidget);
      expect(find.text('Book a ride slot at park kiosks'), findsOneWidget);
    },
  );

  testWidgets(
    'ConfiguredParkMapScreen renders cleanly in portrait phone viewport and filter bottom sheet works',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: ConfiguredParkMapScreen(
            config: _sampleParkConfig(),
            baseUrl: 'http://localhost:3000',
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.byType(DraggableScrollableSheet), findsOneWidget);
      expect(find.text('Explore this park'), findsOneWidget);
      expect(find.text('5 places available'), findsOneWidget);

      // Open the optional filter bottom sheet.
      await tester.tap(find.byIcon(Icons.tune_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Filter Park Map'), findsOneWidget);
      expect(find.text('Short wait time (15 min or less)'), findsOneWidget);
      expect(find.text('Kiosk ride slot booking'), findsOneWidget);

      // Scroll toggle into view and enable Kiosk ride slot booking -> only Recoil matches (1 place).
      await tester.ensureVisible(find.text('Kiosk ride slot booking'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kiosk ride slot booking'));
      await tester.pumpAndSettle();
      expect(find.text('Show 1 place'), findsOneWidget);

      await tester.tap(find.text('Show 1 place'));
      await tester.pumpAndSettle();
      expect(find.text('1 place available'), findsOneWidget);
    },
  );

  testWidgets(
    'VisitorSectionScreen Rides discovery filters rides and preserves kiosk booking flow',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: VisitorSectionScreen(
            title: 'RIDES & WATER ACTIVITIES',
            config: _sampleParkConfig(),
            api: CmsApi(baseUrl: 'http://localhost:3000'),
            initialTab: 'Rides',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('RECOIL'), findsOneWidget);
      expect(find.text('35 min wait'), findsOneWidget);
      expect(find.text('Book a ride slot at park kiosks'), findsOneWidget);

      // Filter by Kids Rides -> hides Recoil, keeps Kiddies Wheel.
      await tester.tap(find.text('Kids Rides'));
      await tester.pumpAndSettle();
      expect(find.text('KIDDIES WHEEL'), findsOneWidget);
      expect(find.text('RECOIL'), findsNothing);

      // Clear all restores Recoil with booking callout intact.
      await tester.tap(find.text('Clear all'));
      await tester.pumpAndSettle();
      expect(find.text('RECOIL'), findsOneWidget);
      expect(find.text('Book a ride slot at park kiosks'), findsOneWidget);
    },
  );
}
