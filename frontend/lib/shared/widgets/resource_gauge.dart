import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:pc_control_center/core/theme/app_theme.dart';

enum GaugeVariant {
  full,    // Radial circular dial (Tablet / Expanded)
  compact, // Linear bar / Mini card (Phone / Compact)
}

class ResourceGauge extends StatelessWidget {
  final String label;
  final double value; // 0.0 to 100.0
  final String? customValueText;
  final String? subtitle;
  final IconData icon;
  final Color? accentColor;
  final GaugeVariant variant;
  final VoidCallback? onTap;

  const ResourceGauge({
    super.key,
    required this.label,
    required this.value,
    this.customValueText,
    this.subtitle,
    required this.icon,
    this.accentColor,
    this.variant = GaugeVariant.full,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? _getDynamicColor(value);
    final displayValue = customValueText ?? '${value.toStringAsFixed(0)}%';

    if (variant == GaugeVariant.compact) {
      return _buildCompact(context, color, displayValue);
    }
    return _buildFull(context, color, displayValue);
  }

  Color _getDynamicColor(double val) {
    return AppColors.getMetricColor(val);
  }

  Widget _buildCompact(BuildContext context, Color color, String displayValue) {
    final clampedPct = (value / 100.0).clamp(0.0, 1.0);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor.withOpacity(0.6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 16, color: color),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.85),
                      ),
                    ),
                  ],
                ),
                Text(
                  displayValue,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: color,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Stack(
                children: [
                  Container(
                    height: 6,
                    width: double.infinity,
                    color: Colors.white.withOpacity(0.08),
                  ),
                  FractionallySizedBox(
                    widthFactor: clampedPct,
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [color.withOpacity(0.7), color],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(0.5),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white.withOpacity(0.45),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFull(BuildContext context, Color color, String displayValue) {
    final clampedPct = (value / 100.0).clamp(0.0, 1.0);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor.withOpacity(0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.35), width: 1.2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 100,
              height: 100,
              child: CustomPaint(
                painter: _CircularGaugePainter(
                  progress: clampedPct,
                  color: color,
                  trackColor: Colors.white.withOpacity(0.08),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, size: 20, color: color),
                      const SizedBox(height: 2),
                      Text(
                        displayValue,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withOpacity(0.5),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CircularGaugePainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;

  _CircularGaugePainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 12) / 2;
    const strokeWidth = 8.0;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    const startAngle = -math.pi * 1.25;
    const sweepAngle = math.pi * 1.5;

    // Draw background arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      trackPaint,
    );

    // Draw active progress arc
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle * progress,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CircularGaugePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
