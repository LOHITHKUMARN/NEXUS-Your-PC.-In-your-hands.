import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pc_control_center/core/models/telemetry_model.dart';
import 'package:pc_control_center/core/providers/telemetry_provider.dart';
import 'package:pc_control_center/features/media/presentation/media_screen.dart';

void main() {
  group('MediaScreen Universal Controls Tests', () {
    UnifiedTelemetryFrameModel createMockFrame({required bool hasMedia, String title = '', bool isPlaying = false}) {
      return UnifiedTelemetryFrameModel.fromJson(<String, dynamic>{
        'timestamp_ms': 1000,
        'pc_name': 'DESKTOP-QNHI8OS',
        'audio': <String, dynamic>{
          'master_volume': 60,
          'is_muted': false,
          'devices': <dynamic>[],
        },
        'media': <String, dynamic>{
          'has_media': hasMedia,
          'title': title,
          'artist': hasMedia ? 'Artist Name' : '',
          'is_playing': isPlaying,
          'duration_ms': 180000,
          'position_ms': 45000,
        },
        'display': <String, dynamic>{'brightness': 75, 'display_count': 1},
        'system': <String, dynamic>{},
      });
    }

    Widget createTestableWidget({required bool hasMedia, String title = '', bool isPlaying = false}) {
      return ProviderScope(
        overrides: [
          telemetryStreamProvider.overrideWith(
            (ref) => Stream.value(createMockFrame(hasMedia: hasMedia, title: title, isPlaying: isPlaying)),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: MediaScreen(),
          ),
        ),
      );
    }

    testWidgets('Standby state renders universal controls, chips, and volume instead of a dead screen',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestableWidget(hasMedia: false));
      await tester.pumpAndSettle();

      // Standby headers
      expect(find.text('Media Standby'), findsOneWidget);
      expect(find.textContaining('Tap Play to resume PC media'), findsOneWidget);

      // Universal transport buttons are present and clickable
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(find.byIcon(Icons.skip_previous_rounded), findsOneWidget);
      expect(find.byIcon(Icons.skip_next_rounded), findsOneWidget);

      // Quick launcher chips
      expect(find.text('Spotify'), findsOneWidget);
      expect(find.text('YouTube'), findsOneWidget);

      // Volume slider is available
      expect(find.text('Master Volume'), findsOneWidget);
    });

    testWidgets('Active playback state displays track metadata and pause button', (WidgetTester tester) async {
      await tester.pumpWidget(createTestableWidget(hasMedia: true, title: 'Blinding Lights', isPlaying: true));
      await tester.pumpAndSettle();

      // Track info
      expect(find.text('Blinding Lights'), findsOneWidget);
      expect(find.text('Artist Name'), findsOneWidget);

      // Pause button shown when playing
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    });
  });
}
