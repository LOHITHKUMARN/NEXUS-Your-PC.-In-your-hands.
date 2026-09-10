import 'package:flutter/material.dart';
import 'package:pc_control_center/core/theme/app_theme.dart';

/// Reusable circular icon badge with calm glowing background and subtle border.
/// Standardized from the Quick Launcher design for use across all screens.
class PcIconBadge extends StatelessWidget {
  final IconData icon;
  final double size;
  final double iconSize;
  final Color? color;
  final Color? backgroundColor;

  const PcIconBadge({
    super.key,
    required this.icon,
    this.size = 36,
    this.iconSize = 18,
    this.color,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? AppColors.accentLive;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? effectiveColor.withOpacity(0.14),
        shape: BoxShape.circle,
        border: Border.all(
          color: effectiveColor.withOpacity(0.25),
          width: 1.0,
        ),
      ),
      child: Center(
        child: Icon(
          icon,
          size: iconSize,
          color: effectiveColor,
        ),
      ),
    );
  }
}
