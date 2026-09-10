import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pc_control_center/shared/widgets/pc_action_button.dart';

void main() {
  group('PcActionButton Widget Tests', () {
    testWidgets('Solid High-Contrast CTA renders with correct text and enabled state', (WidgetTester tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PcActionButton(
              label: 'Save Settings',
              icon: Icons.save_rounded,
              onPressed: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Save Settings'), findsOneWidget);
      expect(find.byIcon(Icons.save_rounded), findsOneWidget);

      await tester.tap(find.byType(PcActionButton));
      expect(tapped, isTrue);

      final button = tester.widget<ButtonStyleButton>(
        find.byWidgetPredicate((w) => w is ButtonStyleButton),
      );
      expect(button.onPressed, isNotNull);
      final bg = button.style?.backgroundColor?.resolve({});
      expect(bg, const Color(0xFFE2E8F0));
    });

    testWidgets('Outlined CTA renders with tactile dark styling', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PcActionButton(
              label: 'Test Connection',
              icon: Icons.network_check_rounded,
              isOutlined: true,
              onPressed: () {},
            ),
          ),
        ),
      );

      expect(find.text('Test Connection'), findsOneWidget);
      final button = tester.widget<ButtonStyleButton>(
        find.byWidgetPredicate((w) => w is ButtonStyleButton),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('Disabled CTA gracefully dims and ignores taps', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PcActionButton(
              label: 'Offline Action',
              onPressed: null,
            ),
          ),
        ),
      );

      final button = tester.widget<ButtonStyleButton>(
        find.byWidgetPredicate((w) => w is ButtonStyleButton),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('Loading CTA shows progress spinner and suppresses clicks', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PcActionButton(
              label: 'Processing',
              isLoading: true,
              onPressed: () {},
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final button = tester.widget<ButtonStyleButton>(
        find.byWidgetPredicate((w) => w is ButtonStyleButton),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('isFullWidth expands to fill parent width', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                child: PcActionButton(
                  label: 'Full Width Action',
                  isFullWidth: true,
                  onPressed: () {},
                ),
              ),
            ),
          ),
        ),
      );

      final size = tester.getSize(find.byType(PcActionButton));
      expect(size.width, 320);
    });
  });
}
