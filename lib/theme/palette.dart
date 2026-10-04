import 'package:flutter/material.dart';

/// color-mix(in srgb, [c] [pct]%, transparent)
Color alphaPct(Color c, double pct) =>
    c.withAlpha((c.alpha * pct).round().clamp(0, 255).toInt());

/// color-mix(in srgb, [a] [pct]%, [b])
Color mixSrgb(Color a, double pct, Color b) => Color.lerp(b, a, pct)!;

/// The website's final "green redesign" tokens (light + dark).
class AppPalette extends ThemeExtension<AppPalette> {
  final bool isDark;
  final Color ink900, ink800, ink700, ink600, ink500;
  final Color line, textHi, textMid, textLow;
  final Color gold, goldDim, teal;

  const AppPalette._({
    required this.isDark,
    required this.ink900,
    required this.ink800,
    required this.ink700,
    required this.ink600,
    required this.ink500,
    required this.line,
    required this.textHi,
    required this.textMid,
    required this.textLow,
    required this.gold,
    required this.goldDim,
    required this.teal,
  });

  static const red = Color(0xFFE5484D);
  static const orange = Color(0xFFF2994A);
  static const yellow = Color(0xFFF2C94C);
  static const green = Color(0xFF3FBF9F);

  static const lightPalette = AppPalette._(
    isDark: false,
    ink900: Color(0xFFE7F0E9),
    ink800: Color(0xFFF5F9F5),
    ink700: Color(0xFFFFFFFF),
    ink600: Color(0xFFDCEBE0),
    ink500: Color(0xFFA9C5B0),
    line: Color.fromRGBO(18, 76, 43, .18),
    textHi: Color(0xFF123C25),
    textMid: Color(0xFF3E624B),
    textLow: Color(0xFF68836F),
    gold: Color(0xFF2F8B57),
    goldDim: Color(0xFF1E6840),
    teal: Color(0xFF176B3C),
  );

  static const darkPalette = AppPalette._(
    isDark: true,
    ink900: Color(0xFF06150C),
    ink800: Color(0xFF0A2113),
    ink700: Color(0xFF10351F),
    ink600: Color(0xFF174A2B),
    ink500: Color(0xFF2B6942),
    line: Color.fromRGBO(190, 230, 201, .18),
    textHi: Color(0xFFEFF9F0),
    textMid: Color(0xFFB9D7BF),
    textLow: Color(0xFF80AA8A),
    gold: Color(0xFF72C58C),
    goldDim: Color(0xFF459765),
    teal: Color(0xFF9ADB9F),
  );

  @override
  AppPalette copyWith() => this;

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) =>
      t < 0.5 ? this : (other as AppPalette? ?? this);

  /// Score band colour: 8+ green, 5-7 yellow, 3-4 orange, else red.
  static Color bandColor(int score) => score >= 8
      ? green
      : score >= 5
          ? yellow
          : score >= 3
              ? orange
              : red;

  static String bandName(int score) => score >= 8
      ? 'green'
      : score >= 5
          ? 'yellow'
          : score >= 3
              ? 'orange'
              : 'red';

  static Color statusColor(String? status) {
    switch ((status ?? '').toUpperCase()) {
      case 'THRIVING':
        return green;
      case 'BALANCING':
        return yellow;
      case 'STRUGGLING':
        return orange;
      default:
        return red;
    }
  }

  /// Transparent when the priority is unknown (website renders an unstyled badge).
  static Color priorityColor(String? p) {
    switch (p) {
      case 'URGENT':
        return red;
      case 'HIGH':
      case 'MODERATE':
        return orange;
      case 'MAINTAIN':
        return green;
      default:
        return const Color(0x00000000);
    }
  }
}

extension PaletteX on BuildContext {
  AppPalette get pal => Theme.of(this).extension<AppPalette>()!;
}
