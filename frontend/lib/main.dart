import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pc_control_center/core/layout/adaptive_scaffold.dart';
import 'package:pc_control_center/core/providers/settings_provider.dart';
import 'package:pc_control_center/core/theme/app_theme.dart';
import 'package:pc_control_center/features/apps/presentation/apps_screen.dart';
import 'package:pc_control_center/features/control_center/presentation/control_center_screen.dart';
import 'package:pc_control_center/features/dashboard/presentation/dashboard_screen.dart';
import 'package:pc_control_center/features/extras/presentation/extras_screen.dart';
import 'package:pc_control_center/features/media/presentation/media_screen.dart';
import 'package:pc_control_center/features/settings/presentation/settings_screen.dart';

import 'package:pc_control_center/core/network/websocket_client.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Allow flexible orientation (portrait on phone, landscape on tablet/dock)
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  runApp(
    const ProviderScope(
      child: PCControlCenterApp(),
    ),
  );
}

class PCControlCenterApp extends ConsumerWidget {
  const PCControlCenterApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final theme = AppTheme.getTheme(settings.themeMode);

    return MaterialApp(
      title: 'PC Control Center',
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: const MainShellScreen(),
    );
  }
}

class MainShellScreen extends ConsumerStatefulWidget {
  const MainShellScreen({super.key});

  @override
  ConsumerState<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends ConsumerState<MainShellScreen> with WidgetsBindingObserver {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      telemetryWsClient.onAppResumed();
    }
  }

  final List<AdaptiveDestination> _destinations = const [
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
    AdaptiveDestination(
      label: 'Media',
      icon: Icons.music_note_outlined,
      selectedIcon: Icons.music_note_rounded,
    ),
    AdaptiveDestination(
      label: 'Apps',
      icon: Icons.rocket_launch_outlined,
      selectedIcon: Icons.rocket_launch_rounded,
    ),
    AdaptiveDestination(
      label: 'Tools & Config',
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final screens = [
      const DashboardScreen(),
      const ControlCenterScreen(),
      const MediaScreen(),
      const AppsScreen(),
      const _ToolsAndSettingsView(),
    ];

    return AdaptiveScaffold(
      selectedIndex: _selectedIndex,
      onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
      destinations: _destinations,
      screens: screens,
    );
  }
}

class _ToolsAndSettingsView extends StatefulWidget {
  const _ToolsAndSettingsView();

  @override
  State<_ToolsAndSettingsView> createState() => _ToolsAndSettingsViewState();
}

class _ToolsAndSettingsViewState extends State<_ToolsAndSettingsView> {
  int _subTab = 0; // 0 = Tools / Extras, 1 = Settings

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.panelBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.panelBorder, width: 1.2),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _subTab = 0),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: _subTab == 0 ? AppColors.buttonSurface : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: _subTab == 0 ? Border.all(color: AppColors.buttonBorder, width: 1) : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.build_rounded,
                            size: 14,
                            color: _subTab == 0 ? Colors.white : AppColors.metricNormal,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Tools & Sync',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: _subTab == 0 ? FontWeight.w700 : FontWeight.w500,
                              color: _subTab == 0 ? Colors.white : AppColors.metricNormal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _subTab = 1),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: _subTab == 1 ? AppColors.buttonSurface : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: _subTab == 1 ? Border.all(color: AppColors.buttonBorder, width: 1) : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.settings_rounded,
                            size: 14,
                            color: _subTab == 1 ? Colors.white : AppColors.metricNormal,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Preferences',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: _subTab == 1 ? FontWeight.w700 : FontWeight.w500,
                              color: _subTab == 1 ? Colors.white : AppColors.metricNormal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: _subTab == 0 ? const ExtrasScreen() : const SettingsScreen(),
        ),
      ],
    );
  }
}
