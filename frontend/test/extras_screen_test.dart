import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pc_control_center/core/network/websocket_client.dart';
import 'package:pc_control_center/core/providers/telemetry_provider.dart';
import 'package:pc_control_center/core/theme/app_theme.dart';
import 'package:pc_control_center/features/extras/presentation/extras_screen.dart';

void main() {
  Finder findButtonWithText(String text) {
    return find.ancestor(
      of: find.text(text),
      matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
    );
  }

  group('ExtrasScreen Connection-Gating & Unified Button Tests', () {
    testWidgets('Offline state: displays warning banner and disables all action buttons', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            connectionStatusProvider.overrideWith((ref) => Stream.value(ConnectionStatus.disconnected)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ExtrasScreen(),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      // Assert offline banner exists
      expect(find.text('PC is offline. Reconnect to execute sync actions.'), findsOneWidget);

      // Verify all 3 primary buttons exist and are disabled
      final clipboardBtn = tester.widget<ButtonStyleButton>(findButtonWithText('Send to Clipboard'));
      final urlBtn = tester.widget<ButtonStyleButton>(findButtonWithText('Open on PC Browser'));
      final toastBtn = tester.widget<ButtonStyleButton>(findButtonWithText('Show Toast Alert'));

      expect(clipboardBtn.onPressed, isNull);
      expect(urlBtn.onPressed, isNull);
      expect(toastBtn.onPressed, isNull);

      // Verify buttons do NOT use cyan, violet, or emerald background colors
      final clipboardStyle = clipboardBtn.style;
      final btnBg = clipboardStyle?.backgroundColor?.resolve({});
      expect(btnBg, isNot(AppColors.cyan));
      expect(btnBg, isNot(AppColors.violet));
      expect(btnBg, isNot(AppColors.emerald));
    });

    testWidgets('Connected state: enables all action buttons and hides offline warning', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            connectionStatusProvider.overrideWith((ref) => Stream.value(ConnectionStatus.connected)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ExtrasScreen(),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      // Assert offline banner is absent
      expect(find.text('PC is offline. Reconnect to execute sync actions.'), findsNothing);

      // Verify all 3 primary buttons are enabled
      final clipboardBtn = tester.widget<ButtonStyleButton>(findButtonWithText('Send to Clipboard'));
      final urlBtn = tester.widget<ButtonStyleButton>(findButtonWithText('Open on PC Browser'));
      final toastBtn = tester.widget<ButtonStyleButton>(findButtonWithText('Show Toast Alert'));

      expect(clipboardBtn.onPressed, isNotNull);
      expect(urlBtn.onPressed, isNotNull);
      expect(toastBtn.onPressed, isNotNull);

      // Verify active styling has high-contrast neutral fill (#E2E8F0)
      final activeBg = clipboardBtn.style?.backgroundColor?.resolve({});
      expect(activeBg, const Color(0xFFE2E8F0));
    });
  });
}
