import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/palette.dart';
import '../theme/theme.dart';
import 'icons.dart';

// ---------------------------------------------------------------------------
// Responsive helpers (website breakpoints)
// ---------------------------------------------------------------------------
double vw(BuildContext c) => MediaQuery.of(c).size.width;
bool isNarrow(BuildContext c) => vw(c) <= 640;
bool isMobileShell(BuildContext c) => vw(c) <= 900;

bool typingInTextField() {
  final ctx = FocusManager.instance.primaryFocus?.context;
  if (ctx == null) return false;
  return ctx.findAncestorWidgetOfExactType<EditableText>() != null;
}

// ---------------------------------------------------------------------------
// Card (.la-card)
// ---------------------------------------------------------------------------
class LaCard extends StatefulWidget {
  const LaCard({
    super.key,
    required this.child,
    this.padding,
    this.background,
    this.borderColor,
    this.clip = false,
    this.hoverBorder = true,
    this.radius = 6,
  });
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? background;
  final Color? borderColor;
  final bool clip;
  final bool hoverBorder;
  final double radius;

  @override
  State<LaCard> createState() => _LaCardState();
}

class _LaCardState extends State<LaCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final w = vw(context);
    final pad = widget.padding ??
        EdgeInsets.all(isNarrow(context) ? 18 : (w * 0.02).clamp(16.0, 24.0).toDouble());
    final border = widget.borderColor ??
        (_hover && widget.hoverBorder ? mixSrgb(p.teal, .42, p.line) : p.line);
    final deco = BoxDecoration(
      color: widget.background ?? p.ink700,
      borderRadius: BorderRadius.circular(widget.radius),
      border: Border.all(color: border),
      boxShadow: [
        BoxShadow(
          color: p.isDark ? const Color.fromRGBO(0, 0, 0, .18) : const Color.fromRGBO(10, 59, 29, .09),
          offset: Offset(0, p.isDark ? 16 : 10),
          blurRadius: p.isDark ? 30 : 24,
        ),
      ],
    );
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Container(
        decoration: deco,
        clipBehavior: widget.clip ? Clip.antiAlias : Clip.none,
        padding: widget.clip ? null : pad,
        child: widget.child,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Buttons (.btn-gold / .btn-outline-la / .la-btn-danger)
// ---------------------------------------------------------------------------
enum BtnKind { gold, outline, danger }

class LaButton extends StatefulWidget {
  const LaButton({
    super.key,
    this.label,
    this.child,
    this.onTap,
    this.kind = BtnKind.gold,
    this.small = false,
    this.expand = false,
    this.autofocus = false,
    this.focusNode,
    this.minWidth,
    this.leading,
    this.textColor,
    this.borderColor,
    this.tooltip,
  });
  final String? label;
  final Widget? child;
  final VoidCallback? onTap;
  final BtnKind kind;
  final bool small;
  final bool expand;
  final bool autofocus;
  final FocusNode? focusNode;
  final double? minWidth;
  final Widget? leading;
  final Color? textColor;
  final Color? borderColor;
  final String? tooltip;

  @override
  State<LaButton> createState() => _LaButtonState();
}

class _LaButtonState extends State<LaButton> {
  bool _hover = false;
  bool _focus = false;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final enabled = widget.onTap != null;
    Color? bg;
    Gradient? gradient;
    Color fg;
    Border? border;
    FontWeight weight = FontWeight.w400;
    switch (widget.kind) {
      case BtnKind.gold:
        bg = _hover && enabled ? p.gold : p.teal;
        fg = _hover && enabled ? Colors.white : const Color(0xFFF4FFF4);
        weight = FontWeight.w700;
        break;
      case BtnKind.outline:
        bg = _hover && enabled ? p.ink600 : Colors.transparent;
        fg = widget.textColor ?? (_hover && enabled ? p.textHi : p.textMid);
        border = Border.all(
            color: widget.borderColor ?? (_hover && enabled ? p.gold : p.teal));
        break;
      case BtnKind.danger:
        gradient = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF06A6E), Color(0xFFC93B40)]);
        fg = Colors.white;
        weight = FontWeight.w700;
        break;
    }
    final pad = widget.small
        ? const EdgeInsets.symmetric(horizontal: 10, vertical: 5)
        : const EdgeInsets.symmetric(horizontal: 18, vertical: 10);
    final style = TextStyle(
      fontFamily: kFont,
      fontFamilyFallback: kFontFallback,
      fontSize: widget.small ? 12 : 14,
      fontWeight: weight,
      color: fg,
      height: 1.3,
    );
    Widget content = widget.child ??
        Text(widget.label ?? '', style: style, textAlign: TextAlign.center);
    if (widget.leading != null) {
      content = Row(mainAxisSize: MainAxisSize.min, children: [
        widget.leading!,
        const SizedBox(width: 8),
        Flexible(child: content),
      ]);
    }
    Widget box = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      constraints: BoxConstraints(minWidth: widget.minWidth ?? 0),
      padding: pad,
      alignment: widget.expand || widget.minWidth != null ? Alignment.center : null,
      decoration: BoxDecoration(
        color: gradient == null ? bg : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(widget.kind == BtnKind.danger ? 6 : 5),
        border: border,
        boxShadow: _focus
            ? [BoxShadow(color: alphaPct(p.gold, .55), spreadRadius: 2)]
            : null,
      ),
      child: DefaultTextStyle(style: style, child: IconTheme(data: IconThemeData(color: fg), child: content)),
    );
    if (widget.expand) box = SizedBox(width: double.infinity, child: box);
    Widget result = Opacity(
      opacity: enabled ? 1 : .4,
      child: FocusableActionDetector(
        enabled: enabled,
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        mouseCursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onShowHoverHighlight: (v) => setState(() => _hover = v),
        onShowFocusHighlight: (v) => setState(() => _focus = v),
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
            widget.onTap?.call();
            return null;
          }),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: box,
        ),
      ),
    );
    if (widget.tooltip != null) {
      result = Tooltip(message: widget.tooltip!, waitDuration: const Duration(milliseconds: 600), child: result);
    }
    return result;
  }
}

// ---------------------------------------------------------------------------
// Badge, stat tile, headings
// ---------------------------------------------------------------------------
class LaBadge extends StatelessWidget {
  const LaBadge(this.text, {super.key, required this.color, this.bg, this.fontSize = 12, this.minWidth, this.center = false});
  final String text;
  final Color color;
  final Color? bg;
  final double fontSize;
  final double? minWidth;
  final bool center;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minWidth: minWidth ?? 0),
      alignment: center ? Alignment.center : null,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: bg ?? alphaPct(color, .16),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text,
          style: ts(context, size: fontSize, weight: FontWeight.w600, color: color, spacing: .24, height: 1.55)),
    );
  }
}

class LaStat extends StatelessWidget {
  const LaStat({super.key, this.value, this.valueWidget, required this.label, this.valueSize = 30, this.valueColor});
  final String? value;
  final Widget? valueWidget;
  final String label;
  final double valueSize;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: p.ink600,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: p.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          valueWidget ??
              Text(value ?? '',
                  style: ts(context, size: valueSize, weight: FontWeight.w700, color: valueColor ?? p.textHi)),
          const SizedBox(height: 4),
          Text(label.toUpperCase(),
              style: ts(context, size: 11, color: p.teal, spacing: .88)),
        ],
      ),
    );
  }
}

/// .la-topbar: title + subtitle on the left, actions on the right, bottom rule.
class TopBar extends StatelessWidget {
  const TopBar({super.key, required this.title, this.subtitle, this.trailing, this.subtitleWidget});
  final String title;
  final String? subtitle;
  final Widget? subtitleWidget;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final w = vw(context);
    final narrow = isNarrow(context);
    final h1 = narrow ? 30.0 : (w * 0.04).clamp(28.0, 44.0).toDouble();
    final head = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title,
            style: ts(context, size: h1, weight: FontWeight.w700, color: p.textHi, height: 1.05, spacing: -.02 * h1)),
        if (subtitle != null || subtitleWidget != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: subtitleWidget ?? Text(subtitle!, style: ts(context, size: 14, color: p.textLow)),
            ),
          ),
      ],
    );
    return Container(
      margin: EdgeInsets.only(bottom: narrow ? 30 : 30),
      padding: EdgeInsets.only(bottom: narrow ? 18 : 22),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.line))),
      child: LayoutBuilder(builder: (context, c) {
        if (trailing == null) return SizedBox(width: double.infinity, child: head);
        if (narrow || c.maxWidth < 560) {
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            head,
            const SizedBox(height: 12),
            Align(alignment: Alignment.centerLeft, child: trailing!),
          ]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: head),
            const SizedBox(width: 12),
            Flexible(flex: 0, child: trailing!),
          ],
        );
      }),
    );
  }
}

/// Responsive grid used for .la-grid (cols-2/3/5 with the website's breakpoints).
class LaGrid extends StatelessWidget {
  const LaGrid({super.key, required this.cols, required this.children, this.gap = 22, this.minColWidth, this.stretch = false});
  final int cols;
  final List<Widget> children;
  final double gap;
  final double? minColWidth;
  final bool stretch;

  @override
  Widget build(BuildContext context) {
    final w = vw(context);
    var n = cols;
    if (w <= 640) {
      n = 1;
    } else if (w <= 900) {
      if (cols >= 2 && cols <= 4) n = 2;
      if (cols == 5) n = 3;
    } else if (w <= 1180) {
      if (cols == 5) n = 3;
    }
    // Also respect per-column minimum widths from the CSS (minmax(...)).
    return LayoutBuilder(builder: (context, c) {
      final min = minColWidth ?? (cols == 2 ? 280 : cols == 3 ? 200 : cols == 5 ? 140 : 170);
      var cnt = n;
      while (cnt > 1 && (c.maxWidth - gap * (cnt - 1)) / cnt < min) {
        cnt--;
      }
      final rows = <Widget>[];
      for (var i = 0; i < children.length; i += cnt) {
        final slice = children.sublist(i, math.min(i + cnt, children.length));
        final cells = <Widget>[];
        for (var j = 0; j < cnt; j++) {
          if (j > 0) cells.add(SizedBox(width: gap));
          cells.add(Expanded(child: j < slice.length ? slice[j] : const SizedBox.shrink()));
        }
        rows.add(stretch
            ? IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: cells))
            : Row(crossAxisAlignment: CrossAxisAlignment.start, children: cells));
        if (i + cnt < children.length) rows.add(SizedBox(height: gap));
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
    });
  }
}

class ChartHeading extends StatelessWidget {
  const ChartHeading({super.key, required this.kicker, required this.title, this.trailing, this.printStyle = false});
  final String kicker;
  final String title;
  final Widget? trailing;
  final bool printStyle;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(kicker.toUpperCase(),
                    style: ts(context, size: 10, weight: FontWeight.w700, color: p.teal, spacing: 1.2, height: 1.4)),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(title,
                      style: ts(context, size: isNarrow(context) ? 17 : 18, weight: FontWeight.w700, color: p.textHi, height: 1.2)),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 16), trailing!],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Form controls
// ---------------------------------------------------------------------------
class LaLabel extends StatelessWidget {
  const LaLabel(this.text, {super.key, this.hi = true, this.bottom = 6});
  final String text;
  final bool hi;
  final double bottom;
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Text(text,
          style: ts(context, size: 13, weight: FontWeight.w600, color: hi ? p.textHi : p.textMid)),
    );
  }
}

class LaInput extends StatefulWidget {
  const LaInput({
    super.key,
    this.controller,
    this.hint,
    this.icon,
    this.iconWidget,
    this.maxLines = 1,
    this.keyboardType,
    this.readOnly = false,
    this.enabled = true,
    this.onSubmitted,
    this.onTap,
    this.onChanged,
    this.focusNode,
    this.autofocus = false,
    this.obscure = false,
    this.invalid = false,
    this.inputFormatters,
    this.trailing,
    this.rounded = 5,
    this.fill,
    this.textInputAction,
  });
  final TextEditingController? controller;
  final String? hint;
  final String? icon;
  final Widget? iconWidget;
  final int maxLines;
  final TextInputType? keyboardType;
  final bool readOnly;
  final bool enabled;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool obscure;
  final bool invalid;
  final List<TextInputFormatter>? inputFormatters;
  final Widget? trailing;
  final double rounded;
  final Color? fill;
  final TextInputAction? textInputAction;

  @override
  State<LaInput> createState() => _LaInputState();
}

class _LaInputState extends State<LaInput> {
  late FocusNode _node;
  bool _ownNode = false;
  bool _focus = false;

  @override
  void initState() {
    super.initState();
    if (widget.focusNode != null) {
      _node = widget.focusNode!;
    } else {
      _node = FocusNode();
      _ownNode = true;
    }
    _node.addListener(_onFocus);
  }

  void _onFocus() {
    if (mounted && _focus != _node.hasFocus) setState(() => _focus = _node.hasFocus);
  }

  @override
  void dispose() {
    _node.removeListener(_onFocus);
    if (_ownNode) _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final hasIcon = widget.icon != null || widget.iconWidget != null;
    final multi = widget.maxLines > 1;
    final borderColor = widget.invalid ? AppPalette.red : (_focus ? p.teal : p.line);
    OutlineInputBorder ob(Color c) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(widget.rounded),
          borderSide: BorderSide(color: c, width: 1),
        );
    final field = TextField(
      controller: widget.controller,
      focusNode: _node,
      autofocus: widget.autofocus,
      readOnly: widget.readOnly,
      enabled: widget.enabled,
      obscureText: widget.obscure,
      maxLines: widget.maxLines,
      minLines: widget.maxLines,
      keyboardType: widget.keyboardType ?? (multi ? TextInputType.multiline : TextInputType.text),
      textInputAction: widget.textInputAction ?? (multi ? TextInputAction.newline : TextInputAction.done),
      inputFormatters: widget.inputFormatters,
      onSubmitted: widget.onSubmitted,
      onChanged: widget.onChanged,
      onTap: widget.onTap,
      cursorColor: p.textHi,
      mouseCursor: widget.readOnly ? SystemMouseCursors.click : null,
      style: ts(context, size: 14, color: p.textHi, height: 1.5),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: widget.fill ?? p.ink800,
        hintText: widget.hint,
        hintStyle: ts(context, size: 14, color: alphaPct(p.textLow, .7), height: 1.5),
        contentPadding: EdgeInsets.fromLTRB(hasIcon ? 40 : 12, 10, widget.trailing != null ? 36 : 12, 10),
        border: ob(p.line),
        enabledBorder: ob(borderColor),
        focusedBorder: ob(widget.invalid ? AppPalette.red : p.teal),
        disabledBorder: ob(p.line),
      ),
    );
    return Opacity(
      opacity: widget.enabled ? 1 : .6,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.rounded),
          boxShadow: _focus
              ? [BoxShadow(color: alphaPct(widget.invalid ? AppPalette.red : p.teal, .2), spreadRadius: 3)]
              : (widget.invalid ? [BoxShadow(color: alphaPct(AppPalette.red, .15), spreadRadius: 3)] : null),
        ),
        child: Stack(
          children: [
            field,
            if (hasIcon)
              Positioned(
                left: 12,
                top: multi ? 14 : 0,
                bottom: multi ? null : 0,
                child: IgnorePointer(
                  child: Center(
                    child: widget.iconWidget ??
                        LaIcon(widget.icon!, size: 16, color: _focus ? p.teal : p.textLow),
                  ),
                ),
              ),
            if (widget.trailing != null)
              Positioned(right: 8, top: 0, bottom: 0, child: Center(child: widget.trailing!)),
          ],
        ),
      ),
    );
  }
}

class LaSelect<T> extends StatefulWidget {
  const LaSelect({super.key, required this.value, required this.items, required this.onChanged, this.focusNode});
  final T value;
  final List<(T, String)> items;
  final ValueChanged<T?> onChanged;
  final FocusNode? focusNode;

  @override
  State<LaSelect<T>> createState() => _LaSelectState<T>();
}

class _LaSelectState<T> extends State<LaSelect<T>> {
  bool _focus = false;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: p.ink800,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: _focus ? p.teal : p.line),
        boxShadow: _focus ? [BoxShadow(color: alphaPct(p.teal, .2), spreadRadius: 3)] : null,
      ),
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onFocusChange: (v) => setState(() => _focus = v),
        child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: widget.value,
          isExpanded: true,
          isDense: true,
          focusNode: widget.focusNode,
          dropdownColor: p.ink800,
          borderRadius: BorderRadius.circular(6),
          icon: Icon(Icons.arrow_drop_down, color: p.textLow),
          style: ts(context, size: 14, color: p.textHi, height: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 10),
          items: [
            for (final it in widget.items)
              DropdownMenuItem<T>(value: it.$1, child: Text(it.$2, style: ts(context, size: 14, color: p.textHi, height: 1.5))),
          ],
          onChanged: widget.onChanged,
        ),
        ),
      ),
    );
  }
}

class LaCheckbox extends StatelessWidget {
  const LaCheckbox({super.key, required this.value, required this.onChanged, required this.label, this.labelColor, this.autofocus = false});
  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;
  final Color? labelColor;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => onChanged(!value),
        behavior: HitTestBehavior.opaque,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: Checkbox(
                value: value,
                autofocus: autofocus,
                onChanged: (v) => onChanged(v ?? false),
                activeColor: p.teal,
                checkColor: p.isDark ? p.ink900 : Colors.white,
                side: BorderSide(color: p.textLow, width: 1.4),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            ),
            const SizedBox(width: 8),
            Text(label, style: ts(context, size: 14, color: labelColor ?? p.textMid)),
          ],
        ),
      ),
    );
  }
}

/// .validation-summary-errors
class ValidationSummary extends StatelessWidget {
  const ValidationSummary(this.errors, {super.key});
  final List<String> errors;
  @override
  Widget build(BuildContext context) {
    if (errors.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: alphaPct(AppPalette.red, .08),
        border: Border.all(color: alphaPct(AppPalette.red, .4)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final e in errors)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text('\u2022 $e', style: ts(context, size: 13, color: AppPalette.red)),
            ),
        ],
      ),
    );
  }
}

class FormSection extends StatelessWidget {
  const FormSection({super.key, required this.title, required this.child, this.last = false});
  final String title;
  final Widget child;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 22),
      decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: p.line))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.only(bottom: 8),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.line))),
                child: Text(title.toUpperCase(),
                    style: ts(context, size: 13, weight: FontWeight.w600, color: p.teal, spacing: 1.04)),
              ),
              Positioned(left: 0, bottom: 15, child: Container(width: 32, height: 2, decoration: BoxDecoration(color: p.teal, borderRadius: BorderRadius.circular(2)))),
            ],
          ),
          child,
        ],
      ),
    );
  }
}

/// .la-form-card with hero header.
class FormCard extends StatelessWidget {
  const FormCard({super.key, required this.avatar, required this.heroTitle, required this.heroText, required this.child});
  final Widget avatar;
  final String heroTitle;
  final String heroText;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final w = vw(context);
    final narrow = isNarrow(context);
    final hPad = narrow ? 18.0 : (w * 0.04).clamp(22.0, 46.0).toDouble();
    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: LaCard(
          clip: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: hPad, vertical: narrow ? 24 : 32),
                decoration: BoxDecoration(color: p.ink600, border: Border(bottom: BorderSide(color: p.line))),
                child: Row(
                  children: [
                    Container(
                      width: narrow ? 48 : 58,
                      height: narrow ? 48 : 58,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [alphaPct(p.teal, .28), alphaPct(p.gold, .18)],
                        ),
                        border: Border.all(color: alphaPct(p.teal, .38)),
                      ),
                      child: avatar,
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(heroTitle,
                              style: ts(context, size: narrow ? 17 : 20, weight: FontWeight.w700, color: p.textHi, height: 1.2)),
                          const SizedBox(height: 4),
                          Text(heroText, style: ts(context, size: 15)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: hPad, vertical: narrow ? 18 : 32),
                child: child,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Buttons row at the bottom of forms (.la-form-actions).
class FormActions extends StatelessWidget {
  const FormActions({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Container(
      margin: const EdgeInsets.only(top: 28),
      padding: const EdgeInsets.only(top: 22),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: p.line))),
      child: Wrap(spacing: 12, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: children),
    );
  }
}

/// Simple full-width "no content" paragraph card text helpers
class LinkText extends StatefulWidget {
  const LinkText(this.text, {super.key, required this.onTap, this.size = 15});
  final String text;
  final VoidCallback onTap;
  final double size;
  @override
  State<LinkText> createState() => _LinkTextState();
}

class _LinkTextState extends State<LinkText> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Text(widget.text,
            style: ts(context, size: widget.size, color: _hover ? const Color(0xFFF0C765) : p.gold)),
      ),
    );
  }
}
