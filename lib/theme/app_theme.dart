import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

class AppColors {
  static const navy = Color(0xFF1B2A6B);
  static const yellow = Color(0xFFFFB81C);
  static const red = Color(0xFFC8102E);
  static const bg = Color(0xFFF3F6FC);
  static const ink = Color(0xFF111A3D);
}

// Aplica la fuente Plus Jakarta Sans a un estilo, conservando tamaño y grosor
TextStyle? _f(TextStyle? s) =>
    s == null ? null : GoogleFonts.plusJakartaSans(textStyle: s);

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.navy,
    primary: AppColors.navy,
    secondary: AppColors.yellow,
    error: AppColors.red,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme);
  final t = base.textTheme;

  final textTheme = t
      .copyWith(
        displayLarge: _f(t.displayLarge),
        displayMedium: _f(t.displayMedium),
        displaySmall: _f(t.displaySmall),
        headlineLarge: _f(t.headlineLarge),
        headlineMedium: _f(t.headlineMedium),
        headlineSmall: _f(t.headlineSmall),
        titleLarge: _f(t.titleLarge),
        titleMedium: _f(t.titleMedium),
        titleSmall: _f(t.titleSmall),
        bodyLarge: _f(t.bodyLarge),
        bodyMedium: _f(t.bodyMedium),
        bodySmall: _f(t.bodySmall),
        labelLarge: _f(t.labelLarge),
        labelMedium: _f(t.labelMedium),
        labelSmall: _f(t.labelSmall),
      )
      .apply(bodyColor: AppColors.ink, displayColor: AppColors.ink);

  return base.copyWith(
    scaffoldBackgroundColor: Colors.transparent,
    textTheme: textTheme,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.7),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.navy, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    // Avisos (SnackBar) flotantes y redondeados
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.navy,
      contentTextStyle: GoogleFonts.plusJakartaSans(
          color: Colors.white, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      showCloseIcon: true,
      closeIconColor: Colors.white70,
      actionTextColor: AppColors.yellow,
    ),
    // Ventanas de confirmación (eliminar, cancelar, etc.)
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white.withValues(alpha: 0.97),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titleTextStyle: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w800, fontSize: 20, color: AppColors.ink),
      contentTextStyle:
          GoogleFonts.plusJakartaSans(fontSize: 15, color: AppColors.ink),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: Colors.white.withValues(alpha: 0.97),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}