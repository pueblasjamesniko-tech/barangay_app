import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const navy = Color(0xFF0B2D6B);
  static const navyDark = Color(0xFF082250);
  static const navyLight = Color(0xFF123E8C);
  static const gold = Color(0xFFF5A623);
  static const bg = Color(0xFFF1F5FB);
  static const text = Color(0xFF14213D);
  static const muted = Color(0xFF6B7A90);
  static const border = Color(0xFFDCE4F0);
  static const green = Color(0xFF2E9E5B);
  static const red = Color(0xFFD64545);
  static const softBlue = Color(0xFFDDE9F8);
  static const softGold = Color(0xFFFFF1D6);
  static const softGreen = Color(0xFFDDF3E6);
  static const errorOnDark = Color(0xFFFFC2C2);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: AppColors.navy)
      .copyWith(primary: AppColors.navy, secondary: AppColors.gold);
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.bg,
  );
  return base.copyWith(
    textTheme: GoogleFonts.poppinsTextTheme(base.textTheme)
        .apply(bodyColor: AppColors.text, displayColor: AppColors.text),
    progressIndicatorTheme:
        const ProgressIndicatorThemeData(color: AppColors.navy),
  );
}
