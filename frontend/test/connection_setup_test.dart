import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pc_control_center/core/layout/adaptive_scaffold.dart';
import 'package:pc_control_center/core/network/websocket_client.dart';
import 'package:pc_control_center/core/providers/settings_provider.dart';
import 'package:pc_control_center/core/providers/telemetry_provider.dart';
import 'package:pc_control_center/features/dashboard/presentation/waiting_connection_view.dart';

void main() {
  const testDestinations = [
    AdaptiveDestination(
      label: 'Dashboard',
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard_rounded,
    ),
    AdaptiveDestination(
      label: 'Controls',
      icon: Icons.tune_outlined,
      selectedIcon: Icons.tune_rounded,
    ),
  ];

  const testScreens = [
    Scaffold(body: Center(child: Text('Dashboard Body'))),
    Scaffold(body: Center(child: Text('Controls Body'))),
  ];

  group('AdaptiveScaffold FAB Collision & Suppression Tests', () {
    testWidgets('FAB is suppressed when connection is disconnected', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            connectionStatusProvider.overrideWith((ref) => Stream.value(ConnectionStatus.disconnected)),
          ],
          child: MaterialApp(
            home: AdaptiveScaffold(
              selectedIndex: 0,
              onDestinationSelected: (_) {},
              destinations: testDestinations,
              screens: testScreens,
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      // Assert FAB is NOT present in tree
      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('FAB is suppressed when connection is connecting', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            connectionStatusProvider.overrideWith((ref) => Stream.value(ConnectionStatus.connecting)),
          ],
          child: MaterialApp(
            home: AdaptiveScaffold(
              selectedIndex: 0,
              onDestinationSelected: (_) {},
              destinations: testDestinations,
              screens: testScreens,
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      // Assert FAB is NOT present in tree
      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('FAB only renders when connection is connected', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            connectionStatusProvider.overrideWith((ref) => Stream.value(ConnectionStatus.connected)),
          ],
          child: MaterialApp(
            home: AdaptiveScaffold(
              selectedIndex: 0,
              onDestinationSelected: (_) {},
              destinations: testDestinations,
              screens: testScreens,
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      // Assert FAB is rendered
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });
  });

  group('WaitingConnectionView 4-State Tests', () {
    testWidgets('Renders Idle / Ready to Connect state with Quick Targets and Auto-Scan', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsProvider.overrideWith((ref) => SettingsNotifier()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: WaitingConnectionView(),
            ),
          ),
        ),
      );

      await tester.pump();

      // Header status card
      expect(find.text('Ready to Connect'), findsOneWidget);

      // Primary Auto-Scan button
      expect(find.text('Auto-Scan for PC'), findsOneWidget);

      // Quick Targets
      expect(find.text('192.168.29.249 (Wi-Fi)'), findsOneWidget);
      expect(find.text('10.0.2.2 (Emulator)'), findsOneWidget);
      expect(find.text('127.0.0.1 (Local)'), findsOneWidget);

      // Form action buttons
      expect(find.text('Test Connection'), findsOneWidget);
      expect(find.text('Save & Connect'), findsOneWidget);
    });

    testWidgets('Quick target tap autofills PC host address field', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsProvider.overrideWith((ref) => SettingsNotifier()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: WaitingConnectionView(),
            ),
          ),
        ),
      );

      await tester.pump();

      // Tap Emulator chip
      await tester.tap(find.text('10.0.2.2 (Emulator)'));
      await tester.pump();

      // Verify text field contains 10.0.2.2
      final textField = tester.widget<TextField>(find.widgetWithText(TextField, '10.0.2.2'));
      expect(textField.controller?.text, '10.0.2.2');
    });

    testWidgets('Clearance test: Scroll view bottom padding protects buttons from edge obstruction', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsProvider.overrideWith((ref) => SettingsNotifier()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: WaitingConnectionView(),
            ),
          ),
        ),
      );

      await tester.pump();

      // Check vertical SingleChildScrollView has 80 bottom padding
      final verticalFinder = find.byWidgetPredicate(
        (w) => w is SingleChildScrollView && w.scrollDirection == Axis.vertical,
      );
      expect(verticalFinder, findsOneWidget);

      final scrollView = tester.widget<SingleChildScrollView>(verticalFinder);
      final padding = scrollView.padding as EdgeInsets;
      expect(padding.bottom, greaterThanOrEqualTo(80));
    });
  });
}
