import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/palette.dart';
import '../theme/theme.dart';
import '../widgets/anim.dart';
import '../widgets/common.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key, required this.app, required this.placeId});
  final AppState app;
  final int placeId;
  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final _actions = PageActions();
  bool _loading = true;
  PlaceDto? _place;
  List<AssessmentDto> _history = [];

  AppState get app => widget.app;

  @override
  void initState() {
    super.initState();
    _actions
      ..newItem = _new
      ..print = _printLatest
      ..savePdf = _printLatest;
    app.registerPage(_actions);
    app.contextPlaceId = widget.placeId;
    _load();
  }

  @override
  void dispose() {
    app.unregisterPage(_actions);
    super.dispose();
  }

  Future<void> _load() async {
    final r = await Future.wait<dynamic>([app.api.assessmentsFor(widget.placeId), app.api.place(widget.placeId)]);
    if (!mounted) return;
    setState(() {
      _history = r[0] as List<AssessmentDto>;
      _place = r[1] as PlaceDto?;
      _loading = false;
    });
  }

  void _new() => app.navigate(AppRoute(PageId.assessmentNew, placeId: _place?.placeId ?? widget.placeId));
  void _printLatest() => app.navigate(AppRoute(PageId.report, placeId: widget.placeId));

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final sorted = [..._history]..sort((a, b) => b.assessmentDate.compareTo(a.assessmentDate));
    final asc = [..._history]..sort((a, b) => a.assessmentDate.compareTo(b.assessmentDate));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TopBar(
          title: 'Incident History',
          subtitle: _place == null ? '' : '${_place!.psgcCode} \u2014 ${_place!.name}',
          trailing: LaButton(label: '+ New Assessment', tooltip: 'New Assessment (Ctrl+N)', onTap: _new),
        ),
        if (_loading)
          const LoadingBlock()
        else ...[
          if (sorted.isEmpty)
            LaCard(
              child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 6, children: [
                Text('No assessment history yet for this place.', style: ts(context, color: p.textLow)),
                LinkText('Create the first assessment \u2192', onTap: _new),
              ]),
            )
          else
            LaCard(
              child: SizedBox(
                height: 280,
                width: double.infinity,
                child: TrendChart(
                  labels: [for (final a in asc) fmtMmmYyyy(a.assessmentDate)],
                  values: [for (final a in asc) a.overallScore.toDouble()],
                ),
              ),
            ),
          const SizedBox(height: 18),
          LaCard(child: _table(context, sorted)),
        ],
      ],
    );
  }

  Widget _table(BuildContext context, List<AssessmentDto> rows) {
    final p = context.pal;
    final narrow = isNarrow(context);
    Widget h(String t, {double? w, int? flex}) {
      final box = Container(
        width: w,
        padding: const EdgeInsets.all(10),
        child: Text(t.toUpperCase(), style: ts(context, size: 11, weight: FontWeight.w600, color: p.textLow, spacing: .66)),
      );
      return flex != null ? Expanded(flex: flex, child: box) : box;
    }

    Widget c(Widget child, {double? w, int? flex}) {
      final box = Container(width: w, padding: const EdgeInsets.all(10), alignment: Alignment.centerLeft, child: child);
      return flex != null ? Expanded(flex: flex, child: box) : box;
    }

    final table = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.line))),
        child: Row(children: [
          h('Date', w: 130),
          h('Overall', w: 90),
          h('Status', w: 140),
          h('Priority', w: 120),
          h('Weakest', flex: 2),
          h('Strongest', flex: 2),
          h('', w: 90),
        ]),
      ),
      for (final a in rows)
        Container(
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.line))),
          child: Row(children: [
            c(Text(fmtMmmDYyyy(a.assessmentDate), style: ts(context, size: 13.5)), w: 130),
            c(Text(numText(a.overallScore), style: ts(context, size: 13.5, weight: FontWeight.w700, color: p.textHi)), w: 90),
            c(LaBadge(a.overallStatus, color: AppPalette.statusColor(a.overallStatus)), w: 140),
            c(LaBadge(a.priorityLevel, color: AppPalette.priorityColor(a.priorityLevel)), w: 120),
            c(Text('${a.weakestDomain} (${a.weakestScore})', style: ts(context, size: 13.5)), flex: 2),
            c(Text('${a.strongestDomain} (${a.strongestScore})', style: ts(context, size: 13.5)), flex: 2),
            c(LaButton(label: 'Print', kind: BtnKind.outline, small: true, onTap: () => app.navigate(AppRoute(PageId.report, placeId: a.placeId))), w: 90),
          ]),
        ),
    ]);
    return LayoutBuilder(builder: (context, cts) {
      final minW = narrow ? 700.0 : 860.0;
      if (cts.maxWidth >= minW) return table;
      return Scrollbar(
        child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: SizedBox(width: minW, child: table)),
      );
    });
  }
}

/// Chart.js-style line chart (category x axis, 0-10 y axis, smooth line, filled).
class TrendChart extends StatefulWidget {
  const TrendChart({super.key, required this.labels, required this.values});
  final List<String> labels;
  final List<double> values;
  @override
  State<TrendChart> createState() => _TrendChartState();
}

class _TrendChartState extends State<TrendChart> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..forward();
  int? _hover;
  Offset _mouse = Offset.zero;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  static const _left = 34.0, _right = 12.0, _top = 10.0, _bottom = 30.0;

  List<Offset> _points(Size s) {
    final n = widget.values.length;
    final w = s.width - _left - _right;
    final h = s.height - _top - _bottom;
    return [
      for (var i = 0; i < n; i++)
        Offset(
          _left + (n == 1 ? w / 2 : w * i / (n - 1)),
          _top + h * (1 - (widget.values[i].clamp(0, 10).toDouble()) / 10),
        )
    ];
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return LayoutBuilder(builder: (context, c) {
      final size = Size(c.maxWidth, c.maxHeight);
      return MouseRegion(
        onHover: (e) {
          final pts = _points(size);
          int? best;
          double bd = 24;
          for (var i = 0; i < pts.length; i++) {
            final d = (pts[i] - e.localPosition).distance;
            if (d < bd) {
              bd = d;
              best = i;
            }
          }
          if (best != _hover || (best != null && (e.localPosition - _mouse).distance > 1)) {
            setState(() {
              _hover = best;
              _mouse = e.localPosition;
            });
          }
        },
        onExit: (_) => setState(() => _hover = null),
        child: Stack(
          children: [
            AnimatedBuilder(
              animation: _c,
              builder: (context, _) => CustomPaint(
                size: size,
                painter: _TrendPainter(
                  labels: widget.labels,
                  values: widget.values,
                  p: p,
                  progress: Curves.easeOutQuart.transform(_c.value),
                  hover: _hover,
                  textStyle: ts(context, size: 12, color: p.textLow, height: 1),
                ),
              ),
            ),
            if (_hover != null)
              Positioned(
                left: math.min(_mouse.dx + 12, size.width - 150),
                top: math.max(0, _mouse.dy - 52),
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color.fromRGBO(0, 0, 0, .8),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text(widget.labels[_hover!],
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12, fontFamily: kFont)),
                      const SizedBox(height: 4),
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(width: 8, height: 8, color: p.gold),
                        const SizedBox(width: 6),
                        Text('Overall Score: ${numText(widget.values[_hover!])}',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: kFont)),
                      ]),
                    ]),
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter({required this.labels, required this.values, required this.p, required this.progress, required this.hover, required this.textStyle});
  final List<String> labels;
  final List<double> values;
  final AppPalette p;
  final double progress;
  final int? hover;
  final TextStyle textStyle;

  @override
  void paint(Canvas canvas, Size size) {
    const left = _TrendChartState._left, right = _TrendChartState._right, top = _TrendChartState._top, bottom = _TrendChartState._bottom;
    final w = size.width - left - right;
    final h = size.height - top - bottom;
    final grid = Paint()
      ..color = p.line
      ..strokeWidth = 1;
    // y grid + labels (0..10)
    for (var v = 0; v <= 10; v++) {
      final y = top + h * (1 - v / 10);
      canvas.drawLine(Offset(left, y), Offset(size.width - right, y), grid);
      final tp = TextPainter(text: TextSpan(text: '$v', style: textStyle), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(left - 8 - tp.width, y - tp.height / 2));
    }
    final n = values.length;
    final pts = [
      for (var i = 0; i < n; i++)
        Offset(left + (n == 1 ? w / 2 : w * i / (n - 1)), top + h * (1 - values[i].clamp(0, 10).toDouble() / 10))
    ];
    // x labels (skip overlaps)
    double lastRight = -1e9;
    for (var i = 0; i < n; i++) {
      final tp = TextPainter(text: TextSpan(text: labels[i], style: textStyle), textDirection: TextDirection.ltr)..layout();
      var x = pts[i].dx - tp.width / 2;
      x = x.clamp(0.0, size.width - tp.width).toDouble();
      if (x > lastRight + 8) {
        tp.paint(canvas, Offset(x, size.height - bottom + 10));
        lastRight = x + tp.width;
      }
    }
    if (n == 0) return;

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, left + (size.width - left) * progress, size.height));

    // Chart.js spline (tension .3)
    final path = Path()..moveTo(pts[0].dx, pts[0].dy);
    if (n > 1) {
      const t = 0.3;
      List<Offset> prevCp = List.filled(n, Offset.zero), nextCp = List.filled(n, Offset.zero);
      for (var i = 0; i < n; i++) {
        final a = pts[math.max(0, i - 1)], m = pts[i], b = pts[math.min(n - 1, i + 1)];
        final d01 = (m - a).distance, d12 = (b - m).distance;
        final s01 = (d01 + d12) == 0 ? 0.0 : d01 / (d01 + d12);
        final s12 = 1 - s01;
        final fa = t * s01, fb = t * s12;
        prevCp[i] = Offset(m.dx - fa * (b.dx - a.dx), m.dy - fa * (b.dy - a.dy));
        nextCp[i] = Offset(m.dx + fb * (b.dx - a.dx), m.dy + fb * (b.dy - a.dy));
        double cy(double y) => y.clamp(top, top + h).toDouble();
        prevCp[i] = Offset(prevCp[i].dx, cy(prevCp[i].dy));
        nextCp[i] = Offset(nextCp[i].dx, cy(nextCp[i].dy));
      }
      for (var i = 0; i < n - 1; i++) {
        final c1 = i == 0 ? pts[0] : nextCp[i];
        final c2 = i + 1 == n - 1 ? pts[n - 1] : prevCp[i + 1];
        path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, pts[i + 1].dx, pts[i + 1].dy);
      }
    }
    final fill = Path.from(path)
      ..lineTo(pts.last.dx, top + h)
      ..lineTo(pts.first.dx, top + h)
      ..close();
    canvas.drawPath(fill, Paint()..color = const Color.fromRGBO(181, 123, 5, .15));
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = p.gold
        ..strokeJoin = StrokeJoin.round,
    );
    for (var i = 0; i < n; i++) {
      final r = (i == hover) ? 5.0 : 3.0;
      canvas.drawCircle(pts[i], r, Paint()..color = p.isDark ? p.ink700 : Colors.white);
      canvas.drawCircle(
          pts[i],
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = (i == hover) ? 2 : 1
            ..color = p.gold);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) => old.progress != progress || old.hover != hover || old.p != p || old.values != values;
}
