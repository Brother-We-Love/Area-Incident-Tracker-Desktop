import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import '../state/app_state.dart';
import '../theme/palette.dart';
import '../theme/theme.dart';
import 'common.dart';

/// .la-modal (+ accent variants).
class LaModal extends StatelessWidget {
  const LaModal({
    super.key,
    this.accent = 'info',
    this.icon,
    this.title,
    required this.body,
    required this.actions,
    this.maxWidth = 420,
    this.bodyAlignCenter = true,
  });
  final String accent;
  final String? icon;
  final String? title;
  final Widget body;
  final List<Widget> actions;
  final double maxWidth;
  final bool bodyAlignCenter;

  static Color accentColor(BuildContext c, String accent) {
    final p = c.pal;
    switch (accent) {
      case 'success':
        return AppPalette.green;
      case 'error':
        return AppPalette.red;
      case 'warning':
        return AppPalette.orange;
      default:
        return p.gold;
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final ac = accentColor(context, accent);
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [p.ink700, p.ink800],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: p.line),
          boxShadow: const [BoxShadow(color: Color.fromRGBO(0, 0, 0, .45), offset: Offset(0, 30), blurRadius: 70)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (icon != null)
              Container(
                width: 54,
                height: 54,
                margin: const EdgeInsets.only(bottom: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(shape: BoxShape.circle, color: alphaPct(ac, .16)),
                child: Text(icon!, style: ts(context, size: 26, color: ac, height: 1)),
              ),
            if (title != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(title!,
                    textAlign: TextAlign.center,
                    style: ts(context, size: 20, weight: FontWeight.w700, color: p.textHi, height: 1.3)),
              ),
            Padding(
              padding: const EdgeInsets.only(bottom: 22),
              child: DefaultTextStyle(
                style: ts(context, size: 14),
                textAlign: bodyAlignCenter ? TextAlign.center : TextAlign.left,
                child: body,
              ),
            ),
            Wrap(alignment: WrapAlignment.center, spacing: 10, runSpacing: 10, children: actions),
          ],
        ),
      ),
    );
  }
}

/// Shows a modal dialog with the website's overlay (dimmed + blurred backdrop,
/// scale/slide-in). Tracks open modals so global shortcuts can stand down.
Future<T?> showLaModal<T>(AppState app, {required WidgetBuilder builder}) async {
  // The Navigator's own context can't find itself; use the overlay's context.
  final ctx = app.navigatorKey.currentState?.overlay?.context;
  if (ctx == null) return null;
  app.modalOpened();
  try {
    return await showGeneralDialog<T>(
      context: ctx,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: const Color.fromRGBO(8, 14, 18, .55),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (c, a, s) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
        child: Material(
          type: MaterialType.transparency,
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(isNarrow(c) ? 16 : 20),
              child: builder(c),
            ),
          ),
        ),
      ),
      transitionBuilder: (c, a, s, child) {
        final curved = CurvedAnimation(parent: a, curve: Curves.easeOutCubic, reverseCurve: Curves.easeIn);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, .03), end: Offset.zero).animate(curved),
            child: ScaleTransition(scale: Tween<double>(begin: .97, end: 1).animate(curved), child: child),
          ),
        );
      },
    );
  } finally {
    app.modalClosed();
  }
}

/// Confirm dialog (LA.confirm). Resolves true only when confirmed.
Future<bool> laConfirm(
  AppState app, {
  String title = 'Are you sure?',
  String message = '',
  String confirmText = 'Confirm',
  String cancelText = 'Cancel',
  bool danger = false,
}) async {
  final r = await showLaModal<bool>(
    app,
    builder: (c) => LaModal(
      accent: danger ? 'error' : 'warning',
      icon: '?',
      title: title,
      body: Text(message),
      actions: [
        LaButton(
          label: cancelText,
          kind: BtnKind.outline,
          minWidth: 120,
          autofocus: true,
          onTap: () => Navigator.of(c).pop(false),
        ),
        LaButton(
          label: confirmText,
          kind: danger ? BtnKind.danger : BtnKind.gold,
          minWidth: 120,
          onTap: () => Navigator.of(c).pop(true),
        ),
      ],
    ),
  );
  return r ?? false;
}

/// Alert dialog (LA.alert).
Future<void> laAlert(AppState app, {String type = 'info', String title = 'Notice', required String message, String okText = 'OK'}) async {
  const icons = {'success': '\u2713', 'error': '!', 'warning': '\u26A0', 'info': 'i'};
  await showLaModal<void>(
    app,
    builder: (c) => LaModal(
      accent: type,
      icon: icons[type] ?? 'i',
      title: title,
      body: Text(message),
      actions: [LaButton(label: okText, minWidth: 120, autofocus: true, onTap: () => Navigator.of(c).pop())],
    ),
  );
}
