import 'package:flutter/material.dart';

class PosColors {
  static const Color primary = Color(0xFF007A68);
  static const Color primaryDark = Color(0xFF063F39);
  static const Color primarySoft = Color(0xFFE6F5F1);
  static const Color accent = Color(0xFFF59E0B);
  static const Color accentSoft = Color(0xFFFFF4D6);
  static const Color background = Color(0xFFF7F8F4);
  static const Color surface = Colors.white;
  static const Color surfaceWarm = Color(0xFFFCFDF9);
  static const Color slate = Color(0xFF172126);
  static const Color muted = Color(0xFF637171);
  static const Color mutedSoft = Color(0xFFEEF2EF);
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFDC2626);
  static const Color info = Color(0xFF2563EB);
  static const Color purple = Color(0xFF7C3AED);
  static const Color line = Color(0xFFE4E9E4);
  static const Color lineStrong = Color(0xFFD7DED8);
}

class AppTheme {
  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: PosColors.primary,
      primary: PosColors.primary,
      secondary: PosColors.accent,
      surface: PosColors.surface,
      error: PosColors.danger,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: PosColors.background,
      fontFamily: 'Roboto',
      textTheme: const TextTheme(
        displaySmall: TextStyle(
          fontSize: 29,
          fontWeight: FontWeight.w800,
          color: PosColors.slate,
          height: 1.08,
        ),
        headlineMedium: TextStyle(
          fontSize: 23,
          fontWeight: FontWeight.w800,
          color: PosColors.slate,
          height: 1.12,
        ),
        titleLarge: TextStyle(
          fontSize: 18.5,
          fontWeight: FontWeight.w800,
          color: PosColors.slate,
          height: 1.15,
        ),
        titleMedium: TextStyle(
          fontSize: 14.2,
          fontWeight: FontWeight.w700,
          color: PosColors.slate,
          height: 1.2,
        ),
        bodyLarge: TextStyle(
          fontSize: 14.2,
          color: PosColors.slate,
          height: 1.36,
        ),
        bodyMedium: TextStyle(
          fontSize: 12.6,
          color: PosColors.muted,
          height: 1.36,
        ),
        bodySmall: TextStyle(
          fontSize: 11.5,
          color: PosColors.muted,
          height: 1.25,
        ),
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: PosColors.background,
        foregroundColor: PosColors.slate,
      ),
      cardTheme: CardThemeData(
        elevation: 1.5,
        shadowColor: const Color(0x1A0F172A),
        color: PosColors.surface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: PosColors.line),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: PosColors.surfaceWarm,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: PosColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: PosColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: PosColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: PosColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: PosColors.danger, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        labelStyle: const TextStyle(color: PosColors.muted),
        hintStyle: const TextStyle(color: PosColors.muted),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(46, 44),
          elevation: 0.5,
          shadowColor: const Color(0x1A006C5B),
          backgroundColor: PosColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          textStyle: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(46, 44),
          foregroundColor: PosColors.primary,
          backgroundColor: PosColors.surface,
          side: const BorderSide(color: PosColors.lineStrong),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          textStyle: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: PosColors.surface,
        elevation: 10,
        shadowColor: const Color(0x140F172A),
        indicatorColor: PosColors.primarySoft,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: PosColors.slate,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: selected ? 24 : 23,
            color: selected ? PosColors.primary : PosColors.slate,
          );
        }),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: PosColors.surface,
        selectedIconTheme: IconThemeData(color: PosColors.primary, size: 24),
        unselectedIconTheme: IconThemeData(color: PosColors.muted, size: 23),
        selectedLabelTextStyle: TextStyle(
          color: PosColors.primary,
          fontWeight: FontWeight.w800,
          fontSize: 13,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: PosColors.muted,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
        indicatorColor: PosColors.primarySoft,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return PosColors.primarySoft;
            }
            return PosColors.surface;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return PosColors.primary;
            return PosColors.slate;
          }),
          side: WidgetStateProperty.all(
            const BorderSide(color: PosColors.line),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          textStyle: WidgetStateProperty.all(
            const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return PosColors.primary;
          return PosColors.muted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return PosColors.primary.withValues(alpha: 0.24);
          }
          return PosColors.mutedSoft;
        }),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: PosColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: PosColors.surface,
        modalBackgroundColor: PosColors.surface,
        showDragHandle: true,
        dragHandleColor: PosColors.lineStrong,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: PosColors.slate,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
