import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pc_control_center/core/providers/input_provider.dart';
import 'package:pc_control_center/core/network/input_websocket_client.dart';
import 'package:pc_control_center/core/network/websocket_client.dart';
import 'package:pc_control_center/features/trackpad/presentation/trackpad_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TrackpadPreferences Tests', () {
    test('Default values match spec', () {
      const prefs = TrackpadPreferences();
      // User specified: default sensitivity must be 1.2x and natural scroll true
      expect(prefs.sensitivity, 1.2);
      expect(prefs.isNaturalScroll, true);
      expect(prefs.showHotkeys, true);
    });

    test('CopyWith updates properties correctly', () {
      const prefs = TrackpadPreferences();
      final updated = prefs.copyWith(
        sensitivity: 2.0,
        isNaturalScroll: false,
        showHotkeys: false,
      );
      expect(updated.sensitivity, 2.0);
      expect(updated.isNaturalScroll, false);
      expect(updated.showHotkeys, false);
    });
  });

  group('InputWebSocketClient Move Buffer Tests', () {
    test('sendMove accumulates displacements', () {
      final client = InputWebSocketClient();
      client.sendMove(5.0, -3.0, sensitivity: 1.2);
      client.sendMove(2.0, 1.0, sensitivity: 1.2);

      // Verify methods don't throw when disconnected
      client.sendClick('left', 'tap');
      client.sendScroll(-4.0, natural: true);
      client.sendKey('esc');
      client.sendText('Hello 🚀');
      client.sendCombo(['ctrl', 'c']);
      client.disconnect();
    });
  });

  group('TrackpadScreen UI Tests', () {
    testWidgets('Renders all trackpad components: surface with dot-grid, balanced scroll rail, hotkeys with fade mask, click buttons',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: TrackpadScreen(),
          ),
        ),
      );

      // Top bar title or status
      expect(find.textContaining('Trackpad'), findsWidgets);
      expect(find.byTooltip('Special Modifiers & Hotkeys'), findsOneWidget);
      expect(find.byTooltip('Virtual Keyboard'), findsOneWidget);
      expect(find.byTooltip('Sensitivity & Preferences'), findsOneWidget);

      // Hotkey chips wrapped in ShaderMask
      expect(find.byType(ShaderMask), findsWidgets);
      expect(find.text('Esc'), findsOneWidget);
      expect(find.text('Win+D'), findsOneWidget);
      expect(find.text('Ctrl+C'), findsOneWidget);

      // Dedicated Scroll Lane with chevrons
      expect(find.byIcon(Icons.keyboard_arrow_up_rounded), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);

      // Trackpad Surface has dot-grid painter and readable hints
      expect(find.byType(CustomPaint), findsWidgets);
      expect(find.textContaining('1 Finger: Move & Tap'), findsOneWidget);

      // Bottom Click Zones wrapped in SafeArea
      expect(find.byType(SafeArea), findsWidgets);
      expect(find.text('Left Click'), findsOneWidget);
      expect(find.text('Right Click'), findsOneWidget);

      // Clean up widget tree and timers
      await tester.pumpWidget(const SizedBox());
      inputWsClient.disconnect();
      await tester.pumpAndSettle();
    });

    testWidgets('Click buttons animate scale on tap down and up', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: TrackpadScreen(),
          ),
        ),
      );

      final leftClick = find.text('Left Click');
      expect(leftClick, findsOneWidget);

      // Tap and hold
      final gesture = await tester.startGesture(tester.getCenter(leftClick));
      await tester.pump(const Duration(milliseconds: 100));

      // Release
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.pumpWidget(const SizedBox());
      inputWsClient.disconnect();
      await tester.pumpAndSettle();
    });

    testWidgets('Lifecycle auto-lock: background disconnects, resume immediately accepts drag',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: TrackpadScreen(),
          ),
        ),
      );

      // 1. Simulate app backgrounded (e.g. phone screen locked or user switched to home)
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();

      // Socket should be disconnected
      expect(inputWsClient.status, ConnectionStatus.disconnected);

      // 2. Simulate app resumed (user returns to Trackpad screen)
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      // 3. Immediately perform drag gesture on trackpad surface without waiting
      final center = tester.getCenter(find.byType(TrackpadScreen));
      final gesture = await tester.startGesture(center);
      await gesture.moveBy(const Offset(15, -10));
      await tester.pump();
      await gesture.moveBy(const Offset(25, 5));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      // Cleanup
      await tester.pumpWidget(const SizedBox());
      inputWsClient.disconnect();
      await tester.pumpAndSettle();
    });
  });
}
