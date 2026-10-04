import 'dart:io';
import 'dart:typed_data';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../models/models.dart';
import '../services/report_pdf.dart';
import '../state/app_state.dart';
import '../theme/palette.dart';
import '../theme/theme.dart';
import '../widgets/anim.dart';
import '../widgets/common.dart';

class ReportPage extends StatefulWidget {
  const ReportPage({super.key, required this.app, required this.placeId});
  final AppState app;
  final int placeId;
  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  final _actions = PageActions();
  bool _loading = true;
  bool _missing = false;
  bool _busy = false;
  PlaceDto? _place;
  AssessmentDto? _a;

  AppState get app => widget.app;

  @override
  void initState() {
    super.initState();
    _actions
      ..print = _print
      ..savePdf = _savePdf
      ..save = _savePdf;
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
    final r = await Future.wait<dynamic>([app.api.place(widget.placeId), app.api.latestFor(widget.placeId)]);
    if (!mounted) return;
    setState(() {
      _place = r[0] as PlaceDto?;
      _a = r[1] as AssessmentDto?;
      _missing = _place == null || _a == null;
      _loading = false;
    });
  }

  String get _fileName {
    final name = (_place?.name ?? 'Area').replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    return 'Life Audit Report - $name - ${ymd(_a!.assessmentDate)}.pdf';
  }

  Future<Uint8List?> _bytes() async {
    try {
      return await ReportPdf.build(_a!, _place);
    } catch (e) {
      app.toast('error', 'Could not build the report: $e', title: 'Error');
      return null;
    }
  }

  Future<void> _print() async {
    if (_a == null || _busy) return;
    setState(() => _busy = true);
    try {
      final bytes = await _bytes();
      if (bytes == null) return;
      await Printing.layoutPdf(name: _fileName, onLayout: (_) async => bytes);
    } catch (e) {
      app.toast('error', 'Printing failed: $e', title: 'Error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _savePdf() async {
    if (_a == null || _busy) return;
    setState(() => _busy = true);
    try {
      final loc = await getSaveLocation(
        suggestedName: _fileName,
        acceptedTypeGroups: const [XTypeGroup(label: 'PDF', extensions: ['pdf'])],
      );
      if (loc == null) return;
      final bytes = await _bytes();
      if (bytes == null) return;
      var path = loc.path;
      if (!path.toLowerCase().endsWith('.pdf')) path = '$path.pdf';
      await File(path).writeAsBytes(bytes, flush: true);
      app.toast('success', 'Report saved to $path', title: 'Saved');
    } catch (e) {
      app.toast('error', 'Could not save the PDF: $e', title: 'Error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    if (_loading) return const LoadingBlock();
    if (_missing) {
      return LaCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Report not found', style: ts(context, size: 18, weight: FontWeight.w700, color: p.textHi)),
          const SizedBox(height: 6),
          Text('There is no assessment to print for this place yet.', style: ts(context, color: p.textLow)),
          const SizedBox(height: 12),
          LaButton(label: 'Back', kind: BtnKind.outline, onTap: app.back),
        ]),
      );
    }
    final a = _a!;
    final narrow = isNarrow(context);
    final statusColor = AppPalette.statusColor(a.overallStatus);
    final inner = p.ink600;

    Widget panel(Widget child) => LaCard(background: inner, hoverBorder: false, child: child);
    Widget infoCell(String label, String value) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label.toUpperCase(), style: ts(context, size: 11, weight: FontWeight.w700, color: p.textHi, spacing: .66, height: 1.3)),
          const SizedBox(height: 4),
          Text(value, style: ts(context, color: p.textMid)),
        ]);
    Widget scaleRow(String range, Color c, String text) => Row(children: [
          LaBadge(range, color: c, minWidth: 80, center: true),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: ts(context, size: 13))),
        ]);
    Widget scoreTable(List<(String, int)> rows) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.line))),
            child: Row(children: [
              Expanded(child: Padding(padding: const EdgeInsets.all(8), child: Text('DOMAIN', style: ts(context, size: 11, weight: FontWeight.w600, color: p.textLow, spacing: .66)))),
              SizedBox(width: 80, child: Padding(padding: const EdgeInsets.all(8), child: Text('SCORE', textAlign: TextAlign.right, style: ts(context, size: 11, weight: FontWeight.w600, color: p.textLow, spacing: .66)))),
              SizedBox(width: 100, child: Padding(padding: const EdgeInsets.all(8), child: Text('RATING', textAlign: TextAlign.center, style: ts(context, size: 11, weight: FontWeight.w600, color: p.textLow, spacing: .66)))),
            ]),
          ),
          for (final r in rows)
            Container(
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.line))),
              child: Row(children: [
                Expanded(child: Padding(padding: const EdgeInsets.all(10), child: Text(r.$1, style: ts(context, size: 13.5)))),
                SizedBox(
                    width: 80,
                    child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Text('${r.$2}', textAlign: TextAlign.right, style: ts(context, size: 16, weight: FontWeight.w700, color: p.textHi, height: 1.2)))),
                SizedBox(
                    width: 100,
                    child: Center(child: LaBadge(AppPalette.bandName(r.$2), color: AppPalette.bandColor(r.$2), fontSize: 10))),
              ]),
            ),
        ]);

    Widget bullet(String? s) => (s ?? '').trim().isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(padding: const EdgeInsets.only(left: 4, right: 10), child: Text('\u2022', style: ts(context, size: 13.5))),
              Expanded(child: Text(s!, style: ts(context, size: 13.5))),
            ]),
          );

    final ds = a.domainScores;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            LaButton(label: 'Back', kind: BtnKind.outline, tooltip: 'Back (Esc)', onTap: app.back),
            LaButton(label: _busy ? 'Working...' : 'Print', kind: BtnKind.gold, tooltip: 'Print (Ctrl+P)', onTap: _busy ? null : _print),
            LaButton(label: 'Save PDF', tooltip: 'Save as PDF (Ctrl+S)', onTap: _busy ? null : _savePdf),
          ]),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: LaCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 22),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.end,
                    runSpacing: 12,
                    children: [
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Personal Life Audit Report', style: ts(context, size: 24, weight: FontWeight.w700, color: p.textHi, height: 1.2)),
                        const SizedBox(height: 4),
                        Text('Comprehensive assessment summary and guidance', style: ts(context, size: 14, color: p.textLow)),
                      ]),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        LaBadge(a.overallStatus, color: statusColor),
                        LaBadge(fmtMmmmDYyyy(a.assessmentDate), color: p.textHi, bg: p.ink600),
                      ]),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: LaGrid(cols: 5, stretch: true, children: [
                    LaStat(value: numText(a.overallScore), label: 'Overall Score'),
                    LaStat(valueWidget: Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Align(alignment: Alignment.centerLeft, child: LaBadge(a.overallStatus, color: statusColor))), label: 'Status'),
                    LaStat(valueWidget: Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Align(alignment: Alignment.centerLeft, child: LaBadge(a.priorityLevel, color: p.textHi, bg: p.ink600))), label: 'Priority'),
                    LaStat(value: a.weakestDomain, valueSize: 16, valueColor: AppPalette.red, label: 'Weakest (${a.weakestScore})'),
                    LaStat(value: a.strongestDomain, valueSize: 16, valueColor: AppPalette.green, label: 'Strongest (${a.strongestScore})'),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: LaGrid(cols: 2, stretch: true, children: [
                    panel(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      const ChartHeading(kicker: 'Assessment Details', title: 'Place Information'),
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(child: infoCell('PSGC Code', _place?.psgcCode ?? '')),
                        const SizedBox(width: 12),
                        Expanded(child: infoCell('Place Name', _place?.name ?? '')),
                      ]),
                      const SizedBox(height: 12),
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(child: infoCell('Assessment Date', fmtMmmmDYyyy(a.assessmentDate))),
                        const SizedBox(width: 12),
                        Expanded(child: infoCell('Next Review', a.nextReviewDate == null ? '' : fmtMmmmDYyyy(a.nextReviewDate!))),
                      ]),
                    ])),
                    panel(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      const ChartHeading(kicker: 'Scoring Guide', title: 'Rating Scale'),
                      scaleRow('8 \u2013 10', AppPalette.green, 'Thriving \u2014 Strong performance, maintain and build from here'),
                      const SizedBox(height: 10),
                      scaleRow('5 \u2013 7', AppPalette.yellow, 'Balancing \u2014 Functional but with room for improvement'),
                      const SizedBox(height: 10),
                      scaleRow('3 \u2013 4', AppPalette.orange, 'Struggling \u2014 Needs attention and focused effort'),
                      const SizedBox(height: 10),
                      scaleRow('1 \u2013 2', AppPalette.red, 'Critical \u2014 Requires immediate action and support'),
                    ])),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: panel(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const ChartHeading(kicker: 'Detailed breakdown', title: '11-Domain Scorecard'),
                    narrow
                        ? Column(children: [scoreTable(ds.take(6).toList()), const SizedBox(height: 16), scoreTable(ds.skip(6).toList())])
                        : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Expanded(child: scoreTable(ds.take(6).toList())),
                            const SizedBox(width: 16),
                            Expanded(child: scoreTable(ds.skip(6).toList())),
                          ]),
                  ])),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: LaGrid(cols: 2, stretch: true, children: [
                    panel(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      const ChartHeading(kicker: 'Insights', title: 'Automated Guidance'),
                      Text(a.automatedAdvice ?? '', style: ts(context, size: 14, color: p.textMid, height: 1.6)),
                    ])),
                    panel(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      const ChartHeading(kicker: 'Direction', title: 'North Star \u00B7 Priorities'),
                      Text.rich(TextSpan(children: [
                        TextSpan(text: 'North Star: ', style: ts(context, size: 14, weight: FontWeight.w700, color: p.textHi)),
                        TextSpan(text: a.northStarStatement ?? '', style: ts(context, size: 14, color: p.textMid)),
                      ])),
                      const SizedBox(height: 8),
                      bullet(a.topPriority1),
                      bullet(a.topPriority2),
                      bullet(a.topPriority3),
                      const SizedBox(height: 8),
                      Text.rich(TextSpan(children: [
                        TextSpan(text: 'Stop / Reduce: ', style: ts(context, size: 13.5, weight: FontWeight.w700, color: p.textHi)),
                        TextSpan(text: a.stopReduce ?? '', style: ts(context, size: 13.5, color: p.textMid)),
                      ])),
                    ])),
                  ]),
                ),
                Container(
                  padding: EdgeInsets.all(narrow ? 18 : 24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [alphaPct(p.gold, .06), alphaPct(p.teal, .04)],
                    ),
                    border: Border.all(color: p.line),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(children: [
                    Text('\u2726', style: ts(context, size: 18, color: p.gold, height: 1)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Planning/tracking tool only. Not a medical, psychological, legal, or financial diagnosis. '
                        'Generated by Area Incident Tracker \u00B7 ${fmtMmmmDYyyy(DateTime.now())}',
                        style: ts(context, size: 12, color: p.textLow),
                      ),
                    ),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      ],
    );
  }
}
