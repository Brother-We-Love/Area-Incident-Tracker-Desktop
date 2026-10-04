import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/palette.dart';
import '../theme/theme.dart';
import '../widgets/anim.dart';
import '../widgets/common.dart';
import '../widgets/pickers.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, required this.app, this.placeId});
  final AppState app;
  final int? placeId;
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final _actions = PageActions();
  bool _loading = true;
  PlaceDto? _place;
  AssessmentDto? _latest;
  int? _selectedId;

  AppState get app => widget.app;

  @override
  void initState() {
    super.initState();
    _actions
      ..newItem = _newAssessment
      ..openHistory = _history
      ..print = _report
      ..savePdf = _report;
    app.registerPage(_actions);
    _load();
  }

  @override
  void dispose() {
    app.unregisterPage(_actions);
    super.dispose();
  }

  Future<void> _load() async {
    final api = app.api;
    var placeId = widget.placeId;
    PlaceDto? place;
    AssessmentDto? latest;

    final placesF = api.places('api/places');
    if (placeId != null) {
      final results = await Future.wait<dynamic>([placesF, api.place(placeId), api.latestFor(placeId)]);
      final list = results[0] as PagedResult<PlaceDto>;
      place = (results[1] as PlaceDto?) ??
          list.items.cast<PlaceDto?>().firstWhere((e) => e!.placeId == placeId, orElse: () => null);
      latest = results[2] as AssessmentDto?;
    } else {
      final list = await placesF;
      if (list.items.isNotEmpty) {
        place = list.items.first;
        placeId = place.placeId;
        latest = await api.latestFor(placeId);
      }
    }
    if (!mounted) return;
    app.contextPlaceId = placeId;
    setState(() {
      _place = place;
      _latest = latest;
      _selectedId = placeId;
      _loading = false;
    });
  }

  void _newAssessment() => app.navigate(AppRoute(PageId.assessmentNew, placeId: _selectedId));
  void _history() {
    if (_selectedId != null) app.navigate(AppRoute(PageId.history, placeId: _selectedId));
  }

  void _report() {
    if (_latest != null) app.navigate(AppRoute(PageId.report, placeId: _latest!.placeId));
  }

  Future<void> _pick() async {
    final pl = await showPlacePicker(app);
    if (pl != null && mounted) app.goDashboard(placeId: pl.placeId);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final label = _place != null ? _place!.label : 'Select a place...';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TopBar(
          title: 'Dashboard',
          subtitle: 'Live 11-category dashboard, generated the moment an incident is saved.',
          trailing: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 260, maxWidth: 420),
            child: PlacePickerButton(label: label, onTap: _pick),
          ),
        ),
        if (_loading)
          const LoadingBlock()
        else if (_latest == null)
          LaCard(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              children: [
                Text('No assessment found for this place yet.', style: ts(context, color: p.textLow)),
                LinkText('Create the first assessment \u2192', onTap: _newAssessment),
              ],
            ),
          )
        else
          _content(context, _latest!),
      ],
    );
  }

  Widget _content(BuildContext context, AssessmentDto a) {
    final p = context.pal;
    final statusColor = AppPalette.statusColor(a.overallStatus);
    final stats = <Widget>[
      LaStat(value: numText(a.overallScore), label: 'Overall Score'),
      LaStat(
        valueWidget: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Align(alignment: Alignment.centerLeft, child: LaBadge(a.overallStatus, color: statusColor)),
        ),
        label: 'Status',
      ),
      LaStat(
        valueWidget: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Align(
              alignment: Alignment.centerLeft,
              child: LaBadge(a.priorityLevel, color: AppPalette.priorityColor(a.priorityLevel))),
        ),
        label: 'Priority',
      ),
      LaStat(value: a.weakestDomain, valueSize: 18, valueColor: AppPalette.red, label: 'Weakest (${a.weakestScore})'),
      LaStat(value: a.strongestDomain, valueSize: 18, valueColor: AppPalette.green, label: 'Strongest (${a.strongestScore})'),
    ];

    return Entrance(
      totalMs: 2000,
      builder: (context, t) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LaGrid(cols: 5, stretch: true, children: stats),
          const SizedBox(height: 18),
          LaGrid(cols: 2, stretch: true, children: [
            _breakdownCard(context, a, t),
            _barsCard(context, a, t),
          ]),
          const SizedBox(height: 18),
          LaGrid(cols: 2, stretch: true, children: [
            _compassCard(context, a, t),
            _guidanceCard(context, a),
          ]),
        ],
      ),
    );
  }

  Widget _breakdownCard(BuildContext context, AssessmentDto a, double t) {
    final p = context.pal;
    final narrow = isNarrow(context);
    final rows = a.domainScores;
    return LaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ChartHeading(
            kicker: 'Your current shape',
            title: 'Category Breakdown',
            trailing: Padding(
              padding: const EdgeInsets.only(top: 15),
              child: Text('0 \u2014 10', style: ts(context, size: 11, color: p.textLow)),
            ),
          ),
          for (var i = 0; i < rows.length; i++)
            Opacity(
              opacity: stagger(t, 2000, i * 60, 500, curve: Curves.ease),
              child: Transform.translate(
                offset: Offset(-8 * (1 - stagger(t, 2000, i * 60, 500, curve: Curves.ease)), 0),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  decoration: i == rows.length - 1
                      ? null
                      : BoxDecoration(border: Border(bottom: BorderSide(color: p.line, style: BorderStyle.solid))),
                  child: Row(
                    children: [
                      SizedBox(
                        width: narrow ? 118 : 190,
                        child: Text(rows[i].$1, style: ts(context, size: narrow ? 12 : 13), overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          height: 8,
                          decoration: BoxDecoration(color: p.ink600, borderRadius: BorderRadius.circular(99)),
                          clipBehavior: Clip.antiAlias,
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: (rows[i].$2 * 10 / 100) * stagger(t, 2000, i * 60, 800, curve: const Cubic(.4, 0, .2, 1)),
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppPalette.bandColor(rows[i].$2),
                                borderRadius: BorderRadius.circular(99),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 26,
                        child: Text('${rows[i].$2}',
                            textAlign: TextAlign.right,
                            style: ts(context, size: 13, weight: FontWeight.w600, color: p.textHi)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _legendItem(BuildContext context, Color c, String text) {
    final p = context.pal;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 7, height: 7, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
      const SizedBox(width: 5),
      Text(text, style: ts(context, size: 10, color: p.textLow, height: 1.4)),
    ]);
  }

  Widget _barsCard(BuildContext context, AssessmentDto a, double t) {
    final p = context.pal;
    final narrow = isNarrow(context);
    final rows = a.domainScores;
    final trackH = narrow ? 190.0 : 218.0;
    return LaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ChartHeading(
            kicker: 'At a glance',
            title: 'Score Bands',
            trailing: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Wrap(spacing: 10, runSpacing: 5, alignment: WrapAlignment.end, children: [
                _legendItem(context, AppPalette.red, 'Needs care'),
                _legendItem(context, AppPalette.green, 'Thriving'),
              ]),
            ),
          ),
          SizedBox(
            height: narrow ? 250 : 350,
            child: CustomPaint(
              painter: _GridLinesPainter(p.line),
              child: Container(
                padding: const EdgeInsets.only(top: 14),
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.line))),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < rows.length; i++) ...[
                      if (i > 0) SizedBox(width: (vw(context) * .01).clamp(5.0, 12.0).toDouble()),
                      Expanded(
                        child: Tooltip(
                          message: '${rows[i].$1}: ${rows[i].$2} out of 10',
                          child: Opacity(
                            opacity: stagger(t, 2000, i * 80, 500, curve: Curves.ease),
                            child: Stack(
                              alignment: Alignment.bottomCenter,
                              children: [
                                Positioned(
                                  top: 0,
                                  left: 0,
                                  right: 0,
                                  child: Text('${rows[i].$2}',
                                      textAlign: TextAlign.center,
                                      style: ts(context, size: 13, weight: FontWeight.w700, color: p.textHi, height: 1)),
                                ),
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    SizedBox(
                                      height: trackH,
                                      child: Align(
                                        alignment: Alignment.bottomCenter,
                                        child: FractionallySizedBox(
                                          widthFactor: narrow ? .76 : .72,
                                          child: Align(
                                            alignment: Alignment.bottomCenter,
                                            child: ConstrainedBox(
                                              constraints: BoxConstraints(maxWidth: narrow ? 24.0 : 30.0),
                                              child: Container(
                                                height: trackH * rows[i].$2 * 10 / 100 *
                                                    stagger(t, 2000, i * 80, 800, curve: const Cubic(.4, 0, .2, 1)),
                                                decoration: BoxDecoration(
                                                  borderRadius: const BorderRadius.only(
                                                    topLeft: Radius.circular(6),
                                                    topRight: Radius.circular(6),
                                                    bottomLeft: Radius.circular(2),
                                                    bottomRight: Radius.circular(2),
                                                  ),
                                                  gradient: LinearGradient(
                                                    begin: Alignment.topCenter,
                                                    end: Alignment.bottomCenter,
                                                    colors: _barGradient(rows[i].$2),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(top: 9),
                                      child: Text(shortDomain(rows[i].$1),
                                          maxLines: 1,
                                          overflow: TextOverflow.visible,
                                          softWrap: false,
                                          textAlign: TextAlign.center,
                                          style: ts(context, size: 9, color: p.textLow, height: 1.15)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Color> _barGradient(int score) {
    if (score >= 8) return const [Color(0xFF73DFC1), AppPalette.green];
    if (score >= 5) return const [Color(0xFFFFE58A), AppPalette.yellow];
    if (score >= 3) return const [Color(0xFFFFC078), AppPalette.orange];
    return const [Color(0xFFEF6B70), AppPalette.red];
  }

  Widget _compassCard(BuildContext context, AssessmentDto a, double t) {
    final p = context.pal;
    final narrow = isNarrow(context);
    return LaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ChartHeading(
            kicker: 'Balance across the whole',
            title: 'Category Compass',
            trailing: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('\u2726', style: ts(context, size: 21, color: p.gold, height: 1)),
            ),
          ),
          SizedBox(
            height: narrow ? 380 : 420,
            child: CustomPaint(
              painter: _CompassPainter(
                scores: a.scores,
                labels: [for (final d in a.domainScores) shortDomain(d.$1)],
                t: t,
                p: p,
                textStyle: ts(context, size: 10, weight: FontWeight.w600, color: p.textMid, height: 1),
              ),
              size: Size.infinite,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(children: [
              Container(width: 22, height: 1, color: p.gold.withAlpha(180)),
              const SizedBox(width: 8),
              Text('Every axis is one part of your life system', style: ts(context, size: 11, color: p.textLow)),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _guidanceCard(BuildContext context, AssessmentDto a) {
    final p = context.pal;
    Widget bullet(String? s) => (s ?? '').trim().isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, right: 10, top: 2),
                child: Text('\u2022', style: ts(context, size: 13)),
              ),
              Expanded(child: Text(s!, style: ts(context, size: 13))),
            ]),
          );
    return LaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('System Guidance \u2014 Weakest Category',
              style: ts(context, size: 16, weight: FontWeight.w700, color: p.textHi, height: 1.2)),
          const SizedBox(height: 10),
          Text(a.automatedAdvice ?? '', style: ts(context)),
          Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Divider(height: 1, color: p.line)),
          Text('Mission & Priorities', style: ts(context, size: 14, weight: FontWeight.w700, color: p.textHi, height: 1.2)),
          const SizedBox(height: 8),
          Text.rich(TextSpan(children: [
            TextSpan(text: 'North Star: ', style: ts(context, size: 13, weight: FontWeight.w700, color: p.textHi)),
            TextSpan(text: a.northStarStatement ?? '', style: ts(context, size: 13)),
          ])),
          const SizedBox(height: 8),
          bullet(a.topPriority1),
          bullet(a.topPriority2),
          bullet(a.topPriority3),
          if ((a.stopReduce ?? '').trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Text.rich(TextSpan(children: [
                TextSpan(text: 'Stop / Reduce: ', style: ts(context, size: 13, weight: FontWeight.w700, color: p.textHi)),
                TextSpan(text: a.stopReduce!, style: ts(context, size: 13)),
              ])),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Text(
              'Next review: ${a.nextReviewDate == null ? '' : fmtMmmDYyyy(a.nextReviewDate!)}',
              style: ts(context, size: 12, color: p.textLow),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            LaButton(label: '\u{1F5A8} Print Report', kind: BtnKind.outline, tooltip: 'Print Report (Ctrl+P)', onTap: _report),
            LaButton(label: '\u{1F4C8} History', kind: BtnKind.outline, tooltip: 'History (Ctrl+H)', onTap: _history),
            LaButton(label: '+ New Assessment', tooltip: 'New Assessment (Ctrl+N)', onTap: _newAssessment),
          ]),
        ],
      ),
    );
  }
}

class _GridLinesPainter extends CustomPainter {
  _GridLinesPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    // repeating-linear-gradient: a 1px line at each 20% step (not at the very top).
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (var i = 1; i < 5; i++) {
      final y = size.height * .2 * i - 1;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridLinesPainter old) => old.color != color;
}

class _CompassPainter extends CustomPainter {
  _CompassPainter({required this.scores, required this.labels, required this.t, required this.p, required this.textStyle});
  final List<int> scores;
  final List<String> labels;
  final double t; // 0..1 across 2000ms
  final AppPalette p;
  final TextStyle textStyle;

  static const _cx = 260.0, _cy = 205.0, _r = 150.0;

  @override
  void paint(Canvas canvas, Size size) {
    final n = scores.length;
    final scale = math.min(size.width / 520, size.height / 420);
    final reveal = stagger(t, 2000, 0, 900, curve: const Cubic(.4, 0, .2, 1));
    final s = scale * (0.92 + .08 * reveal);
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(s);
    canvas.translate(-260, -210);

    Offset pt(int i, double radius) {
      final ang = (math.pi * 2 * i / n) - math.pi / 2;
      return Offset(_cx + radius * math.cos(ang), _cy + radius * math.sin(ang));
    }

    final op = reveal;
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = p.line.withOpacity(p.line.opacity * op);
    for (var ring = 2; ring <= 10; ring += 2) {
      final path = Path();
      for (var i = 0; i < n; i++) {
        final o = pt(i, _r * ring / 10.0);
        i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
      }
      path.close();
      canvas.drawPath(path, linePaint);
    }
    for (var i = 0; i < n; i++) {
      canvas.drawLine(const Offset(_cx, _cy), pt(i, _r), linePaint);
    }

    final area = Path();
    for (var i = 0; i < n; i++) {
      final o = pt(i, _r * scores[i] / 10.0);
      i == 0 ? area.moveTo(o.dx, o.dy) : area.lineTo(o.dx, o.dy);
    }
    area.close();
    canvas.drawPath(area, Paint()..color = alphaPct(p.gold, .18 * op));
    canvas.drawPath(
      area,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round
        ..color = p.gold.withOpacity(op),
    );

    for (var i = 0; i < n; i++) {
      final o = pt(i, _r * scores[i] / 10.0);
      final k = stagger(t, 2000, 300 + i * 70, 400, curve: const Cubic(.2, .9, .3, 1.2));
      if (k > 0) {
        final rad = 5 * k;
        canvas.drawCircle(o, rad + 1.25, Paint()..color = p.ink700.withOpacity(math.min(1, k)));
        canvas.drawCircle(o, rad, Paint()..color = AppPalette.bandColor(scores[i]).withOpacity(math.min(1, k)));
      }
      // Labels
      final lab = pt(i, 184);
      final anchor = lab.dx < 245 ? 'end' : (lab.dx > 275 ? 'start' : 'middle');
      final tp = TextPainter(
        text: TextSpan(text: labels[i], style: textStyle.copyWith(color: textStyle.color!.withOpacity(op))),
        textDirection: TextDirection.ltr,
      )..layout();
      double dx = lab.dx;
      if (anchor == 'end') dx -= tp.width;
      if (anchor == 'middle') dx -= tp.width / 2;
      tp.paint(canvas, Offset(dx, lab.dy - tp.height * .78));
    }

    canvas.drawCircle(const Offset(_cx, _cy), 4 + 2.5, Paint()..color = alphaPct(p.gold, .35 * op));
    canvas.drawCircle(const Offset(_cx, _cy), 4, Paint()..color = p.gold.withOpacity(op));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CompassPainter old) => old.t != t || old.p != p || old.scores != scores;
}
