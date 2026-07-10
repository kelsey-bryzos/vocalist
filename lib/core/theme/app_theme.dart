import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Industrial construction-grade design system.
///
/// Palette:
///   Background  — Charcoal near-black  #1A1C1E
///   Surface     — Dark steel           #24272B
///   Card        — Slightly lifted      #2C3035
///   Accent      — Safety orange/amber  #F59E0B
///   On-accent   — Near black           #0F0F0F
///   Text        — Off-white            #E8EAED
///   Subtle text — Steel gray           #8A9099
///   Danger      — Hard red             #EF4444
///
/// Typography:
///   Display/Titles — Rajdhani (condensed, bold, industrial)
///   Body/UI        — Inter (clean, legible)
class AppTheme {
  AppTheme._();

  // ── Brand colors ────────────────────────────────────────────────────────────
  static const _bg = Color(0xFF1A1C1E);
  static const _surface = Color(0xFF24272B);
  static const _card = Color(0xFF2C3035);
  static const _accent = Color(0xFFF59E0B); // safety amber
  static const _accentDim = Color(0xFF78500A);
  static const _onAccent = Color(0xFF0F0F0F);
  static const _text = Color(0xFFE8EAED);
  static const _textMuted = Color(0xFF8A9099);
  static const _divider = Color(0xFF363B41);
  static const _danger = Color(0xFFEF4444);

  // ── Color scheme ─────────────────────────────────────────────────────────────
  static const _cs = ColorScheme(
    brightness: Brightness.dark,
    primary: _accent,
    onPrimary: _onAccent,
    primaryContainer: _accentDim,
    onPrimaryContainer: _accent,
    secondary: Color(0xFF5C6BC0), // steel blue for secondary actions
    onSecondary: _text,
    secondaryContainer: Color(0xFF1E2340),
    onSecondaryContainer: Color(0xFFB0BEF8),
    tertiary: Color(0xFF4CAF7D), // site-green for success
    onTertiary: Color(0xFF0F0F0F),
    tertiaryContainer: Color(0xFF0D2B1A),
    onTertiaryContainer: Color(0xFF6EE7A8),
    error: _danger,
    onError: _text,
    errorContainer: Color(0xFF3B0E0E),
    onErrorContainer: Color(0xFFFCA5A5),
    surface: _surface,
    onSurface: _text,
    surfaceContainerHighest: _card,
    onSurfaceVariant: _textMuted,
    outline: _divider,
    outlineVariant: Color(0xFF2A2F35),
    shadow: Color(0xFF000000),
    inverseSurface: _text,
    onInverseSurface: _bg,
    inversePrimary: _accentDim,
    surfaceTint: Colors.transparent,
  );

  // ── Text styles ──────────────────────────────────────────────────────────────
  static TextTheme _buildTextTheme() {
    final body = GoogleFonts.interTextTheme().apply(
      bodyColor: _text,
      displayColor: _text,
    );

    // Override display/headline/title sizes with Rajdhani
    final rajdhani = GoogleFonts.rajdhaniTextTheme().apply(
      bodyColor: _text,
      displayColor: _text,
    );

    return body.copyWith(
      // Large screen titles — Rajdhani Bold
      displayLarge: rajdhani.displayLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 1.0,
        color: _text,
      ),
      displayMedium: rajdhani.displayMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: _text,
      ),
      displaySmall: rajdhani.displaySmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
        color: _text,
      ),
      headlineLarge: rajdhani.headlineLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
        color: _text,
      ),
      headlineMedium: rajdhani.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
        color: _text,
      ),
      headlineSmall: rajdhani.headlineSmall?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: _text,
      ),
      titleLarge: rajdhani.titleLarge?.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
        color: _text,
      ),
      titleMedium: rajdhani.titleMedium?.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
        color: _text,
      ),
      titleSmall: rajdhani.titleSmall?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: _text,
      ),
      // Body — Inter (clean legibility for note content)
      bodyLarge: body.bodyLarge?.copyWith(color: _text),
      bodyMedium: body.bodyMedium?.copyWith(color: _text),
      bodySmall: body.bodySmall?.copyWith(color: _textMuted),
      labelLarge: body.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
        color: _text,
      ),
      labelMedium: body.labelMedium?.copyWith(color: _textMuted),
      labelSmall: body.labelSmall?.copyWith(color: _textMuted),
    );
  }

  static ThemeData build() {
    final tt = _buildTextTheme();

    return ThemeData(
      colorScheme: _cs,
      useMaterial3: true,
      scaffoldBackgroundColor: _bg,
      textTheme: tt,

      // ── App bar ─────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: _bg,
        foregroundColor: _text,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.rajdhani(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: _text,
        ),
        iconTheme: const IconThemeData(color: _text),
        actionsIconTheme: const IconThemeData(color: _textMuted),
      ),

      // ── Bottom navigation bar ────────────────────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        height: 68,
        backgroundColor: _surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: _accent.withValues(alpha: 0.18),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: _accent, size: 24);
          }
          return const IconThemeData(color: _textMuted, size: 22);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final base = GoogleFonts.rajdhani(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          );
          if (states.contains(WidgetState.selected)) {
            return base.copyWith(color: _accent);
          }
          return base.copyWith(color: _textMuted);
        }),
        overlayColor: WidgetStateProperty.all(Colors.transparent),
      ),

      // ── Cards ────────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        elevation: 0,
        color: _card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: _divider, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),

      // ── Dividers ─────────────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: _divider,
        thickness: 1,
        space: 1,
      ),

      // ── Input fields ──────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _bg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _accent, width: 2),
        ),
        hintStyle: const TextStyle(color: _textMuted),
        labelStyle: const TextStyle(color: _textMuted),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),

      // ── Buttons ───────────────────────────────────────────────────────────
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _accent,
          foregroundColor: _onAccent,
          textStyle: GoogleFonts.rajdhani(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 0,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _accent,
          textStyle: GoogleFonts.rajdhani(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _accent,
          side: const BorderSide(color: _accent),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),

      // ── FAB ──────────────────────────────────────────────────────────────
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: _accent,
        foregroundColor: _onAccent,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      // ── Chips ─────────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: _card,
        selectedColor: _accentDim,
        labelStyle: const TextStyle(color: _text, fontSize: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: const BorderSide(color: _divider),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      ),

      // ── Bottom sheets ─────────────────────────────────────────────────────
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: _surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: _textMuted,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),

      // ── Dialogs ───────────────────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: _surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        titleTextStyle: GoogleFonts.rajdhani(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: _text,
        ),
      ),

      // ── List tiles ────────────────────────────────────────────────────────
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16),
        textColor: _text,
        iconColor: _textMuted,
        tileColor: Colors.transparent,
      ),

      // ── Popup menus ───────────────────────────────────────────────────────
      popupMenuTheme: PopupMenuThemeData(
        color: _card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: _divider),
        ),
        textStyle: const TextStyle(color: _text),
      ),

      // ── Icon buttons ──────────────────────────────────────────────────────
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: _textMuted,
        ),
      ),

      // ── Progress indicator ────────────────────────────────────────────────
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: _accent,
      ),

      // ── Switch / checkbox ─────────────────────────────────────────────────
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? _accent : Colors.transparent),
        checkColor: WidgetStateProperty.all(_onAccent),
        side: const BorderSide(color: _textMuted, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
      ),
    );
  }

  // Convenience accessors for one-off use in widgets
  static const accent = _accent;
  static const textMuted = _textMuted;
  static const cardColor = _card;
  static const surfaceColor = _surface;
  static const bgColor = _bg;
  static const dividerColor = _divider;
  static const dangerColor = _danger;
}
