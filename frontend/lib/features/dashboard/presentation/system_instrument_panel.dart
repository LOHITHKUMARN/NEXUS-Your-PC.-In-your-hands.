import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:pc_control_center/core/models/telemetry_model.dart';
import 'package:pc_control_center/core/theme/app_theme.dart';

class SystemInstrumentPanel extends StatelessWidget {
  final SystemTelemetryModel system;

  const SystemInstrumentPanel({
    super.key,
    required this.system,
  });

  @override
  Widget build(BuildContext context) {
    final cpuVal = system.cpuPercent;
    final cpuSubtitle = system.cpuFreqMhz != null
        ? '${system.cpuFreqMhz!.toStringAsFixed(0)} MHz'
        : '${system.cpuCoresPercent.length} Cores';

    final ramVal = system.ramPercent;
    final ramSubtitle = '${system.ramUsedGb.toStringAsFixed(1)} / ${system.ramTotalGb.toStringAsFixed(1)} GB';

    final gpuVal = system.gpu.available ? (system.gpu.loadPercent ?? 0.0) : 0.0;
    final gpuSubtitle = system.gpu.temperatureC != null
        ? '${system.gpu.temperatureC!.toStringAsFixed(0)}°C'
        : (system.gpu.name != null && system.gpu.name!.isNotEmpty ? system.gpu.name! : '0°C');

    return Container(
      decoration: BoxDecoration(
        color: AppColors.panelBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.panelBorder, width: 1.2),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.accentLive,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'SYSTEM MONITOR',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.metricNormal,
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),
              if (ramVal >= 80 || cpuVal >= 80)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.warningAmber.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.warningAmber.withOpacity(0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: AppColors.warningAmber, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        ramVal >= 90 || cpuVal >= 90 ? 'CRITICAL' : 'HIGH LOAD',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: AppColors.warningAmber,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // 3 Radial Dials in a Row: CPU | RAM | GPU
          Row(
            children: [
              Expanded(
                child: _RadialDialWidget(
                  label: 'CPU',
                  value: cpuVal,
                  subtitle: cpuSubtitle,
                  icon: Icons.memory_rounded,
                ),
              ),
              Container(width: 1, height: 75, color: AppColors.panelBorder.withOpacity(0.6)),
              Expanded(
                child: _RadialDialWidget(
                  label: 'RAM',
                  value: ramVal,
                  subtitle: ramSubtitle,
                  icon: Icons.developer_board_rounded,
                ),
              ),
              Container(width: 1, height: 75, color: AppColors.panelBorder.withOpacity(0.6)),
              Expanded(
                child: _RadialDialWidget(
                  label: 'GPU',
                  value: gpuVal,
                  subtitle: gpuSubtitle,
                  icon: Icons.videogame_asset_rounded,
                  isGpuAvailable: system.gpu.available,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Divider
          Container(
            height: 1,
            color: AppColors.panelBorder.withOpacity(0.6),
          ),
          const SizedBox(height: 10),

          // Network Throughput Strip
          _NetworkStripWidget(network: system.network),
        ],
      ),
    );
  }
}

class _RadialDialWidget extends StatelessWidget {
  final String label;
  final double value;
  final String subtitle;
  final IconData icon;
  final bool isGpuAvailable;

  const _RadialDialWidget({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.icon,
    this.isGpuAvailable = true,
  });

  @override
  Widget build(BuildContext context) {
    final semanticColor = AppColors.getMetricColor(value);
    final clampedValue = value.clamp(0.0, 100.0);
    final hasWarning = value >= 80.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Label with Icon
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 12, color: AppColors.metricNormal),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.metricNormal,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),

        // Custom Radial Arc Dial
        SizedBox(
          width: 76,
          height: 76,
          child: CustomPaint(
            painter: _RadialArcPainter(
              percentage: clampedValue / 100.0,
              arcColor: semanticColor,
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        isGpuAvailable ? '${value.toStringAsFixed(0)}%' : 'N/A',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: isGpuAvailable ? semanticColor : AppColors.metricNormal,
                          fontFamily: 'monospace',
                          letterSpacing: -0.5,
                        ),
                      ),
                      if (hasWarning && isGpuAvailable) ...[
                        const SizedBox(width: 2),
                        Icon(Icons.warning_amber_rounded, color: semanticColor, size: 10),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),

        // Subtitle metric
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: AppColors.metricNormal,
            fontFamily: 'monospace',
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _RadialArcPainter extends CustomPainter {
  final double percentage; // 0.0 to 1.0
  final Color arcColor;

  _RadialArcPainter({
    required this.percentage,
    required this.arcColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 10) / 2;

    const startAngle = 0.75 * math.pi; // 135 degrees
    const totalSweep = 1.5 * math.pi;  // 270 degrees

    // Track Paint
    final trackPaint = Paint()
      ..color = const Color(0xFF1E2533)
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      totalSweep,
      false,
      trackPaint,
    );

    // Active Value Arc
    if (percentage > 0.001) {
      final activeSweep = totalSweep * percentage.clamp(0.0, 1.0);
      final activePaint = Paint()
        ..color = arcColor
        ..strokeWidth = 5.0
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        activeSweep,
        false,
        activePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RadialArcPainter oldDelegate) {
    return oldDelegate.percentage != percentage || oldDelegate.arcColor != arcColor;
  }
}

class _NetworkStripWidget extends StatelessWidget {
  final NetworkRateModel network;

  const _NetworkStripWidget({
    required this.network,
  });

  @override
  Widget build(BuildContext context) {
    final isDownActive = network.downloadKbps > 5.0;
    final isUpActive = network.uploadKbps > 5.0;

    return Row(
      children: [
        // Label
        const Row(
          children: [
            Icon(Icons.swap_vert_rounded, size: 14, color: AppColors.metricNormal),
            SizedBox(width: 4),
            Text(
              'NET',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.metricNormal,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        const SizedBox(width: 12),

        // Live Mini Sparkline Activity Bar
        Expanded(
          child: SizedBox(
            height: 16,
            child: CustomPaint(
              painter: _NetworkWaveformPainter(
                downloadRate: network.downloadKbps,
                uploadRate: network.uploadKbps,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Monospace Rates
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.arrow_downward_rounded, size: 11, color: isDownActive ? AppColors.accentLive : AppColors.metricNormal),
            const SizedBox(width: 2),
            Text(
              _formatRate(network.downloadKbps),
              style: TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
                color: isDownActive ? Colors.white : AppColors.metricNormal,
              ),
            ),
            const SizedBox(width: 10),
            Icon(Icons.arrow_upward_rounded, size: 11, color: isUpActive ? AppColors.accentLive : AppColors.metricNormal),
            const SizedBox(width: 2),
            Text(
              _formatRate(network.uploadKbps),
              style: TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
                color: isUpActive ? Colors.white : AppColors.metricNormal,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatRate(double kbps) {
    if (kbps >= 1024) {
      return '${(kbps / 1024).toStringAsFixed(1)}M/s';
    }
    return '${kbps.toStringAsFixed(0)}K/s';
  }
}

class _NetworkWaveformPainter extends CustomPainter {
  final double downloadRate;
  final double uploadRate;

  _NetworkWaveformPainter({
    required this.downloadRate,
    required this.uploadRate,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    final midY = height / 2;

    final bgPaint = Paint()
      ..color = const Color(0xFF1B2230)
      ..strokeWidth = 1.0;

    canvas.drawLine(Offset(0, midY), Offset(width, midY), bgPaint);

    final totalRate = downloadRate + uploadRate;
    final barCount = 14;
    final barSpacing = width / barCount;
    final isMoving = totalRate > 2.0;

    final barPaint = Paint()
      ..color = isMoving ? AppColors.accentLive.withOpacity(0.65) : const Color(0xFF283244)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < barCount; i++) {
      final x = i * barSpacing + 2.0;
      double h = 2.0;
      if (isMoving) {
        // Subtle rhythmic sparkline variation
        final factor = math.sin((i * 0.8) + (totalRate * 0.05)).abs();
        h = (height * 0.35 * factor).clamp(2.0, height * 0.45);
      }
      canvas.drawLine(Offset(x, midY - h), Offset(x, midY + h), barPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _NetworkWaveformPainter oldDelegate) {
    return oldDelegate.downloadRate != downloadRate || oldDelegate.uploadRate != uploadRate;
  }
}
