import 'package:flutter/material.dart';

enum AppThemeMode {
  cyberDark,
  amoledBlack,
  midnightBlue,
}

class AppColors {
  // Brand accents
  static const Color cyan = Color(0xFF00F0FF);
  static const Color violet = Color(0xFF8B5CF6);
  static const Color magenta = Color(0xFFFF007A);
  static const Color emerald = Color(0xFF10B981);
  static const Color amber = Color(0xFFF59E0B);
  static const Color red = Color(0xFFEF4444);

  // Cyber Dark Theme (Default)
  static const Color cyberBackground = Color(0xFF0A0E17);
  static const Color cyberSurface = Color(0xFF131B2A);
  static const Color cyberCard = Color(0xFF182236);
  static const Color cyberBorder = Color(0xFF25334D);

  // Semantic Control Panel & Cockpit Tokens
  static const Color panelBackground = Color(0xFF0F1218);
  static const Color panelSurface = Color(0xFF131720);
  static const Color panelBorder = Color(0xFF1F2633);
  static const Color metricNormal = Color(0xFF8A93A6); // Calm neutral slate for normal readouts
  static const Color accentLive = Color(0xFF3DE8C9);   // Signature connected teal
  static const Color warningAmber = Color(0xFFF5A623); // Warning threshold >= 80%
  static const Color criticalRed = Color(0xFFE5484D);  // Critical threshold >= 90%
  static const Color buttonSurface = Color(0xFF181D27); // Solid tactile button fill
  static const Color buttonBorder = Color(0xFF262E3E);  // Tactile button border

  /// Evaluates 0-100% metrics and returns the semantic alert color
  static Color getMetricColor(double percent) {
    if (percent >= 90.0) return criticalRed;
    if (percent >= 80.0) return warningAmber;
    return metricNormal;
  }

  // AMOLED Black Theme
  static const Color amoledBackground = Color(0xFF000000);
  static const Color amoledSurface = Color(0xFF0D0D0D);
  static const Color amoledCard = Color(0xFF141414);
  static const Color amoledBorder = Color(0xFF242424);

  // Midnight Blue Theme
  static const Color midnightBackground = Color(0xFF060B19);
  static const Color midnightSurface = Color(0xFF0E1626);
  static const Color midnightCard = Color(0xFF152238);
  static const Color midnightBorder = Color(0xFF1F3252);
}

class AppTheme {
  static ThemeData getTheme(AppThemeMode mode) {
    Color bg;
    Color surface;
    Color card;
    Color border;

    switch (mode) {
      case AppThemeMode.amoledBlack:
        bg = AppColors.amoledBackground;
        surface = AppColors.amoledSurface;
        card = AppColors.amoledCard;
        border = AppColors.amoledBorder;
        break;
      case AppThemeMode.midnightBlue:
        bg = AppColors.midnightBackground;
        surface = AppColors.midnightSurface;
        card = AppColors.midnightCard;
        border = AppColors.midnightBorder;
        break;
      case AppThemeMode.cyberDark:
      default:
        bg = AppColors.cyberBackground;
        surface = AppColors.cyberSurface;
        card = AppColors.cyberCard;
        border = AppColors.cyberBorder;
        break;
    }

    final colorScheme = ColorScheme.dark(
      surface: surface,
      primary: AppColors.cyan,
      secondary: AppColors.violet,
      tertiary: AppColors.emerald,
      error: AppColors.red,
      outline: border,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bg,
      colorScheme: colorScheme,
      cardColor: card,
      dividerColor: border,
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: surface,
        selectedIconTheme: const IconThemeData(color: AppColors.cyan, size: 24),
        unselectedIconTheme: IconThemeData(color: Colors.white.withOpacity(0.5), size: 22),
        selectedLabelTextStyle: const TextStyle(
          color: AppColors.cyan,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: Colors.white.withOpacity(0.5),
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
        indicatorColor: AppColors.cyan.withOpacity(0.15),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        elevation: 8,
        height: 65,
        indicatorColor: AppColors.cyan.withOpacity(0.2),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              color: AppColors.cyan,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            );
          }
          return TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 11,
            fontWeight: FontWeight.w400,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.cyan, size: 22);
          }
          return IconThemeData(color: Colors.white.withOpacity(0.5), size: 20);
        }),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.cyan,
        inactiveTrackColor: Colors.white.withOpacity(0.12),
        thumbColor: Colors.white,
        overlayColor: AppColors.cyan.withOpacity(0.2),
        trackHeight: 6,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
