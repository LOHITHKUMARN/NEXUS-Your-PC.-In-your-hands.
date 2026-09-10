import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pc_control_center/core/layout/form_factor.dart';
import 'package:pc_control_center/core/theme/app_theme.dart';
import 'package:pc_control_center/shared/widgets/resource_gauge.dart';

void main() {
  group('FormFactor Breakpoint Tests', () {
    test('formFactorOf correctly resolves compact, medium, and expanded', () {
      expect(formFactorOf(360), FormFactor.compact);
      expect(formFactorOf(430), FormFactor.compact);
      expect(formFactorOf(599), FormFactor.compact);
      expect(formFactorOf(600), FormFactor.medium);
      expect(formFactorOf(839), FormFactor.medium);
      expect(formFactorOf(840), FormFactor.expanded);
      expect(formFactorOf(1024), FormFactor.expanded);
      expect(formFactorOf(1440), FormFactor.expanded);
    });

    test('FormFactor helper booleans work as expected', () {
      expect(FormFactor.compact.isCompact, true);
      expect(FormFactor.compact.isHandheld, true);
      expect(FormFactor.medium.isMedium, true);
      expect(FormFactor.medium.isHandheld, true);
      expect(FormFactor.expanded.isExpanded, true);
      expect(FormFactor.expanded.isHandheld, false);
    });
  });

  group('ResourceGauge Tests', () {
    testWidgets('ResourceGauge compact mode renders correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ResourceGauge(
              label: 'CPU',
              value: 45.0,
              icon: Icons.memory,
              variant: GaugeVariant.compact,
            ),
          ),
        ),
      );

      expect(find.text('CPU'), findsOneWidget);
      expect(find.text('45%'), findsOneWidget);
    });

    testWidgets('ResourceGauge full dial mode renders correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ResourceGauge(
              label: 'RAM',
              value: 70.0,
              icon: Icons.developer_board,
              variant: GaugeVariant.full,
            ),
          ),
        ),
      );

      expect(find.text('RAM'), findsOneWidget);
      expect(find.text('70%'), findsOneWidget);
    });
  });

  group('AppTheme Tests', () {
    test('AppTheme generates dark themes with proper color schemes', () {
      final theme = AppTheme.getTheme(AppThemeMode.cyberDark);
      expect(theme.brightness, Brightness.dark);
      expect(theme.colorScheme.primary, AppColors.cyan);

      final amoledTheme = AppTheme.getTheme(AppThemeMode.amoledBlack);
      expect(amoledTheme.scaffoldBackgroundColor, AppColors.amoledBackground);
    });
  });
}
