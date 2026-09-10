import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pc_control_center/core/models/telemetry_model.dart';
import 'package:pc_control_center/core/providers/telemetry_provider.dart';
import 'package:pc_control_center/core/theme/app_theme.dart';
import 'package:pc_control_center/shared/widgets/confirmation_dialog.dart';
import 'package:pc_control_center/shared/widgets/custom_slider.dart';
import 'package:pc_control_center/shared/widgets/glass_card.dart';

class ControlCenterScreen extends ConsumerStatefulWidget {
  const ControlCenterScreen({super.key});

  @override
  ConsumerState<ControlCenterScreen> createState() => _ControlCenterScreenState();
}

class _ControlCenterScreenState extends ConsumerState<ControlCenterScreen> {
  int _selectedTab = 0; // 0 = Audio, 1 = Display, 2 = Power

  @override
  Widget build(BuildContext context) {
    final telemetryAsync = ref.watch(telemetryStreamProvider);
    final audioCtrl = ref.read(audioControllerProvider);
    final displayCtrl = ref.read(displayControllerProvider);
    final powerCtrl = ref.read(powerControllerProvider);

    final frame = telemetryAsync.value;
    final audio = frame?.audio;
    final display = frame?.display;

    return ListView(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 14, bottom: 88),
      children: [
        // Tab Selector for Phone Thumb Navigation
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.panelBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.panelBorder, width: 1.2),
          ),
          child: Row(
            children: [
              _buildTabButton(0, 'Audio', Icons.volume_up_rounded),
              const SizedBox(width: 4),
              _buildTabButton(1, 'Display', Icons.brightness_6_rounded),
              const SizedBox(width: 4),
              _buildTabButton(2, 'Power', Icons.power_settings_new_rounded),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Section Content
        if (_selectedTab == 0 && audio != null)
          _buildAudioSection(audio, audioCtrl)
        else if (_selectedTab == 1 && display != null)
          _buildDisplaySection(display, displayCtrl, powerCtrl)
        else if (_selectedTab == 2)
          _buildPowerSection(context, powerCtrl)
        else
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'Awaiting connection...',
                style: TextStyle(color: Colors.white.withOpacity(0.5)),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTabButton(int index, String label, IconData icon) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedTab = index),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.buttonSurface : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isSelected ? Border.all(color: AppColors.buttonBorder, width: 1.0) : null,
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
      ),
    );
  }

  Widget _buildAudioSection(AudioStatusModel audio, AudioController ctrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CustomSliderCard(
          title: 'Master Audio Volume',
          value: audio.masterVolume,
          icon: audio.isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
          accentColor: audio.isMuted ? AppColors.red : AppColors.cyan,
          onChanged: (v) => ctrl.setVolume(v),
          onNudgeDown: () => ctrl.stepVolume(-5),
          onNudgeUp: () => ctrl.stepVolume(5),
          trailing: IconButton(
            icon: Icon(
              audio.isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
              color: audio.isMuted ? AppColors.red : AppColors.cyan,
            ),
            onPressed: () => ctrl.toggleMute(),
          ),
        ),
        const SizedBox(height: 16),

        // Audio Endpoints Section
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Text(
            'Playback Audio Devices',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
          ),
        ),
        const SizedBox(height: 6),

        if (audio.devices.isEmpty)
          GlassCard(
            child: Text(
              'No external playback devices enumerated',
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
            ),
          )
        else
          ...audio.devices.map((device) {
            final isCurrent = device.isDefault || (audio.activeDeviceName != null && audio.activeDeviceName == device.name);
            return GlassCard(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              borderColor: isCurrent ? AppColors.cyan.withOpacity(0.5) : null,
              onTap: () => ctrl.switchDevice(device.id),
              child: Row(
                children: [
                  Icon(
                    device.name.toLowerCase().contains('headphone')
                        ? Icons.headphones_rounded
                        : Icons.speaker_rounded,
                    color: isCurrent ? AppColors.cyan : Colors.white.withOpacity(0.6),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      device.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w400,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isCurrent)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.cyan.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Active',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.cyan),
                      ),
                    ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _buildDisplaySection(DisplayStatusModel display, DisplayController ctrl, PowerController powerCtrl) {
    return Column(
      children: [
        CustomSliderCard(
          title: 'Display Brightness',
          value: display.brightness,
          icon: Icons.brightness_6_rounded,
          accentColor: AppColors.amber,
          onChanged: (v) => ctrl.setBrightness(v),
          onNudgeDown: () => ctrl.setBrightness((display.brightness - 10).clamp(0, 100)),
          onNudgeUp: () => ctrl.setBrightness((display.brightness + 10).clamp(0, 100)),
        ),
        const SizedBox(height: 16),
        GlassCard(
          padding: const EdgeInsets.all(16),
          onTap: () => powerCtrl.screenOff(),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.cyan.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.nightlight_round, color: AppColors.cyan, size: 22),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Turn Off Screen',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Puts monitor to sleep instantly without sleeping PC',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.grey),
            ],
          ),
        ),
        const SizedBox(height: 10),
        GlassCard(
          padding: const EdgeInsets.all(16),
          onTap: () => powerCtrl.screenOn(),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.emerald.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.wb_sunny_rounded, color: AppColors.emerald, size: 22),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Turn On / Wake Screen',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Wakes up the monitor immediately',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.grey),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPowerSection(BuildContext context, PowerController powerCtrl) {
    return Column(
      children: [
        _buildPowerCard(
          icon: Icons.lock_outline_rounded,
          color: AppColors.amber,
          title: 'Lock Workstation',
          subtitle: 'Locks Windows session immediately',
          onTap: () => powerCtrl.lock(),
        ),
        const SizedBox(height: 10),
        _buildPowerCard(
          icon: Icons.bedtime_outlined,
          color: AppColors.cyan,
          title: 'Sleep Mode',
          subtitle: 'Puts host computer into low-power sleep state',
          onTap: () => powerCtrl.sleep(),
        ),
        const SizedBox(height: 10),
        _buildPowerCard(
          icon: Icons.restart_alt_rounded,
          color: AppColors.violet,
          title: 'Restart PC',
          subtitle: 'Reboots the host machine with confirmation',
          onTap: () {
            SafetyActionDialog.show(
              context: context,
              title: 'Restart PC',
              description: 'Are you sure you want to restart your PC? Any unsaved work will be lost.',
              confirmText: 'Restart Now',
              icon: Icons.restart_alt_rounded,
              accentColor: AppColors.violet,
              onConfirm: () => powerCtrl.restart(),
            );
          },
        ),
        const SizedBox(height: 10),
        _buildPowerCard(
          icon: Icons.power_settings_new_rounded,
          color: AppColors.red,
          title: 'Shut Down PC',
          subtitle: 'Safely powers off your Windows PC',
          onTap: () {
            SafetyActionDialog.show(
              context: context,
              title: 'Shut Down PC',
              description: 'Are you sure you want to completely shut down your computer?',
              confirmText: 'Shut Down',
              icon: Icons.power_settings_new_rounded,
              accentColor: AppColors.red,
              onConfirm: () => powerCtrl.shutdown(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPowerCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      borderColor: color.withOpacity(0.35),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.6)),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: Colors.white.withOpacity(0.4)),
        ],
      ),
    );
  }
}
