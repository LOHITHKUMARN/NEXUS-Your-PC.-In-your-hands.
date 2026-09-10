import 'package:flutter/material.dart';
import 'package:pc_control_center/core/theme/app_theme.dart';

class CustomSliderCard extends StatelessWidget {
  final String title;
  final int value; // 0 to 100
  final IconData icon;
  final ValueChanged<int> onChanged;
  final VoidCallback? onNudgeDown;
  final VoidCallback? onNudgeUp;
  final Color? accentColor;
  final Widget? trailing;

  const CustomSliderCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.onChanged,
    this.onNudgeDown,
    this.onNudgeUp,
    this.accentColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? AppColors.cyan;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.panelBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.panelBorder, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  if (trailing != null) ...[
                    trailing!,
                    const SizedBox(width: 8),
                  ],
                  Text(
                    '$value%',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: color,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (onNudgeDown != null)
                IconButton(
                  onPressed: onNudgeDown,
                  icon: const Icon(Icons.remove_circle_outline_rounded, size: 22),
                  color: Colors.white.withOpacity(0.6),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: color,
                    inactiveTrackColor: const Color(0xFF222A38),
                    trackHeight: 6.0,
                    thumbColor: Colors.white,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9.0),
                    overlayColor: color.withOpacity(0.25),
                  ),
                  child: Slider(
                    value: value.toDouble().clamp(0.0, 100.0),
                    min: 0,
                    max: 100,
                    onChanged: (v) => onChanged(v.round()),
                  ),
                ),
              ),
              if (onNudgeUp != null)
                IconButton(
                  onPressed: onNudgeUp,
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 22),
                  color: Colors.white.withOpacity(0.6),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
