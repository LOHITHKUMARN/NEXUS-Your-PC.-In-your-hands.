import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pc_control_center/core/providers/settings_provider.dart';
import 'package:pc_control_center/core/theme/app_theme.dart';
import 'package:pc_control_center/features/settings/presentation/settings_screen.dart';
import 'package:pc_control_center/shared/widgets/pc_action_button.dart';

void main() {
  group('SettingsScreen Semantic Color Audit Tests', () {
    testWidgets('Renders all cards with PcActionButton and no decorative neon buttons', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsProvider.overrideWith((ref) => SettingsNotifier()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SettingsScreen(),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      // Assert PcActionButtons exist for all primary and secondary actions
      expect(find.widgetWithText(PcActionButton, 'Test Connection'), findsOneWidget);
      expect(find.widgetWithText(PcActionButton, 'Save Settings'), findsOneWidget);
      expect(find.widgetWithText(PcActionButton, 'Run "Test My Setup" Diagnostics'), findsOneWidget);
      expect(find.widgetWithText(PcActionButton, 'Wake PC (Send Magic Packet)'), findsOneWidget);
      expect(find.widgetWithText(PcActionButton, 'View PC Activity Log'), findsOneWidget);

      // Verify that Save Settings does NOT use cyan background
      final saveBtn = tester.widget<ButtonStyleButton>(
        find.descendant(
          of: find.widgetWithText(PcActionButton, 'Save Settings'),
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
        ),
      );
      final bg = saveBtn.style?.backgroundColor?.resolve({});
      expect(bg, isNot(AppColors.cyan));
      expect(bg, const Color(0xFFE2E8F0));

      // Verify consolidated Auto-Scan and Fast-Pair QR buttons
      expect(find.text('Auto-Scan PC'), findsOneWidget);
      expect(find.text('Fast-Pair QR'), findsOneWidget);

      // Verify theme customization preserves preview accents
      expect(find.text('Cyber Dark (Default)'), findsOneWidget);
      expect(find.text('Midnight AMOLED Black'), findsOneWidget);
      expect(find.text('Midnight Blue Glass'), findsOneWidget);
    });
  });
}
