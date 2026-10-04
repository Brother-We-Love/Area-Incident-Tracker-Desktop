import 'package:flutter/material.dart';
import 'palette.dart';

const kFont = 'Arial';
const kFontFallback = <String>['Segoe UI', 'Segoe UI Emoji', 'Segoe UI Symbol'];

ThemeData buildTheme(AppPalette p) {
  final scheme = ColorScheme(
    brightness: p.isDark ? Brightness.dark : Brightness.light,
    primary: p.teal,
    onPrimary: const Color(0xFFF4FFF4),
    secondary: p.gold,
    onSecondary: p.ink900,
    error: AppPalette.red,
    onError: Colors.white,
    surface: p.ink700,
    onSurface: p.textHi,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: kFont,
    fontFamilyFallback: kFontFallback,
    scaffoldBackgroundColor: p.ink800,
    canvasColor: p.ink800,
    dividerColor: p.line,
    extensions: [p],
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: p.textHi,
      selectionColor: alphaPct(p.teal, .35),
      selectionHandleColor: p.teal,
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStatePropertyAll(alphaPct(p.textLow, .55)),
      thickness: const WidgetStatePropertyAll(8),
      radius: const Radius.circular(99),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: p.ink600,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: p.line),
      ),
      textStyle: TextStyle(color: p.textHi, fontSize: 12, fontFamily: kFont),
    ),
    popupMenuTheme: PopupMenuThemeData(color: p.ink800),
  );
}

/// Default body text: 15px / 1.55, colour text-mid.
TextStyle ts(
  BuildContext context, {
  double size = 15,
  FontWeight weight = FontWeight.w400,
  Color? color,
  double height = 1.55,
  double? spacing,
  FontStyle? style,
  TextDecoration? decoration,
}) {
  final p = Theme.of(context).extension<AppPalette>()!;
  return TextStyle(
    fontFamily: kFont,
    fontFamilyFallback: kFontFallback,
    fontSize: size,
    fontWeight: weight,
    color: color ?? p.textMid,
    height: height,
    letterSpacing: spacing,
    fontStyle: style,
    decoration: decoration,
  );
}
