import 'package:flutter/material.dart';
import 'package:pc_control_center/core/theme/app_theme.dart';

/// Standard, high-contrast action button used across PC Control Center.
/// Enforces consistent CTA aesthetics and eliminates per-card decorative colors.
class PcActionButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool isOutlined;
  final bool isFullWidth;
  final bool isLoading;
  final Color? customAccent;

  const PcActionButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.isOutlined = false,
    this.isFullWidth = false,
    this.isLoading = false,
    this.customAccent,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null && !isLoading;

    final Widget content;

    if (isOutlined) {
      final style = OutlinedButton.styleFrom(
        backgroundColor: isEnabled ? AppColors.buttonSurface : const Color(0xFF161C26),
        foregroundColor: isEnabled ? (customAccent ?? Colors.white) : const Color(0xFF64748B),
        side: BorderSide(
          color: isEnabled ? (customAccent?.withOpacity(0.5) ?? AppColors.buttonBorder) : const Color(0xFF202836),
          width: 1.2,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      );

      if (isLoading) {
        content = OutlinedButton.icon(
          style: style,
          icon: const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
          ),
          label: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          onPressed: null,
        );
      } else if (icon != null) {
        content = OutlinedButton.icon(
          style: style,
          icon: Icon(icon, size: 16),
          label: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          onPressed: onPressed,
        );
      } else {
        content = OutlinedButton(
          style: style,
          onPressed: onPressed,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
        );
      }
    } else {
      // Solid High-Contrast Neutral CTA
      final style = ElevatedButton.styleFrom(
        backgroundColor: isEnabled ? (customAccent ?? const Color(0xFFE2E8F0)) : const Color(0xFF1E2533),
        foregroundColor: isEnabled ? (customAccent != null ? Colors.white : const Color(0xFF0B0F17)) : const Color(0xFF64748B),
        disabledBackgroundColor: const Color(0xFF1E2533),
        disabledForegroundColor: const Color(0xFF64748B),
        elevation: isEnabled ? 2 : 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      );

      if (isLoading) {
        content = ElevatedButton.icon(
          style: style,
          icon: const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0B0F17)),
          ),
          label: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          onPressed: null,
        );
      } else if (icon != null) {
        content = ElevatedButton.icon(
          style: style,
          icon: Icon(icon, size: 16),
          label: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          onPressed: onPressed,
        );
      } else {
        content = ElevatedButton(
          style: style,
          onPressed: onPressed,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
        );
      }
    }

    if (isFullWidth) {
      return SizedBox(
        width: double.infinity,
        child: content,
      );
    }

    return content;
  }
}
