import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pc_control_center/features/settings/presentation/diagnostics_screen.dart';

void main() {
  group('DiagnosticsScreen Tests', () {
    testWidgets('Renders all 4 diagnostic stages and run button', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: DiagnosticsScreen(),
          ),
        ),
      );

      // Title & Header
      expect(find.text('Connection Diagnostics'), findsOneWidget);
      expect(find.text('Self-Diagnostic Engine'), findsOneWidget);
      expect(find.text('Run "Test My Setup"'), findsOneWidget);

      // 4 Stages
      expect(find.text('1. LAN Reachability & Discovery'), findsOneWidget);
      expect(find.text('2. API Key Authentication'), findsOneWidget);
      expect(find.text('3. Telemetry Stream (500ms)'), findsOneWidget);
      expect(find.text('4. Input Control Stream (Sub-20ms)'), findsOneWidget);

      // Initial PENDING badges
      expect(find.text('PENDING'), findsNWidgets(4));

      // Cleanup
      await tester.pumpWidget(const SizedBox());
    });
  });
}
