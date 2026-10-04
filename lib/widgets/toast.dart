import 'package:flutter/material.dart';
import '../state/app_state.dart';
import '../theme/palette.dart';
import '../theme/theme.dart';
import 'common.dart';

/// Top-right toast stack (.la-toast-region).
class ToastHost extends StatelessWidget {
  const ToastHost({super.key, required this.app});
  final AppState app;

  @override
  Widget build(BuildContext context) {
    final w = vw(context);
    final narrow = w <= 640;
    return Positioned(
      top: narrow ? 12 : 18,
      right: narrow ? 12 : 18,
      left: narrow ? 12 : null,
      width: narrow ? null : (360.0 < w - 36 ? 360.0 : w - 36),
      child: ValueListenableBuilder<List<ToastData>>(
        valueListenable: app.toasts,
        builder: (context, list, _) {
          if (list.isEmpty) return const SizedBox.shrink();
          return Material(
            type: MaterialType.transparency,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final t in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ToastCard(key: ValueKey(t.id), data: t, onDismissed: () => app.dismissToast(t.id)),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class ToastCard extends StatefulWidget {
  const ToastCard({super.key, required this.data, required this.onDismissed});
  final ToastData data;
  final VoidCallback onDismissed;

  @override
  State<ToastCard> createState() => _ToastCardState();
}

class _ToastCardState extends State<ToastCard> with TickerProviderStateMixin {
  late final AnimationController _enter =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
  late final AnimationController _progress =
      AnimationController(vsync: this, duration: Duration(milliseconds: widget.data.durationMs));
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _enter.forward();
    if (widget.data.durationMs > 0) {
      _progress.forward();
      _progress.addStatusListener((s) {
        if (s == AnimationStatus.completed) _dismiss();
      });
    }
  }

  Future<void> _dismiss() async {
    if (_leaving || !mounted) return;
    _leaving = true;
    await _enter.reverse();
    if (mounted) widget.onDismissed();
  }

  @override
  void dispose() {
    _enter.dispose();
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final d = widget.data;
    const icons = {'success': '\u2713', 'error': '!', 'warning': '\u26A0', 'info': 'i', 'question': '?'};
    final accent = d.type == 'success'
        ? AppPalette.green
        : d.type == 'error'
            ? AppPalette.red
            : d.type == 'warning'
                ? AppPalette.orange
                : p.gold;
    final curved = CurvedAnimation(parent: _enter, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(1.2, 0), end: Offset.zero).animate(curved),
        child: MouseRegion(
          onEnter: (_) {
            if (d.durationMs > 0) _progress.stop();
          },
          onExit: (_) {
            if (d.durationMs > 0 && !_leaving) _progress.forward();
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [p.ink700, p.ink800],
                ),
                border: Border(
                  left: BorderSide(color: accent, width: 4),
                  top: BorderSide(color: p.line),
                  right: BorderSide(color: p.line),
                  bottom: BorderSide(color: p.line),
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [BoxShadow(color: Color.fromRGBO(0, 0, 0, .35), offset: Offset(0, 18), blurRadius: 40)],
              ),
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 17),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: alphaPct(accent, .18)),
                          child: Text(icons[d.type] ?? 'i', style: ts(context, size: 15, color: accent, height: 1)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if ((d.title ?? '').isNotEmpty)
                                Text(d.title!, style: ts(context, size: 14, weight: FontWeight.w700, color: p.textHi)),
                              if (d.message.isNotEmpty) Text(d.message, style: ts(context, size: 13)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: _dismiss,
                            child: Text('\u00D7', style: ts(context, size: 18, color: p.textLow, height: 1)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (d.durationMs > 0)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: AnimatedBuilder(
                        animation: _progress,
                        builder: (context, _) => Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: (1 - _progress.value).clamp(0.0, 1.0).toDouble(),
                            child: Container(height: 3, color: accent),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
