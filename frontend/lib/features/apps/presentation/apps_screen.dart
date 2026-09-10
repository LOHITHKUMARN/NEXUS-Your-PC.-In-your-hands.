import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pc_control_center/core/models/telemetry_model.dart';
import 'package:pc_control_center/core/network/api_client.dart';
import 'package:pc_control_center/core/theme/app_theme.dart';
import 'package:pc_control_center/shared/widgets/glass_card.dart';
import 'package:pc_control_center/shared/widgets/pc_action_button.dart';
import 'package:pc_control_center/shared/widgets/pc_icon_badge.dart';

final appsListFutureProvider = FutureProvider.autoDispose<List<AppItemModel>>((ref) async {
  return apiClient.getApps();
});

final tasksListFutureProvider = FutureProvider.autoDispose<List<RunningTaskModel>>((ref) async {
  return apiClient.getTasks();
});

class AppsScreen extends ConsumerStatefulWidget {
  const AppsScreen({super.key});

  @override
  ConsumerState<AppsScreen> createState() => _AppsScreenState();
}

class _AppsScreenState extends ConsumerState<AppsScreen> {
  int _viewMode = 0; // 0 = App Launchers, 1 = Active Tasks

  IconData _getIconForApp(String iconName) {
    switch (iconName.toLowerCase()) {
      case 'music':
      case 'spotify':
        return Icons.music_note_rounded;
      case 'chrome':
        return Icons.language_rounded;
      case 'message-square':
      case 'discord':
        return Icons.chat_bubble_outline_rounded;
      case 'gamepad-2':
      case 'steam':
        return Icons.sports_esports_rounded;
      case 'code':
        return Icons.code_rounded;
      case 'calculator':
        return Icons.calculate_rounded;
      case 'activity':
      case 'taskmgr':
        return Icons.stacked_bar_chart_rounded;
      case 'file-text':
      case 'notepad':
        return Icons.description_outlined;
      case 'terminal':
        return Icons.terminal_rounded;
      default:
        return Icons.apps_rounded;
    }
  }

  Future<void> _confirmKillTask(RunningTaskModel task) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B26),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.criticalRed, size: 22),
            const SizedBox(width: 8),
            const Text('End Process?', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to terminate ${task.name}?',
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.panelSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.panelBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Process: ${task.name}', style: const TextStyle(fontSize: 12, color: Colors.white70, fontFamily: 'monospace')),
                  const SizedBox(height: 3),
                  Text('PID: ${task.pid}', style: const TextStyle(fontSize: 12, color: Colors.white70, fontFamily: 'monospace')),
                  const SizedBox(height: 3),
                  Text('Memory Footprint: ${task.memoryMb.toStringAsFixed(0)} MB', style: const TextStyle(fontSize: 12, color: Colors.white70, fontFamily: 'monospace')),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.metricNormal)),
          ),
          PcActionButton(
            label: 'End Process',
            customAccent: AppColors.criticalRed,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await apiClient.killTask(task.pid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Terminated ${task.name} (PID: ${task.pid})' : 'Failed to terminate ${task.name}.'),
            backgroundColor: success ? AppColors.buttonSurface : AppColors.criticalRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
        ref.invalidate(tasksListFutureProvider);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appsAsync = ref.watch(appsListFutureProvider);
    final tasksAsync = ref.watch(tasksListFutureProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        color: AppColors.accentLive,
        backgroundColor: const Color(0xFF1E2230),
        onRefresh: () async {
          ref.invalidate(appsListFutureProvider);
          ref.invalidate(tasksListFutureProvider);
        },
        child: ListView(
          // Generous bottom buffer (88dp) guarantees FAB never obstructs bottom items
          padding: const EdgeInsets.only(left: 16, right: 16, top: 14, bottom: 88),
          children: [
            // Unified Segmented Switcher
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.panelBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.panelBorder, width: 1.2),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildSubTab(0, 'Quick Launchers', Icons.rocket_launch_rounded),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _buildSubTab(1, 'Active PC Tasks', Icons.memory_rounded),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (_viewMode == 0) ...[
              appsAsync.when(
                loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
                error: (err, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(30),
                    child: Column(
                      children: [
                        const Icon(Icons.cloud_off_rounded, size: 40, color: AppColors.metricNormal),
                        const SizedBox(height: 10),
                        Text(
                          'Could not reach PC Host.\nEnsure PC server is active & on the same Wi-Fi.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
                        ),
                        const SizedBox(height: 14),
                        PcActionButton(
                          label: 'Retry',
                          icon: Icons.refresh_rounded,
                          isOutlined: true,
                          onPressed: () => ref.invalidate(appsListFutureProvider),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (apps) => _buildAppGrid(apps),
              ),
            ] else ...[
              tasksAsync.when(
                loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
                error: (err, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(30),
                    child: Column(
                      children: [
                        const Icon(Icons.cloud_off_rounded, size: 40, color: AppColors.metricNormal),
                        const SizedBox(height: 10),
                        Text(
                          'Failed to retrieve active PC tasks.\nEnsure PC server is active & on the same Wi-Fi.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
                        ),
                        const SizedBox(height: 14),
                        PcActionButton(
                          label: 'Retry',
                          icon: Icons.refresh_rounded,
                          isOutlined: true,
                          onPressed: () => ref.invalidate(tasksListFutureProvider),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (tasks) => _buildTaskList(tasks),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSubTab(int index, String label, IconData icon) {
    final isSelected = _viewMode == index;
    return InkWell(
      onTap: () => setState(() => _viewMode = index),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.buttonSurface : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected ? Border.all(color: AppColors.buttonBorder, width: 1) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? Colors.white : AppColors.metricNormal,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.metricNormal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppGrid(List<AppItemModel> apps) {
    if (apps.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            children: [
              Icon(Icons.apps_outlined, size: 48, color: Colors.white.withOpacity(0.3)),
              const SizedBox(height: 12),
              const Text('No Applications Available', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Pull down or tap below to query PC launcher apps.', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.4))),
              const SizedBox(height: 16),
              PcActionButton(
                label: 'Refresh Apps',
                icon: Icons.refresh_rounded,
                onPressed: () => ref.invalidate(appsListFutureProvider),
              ),
            ],
          ),
        ),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 180,
        childAspectRatio: 0.96, // Balanced height to prevent long name clipping
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: apps.length,
      itemBuilder: (context, idx) {
        final app = apps[idx];
        final icon = _getIconForApp(app.icon);

        return GlassCard(
          padding: const EdgeInsets.all(12),
          borderColor: app.isRunning ? const Color(0xFF34D399).withOpacity(0.4) : null,
          onTap: () async {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Launching ${app.name}...'),
                duration: const Duration(seconds: 1),
                backgroundColor: AppColors.buttonSurface,
                behavior: SnackBarBehavior.floating,
              ),
            );
            await apiClient.launchApp(app.id);
            ref.invalidate(appsListFutureProvider);
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  PcIconBadge(
                    icon: icon,
                    size: 44,
                    iconSize: 22,
                  ),
                  if (app.isRunning)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: const Color(0xFF34D399),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF34D399).withOpacity(0.6),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                app.name,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                app.isRunning ? 'Active' : 'Tap to Launch',
                style: TextStyle(
                  fontSize: 10,
                  color: app.isRunning ? const Color(0xFF34D399) : Colors.white.withOpacity(0.4),
                  fontWeight: app.isRunning ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTaskList(List<RunningTaskModel> tasks) {
    if (tasks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            children: [
              Icon(Icons.memory_rounded, size: 48, color: Colors.white.withOpacity(0.3)),
              const SizedBox(height: 12),
              const Text('No Active Tasks Reported', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Pull down to refresh active processes from PC.', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.4))),
              const SizedBox(height: 16),
              PcActionButton(
                label: 'Refresh Tasks',
                icon: Icons.refresh_rounded,
                onPressed: () => ref.invalidate(tasksListFutureProvider),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      children: tasks.map((task) {
        // Outlier heuristic: memory >= 500 MB is highlighted with amber warning
        final isHeavy = task.memoryMb >= 500.0;
        final rowColor = isHeavy ? AppColors.warningAmber : AppColors.metricNormal;

        return GlassCard(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          onTap: () => _confirmKillTask(task),
          child: Row(
            children: [
              Icon(
                isHeavy ? Icons.circle : Icons.circle_outlined,
                size: 12,
                color: rowColor,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  task.name,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${task.memoryMb.toStringAsFixed(0)} MB',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isHeavy ? AppColors.warningAmber : Colors.white,
                      fontFamily: 'monospace',
                    ),
                  ),
                  Text(
                    'PID: ${task.pid}',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withOpacity(0.5),
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 6),
              Icon(Icons.close_rounded, size: 14, color: Colors.white.withOpacity(0.2)),
            ],
          ),
        );
      }).toList(),
    );
  }
}
