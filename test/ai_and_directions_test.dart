import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:maps_wonderla_flutter/features/ai_assistant/wonderla_ai_service.dart';
import 'package:maps_wonderla_flutter/features/ai_assistant/wonderla_ai_sheet.dart';
import 'package:maps_wonderla_flutter/features/cms/cms_api.dart';
import 'package:maps_wonderla_flutter/features/home/configured_park_map_screen.dart';
import 'package:maps_wonderla_flutter/features/home/visitor_home.dart';
import 'package:maps_wonderla_flutter/features/park_map/models/park_discovery_item.dart';
import 'package:maps_wonderla_flutter/shared/wonderla_palette.dart';

Map<String, dynamic> _parkWithCmsDirections() => {
  'slug': 'bengaluru',
  'name': 'Wonderla Bengaluru',
  'location': 'Bengaluru, Karnataka',
  'active': true,
  'rides': [
    {
      'title': 'Kiddies Wheel',
      'description': 'A miniature giant wheel for children.',
      'tags': ['Kids', 'Gentle Thrill'],
      'minHeight': '85 cm',
    },
    {
      'title': 'Recoil',
      'description': 'Reverse looping coaster',
      'tags': ['High Thrill'],
      'minHeight': '140 cm',
    },
  ],
  'liveWaitTimes': [
    {'title': 'Kiddies Wheel', 'time': 5, 'description': 'Quick line'},
    {'title': 'Recoil', 'time': 35, 'description': 'Busy coaster'},
  ],
  'waveRainDance': [
    {
      'title': 'Wave Pool',
      'timeSlot': ['12:00 PM', '02:00 PM'],
      'rideDuration': 20,
    },
  ],
  'events': [
    {
      'title': 'Character Parade',
      'time': '04:00 PM',
      'description': 'Live parade at Central Plaza',
    },
  ],
  'dining': [
    {
      'img': '',
      'name': 'Greens Restaurant',
      'cuisine': 'Pure Vegetarian',
      'description': 'Wholesome veg meals and biryanis.',
      'directions': 'Walk straight past Dome Plaza and turn left beside Wave Pool.',
      'directionsUrl': 'https://maps.google.com/?q=12.8331,77.4005',
      'tags': ['Vegetarian'],
      'items': [
        {'name': 'Veg Biryani', 'price': '₹240', 'veg': true, 'img': ''},
      ],
    },
  ],
  'parkMap': {
    'centerLat': 12.8343,
    'centerLng': 77.401,
    'img': '/wonderla/parks/bengaluru-layout.jpg',
    'description': 'Interactive park map',
    'zones': const <Map<String, dynamic>>[],
    'places': [
      {
        'name': 'Recoil',
        'category': 'Ride',
        'x': 77,
        'y': 30,
        'lat': 12.832685,
        'lng': 77.401272,
      },
    ],
  },
};

void main() {
  test('Parses GPS coordinates automatically from CMS Google Maps directionsUrl', () {
    final pos1 = ParkDiscoveryCatalog.parseCoordinatesFromDirectionsUrl(
      'https://maps.google.com/?q=12.8331,77.4005',
    );
    expect(pos1, isNotNull);
    expect(pos1!.latitude, closeTo(12.8331, 0.0001));
    expect(pos1.longitude, closeTo(77.4005, 0.0001));

    final pos2 = ParkDiscoveryCatalog.parseCoordinatesFromDirectionsUrl(
      'https://www.google.com/maps/@12.8343,77.4010,17z',
    );
    expect(pos2, isNotNull);
    expect(pos2!.latitude, closeTo(12.8343, 0.0001));
  });

  testWidgets(
    'Clicking Map on a restaurant opens park map directly showing CMS directions without Live GPS / Park Guide buttons',
    (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final config = _parkWithCmsDirections();
      await tester.pumpWidget(
        MaterialApp(
          theme: buildWonderlaTheme(),
          home: VisitorSectionScreen(
            title: 'DINING & MENU',
            config: config,
            api: CmsApi(baseUrl: 'http://localhost:3000'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Greens Restaurant'), findsOneWidget);
      await tester.tap(find.text('Map'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(ConfiguredParkMapScreen), findsOneWidget);
      expect(find.text('Live GPS'), findsNothing);
      expect(find.text('Park Guide'), findsNothing);
      expect(find.text('DIRECTIONS TO'), findsOneWidget);
      expect(find.text('Greens Restaurant'), findsWidgets);
      expect(
        find.text(
          'Walk straight past Dome Plaza and turn left beside Wave Pool.',
        ),
        findsOneWidget,
      );
      expect(find.text('Open in Google Maps'), findsOneWidget);
    },
  );

  testWidgets(
    'Ask Chiku FAB and Chat UI stream tool status and incremental response chunks cleanly',
    (tester) async {
      tester.view.physicalSize = const Size(430, 860);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final controller = StreamController<AiStreamEvent>();
      addTearDown(() async {
        if (!controller.isClosed) {
          await controller.close();
        }
      });
      AiSuggestedPlace? tappedPlace;

      final service = WonderlaAiService(
        baseUrl: 'http://localhost:3000',
        streamOverride: ({
          required parkSlug,
          required message,
          required history,
          required parkConfig,
        }) => controller.stream,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: buildWonderlaTheme(),
          home: Scaffold(
            floatingActionButton: Builder(
              builder: (ctx) => WonderlaAiFab(
                onTap: () => showWonderlaAiAssistantSheet(
                  ctx,
                  parkConfig: _parkWithCmsDirections(),
                  baseUrl: 'http://localhost:3000',
                  aiService: service,
                  onOpenPlaceOnMap: (place) => tappedPlace = place,
                ),
              ),
            ),
            body: const SizedBox.shrink(),
          ),
        ),
      );

      // Launch Ask Chiku sheet from Mascot FAB (no "Ask AI" or "Plan & Maps")
      expect(find.text('Ask Chiku'), findsOneWidget);
      expect(find.text('Ask AI'), findsNothing);
      expect(find.text('Plan & Maps'), findsNothing);

      await tester.tap(find.text('Ask Chiku'));
      await tester.pumpAndSettle();

      // Sheet header also says Ask Chiku
      expect(find.text('Ask Chiku'), findsWidgets);
      expect(find.text('Ask Wonderla AI'), findsNothing);

      await tester.tap(
        find.text(
          'Which rides can I do with my 110 cm kid, and plan my next 3 hours?',
        ),
      );
      await tester.pump();

      // Emit live Genkit tool status event first
      controller.add(
        const AiToolStatusEvent(
          tool: 'getParkRidesAndStatus',
          label: 'Checking rides safe for 110 cm & operating status…',
        ),
      );
      await tester.pump();
      expect(
        find.text('Checking rides safe for 110 cm & operating status…'),
        findsOneWidget,
      );

      // Stream first chunk BEFORE stream completes -> must display immediately
      controller.add(
        const AiTextChunkEvent(
          "Let's plan your next 3 hours at Wonderla! ",
        ),
      );
      await tester.pump();
      expect(
        find.textContaining("Let's plan your next 3 hours at Wonderla!"),
        findsOneWidget,
      );

      // Stream second chunk + place chip + completion
      controller.add(
        const AiTextChunkEvent('Start with Kiddies Wheel (5 min wait).'),
      );
      controller.add(
        const AiPlacesEvent([
          AiSuggestedPlace(
            name: 'Greens Restaurant',
            category: 'Dining',
            directions: 'Next to Wave Pool',
            action: 'directions',
          ),
        ]),
      );
      controller.add(const AiDoneEvent(mode: 'genkit'));
      await controller.close();
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Start with Kiddies Wheel (5 min wait).'),
        findsOneWidget,
      );
      expect(find.text('Directions · Greens Restaurant'), findsOneWidget);

      await tester.tap(find.text('Directions · Greens Restaurant'));
      await tester.pumpAndSettle();
      expect(tappedPlace?.name, 'Greens Restaurant');
      expect(tappedPlace?.prefersDirections, isTrue);
    },
  );

  test('describeParkConfigChanges detects CMS updates across park sections', () {
    final before = _parkWithCmsDirections();
    final after = Map<String, dynamic>.from(before)
      ..['liveWaitTimes'] = [
        {'title': 'Kiddies Wheel', 'time': 10, 'description': 'Quick line'},
      ]
      ..['dining'] = [
        {
          'name': 'Greens Restaurant',
          'cuisine': 'South Indian',
          'directions': 'New entrance beside Wave Pool deck.',
          'items': const [],
        },
      ];

    final changes = describeParkConfigChanges(before, after);
    expect(changes, containsAll(['Wait times', 'Dining & directions']));
    expect(describeParkConfigChanges(before, before), isEmpty);
  });
}
