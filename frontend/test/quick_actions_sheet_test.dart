import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pc_control_center/core/models/telemetry_model.dart';
import 'package:pc_control_center/core/providers/telemetry_provider.dart';
import 'package:pc_control_center/shared/widgets/confirmation_dialog.dart';
import 'package:pc_control_center/shared/widgets/quick_actions_sheet.dart';

void main() {
  group('QuickActionsSheet UI & Hierarchy Tests', () {
    UnifiedTelemetryFrameModel createMockFrame({bool isMuted = false, int volume = 40}) {
      return UnifiedTelemetryFrameModel.fromJson(<String, dynamic>{
        'timestamp_ms': 1000,
        'pc_name': 'DESKTOP-QNHI8OS',
        'audio': <String, dynamic>{
          'master_volume': volume,
          'is_muted': isMuted,
          'devices': <dynamic>[],
        },
        'media': <String, dynamic>{
          'has_media': true,
          'title': 'Test Song',
          'artist': 'Test Artist',
          'is_playing': false,
        },
        'display': <String, dynamic>{
          'brightness': 75,
          'display_count': 1,
        },
        'system': <String, dynamic>{},
      });
    }

    Widget createTestableWidget({bool isMuted = false, int volume = 40}) {
      return ProviderScope(
        overrides: [
          telemetryStreamProvider.overrideWith((ref) => Stream.value(createMockFrame(isMuted: isMuted, volume: volume))),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: QuickActionsSheet(),
          ),
        ),
      );
    }

    testWidgets('Renders hero Trackpad card and explicit category headers', (WidgetTester tester) async {
      await tester.pumpWidget(createTestableWidget());
      await tester.pumpAndSettle();

      // Top header
      expect(find.text('Quick Controls'), findsOneWidget);

      // Hero action
      expect(find.text('Remote Trackpad & Keyboard'), findsOneWidget);
      expect(find.text('Precision cursor, gestures & keyboard input'), findsOneWidget);

      // Categorized section headers
      expect(find.text('VOLUME & AUDIO'), findsOneWidget);
      expect(find.text('MEDIA PLAYBACK'), findsOneWidget);
      expect(find.text('DISPLAY & SYSTEM POWER'), findsOneWidget);
    });

    testWidgets('Mute button shows dynamic Mute / Unmute and no broken "Mute (0%)"', (WidgetTester tester) async {
      final controller = StreamController<UnifiedTelemetryFrameModel>.broadcast();
      addTearDown(controller.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            telemetryStreamProvider.overrideWith((ref) => controller.stream),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: QuickActionsSheet(),
            ),
          ),
        ),
      );

      // 1. Emit unmuted state
      controller.add(createMockFrame(isMuted: false, volume: 40));
      await tester.pumpAndSettle();

      expect(find.text('Mute'), findsOneWidget);
      expect(find.text('(40%)'), findsOneWidget);
      expect(find.text('Mute (0%)'), findsNothing);

      // 2. Emit muted state
      controller.add(createMockFrame(isMuted: true, volume: 40));
      await tester.pumpAndSettle();

      expect(find.text('Unmute'), findsOneWidget);
      expect(find.text('(Muted)'), findsOneWidget);
    });

    testWidgets('Tapping Lock PC triggers SafetyActionDialog confirmation', (WidgetTester tester) async {
      await tester.pumpWidget(createTestableWidget());
      await tester.pumpAndSettle();

      // Tap Lock PC
      await tester.tap(find.text('Lock PC'));
      await tester.pumpAndSettle();

      // Verify SafetyActionDialog is shown
      expect(find.byType(SafetyActionDialog), findsOneWidget);
      expect(find.text('Lock Host PC?'), findsOneWidget);
      expect(find.text('Your PC session will be locked immediately. You will need to enter your PIN or password on the PC to resume.'), findsOneWidget);
    });
  });
}
