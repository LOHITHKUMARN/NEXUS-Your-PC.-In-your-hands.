import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pc_control_center/core/layout/form_factor.dart';
import 'package:pc_control_center/core/models/telemetry_model.dart';
import 'package:pc_control_center/core/providers/telemetry_provider.dart';
import 'package:pc_control_center/core/theme/app_theme.dart';
import 'package:pc_control_center/features/dashboard/presentation/system_instrument_panel.dart';
import 'package:pc_control_center/features/dashboard/presentation/waiting_connection_view.dart';
import 'package:pc_control_center/shared/widgets/confirmation_dialog.dart';
import 'package:pc_control_center/shared/widgets/custom_slider.dart';
import 'package:pc_control_center/shared/widgets/glass_card.dart';
import 'package:pc_control_center/shared/widgets/resource_gauge.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final telemetryAsync = ref.watch(telemetryStreamProvider);
    final formFactor = context.formFactor;

    final frame = telemetryAsync.value;

    if (frame == null) {
      return const WaitingConnectionView();
    }


    if (formFactor.isCompact) {
      return _buildCompactDashboard(context, ref, frame);
    }
    return _buildExpandedDashboard(context, ref, frame);
  }

  // --- 1. Compact Phone Layout (Single-Column Vertically Scrolling) ---
  Widget _buildCompactDashboard(BuildContext context, WidgetRef ref, UnifiedTelemetryFrameModel frame) {
    final sys = frame.system;
    final audio = frame.audio;
    final media = frame.media;
    final display = frame.display;

    final audioCtrl = ref.read(audioControllerProvider);
    final mediaCtrl = ref.read(mediaControllerProvider);
    final displayCtrl = ref.read(displayControllerProvider);
    final powerCtrl = ref.read(powerControllerProvider);

    return ListView(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 88),
      children: [
        // Consolidated Cockpit System Instrument Panel
        SystemInstrumentPanel(system: sys),
        const SizedBox(height: 14),

        // Now Playing Card (Compact)
        if (media.hasMedia) ...[
          _buildCompactMediaCard(context, media, mediaCtrl),
          const SizedBox(height: 14),
        ],

        // Volume Slider (Full-Width)
        CustomSliderCard(
          title: 'Master Volume',
          value: audio.masterVolume,
          icon: audio.isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
          accentColor: audio.isMuted ? AppColors.criticalRed : AppColors.accentLive,
          onChanged: (val) => audioCtrl.setVolume(val),
          onNudgeDown: () => audioCtrl.stepVolume(-5),
          onNudgeUp: () => audioCtrl.stepVolume(5),
          trailing: IconButton(
            icon: Icon(
              audio.isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
              color: audio.isMuted ? AppColors.criticalRed : AppColors.accentLive,
              size: 20,
            ),
            onPressed: () => audioCtrl.toggleMute(),
          ),
        ),
        const SizedBox(height: 12),

        // Brightness Slider (Full-Width)
        CustomSliderCard(
          title: 'Brightness',
          value: display.brightness,
          icon: Icons.brightness_6_rounded,
          accentColor: AppColors.accentLive,
          onChanged: (val) => displayCtrl.setBrightness(val),
          onNudgeDown: () => displayCtrl.setBrightness((display.brightness - 10).clamp(0, 100)),
          onNudgeUp: () => displayCtrl.setBrightness((display.brightness + 10).clamp(0, 100)),
        ),
        const SizedBox(height: 14),

        // Disk Storage & Battery Row
        _buildCompactStorageAndBattery(sys),
        const SizedBox(height: 14),

        // Power Actions (Thumb-friendly wrap)
        _buildPowerQuickButtons(context, powerCtrl),
        const SizedBox(height: 40),
      ],
    );
  }

  // --- 2. Expanded Tablet / Landscape Layout (Multi-Column Grid) ---
  Widget _buildExpandedDashboard(BuildContext context, WidgetRef ref, UnifiedTelemetryFrameModel frame) {
    final sys = frame.system;
    final audio = frame.audio;
    final media = frame.media;
    final display = frame.display;

    final audioCtrl = ref.read(audioControllerProvider);
    final mediaCtrl = ref.read(mediaControllerProvider);
    final displayCtrl = ref.read(displayControllerProvider);
    final powerCtrl = ref.read(powerControllerProvider);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Circular Radial Dials Row
        Row(
          children: [
            Expanded(
              child: ResourceGauge(
                label: 'CPU Usage',
                value: sys.cpuPercent,
                subtitle: sys.cpuFreqMhz != null ? '${sys.cpuFreqMhz!.toStringAsFixed(0)} MHz' : '${sys.cpuCoresPercent.length} Cores',
                icon: Icons.memory_rounded,
                accentColor: AppColors.cyan,
                variant: GaugeVariant.full,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: ResourceGauge(
                label: 'RAM Memory',
                value: sys.ramPercent,
                subtitle: '${sys.ramUsedGb.toStringAsFixed(1)} / ${sys.ramTotalGb.toStringAsFixed(1)} GB',
                icon: Icons.developer_board_rounded,
                accentColor: AppColors.violet,
                variant: GaugeVariant.full,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: ResourceGauge(
                label: 'GPU Load',
                value: sys.gpu.available ? (sys.gpu.loadPercent ?? 0.0) : 0.0,
                customValueText: sys.gpu.available ? '${sys.gpu.loadPercent?.toStringAsFixed(0)}%' : 'N/A',
                subtitle: sys.gpu.temperatureC != null ? '${sys.gpu.temperatureC!.toStringAsFixed(0)}°C Temp' : (sys.gpu.name ?? 'GPU'),
                icon: Icons.videogame_asset_rounded,
                accentColor: AppColors.magenta,
                variant: GaugeVariant.full,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: ResourceGauge(
                label: 'Primary Disk',
                value: sys.disks.isNotEmpty ? sys.disks.first.percent : 0.0,
                subtitle: sys.disks.isNotEmpty ? '${sys.disks.first.usedGb.toStringAsFixed(0)} / ${sys.disks.first.totalGb.toStringAsFixed(0)} GB' : 'Disk',
                icon: Icons.storage_rounded,
                accentColor: AppColors.emerald,
                variant: GaugeVariant.full,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Controls & Media Split Grid
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Column: Sliders & Power
            Expanded(
              flex: 5,
              child: Column(
                children: [
                  CustomSliderCard(
                    title: 'Master Audio Volume',
                    value: audio.masterVolume,
                    icon: audio.isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                    accentColor: audio.isMuted ? AppColors.red : AppColors.cyan,
                    onChanged: (val) => audioCtrl.setVolume(val),
                    onNudgeDown: () => audioCtrl.stepVolume(-5),
                    onNudgeUp: () => audioCtrl.stepVolume(5),
                    trailing: IconButton(
                      icon: Icon(
                        audio.isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                        color: audio.isMuted ? AppColors.red : AppColors.cyan,
                        size: 20,
                      ),
                      onPressed: () => audioCtrl.toggleMute(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  CustomSliderCard(
                    title: 'Screen Brightness',
                    value: display.brightness,
                    icon: Icons.brightness_6_rounded,
                    accentColor: AppColors.amber,
                    onChanged: (val) => displayCtrl.setBrightness(val),
                    onNudgeDown: () => displayCtrl.setBrightness((display.brightness - 10).clamp(0, 100)),
                    onNudgeUp: () => displayCtrl.setBrightness((display.brightness + 10).clamp(0, 100)),
                  ),
                  const SizedBox(height: 14),
                  _buildPowerQuickButtons(context, powerCtrl),
                ],
              ),
            ),
            const SizedBox(width: 16),

            // Right Column: Media Center & Network
            Expanded(
              flex: 5,
              child: Column(
                children: [
                  if (media.hasMedia)
                    _buildCompactMediaCard(context, media, mediaCtrl)
                  else
                    GlassCard(
                      padding: const EdgeInsets.all(20),
                      child: Center(
                        child: Text(
                          'No media playback active on PC',
                          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
                        ),
                      ),
                    ),
                  const SizedBox(height: 14),
                  _buildNetworkStatsCard(sys),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- Subcomponents ---

  Widget _buildCompactMediaCard(BuildContext context, MediaStatusModel media, MediaController mediaCtrl) {
    return GlassCard(
      borderColor: AppColors.violet.withOpacity(0.4),
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.violet.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.violet.withOpacity(0.4)),
                ),
                child: const Icon(Icons.music_note_rounded, color: AppColors.violet, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      media.title.isNotEmpty ? media.title : 'Playing Media',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      media.artist.isNotEmpty ? media.artist : (media.sourceApp.isNotEmpty ? media.sourceApp : 'Unknown Artist'),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.6),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Playback Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: const Icon(Icons.skip_previous_rounded),
                color: Colors.white.withOpacity(0.8),
                onPressed: () => mediaCtrl.previous(),
              ),
              IconButton.filled(
                style: IconButton.styleFrom(backgroundColor: AppColors.violet),
                icon: Icon(media.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                color: Colors.white,
                onPressed: () => mediaCtrl.toggle(),
              ),
              IconButton(
                icon: const Icon(Icons.skip_next_rounded),
                color: Colors.white.withOpacity(0.8),
                onPressed: () => mediaCtrl.next(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStorageAndBattery(SystemTelemetryModel sys) {
    return Row(
      children: [
        if (sys.disks.isNotEmpty)
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.panelBackground,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.panelBorder, width: 1.2),
              ),
              child: Row(
                children: [
                  const Icon(Icons.storage_rounded, size: 18, color: AppColors.metricNormal),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Disk (${sys.disks.first.mount})',
                          style: const TextStyle(fontSize: 11, color: AppColors.metricNormal, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${sys.disks.first.freeGb.toStringAsFixed(0)} GB free',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white, fontFamily: 'monospace'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (sys.battery.present) ...[
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.panelBackground,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.panelBorder, width: 1.2),
              ),
              child: Row(
                children: [
                  Icon(
                    sys.battery.powerPlugged == true
                        ? Icons.power_rounded
                        : Icons.battery_std_rounded,
                    size: 18,
                    color: sys.battery.powerPlugged == true
                        ? AppColors.accentLive
                        : ((sys.battery.percent ?? 100) <= 20 ? AppColors.warningAmber : AppColors.metricNormal),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'PC Battery',
                          style: TextStyle(fontSize: 11, color: AppColors.metricNormal, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              '${sys.battery.percent?.toStringAsFixed(0)}%',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white, fontFamily: 'monospace'),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              sys.battery.powerPlugged == true ? 'AC Plugged' : 'On Battery',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: sys.battery.powerPlugged == true ? AppColors.accentLive : AppColors.metricNormal,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildNetworkStatsCard(SystemTelemetryModel sys) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Row(
            children: [
              const Icon(Icons.arrow_downward_rounded, color: AppColors.cyan, size: 20),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Download', style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.6))),
                  Text(
                    '${sys.network.downloadKbps.toStringAsFixed(1)} KB/s',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ],
              ),
            ],
          ),
          Container(width: 1, height: 32, color: Colors.white.withOpacity(0.15)),
          Row(
            children: [
              const Icon(Icons.arrow_upward_rounded, color: AppColors.emerald, size: 20),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Upload', style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.6))),
                  Text(
                    '${sys.network.uploadKbps.toStringAsFixed(1)} KB/s',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTactileActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? accentColor,
  }) {
    final color = accentColor ?? AppColors.metricNormal;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.buttonSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.buttonBorder, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPowerQuickButtons(BuildContext context, PowerController powerCtrl) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildTactileActionButton(
                icon: Icons.nightlight_round,
                label: 'Screen Off',
                accentColor: AppColors.metricNormal,
                onTap: () => powerCtrl.screenOff(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildTactileActionButton(
                icon: Icons.wb_sunny_rounded,
                label: 'Screen On',
                accentColor: AppColors.accentLive,
                onTap: () => powerCtrl.screenOn(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildTactileActionButton(
                icon: Icons.lock_outline_rounded,
                label: 'Lock PC',
                accentColor: AppColors.warningAmber,
                onTap: () => powerCtrl.lock(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildTactileActionButton(
                icon: Icons.power_settings_new_rounded,
                label: 'Power Menu',
                accentColor: AppColors.criticalRed,
                onTap: () {
                  SafetyActionDialog.show(
                    context: context,
                    title: 'Power Management',
                    description: 'Choose whether to restart or shut down your PC.',
                    confirmText: 'Shut Down',
                    icon: Icons.power_settings_new_rounded,
                    accentColor: AppColors.criticalRed,
                    onConfirm: () => powerCtrl.shutdown(),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}


