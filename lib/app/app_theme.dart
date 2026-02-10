import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // === BRAND COLORS (UPDATED) ===
  // Merged from fintech palette: deep blue primary + deep red secondary + warm gold accent
  static const Color brandBlue = Color(0xFF0D3B66); // Deep Blue (primary)
  static const Color brandRed = Color(0xFF0A3A72); // Deep Red (secondary / emphasis)
  static const Color brandGold = Color(0xFFF4C430); // Warm Yellow Accent

  // === BACKGROUNDS ===
  static const Color lightBackground = Color(0xFFF5F7FB);
  static const Color darkBackground = Color(0xFF0B1220);

  // === SURFACES ===
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color darkSurface = Color(0xFF111827);
  static const Color lightSurfaceAlt = Color(0xFFF7FAFF);
  static const Color darkSurfaceAlt = Color(0xFF0F1A2B);

  // === BORDERS ===
  static const Color lightBorder = Color(0xFFE5E7EB);
  static const Color darkBorder = Color(0xFF1F2937);

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final accent = isDark ? brandGold : brandRed;

    final baseScheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: brightness,
    );

    final colorScheme = baseScheme.copyWith(
      primary: accent,
      secondary: accent,
      tertiary: brandBlue,
      background: isDark ? darkBackground : lightBackground,
      surface: isDark ? darkSurface : lightSurface,
    );

    final textTheme = GoogleFonts.manropeTextTheme(
      ThemeData(brightness: brightness).textTheme,
    ).apply(
      bodyColor: colorScheme.onBackground,
      displayColor: colorScheme.onBackground,
    );

    final tokens = isDark ? AppThemeTokens.dark() : AppThemeTokens.light();

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.background,
      textTheme: textTheme.copyWith(
        titleLarge: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        titleMedium: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        titleSmall: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        bodyMedium: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.background,
        surfaceTintColor: colorScheme.background,
        elevation: 0,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: colorScheme.onBackground,
        ),
        iconTheme: IconThemeData(color: colorScheme.onBackground),
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: tokens.border),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: colorScheme.onSurface,
        textColor: colorScheme.onSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: tokens.border,
        thickness: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.surfaceAlt,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: tokens.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: tokens.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.4),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.secondary, // Deep Red CTA
          foregroundColor: Colors.white,
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          side: BorderSide(color: colorScheme.primary),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: tokens.surfaceAlt,
        shape: StadiumBorder(side: BorderSide(color: tokens.border)),
        labelStyle: textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      extensions: [tokens],
    );
  }
}

@immutable
class AppThemeTokens extends ThemeExtension<AppThemeTokens> {
  const AppThemeTokens({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.shadow,
    required this.mutedText,
    required this.heroStart,
    required this.heroEnd,
    required this.success,
    required this.warning,
  });

  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color border;
  final Color shadow;
  final Color mutedText;
  final Color heroStart;
  final Color heroEnd;
  final Color success;
  final Color warning;

  static AppThemeTokens light() {
    return const AppThemeTokens(
      background: AppTheme.lightBackground,
      surface: AppTheme.lightSurface,
      surfaceAlt: AppTheme.lightSurfaceAlt,
      border: AppTheme.lightBorder,
      shadow: Color(0x1A0B1220),
      mutedText: Color(0xFF6B7280),
      heroStart: AppTheme.brandBlue,
      heroEnd: AppTheme.brandRed,
      success: Color(0xFF2ECC71),
      warning: Color(0xFFF4C430),
    );
  }

  static AppThemeTokens dark() {
    return const AppThemeTokens(
      background: AppTheme.darkBackground,
      surface: AppTheme.darkSurface,
      surfaceAlt: AppTheme.darkSurfaceAlt,
      border: AppTheme.darkBorder,
      shadow: Color(0x66000000),
      mutedText: Color(0xFF9CA3AF),
      heroStart: AppTheme.brandBlue,
      heroEnd: AppTheme.brandRed,
      success: Color(0xFF34D399),
      warning: Color(0xFFFBBF24),
    );
  }

  static AppThemeTokens of(BuildContext context) {
    final tokens = Theme.of(context).extension<AppThemeTokens>();
    return tokens ??
        (Theme.of(context).brightness == Brightness.dark
            ? AppThemeTokens.dark()
            : AppThemeTokens.light());
  }

  @override
  AppThemeTokens copyWith({
    Color? background,
    Color? surface,
    Color? surfaceAlt,
    Color? border,
    Color? shadow,
    Color? mutedText,
    Color? heroStart,
    Color? heroEnd,
    Color? success,
    Color? warning,
  }) {
    return AppThemeTokens(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      border: border ?? this.border,
      shadow: shadow ?? this.shadow,
      mutedText: mutedText ?? this.mutedText,
      heroStart: heroStart ?? this.heroStart,
      heroEnd: heroEnd ?? this.heroEnd,
      success: success ?? this.success,
      warning: warning ?? this.warning,
    );
  }

  @override
  AppThemeTokens lerp(ThemeExtension<AppThemeTokens>? other, double t) {
    if (other is! AppThemeTokens) return this;
    return AppThemeTokens(
      background: Color.lerp(background, other.background, t) ?? background,
      surface: Color.lerp(surface, other.surface, t) ?? surface,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t) ?? surfaceAlt,
      border: Color.lerp(border, other.border, t) ?? border,
      shadow: Color.lerp(shadow, other.shadow, t) ?? shadow,
      mutedText: Color.lerp(mutedText, other.mutedText, t) ?? mutedText,
      heroStart: Color.lerp(heroStart, other.heroStart, t) ?? heroStart,
      heroEnd: Color.lerp(heroEnd, other.heroEnd, t) ?? heroEnd,
      success: Color.lerp(success, other.success, t) ?? success,
      warning: Color.lerp(warning, other.warning, t) ?? warning,
    );
  }
}