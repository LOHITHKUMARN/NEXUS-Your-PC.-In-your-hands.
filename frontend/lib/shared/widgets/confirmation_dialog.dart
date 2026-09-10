import 'package:flutter/material.dart';
import 'package:pc_control_center/core/theme/app_theme.dart';
import 'package:pc_control_center/shared/widgets/glass_card.dart';

class SafetyActionDialog extends StatelessWidget {
  final String title;
  final String description;
  final String confirmText;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onConfirm;

  const SafetyActionDialog({
    super.key,
    required this.title,
    required this.description,
    required this.confirmText,
    required this.icon,
    this.accentColor = AppColors.red,
    required this.onConfirm,
  });

  static Future<bool?> show({
    required BuildContext context,
    required String title,
    required String description,
    required String confirmText,
    required IconData icon,
    Color accentColor = AppColors.red,
    required VoidCallback onConfirm,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => SafetyActionDialog(
        title: title,
        description: description,
        confirmText: confirmText,
        icon: icon,
        accentColor: accentColor,
        onConfirm: () {
          Navigator.pop(ctx, true);
          onConfirm();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: GlassCard(
        borderColor: accentColor.withOpacity(0.5),
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(color: accentColor.withOpacity(0.4), width: 1.5),
              ),
              child: Icon(icon, color: accentColor, size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withOpacity(0.7),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            // Thumb reachable buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white.withOpacity(0.8),
                      side: BorderSide(color: Colors.white.withOpacity(0.2)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      elevation: 4,
                      shadowColor: accentColor.withOpacity(0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: onConfirm,
                    child: Text(
                      confirmText,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
