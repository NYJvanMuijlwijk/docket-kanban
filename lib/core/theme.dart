import 'package:flutter/material.dart';

// ── Palette ────────────────────────────────────────────────────────────
// Deep cool neutrals with a warm amber accent. Hand-tuned for contrast
// between background → column → card surfaces, avoiding the generic
// M3-seeded look.

const _accent = Color(0xFFD4A054); // warm amber — actions, focus
const _accentDim = Color(0xFF8B6B3A); // muted amber — secondary, badges

const _background = Color(0xFF0F1114); // near-black with a cool tint
const _surface = Color(0xFF151719); // base surface (Scaffold)
const _surfaceContainerLowest = Color(0xFF191C1F);
const _surfaceContainerLow = Color(0xFF1C1F23); // column background
const _surfaceContainer = Color(0xFF22262B);
const _surfaceContainerHigh = Color(0xFF282D33); // card background
const _surfaceContainerHighest = Color(0xFF2E343B);

const _onSurface = Color(0xFFE2E4E8); // primary text
const _onSurfaceVariant = Color(0xFF8B919A); // secondary text, icons
const _outline = Color(0xFF3A4049); // borders, dividers
const _outlineVariant = Color(0xFF2A2F36);

const _error = Color(0xFFE5736E); // warm red — destructive
const _onError = Color(0xFF1A0F0F);
const _errorContainer = Color(0xFF3D1F1D);

// ── Column accent palette ─────────────────────────────────────────────
// Six muted colors that sit comfortably against dark surfaces.
// Deterministic rotation: column index % 6 picks the accent.
// Kept desaturated to avoid fighting the zen aesthetic — these are
// wayfinding cues, not primary UI chrome.
const _columnAccents = <Color>[
  Color(0xFF7CA8C6), // steel blue
  Color(0xFF8EBD9E), // sage green
  Color(0xFFC49A6C), // warm clay
  Color(0xFFB08FC2), // muted lavender
  Color(0xFFC27878), // dusty rose
  Color(0xFF7AB5A0), // seafoam
];

/// Returns a muted accent color for a column based on its position index.
/// Deterministic: same index always yields same color (modulo palette size).
Color columnAccentColor(int index) =>
    _columnAccents[index % _columnAccents.length];

/// App theme — Material 3, dark-mode-first, minimal/zen aesthetic.
///
/// Custom [ColorScheme.dark] for deliberate surface layering and a
/// warm amber accent that creates chromatic tension against cool neutrals.
ThemeData buildDarkTheme() {
  const colorScheme = ColorScheme.dark(
    primary: _accent,
    onPrimary: Color(0xFF1A1408),
    primaryContainer: _accentDim,
    onPrimaryContainer: Color(0xFFF5E6CC),
    secondary: _accentDim,
    onSecondary: Color(0xFFF0E0C8),
    surface: _surface,
    onSurface: _onSurface,
    onSurfaceVariant: _onSurfaceVariant,
    surfaceContainerLowest: _surfaceContainerLowest,
    surfaceContainerLow: _surfaceContainerLow,
    surfaceContainer: _surfaceContainer,
    surfaceContainerHigh: _surfaceContainerHigh,
    surfaceContainerHighest: _surfaceContainerHighest,
    outline: _outline,
    outlineVariant: _outlineVariant,
    error: _error,
    onError: _onError,
    errorContainer: _errorContainer,
    onErrorContainer: Color(0xFFF5C8C6),
  );

  final textTheme = _buildTextTheme(colorScheme);

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: _background,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: _background,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: textTheme.titleLarge,
    ),
    cardTheme: const CardThemeData(
      elevation: 0,
      margin: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      color: _surfaceContainerHigh,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: _accent,
        foregroundColor: const Color(0xFF1A1408),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: _accent,
      foregroundColor: Color(0xFF1A1408),
      elevation: 2,
    ),
    dividerTheme: const DividerThemeData(
      color: _outlineVariant,
      thickness: 1,
    ),
    popupMenuTheme: const PopupMenuThemeData(
      color: _surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: _surfaceContainerHighest,
      contentTextStyle: const TextStyle(color: _onSurface),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      behavior: SnackBarBehavior.floating,
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: _surfaceContainer,
      surfaceTintColor: Colors.transparent,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: _surfaceContainer,
      surfaceTintColor: Colors.transparent,
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _accent, width: 1.5),
      ),
      labelStyle: const TextStyle(color: _onSurfaceVariant),
      floatingLabelStyle: const TextStyle(color: _accent),
    ),
  );
}

ThemeData buildLightTheme() {
  // Light theme kept as auto-generated for now — dark-mode-first.
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorSchemeSeed: const Color(0xFF6B7280),
  );
}

// ── Typography ─────────────────────────────────────────────────────────
// Plus Jakarta Sans — geometric humanist with more character than Inter.
// Major-third scale (~1.2x): 11 → 13 → 16 → 20 → 24.
// Bold headings (w700) contrast with regular body (w400).
// Tight negative letter-spacing on headings for developer-tool density.
// Slightly elevated line-height on body for dark-mode readability.
const _fontFamily = 'PlusJakartaSans';

TextTheme _buildTextTheme(ColorScheme colorScheme) {
  return TextTheme(
    // Display — rare but defined for completeness.
    displayLarge: TextStyle(
      fontFamily: _fontFamily,
      fontWeight: FontWeight.w700,
      letterSpacing: -1,
      color: colorScheme.onSurface,
    ),
    displayMedium: TextStyle(
      fontFamily: _fontFamily,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
      color: colorScheme.onSurface,
    ),
    displaySmall: TextStyle(
      fontFamily: _fontFamily,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.3,
      color: colorScheme.onSurface,
    ),
    // Headlines — error screen, large empty states.
    headlineLarge: TextStyle(
      fontFamily: _fontFamily,
      fontWeight: FontWeight.w700,
      fontSize: 28,
      letterSpacing: -0.5,
      color: colorScheme.onSurface,
    ),
    headlineMedium: TextStyle(
      fontFamily: _fontFamily,
      fontWeight: FontWeight.w600,
      fontSize: 24,
      letterSpacing: -0.3,
      color: colorScheme.onSurface,
    ),
    headlineSmall: TextStyle(
      fontFamily: _fontFamily,
      fontWeight: FontWeight.w600,
      fontSize: 20,
      letterSpacing: -0.2,
      color: colorScheme.onSurface,
    ),
    // Titles — AppBar, sheet headers.
    titleLarge: TextStyle(
      fontFamily: _fontFamily,
      fontWeight: FontWeight.w700,
      fontSize: 20,
      letterSpacing: -0.3,
      color: colorScheme.onSurface,
    ),
    // Column headers (uppercase, wide-tracked).
    titleMedium: TextStyle(
      fontFamily: _fontFamily,
      fontWeight: FontWeight.w700,
      fontSize: 11,
      letterSpacing: 1.2,
      color: colorScheme.onSurfaceVariant,
    ),
    titleSmall: TextStyle(
      fontFamily: _fontFamily,
      fontWeight: FontWeight.w600,
      fontSize: 13,
      letterSpacing: 0.1,
      color: colorScheme.onSurfaceVariant,
    ),
    // Body — card content, descriptions, general text.
    bodyLarge: TextStyle(
      fontFamily: _fontFamily,
      fontWeight: FontWeight.w400,
      fontSize: 16,
      height: 1.5,
      color: colorScheme.onSurface,
    ),
    bodyMedium: TextStyle(
      fontFamily: _fontFamily,
      fontWeight: FontWeight.w400,
      fontSize: 14,
      height: 1.5,
      color: colorScheme.onSurface,
    ),
    bodySmall: TextStyle(
      fontFamily: _fontFamily,
      fontWeight: FontWeight.w400,
      fontSize: 13,
      height: 1.45,
      color: colorScheme.onSurfaceVariant,
    ),
    // Labels — buttons, chips, badges, metadata.
    labelLarge: TextStyle(
      fontFamily: _fontFamily,
      fontWeight: FontWeight.w600,
      fontSize: 14,
      letterSpacing: 0.2,
      color: colorScheme.onSurface,
    ),
    labelMedium: TextStyle(
      fontFamily: _fontFamily,
      fontWeight: FontWeight.w500,
      fontSize: 13,
      letterSpacing: 0.3,
      color: colorScheme.onSurfaceVariant,
    ),
    labelSmall: TextStyle(
      fontFamily: _fontFamily,
      fontWeight: FontWeight.w500,
      fontSize: 11,
      letterSpacing: 0.4,
      fontFeatures: const [FontFeature.tabularFigures()],
      color: colorScheme.onSurfaceVariant,
    ),
  );
}
