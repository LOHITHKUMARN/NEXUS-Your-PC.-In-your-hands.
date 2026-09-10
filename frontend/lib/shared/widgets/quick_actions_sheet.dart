import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pc_control_center/core/providers/telemetry_provider.dart';
import 'package:pc_control_center/core/theme/app_theme.dart';
import 'package:pc_control_center/features/trackpad/presentation/trackpad_screen.dart';
import 'package:pc_control_center/shared/widgets/confirmation_dialog.dart';
import 'package:pc_control_center/shared/widgets/pc_icon_badge.dart';

class QuickActionsSheet extends ConsumerWidget {
  const QuickActionsSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => const QuickActionsSheet(),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8, top: 12),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: AppColors.metricNormal,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final telemetryAsync = ref.watch(telemetryStreamProvider);
    final audio = ref.watch(audioControllerProvider);
    final media = ref.watch(mediaControllerProvider);
    final power = ref.watch(powerControllerProvider);

    final frame = telemetryAsync.value;
    final isMuted = frame?.audio.isMuted ?? false;
    final isPlaying = frame?.media.isPlaying ?? false;
    final currentVol = frame?.audio.masterVolume ?? 50;

    return Container(
      padding: const EdgeInsets.only(bottom: 28),
      decoration: BoxDecoration(
        color: AppColors.panelBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: AppColors.panelBorder,
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.45),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Title Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.widgets_rounded, color: AppColors.accentLive, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Quick Controls',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.pop(context),
                  color: Colors.white.withOpacity(0.6),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.panelBorder),
          const SizedBox(height: 14),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                // 0. Primary Hero Action: Remote Trackpad & Keyboard
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const TrackpadScreen()),
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.buttonSurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.accentLive.withOpacity(0.4), width: 1.4),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accentLive.withOpacity(0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const PcIconBadge(
                            icon: Icons.mouse_rounded,
                            size: 40,
                            iconSize: 20,
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Remote Trackpad & Keyboard',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Precision cursor, gestures & keyboard input',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.metricNormal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded, color: AppColors.metricNormal, size: 20),
                        ],
                      ),
                    ),
                  ),
                ),

                // 1. Volume & Audio Section
                _buildSectionHeader('VOLUME & AUDIO'),
                Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: _buildTile(
                        icon: isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                        label: isMuted ? 'Unmute' : 'Mute',
                        badge: isMuted ? 'Muted' : '$currentVol%',
                        badgeColor: isMuted ? AppColors.criticalRed : AppColors.accentLive,
                        iconColor: isMuted ? AppColors.criticalRed : AppColors.accentLive,
                        onTap: () => audio.toggleMute(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: _buildTile(
                        icon: Icons.remove_rounded,
                        label: '-5%',
                        onTap: () => audio.stepVolume(-5),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: _buildTile(
                        icon: Icons.add_rounded,
                        label: '+5%',
                        onTap: () => audio.stepVolume(5),
                      ),
                    ),
                  ],
                ),

                // 2. Media Playback Section
                _buildSectionHeader('MEDIA PLAYBACK'),
                Row(
                  children: [
                    Expanded(
                      child: _buildTile(
                        icon: Icons.skip_previous_rounded,
                        label: 'Prev',
                        onTap: () => media.previous(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: _buildTile(
                        icon: isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        label: isPlaying ? 'Pause' : 'Play',
                        iconColor: isPlaying ? AppColors.accentLive : Colors.white,
                        borderColor: isPlaying ? AppColors.accentLive.withOpacity(0.4) : null,
                        onTap: () => media.toggle(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildTile(
                        icon: Icons.skip_next_rounded,
                        label: 'Next',
                        onTap: () => media.next(),
                      ),
                    ),
                  ],
                ),

                // 3. Display & System Power Section
                _buildSectionHeader('DISPLAY & SYSTEM POWER'),
                Row(
                  children: [
                    Expanded(
                      child: _buildTile(
                        icon: Icons.nightlight_round,
                        label: 'Screen Off',
                        onTap: () {
                          power.screenOff();
                          Navigator.pop(context);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildTile(
                        icon: Icons.wb_sunny_rounded,
                        label: 'Screen On',
                        onTap: () {
                          power.screenOn();
                          Navigator.pop(context);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildTile(
                        icon: Icons.lock_outline_rounded,
                        label: 'Lock PC',
                        iconColor: AppColors.warningAmber,
                        borderColor: AppColors.warningAmber.withOpacity(0.4),
                        onTap: () {
                          SafetyActionDialog.show(
                            context: context,
                            title: 'Lock Host PC?',
                            description: 'Your PC session will be locked immediately. You will need to enter your PIN or password on the PC to resume.',
                            confirmText: 'Lock PC',
                            icon: Icons.lock_outline_rounded,
                            accentColor: AppColors.warningAmber,
                            onConfirm: () {
                              power.lock();
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTile({
    required IconData icon,
    required String label,
    String? badge,
    Color? iconColor,
    Color? badgeColor,
    Color? borderColor,
    required VoidCallback onTap,
  }) {
    final effIconColor = iconColor ?? Colors.white70;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: AppColors.buttonSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: borderColor ?? AppColors.buttonBorder,
              width: 1.2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: effIconColor, size: 20),
              const SizedBox(height: 5),
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (badge != null) ...[
                    const SizedBox(width: 4),
                    Text(
                      '($badge)',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: badgeColor ?? AppColors.metricNormal,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
