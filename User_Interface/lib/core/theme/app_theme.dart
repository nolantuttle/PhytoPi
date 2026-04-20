import 'package:flutter/material.dart';

/// Frutiger Aero-inspired theme for PhytoPi.
///
/// Light: soft mint-white backgrounds, teal-green primary, sky-blue accents,
///        rounded 20px corners, ambient-tinted card shadows.
/// Dark:  deep teal-black backdrop, lighter teal primary, same corner rounding.
///
/// BackdropFilter is intentionally avoided for Pi performance; the glossy feel
/// comes from gradient decoration and elevated card surfaces.
class AppTheme {
  // ── Palette constants ──────────────────────────────────────────────────────
  static const Color _primaryLight = Color(0xFF1B998B);   // teal-green
  static const Color _primaryDark  = Color(0xFF4DB6AC);   // lighter teal
  static const Color _secondary    = Color(0xFF0288D1);   // sky blue
  static const Color _bgLight      = Color(0xFFEBF7F5);   // soft mint-white
  static const Color _bgDark       = Color(0xFF0D1B1E);   // deep teal-black
  static const Color _surfDark     = Color(0xFF1A2E2B);   // surface for dark
  static const Color _cardDark     = Color(0xFF1E3432);   // card for dark

  // ── Shared decoration helpers ──────────────────────────────────────────────

  /// Card shape used everywhere: 20px rounded corners.
  static const ShapeBorder _cardShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(20)),
  );

  static CardThemeData _cardTheme(Color shadow) => CardThemeData(
        elevation: 0,
        shape: _cardShape,
        shadowColor: shadow,
        margin: const EdgeInsets.all(0),
      );

  static InputDecorationTheme _inputTheme(Color fill, Color focused) =>
      InputDecorationTheme(
        filled: true,
        fillColor: fill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: fill),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: fill),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: focused, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      );

  static FilledButtonThemeData _filledButtonTheme(Color bg, Color fg) =>
      FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          elevation: 0,
        ),
      );

  static ElevatedButtonThemeData _elevatedButtonTheme(Color bg, Color fg) =>
      ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      );

  // ── Light theme ────────────────────────────────────────────────────────────
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: _primaryLight,
    scaffoldBackgroundColor: _bgLight,
    cardColor: Colors.white,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _primaryLight,
      brightness: Brightness.light,
      primary: _primaryLight,
      secondary: _secondary,
      surface: Colors.white,
      surfaceContainerLow: const Color(0xFFF0FDFC),
      surfaceContainerHigh: const Color(0xFFD4F0EC),
      background: _bgLight,
    ),

    cardTheme: _cardTheme(_primaryLight.withOpacity(0.12)),

    // AppBar: slightly transparent surface, no divider line
    appBarTheme: AppBarTheme(
      backgroundColor: _bgLight,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: _primaryLight.withOpacity(0.15),
      titleTextStyle: const TextStyle(
        color: Color(0xFF0D3D36),
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
      iconTheme: const IconThemeData(color: Color(0xFF0D3D36)),
    ),

    // NavigationBar (used on some screens)
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white.withOpacity(0.92),
      indicatorColor: _primaryLight.withOpacity(0.18),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _primaryLight);
        }
        return const TextStyle(fontSize: 12, color: Color(0xFF607D8B));
      }),
    ),

    inputDecorationTheme: _inputTheme(
      const Color(0xFFE0F2EF),
      _primaryLight,
    ),

    filledButtonTheme: _filledButtonTheme(_primaryLight, Colors.white),
    elevatedButtonTheme: _elevatedButtonTheme(const Color(0xFFD4F0EC), const Color(0xFF0D3D36)),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: _primaryLight,
        side: const BorderSide(color: _primaryLight),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      ),
    ),

    dividerTheme: DividerThemeData(
      color: _primaryLight.withOpacity(0.15),
      thickness: 1,
    ),

    chipTheme: ChipThemeData(
      backgroundColor: const Color(0xFFE0F2EF),
      selectedColor: _primaryLight.withOpacity(0.25),
      labelStyle: const TextStyle(fontSize: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),

    listTileTheme: const ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
    ),

    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: const Color(0xFF0D3D36),
      contentTextStyle: const TextStyle(color: Colors.white),
    ),

    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 4,
    ),

    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),

    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: _primaryLight,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 4,
    ),
  );

  // ── Dark theme ─────────────────────────────────────────────────────────────
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: _primaryDark,
    scaffoldBackgroundColor: _bgDark,
    cardColor: _cardDark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _primaryDark,
      brightness: Brightness.dark,
      primary: _primaryDark,
      secondary: const Color(0xFF4FC3F7),
      surface: _surfDark,
      surfaceContainerLow: const Color(0xFF152924),
      surfaceContainerHigh: const Color(0xFF1E3A36),
      background: _bgDark,
    ),

    cardTheme: _cardTheme(_primaryDark.withOpacity(0.18)),

    appBarTheme: AppBarTheme(
      backgroundColor: _bgDark,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: _primaryDark.withOpacity(0.2),
      titleTextStyle: const TextStyle(
        color: Color(0xFFB2DFDB),
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
      iconTheme: const IconThemeData(color: Color(0xFFB2DFDB)),
    ),

    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: _surfDark.withOpacity(0.95),
      indicatorColor: _primaryDark.withOpacity(0.22),
    ),

    inputDecorationTheme: _inputTheme(
      const Color(0xFF1E3432),
      _primaryDark,
    ),

    filledButtonTheme: _filledButtonTheme(_primaryDark, const Color(0xFF0D1B1E)),
    elevatedButtonTheme: _elevatedButtonTheme(_surfDark, Colors.white),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: _primaryDark,
        side: BorderSide(color: _primaryDark.withOpacity(0.7)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      ),
    ),

    dividerTheme: DividerThemeData(
      color: _primaryDark.withOpacity(0.2),
      thickness: 1,
    ),

    chipTheme: ChipThemeData(
      backgroundColor: _surfDark,
      selectedColor: _primaryDark.withOpacity(0.3),
      labelStyle: const TextStyle(fontSize: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),

    listTileTheme: const ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
    ),

    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: _surfDark,
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: _cardDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 4,
    ),

    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: _surfDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),

    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: _primaryDark,
      foregroundColor: _bgDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 4,
    ),
  );
}
