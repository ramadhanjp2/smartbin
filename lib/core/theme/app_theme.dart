import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Warna semantik dari desain Stitch "Green Flutter Mobile Interface"
/// (palet #E8F5E9, #A5D6A7, #66BB6A, #1B5E20).
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.background,
    required this.card,
    required this.cardMuted,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.brand,
    required this.brandDark,
    required this.accent,
    required this.accentSoft,
    required this.success,
    required this.warning,
    required this.warningSoft,
    required this.error,
    required this.errorSoft,
    required this.skeleton,
  });

  final Color background;
  final Color card;
  final Color cardMuted;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color brand;
  final Color brandDark;
  final Color accent;
  final Color accentSoft;
  final Color success;
  final Color warning;
  final Color warningSoft;
  final Color error;
  final Color errorSoft;
  final Color skeleton;

  static const light = AppPalette(
    background: Color(0xFFF0FDF1),
    card: Color(0xFFFFFFFF),
    cardMuted: Color(0xFFE8F5E9),
    border: Color(0xFFC8E6C9),
    textPrimary: Color(0xFF1B5E20),
    textSecondary: Color(0xFF2E4732),
    textMuted: Color(0xFF527357),
    brand: Color(0xFF1B5E20),
    brandDark: Color(0xFF00450D),
    accent: Color(0xFF66BB6A),
    accentSoft: Color(0xFFA5D6A7),
    success: Color(0xFF388E3C),
    warning: Color(0xFFF57C00),
    warningSoft: Color(0xFFFFE9D6),
    error: Color(0xFFD32F2F),
    errorSoft: Color(0xFFFFDAD6),
    skeleton: Color(0xFFD9E6DA),
  );

  static const dark = AppPalette(
    background: Color(0xFF0F1A12),
    card: Color(0xFF18261B),
    cardMuted: Color(0xFF213325),
    border: Color(0xFF2E4732),
    textPrimary: Color(0xFFA5D6A7),
    textSecondary: Color(0xFFD7E8D8),
    textMuted: Color(0xFF9DB8A0),
    brand: Color(0xFF2E7D32),
    brandDark: Color(0xFF1B5E20),
    accent: Color(0xFF66BB6A),
    accentSoft: Color(0xFF2F5B36),
    success: Color(0xFF81C784),
    warning: Color(0xFFFFB74D),
    warningSoft: Color(0xFF3D2A12),
    error: Color(0xFFEF9A9A),
    errorSoft: Color(0xFF4A1F1F),
    skeleton: Color(0xFF2A3A2D),
  );

  @override
  AppPalette copyWith() => this;

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      background: l(background, other.background),
      card: l(card, other.card),
      cardMuted: l(cardMuted, other.cardMuted),
      border: l(border, other.border),
      textPrimary: l(textPrimary, other.textPrimary),
      textSecondary: l(textSecondary, other.textSecondary),
      textMuted: l(textMuted, other.textMuted),
      brand: l(brand, other.brand),
      brandDark: l(brandDark, other.brandDark),
      accent: l(accent, other.accent),
      accentSoft: l(accentSoft, other.accentSoft),
      success: l(success, other.success),
      warning: l(warning, other.warning),
      warningSoft: l(warningSoft, other.warningSoft),
      error: l(error, other.error),
      errorSoft: l(errorSoft, other.errorSoft),
      skeleton: l(skeleton, other.skeleton),
    );
  }
}

extension AppPaletteX on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
  TextTheme get text => Theme.of(this).textTheme;
}

class AppTheme {
  /// [fontFamily] hanya untuk test (tanpa unduh font); default Plus Jakarta Sans via google_fonts.
  static ThemeData light({String? fontFamily}) => _build(Brightness.light, AppPalette.light, fontFamily);
  static ThemeData dark({String? fontFamily}) => _build(Brightness.dark, AppPalette.dark, fontFamily);

  static ThemeData _build(Brightness brightness, AppPalette p, String? fontFamily) {
    TextStyle font({double? fontSize, double? height, FontWeight? fontWeight, double? letterSpacing}) => fontFamily != null
        ? TextStyle(fontFamily: fontFamily, fontSize: fontSize, height: height, fontWeight: fontWeight, letterSpacing: letterSpacing)
        : GoogleFonts.plusJakartaSans(fontSize: fontSize, height: height, fontWeight: fontWeight, letterSpacing: letterSpacing);

    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF1B5E20),
      brightness: brightness,
    ).copyWith(primary: p.brand, onPrimary: Colors.white, surface: p.background, error: p.error);

    final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: brightness);
    // google_fonts 9 memakai TextTheme dari `material_ui`, jadi kita hanya mengambil TextStyle-nya.
    final family = font().fontFamily;
    final textTheme = base.textTheme
        .apply(fontFamily: family)
        .copyWith(
          displayLarge: font(fontSize: 40, height: 1.2, fontWeight: FontWeight.w800, letterSpacing: -0.8),
          headlineLarge: font(fontSize: 26, height: 1.3, fontWeight: FontWeight.w700, letterSpacing: -0.26),
          headlineMedium: font(fontSize: 22, height: 1.27, fontWeight: FontWeight.w700),
          headlineSmall: font(fontSize: 18, height: 1.33, fontWeight: FontWeight.w600),
          titleMedium: font(fontSize: 16, height: 1.4, fontWeight: FontWeight.w700),
          bodyLarge: font(fontSize: 16, height: 1.5),
          bodyMedium: font(fontSize: 14, height: 1.43),
          bodySmall: font(fontSize: 12, height: 1.33),
          labelLarge: font(fontSize: 14, height: 1.43, fontWeight: FontWeight.w600, letterSpacing: 0.14),
          labelMedium: font(fontSize: 12, height: 1.33, fontWeight: FontWeight.w600, letterSpacing: 0.24),
          labelSmall: font(fontSize: 11, height: 1.27, fontWeight: FontWeight.w700, letterSpacing: 0.44),
        )
        .apply(bodyColor: p.textSecondary, displayColor: p.textPrimary);

    final pill = RoundedRectangleBorder(borderRadius: BorderRadius.circular(999));

    return base.copyWith(
      scaffoldBackgroundColor: p.background,
      textTheme: textTheme,
      extensions: [p],
      appBarTheme: AppBarTheme(
        backgroundColor: p.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: p.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.brand,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: pill,
          textStyle: textTheme.titleMedium,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.textPrimary,
          side: BorderSide(color: p.border),
          minimumSize: const Size.fromHeight(48),
          shape: pill,
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: p.textPrimary, textStyle: textTheme.labelLarge),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.card,
        hintStyle: textTheme.bodyLarge?.copyWith(color: p.textMuted.withValues(alpha: 0.7)),
        prefixIconColor: p.textMuted,
        suffixIconColor: p.textMuted,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: p.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: p.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: p.brand, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: p.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: p.error, width: 1.6),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.card,
        surfaceTintColor: Colors.transparent,
        indicatorColor: p.accentSoft,
        height: 72,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => textTheme.labelMedium?.copyWith(
            color: s.contains(WidgetState.selected) ? p.textPrimary : p.textMuted,
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(color: s.contains(WidgetState.selected) ? p.textPrimary : p.textMuted)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF28332B),
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dividerTheme: DividerThemeData(color: p.border, thickness: 1, space: 1),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.brand : p.skeleton),
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
    );
  }
}
