import 'package:flutter/material.dart';

class PosColors {
  static const Color primary = Color(0xFF008C76);
  static const Color primaryDark = Color(0xFF053C36);
  static const Color primarySoft = Color(0xFFE3F4EF);
  static const Color primaryGlow = Color(0xFF11B59A);
  static const Color accent = Color(0xFFF59E0B);
  static const Color accentSoft = Color(0xFFFFF3D6);
  static const Color background = Color(0xFFF5F8F5);
  static const Color surface = Colors.white;
  static const Color surfaceWarm = Color(0xFFFBFCF8);
  static const Color surfaceTinted = Color(0xFFF1F6F2);
  static const Color slate = Color(0xFF111B20);
  static const Color slateSoft = Color(0xFF243038);
  static const Color muted = Color(0xFF5C6B6B);
  static const Color mutedSoft = Color(0xFFEEF2EF);
  static const Color success = Color(0xFF15A34A);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFE0264D);
  static const Color info = Color(0xFF2563EB);
  static const Color purple = Color(0xFF7C3AED);
  static const Color line = Color(0xFFE3E8E4);
  static const Color lineStrong = Color(0xFFD3DBD5);
}

class PosRadii {
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double pill = 999;
}

class PosShadows {
  static List<BoxShadow> get card => const [
    BoxShadow(color: Color(0x0F0F2A1F), blurRadius: 14, offset: Offset(0, 4)),
    BoxShadow(color: Color(0x080F2A1F), blurRadius: 32, offset: Offset(0, 18)),
  ];

  static List<BoxShadow> get raised => const [
    BoxShadow(color: Color(0x140F2A1F), blurRadius: 22, offset: Offset(0, 10)),
  ];

  static List<BoxShadow> get glow => [
    BoxShadow(
      color: PosColors.primary.withValues(alpha: 0.28),
      blurRadius: 26,
      offset: const Offset(0, 14),
    ),
  ];
}

class PosGradients {
  static const LinearGradient brand = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF00A084), Color(0xFF006C5C)],
  );

  static const LinearGradient brandDeep = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0EBFA1), Color(0xFF053C36)],
  );

  static LinearGradient softWash({double opacity = 0.72}) => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      PosColors.primarySoft.withValues(alpha: opacity),
      PosColors.background.withValues(alpha: 0),
    ],
  );

  static LinearGradient cardTint(Color color) => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      color.withValues(alpha: 0.10),
      color.withValues(alpha: 0.02),
      PosColors.surface,
    ],
    stops: const [0, 0.45, 1],
  );
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
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      textTheme: const TextTheme(
        displaySmall: TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w900,
          color: PosColors.slate,
          height: 1.06,
          letterSpacing: 0,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w900,
          color: PosColors.slate,
          height: 1.1,
          letterSpacing: 0,
        ),
        titleLarge: TextStyle(
          fontSize: 18.5,
          fontWeight: FontWeight.w800,
          color: PosColors.slate,
          height: 1.18,
          letterSpacing: 0,
        ),
        titleMedium: TextStyle(
          fontSize: 14.5,
          fontWeight: FontWeight.w700,
          color: PosColors.slate,
          height: 1.22,
        ),
        bodyLarge: TextStyle(
          fontSize: 14.4,
          color: PosColors.slate,
          height: 1.4,
        ),
        bodyMedium: TextStyle(
          fontSize: 12.8,
          color: PosColors.muted,
          height: 1.4,
        ),
        bodySmall: TextStyle(
          fontSize: 11.5,
          color: PosColors.muted,
          height: 1.3,
          fontWeight: FontWeight.w600,
        ),
        labelLarge: TextStyle(
          fontSize: 13.2,
          color: PosColors.slate,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.1,
        ),
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: PosColors.background,
        foregroundColor: PosColors.slate,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shadowColor: const Color(0x140F2A1F),
        color: PosColors.surface,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PosRadii.lg),
          side: const BorderSide(color: PosColors.line),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: PosColors.surfaceWarm,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PosRadii.md),
          borderSide: const BorderSide(color: PosColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PosRadii.md),
          borderSide: const BorderSide(color: PosColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PosRadii.md),
          borderSide: const BorderSide(color: PosColors.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PosRadii.md),
          borderSide: const BorderSide(color: PosColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PosRadii.md),
          borderSide: const BorderSide(color: PosColors.danger, width: 1.6),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        labelStyle: const TextStyle(
          color: PosColors.muted,
          fontWeight: FontWeight.w600,
        ),
        hintStyle: const TextStyle(color: PosColors.muted),
        prefixIconColor: PosColors.muted,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(48, 46),
          elevation: 0,
          shadowColor: Colors.transparent,
          backgroundColor: PosColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PosRadii.sm + 2),
          ),
          textStyle: const TextStyle(
            fontSize: 13.6,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.1,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 46),
          backgroundColor: PosColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PosRadii.sm + 2),
          ),
          textStyle: const TextStyle(
            fontSize: 13.6,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 46),
          foregroundColor: PosColors.primary,
          backgroundColor: PosColors.surface,
          side: const BorderSide(color: PosColors.lineStrong),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PosRadii.sm + 2),
          ),
          textStyle: const TextStyle(
            fontSize: 13.6,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.1,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: PosColors.primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: PosColors.slate,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PosRadii.sm),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 74,
        backgroundColor: PosColors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: const Color(0x140F2A1F),
        indicatorColor: PosColors.primarySoft,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PosRadii.md),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11.6,
            fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
            color: selected ? PosColors.primary : PosColors.slate,
            letterSpacing: 0.1,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: selected ? 25 : 23,
            color: selected ? PosColors.primary : PosColors.muted,
          );
        }),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: PosColors.surface,
        selectedIconTheme: IconThemeData(color: PosColors.primary, size: 24),
        unselectedIconTheme: IconThemeData(color: PosColors.muted, size: 23),
        selectedLabelTextStyle: TextStyle(
          color: PosColors.primary,
          fontWeight: FontWeight.w900,
          fontSize: 13,
          letterSpacing: 0.1,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: PosColors.muted,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
        indicatorColor: PosColors.primarySoft,
        useIndicator: true,
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
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(PosRadii.sm + 2),
            ),
          ),
          textStyle: WidgetStateProperty.all(
            const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: PosColors.surface,
        selectedColor: PosColors.primarySoft,
        side: const BorderSide(color: PosColors.line),
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 12,
          color: PosColors.slate,
        ),
        secondaryLabelStyle: const TextStyle(
          fontWeight: FontWeight.w800,
          color: PosColors.primary,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PosRadii.pill),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return Colors.white;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return PosColors.primary;
          return PosColors.lineStrong;
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      dividerTheme: const DividerThemeData(
        color: PosColors.line,
        thickness: 1,
        space: 1,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: PosColors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PosRadii.xl),
        ),
        titleTextStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w900,
          color: PosColors.slate,
        ),
        contentTextStyle: const TextStyle(
          fontSize: 13.6,
          color: PosColors.muted,
          height: 1.45,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: PosColors.surface,
        modalBackgroundColor: PosColors.surface,
        showDragHandle: true,
        dragHandleColor: PosColors.lineStrong,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: PosColors.slate,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PosRadii.md),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: PosColors.slate,
          borderRadius: BorderRadius.circular(PosRadii.xs + 2),
        ),
        textStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 11.5,
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: PosColors.primary,
        linearTrackColor: PosColors.mutedSoft,
        circularTrackColor: PosColors.mutedSoft,
      ),
    );
  }
}
