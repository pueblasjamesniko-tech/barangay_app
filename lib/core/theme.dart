import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const navy = Color(0xFF0B2D6B);
  static const navyDark = Color(0xFF082250);
  static const navyLight = Color(0xFF123E8C);
  static const navySoft = Color(0xFFEAF0FB);
  static const gold = Color(0xFFF5A623);
  static const goldDark = Color(0xFF9A5B00);
  static const bg = Color(0xFFF5F7FB);
  static const text = Color(0xFF14213D);
  static const muted = Color(0xFF5B6B82);
  static const border = Color(0xFFE1E7F0);
  static const green = Color(0xFF1F7A45);
  static const red = Color(0xFFC23B3B);
  static const softBlue = Color(0xFFE3ECFA);
  static const softGold = Color(0xFFFFF3D9);
  static const softGreen = Color(0xFFE2F4EA);
  static const softRed = Color(0xFFFCE8E8);
  static const errorOnDark = Color(0xFFFFC2C2);
}

/// Text styles used everywhere, so sizes stay consistent and readable.
class AppText {
  static TextStyle get title => GoogleFonts.poppins(
      fontSize: 21,
      fontWeight: FontWeight.w700,
      color: AppColors.text,
      height: 1.25);

  static TextStyle get heading => GoogleFonts.poppins(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: AppColors.text,
      height: 1.3);

  static TextStyle get label => GoogleFonts.poppins(
      fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.text);

  static TextStyle get body =>
      GoogleFonts.poppins(fontSize: 14.5, color: AppColors.text, height: 1.45);

  static TextStyle get small =>
      GoogleFonts.poppins(fontSize: 13, color: AppColors.muted, height: 1.4);

  static TextStyle get caption =>
      GoogleFonts.poppins(fontSize: 12, color: AppColors.muted);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: AppColors.navy).copyWith(
    primary: AppColors.navy,
    onPrimary: Colors.white,
    secondary: AppColors.gold,
    onSecondary: AppColors.navy,
    error: AppColors.red,
  );
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
    dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      height: 68,
      indicatorColor: AppColors.navySoft,
      labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>((states) {
        final sel = states.contains(WidgetState.selected);
        return GoogleFonts.poppins(
          fontSize: 11.5,
          fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
          color: sel ? AppColors.navy : AppColors.muted,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith<IconThemeData?>((states) {
        final sel = states.contains(WidgetState.selected);
        return IconThemeData(
            size: 26, color: sel ? AppColors.navy : AppColors.muted);
      }),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.navy,
      contentTextStyle:
          GoogleFonts.poppins(fontSize: 13.5, color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
