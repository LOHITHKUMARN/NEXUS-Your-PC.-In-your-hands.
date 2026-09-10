import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pc_control_center/core/layout/form_factor.dart';
import 'package:pc_control_center/core/network/websocket_client.dart';
import 'package:pc_control_center/core/providers/telemetry_provider.dart';
import 'package:pc_control_center/core/theme/app_theme.dart';
import 'package:pc_control_center/shared/widgets/connection_badge.dart';
import 'package:pc_control_center/shared/widgets/quick_actions_sheet.dart';
import 'package:pc_control_center/features/trackpad/presentation/trackpad_screen.dart';

class AdaptiveDestination {
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  const AdaptiveDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });
}

class AdaptiveScaffold extends ConsumerStatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<AdaptiveDestination> destinations;
  final List<Widget> screens;

  const AdaptiveScaffold({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    required this.screens,
  });

  @override
  ConsumerState<AdaptiveScaffold> createState() => _AdaptiveScaffoldState();
}

class _AdaptiveScaffoldState extends ConsumerState<AdaptiveScaffold> {
  @override
  Widget build(BuildContext context) {
    final formFactor = context.formFactor;
    final telemetryAsync = ref.watch(telemetryStreamProvider);
    final pcName = telemetryAsync.value?.pcName ?? 'My PC';

    final isHandheld = formFactor.isHandheld;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.panelBackground,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.accentLive.withOpacity(0.35),
                  width: 1.2,
                ),
              ),
              child: Image.asset(
                'assets/images/app_logo.png',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.desktop_windows_rounded,
                  color: AppColors.accentLive,
                  size: 18,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                pcName,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.mouse_rounded, color: AppColors.accentLive, size: 20),
            tooltip: 'Remote Trackpad & Keyboard',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TrackpadScreen()),
              );
            },
          ),
          const Padding(
            padding: EdgeInsets.only(right: 12),
            child: ConnectionBadge(),
          ),
        ],
      ),
      body: Row(
        children: [
          if (formFactor.isExpanded)
            NavigationRail(
              selectedIndex: widget.selectedIndex,
              onDestinationSelected: widget.onDestinationSelected,
              labelType: NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: IconButton.filledTonal(
                  icon: const Icon(Icons.bolt_rounded, color: AppColors.cyan),
                  tooltip: 'Quick Controls',
                  onPressed: () => QuickActionsSheet.show(context),
                ),
              ),
              destinations: widget.destinations.map((d) {
                return NavigationRailDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.selectedIcon),
                  label: Text(d.label),
                );
              }).toList(),
            ),
          Expanded(
            child: IndexedStack(
              index: widget.selectedIndex,
              children: widget.screens,
            ),
          ),
        ],
      ),
      // Quick Actions FAB is hidden when disconnected to prevent overlapping setup forms
      // and because PC quick controls (sleep, volume, screen off) require an active socket.
      // (Note: if WoL/remote wake is added in future, conditionally show a wake trigger).
      floatingActionButton: (isHandheld && (ref.watch(connectionStatusProvider).value == ConnectionStatus.connected))
          ? FloatingActionButton(
              mini: true,
              backgroundColor: AppColors.accentLive,
              foregroundColor: Colors.black,
              elevation: 4,
              onPressed: () => QuickActionsSheet.show(context),
              tooltip: 'Quick Controls',
              child: const Icon(Icons.bolt_rounded, size: 20),
            )
          : null,
      bottomNavigationBar: isHandheld
          ? NavigationBar(
              selectedIndex: widget.selectedIndex,
              onDestinationSelected: widget.onDestinationSelected,
              destinations: widget.destinations.map((d) {
                return NavigationDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.selectedIcon),
                  label: d.label,
                );
              }).toList(),
            )
          : null,
    );
  }
}
