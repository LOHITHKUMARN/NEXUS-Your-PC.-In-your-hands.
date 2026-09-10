import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pc_control_center/core/models/telemetry_model.dart';
import 'package:pc_control_center/core/theme/app_theme.dart';
import 'package:pc_control_center/features/apps/presentation/apps_screen.dart';
import 'package:pc_control_center/shared/widgets/pc_action_button.dart';
import 'package:pc_control_center/shared/widgets/pc_icon_badge.dart';

void main() {
  group('AppsScreen Layout Clearance & Semantic Outlier Tests', () {
    final mockApps = [
      AppItemModel(
        id: 'chrome',
        name: 'Google Chrome',
        command: 'chrome.exe',
        icon: 'chrome',
        description: 'Web Browser',
        isRunning: true,
      ),
      AppItemModel(
        id: 'vscode',
        name: 'Visual Studio Code IDE With Long Extension Name',
        command: 'code.exe',
        icon: 'code',
        description: 'Code Editor',
        isRunning: false,
      ),
    ];

    final mockTasks = [
      RunningTaskModel(
        pid: 44672,
        name: 'java.exe',
        cpuPercent: 2.5,
        memoryMb: 774.0, // Heavy outlier >= 500 MB
      ),
      RunningTaskModel(
        pid: 1234,
        name: 'MsMpEng.exe',
        cpuPercent: 0.8,
        memoryMb: 120.0, // Baseline normal < 500 MB
      ),
    ];

    Widget createTestableWidget() {
      return ProviderScope(
        overrides: [
          appsListFutureProvider.overrideWith((ref) => Future.value(mockApps)),
          tasksListFutureProvider.overrideWith((ref) => Future.value(mockTasks)),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: AppsScreen(),
          ),
        ),
      );
    }

    testWidgets('ListView has 88dp bottom clearance to prevent FAB overlap', (WidgetTester tester) async {
      await tester.pumpWidget(createTestableWidget());
      await tester.pumpAndSettle();

      final listView = tester.widget<ListView>(find.byType(ListView));
      final padding = listView.padding as EdgeInsets;
      expect(padding.bottom, 88.0);
    });

    testWidgets('Quick Launchers grid renders PcIconBadge and semantic active status', (WidgetTester tester) async {
      await tester.pumpWidget(createTestableWidget());
      await tester.pumpAndSettle();

      expect(find.byType(PcIconBadge), findsWidgets);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Tap to Launch'), findsOneWidget);
    });

    testWidgets('Active PC Tasks list applies neutral baseline and amber outlier styling', (WidgetTester tester) async {
      await tester.pumpWidget(createTestableWidget());
      await tester.pumpAndSettle();

      // Switch to Active PC Tasks sub-tab
      await tester.tap(find.text('Active PC Tasks'));
      await tester.pumpAndSettle();

      // Verify both tasks rendered
      expect(find.text('java.exe'), findsOneWidget);
      expect(find.text('MsMpEng.exe'), findsOneWidget);

      // Baseline normal row (120 MB) uses neutral circle_outlined
      expect(find.byIcon(Icons.circle_outlined), findsOneWidget);
      // Heavy outlier row (774 MB) uses filled amber circle
      expect(find.byIcon(Icons.circle), findsOneWidget);

      final outlierIcon = tester.widget<Icon>(find.byIcon(Icons.circle));
      expect(outlierIcon.color, AppColors.warningAmber);
    });

    testWidgets('Tapping task opens End Process confirmation dialog with PID and memory footprint', (WidgetTester tester) async {
      await tester.pumpWidget(createTestableWidget());
      await tester.pumpAndSettle();

      // Switch to Active PC Tasks
      await tester.tap(find.text('Active PC Tasks'));
      await tester.pumpAndSettle();

      // Tap on java.exe row
      await tester.tap(find.text('java.exe'));
      await tester.pumpAndSettle();

      // Verify dialog appears
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('End Process?'), findsOneWidget);
      expect(
        find.descendant(of: find.byType(AlertDialog), matching: find.text('PID: 44672')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: find.byType(AlertDialog), matching: find.text('Memory Footprint: 774 MB')),
        findsOneWidget,
      );
      expect(find.widgetWithText(PcActionButton, 'End Process'), findsOneWidget);

      // Tap Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('End Process?'), findsNothing);
    });
  });
}
