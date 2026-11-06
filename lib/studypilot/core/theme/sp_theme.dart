import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:study_app/studypilot/core/theme/sp_colors.dart';
import 'package:study_app/studypilot/core/theme/sp_tokens.dart';

/// StudyPilot light/dark themes (Material 3), based on the AI Studio
/// prototype: indigo brand, slate neutrals, Plus Jakarta Sans.
///
/// Text style sizes and component themes the legacy StudyFlow screens rely
/// on (bottom navigation bar, cards, app bar, FAB) are kept so those screens
/// keep their layout. Theme mode still comes from the existing ThemeProvider.
class SpTheme {
  SpTheme._();

  static ThemeData get light => build(Brightness.light);
  static ThemeData get dark => build(Brightness.dark);

  /// [useGoogleFonts] can be turned off in tests (no network font fetching).
  static ThemeData build(Brightness brightness, {bool useGoogleFonts = true}) {
    final isDark = brightness == Brightness.dark;

    final primary = isDark ? SpColors.primaryDarkMode : SpColors.primary;
    final background = isDark ? SpColors.night : SpColors.slate50;
    final surface = isDark ? SpColors.slate900 : Colors.white;
    final surfaceHigh = isDark ? SpColors.slate800 : SpColors.slate100;
    final border = isDark ? SpColors.slate800 : SpColors.slate200;
    final textPrimary = isDark ? SpColors.slate100 : SpColors.slate900;
    final textSecondary = isDark ? SpColors.slate400 : SpColors.slate500;

    final scheme = ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: isDark ? SpColors.indigo950 : Colors.white,
      primaryContainer: isDark ? SpColors.indigo950 : SpColors.indigo50,
      onPrimaryContainer: isDark ? SpColors.indigo300 : SpColors.indigo700,
      secondary: SpColors.emerald600,
      onSecondary: Colors.white,
      tertiary: SpColors.amber500,
      onTertiary: SpColors.slate900,
      error: isDark ? SpColors.rose400 : SpColors.rose600,
      onError: Colors.white,
      surface: surface,
      onSurface: textPrimary,
      onSurfaceVariant: textSecondary,
      surfaceContainerLowest: background,
      surfaceContainerLow: isDark ? SpColors.slate900 : SpColors.slate50,
      surfaceContainer: surfaceHigh,
      surfaceContainerHigh: surfaceHigh,
      surfaceContainerHighest: isDark ? SpColors.slate700 : SpColors.slate200,
      outline: isDark ? SpColors.slate700 : SpColors.slate300,
      outlineVariant: border,
      shadow: Colors.black,
      inverseSurface: isDark ? SpColors.slate100 : SpColors.slate900,
      onInverseSurface: isDark ? SpColors.slate900 : SpColors.slate50,
      inversePrimary: isDark ? SpColors.indigo600 : SpColors.indigo300,
    );

    final base = isDark ? ThemeData.dark() : ThemeData.light();
    final baseText = base.textTheme.apply(
      bodyColor: textPrimary,
      displayColor: textPrimary,
    );
    final fontText = useGoogleFonts
        ? GoogleFonts.plusJakartaSansTextTheme(baseText)
        : baseText;

    // Same sizes as the legacy AppTheme so existing screens keep layout.
    final textTheme = fontText.copyWith(
      displayLarge: fontText.displayLarge?.copyWith(fontSize: 32, fontWeight: FontWeight.w800),
      displayMedium: fontText.displayMedium?.copyWith(fontSize: 28, fontWeight: FontWeight.w800),
      displaySmall: fontText.displaySmall?.copyWith(fontSize: 24, fontWeight: FontWeight.w700),
      headlineMedium: fontText.headlineMedium?.copyWith(fontSize: 20, fontWeight: FontWeight.w700),
      titleLarge: fontText.titleLarge?.copyWith(fontSize: 18, fontWeight: FontWeight.w700),
      titleMedium: fontText.titleMedium?.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
      bodyLarge: fontText.bodyLarge?.copyWith(fontSize: 16),
      bodyMedium: fontText.bodyMedium?.copyWith(fontSize: 14, color: textSecondary),
      bodySmall: fontText.bodySmall?.copyWith(fontSize: 12, color: textSecondary),
      labelLarge: fontText.labelLarge?.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
      labelMedium: fontText.labelMedium?.copyWith(fontSize: 12, fontWeight: FontWeight.w600),
      labelSmall: fontText.labelSmall?.copyWith(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.2),
    );

    const controlShape = RoundedRectangleBorder(borderRadius: SpRadius.control);
    const buttonPadding = EdgeInsets.symmetric(horizontal: 20, vertical: 14);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      primaryColor: primary,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      dividerColor: border,
      textTheme: textTheme,
      iconTheme: IconThemeData(color: primary),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: textTheme.titleLarge?.copyWith(fontSize: 20, color: textPrimary),
      ),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: SpRadius.card,
          side: BorderSide(color: border),
        ),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      // Legacy StudyFlow MainScreen uses BottomNavigationBar.
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primary,
        unselectedItemColor: isDark ? SpColors.slate500 : SpColors.slate400,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      // StudyPilot shell (later phases) will use NavigationBar.
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        height: 64,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => textTheme.labelSmall?.copyWith(
            color: s.contains(WidgetState.selected) ? primary : textSecondary,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            size: 22,
            color: s.contains(WidgetState.selected) ? primary : textSecondary,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: scheme.onPrimary,
        shape: const RoundedRectangleBorder(borderRadius: SpRadius.card),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: scheme.onPrimary,
          elevation: 0,
          minimumSize: const Size(SpSpacing.minTouch, SpSpacing.minTouch),
          padding: buttonPadding,
          shape: controlShape,
          textStyle: textTheme.labelLarge,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(SpSpacing.minTouch, SpSpacing.minTouch),
          padding: buttonPadding,
          shape: controlShape,
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          minimumSize: const Size(SpSpacing.minTouch, SpSpacing.minTouch),
          padding: buttonPadding,
          side: BorderSide(color: isDark ? SpColors.slate700 : SpColors.slate300),
          shape: controlShape,
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          shape: controlShape,
          textStyle: textTheme.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? SpColors.slate900 : Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: isDark ? SpColors.slate500 : SpColors.slate400,
        ),
        border: OutlineInputBorder(
          borderRadius: SpRadius.control,
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: SpRadius.control,
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: SpRadius.control,
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceHigh,
        selectedColor: scheme.primaryContainer,
        labelStyle: textTheme.labelMedium,
        side: BorderSide(color: border),
        shape: const StadiumBorder(),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: scheme.onInverseSurface),
        shape: const RoundedRectangleBorder(borderRadius: SpRadius.control),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: SpRadius.card),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(SpRadius.lg + 8)),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: surfaceHigh,
      ),
    );
  }
}
