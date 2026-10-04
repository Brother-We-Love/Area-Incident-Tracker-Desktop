import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/models.dart';

/// Builds the printable A4 report, mirroring the website's @media print rules:
/// white page, dark text, ruled headings, banded rating pills.
class ReportPdf {
  static Future<Uint8List> build(AssessmentDto a, PlaceDto? place) async {
    final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/Inter-Regular.ttf'));
    final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/Inter-Bold.ttf'));
    final doc = pw.Document(
      title: 'Personal Life Audit Report',
      author: 'Area Incident Tracker',
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
    );

    const ink = PdfColor.fromInt(0xFF111111);
    const mid = PdfColor.fromInt(0xFF222222);
    const grey = PdfColor.fromInt(0xFF555555);
    const rule = PdfColor.fromInt(0xFFCCCCCC);
    const faint = PdfColor.fromInt(0xFFDDDDDD);

    PdfColor bandFg(String b) => switch (b) {
          'green' => const PdfColor.fromInt(0xFF1A7A5A),
          'yellow' => const PdfColor.fromInt(0xFF8A6D00),
          'orange' => const PdfColor.fromInt(0xFF8A4500),
          _ => const PdfColor.fromInt(0xFF8A1A1A),
        };
    PdfColor bandBg(String b) => switch (b) {
          'green' => const PdfColor.fromInt(0xFFD4F5E9),
          'yellow' => const PdfColor.fromInt(0xFFFEF9E7),
          'orange' => const PdfColor.fromInt(0xFFFFF3E6),
          _ => const PdfColor.fromInt(0xFFFDEAEA),
        };
    String bandOfScore(int s) => s >= 8 ? 'green' : s >= 5 ? 'yellow' : s >= 3 ? 'orange' : 'red';
    String bandOfStatus(String s) => s == 'THRIVING'
        ? 'green'
        : s == 'BALANCING'
            ? 'yellow'
            : s == 'STRUGGLING'
                ? 'orange'
                : 'red';

    pw.Widget pill(String text, String band, {double size = 9, double? minWidth}) => pw.Container(
          constraints: minWidth == null ? null : pw.BoxConstraints(minWidth: minWidth),
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          alignment: minWidth == null ? null : pw.Alignment.center,
          decoration: pw.BoxDecoration(
            color: bandBg(band),
            border: pw.Border.all(color: bandFg(band), width: .8),
            borderRadius: pw.BorderRadius.circular(3),
          ),
          child: pw.Text(text, style: pw.TextStyle(fontSize: size, fontWeight: pw.FontWeight.bold, color: bandFg(band))),
        );

    pw.Widget plainPill(String text) => pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey600, width: .8),
            borderRadius: pw.BorderRadius.circular(3),
          ),
          child: pw.Text(text, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: ink)),
        );

    pw.Widget heading(String kicker, String title) => pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.only(bottom: 6),
          margin: const pw.EdgeInsets.only(bottom: 10),
          decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: rule, width: .8))),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(kicker.toUpperCase(), style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: grey, letterSpacing: 1.1)),
            pw.SizedBox(height: 2),
            pw.Text(title, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: ink)),
          ]),
        );

    pw.Widget stat(pw.Widget value, String label) => pw.Expanded(
          child: pw.Container(
            margin: const pw.EdgeInsets.only(right: 6),
            padding: const pw.EdgeInsets.all(9),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: rule, width: .8)),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              value,
              pw.SizedBox(height: 4),
              pw.Text(label.toUpperCase(), style: pw.TextStyle(fontSize: 7.5, color: grey, letterSpacing: .7)),
            ]),
          ),
        );

    pw.Widget scoreTable(List<(String, int)> rows) => pw.Table(
          columnWidths: {0: const pw.FlexColumnWidth(3), 1: const pw.FixedColumnWidth(40), 2: const pw.FixedColumnWidth(58)},
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: ink, width: 1.5))),
              children: [
                for (var i = 0; i < 3; i++)
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 5),
                    child: pw.Text(const ['DOMAIN', 'SCORE', 'RATING'][i],
                        textAlign: i == 0 ? pw.TextAlign.left : (i == 1 ? pw.TextAlign.right : pw.TextAlign.center),
                        style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF333333), letterSpacing: .5)),
                  ),
              ],
            ),
            for (final r in rows)
              pw.TableRow(
                decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: faint, width: .6))),
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(r.$1, style: const pw.TextStyle(fontSize: 9, color: mid))),
                  pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text('${r.$2}', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: ink))),
                  pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 2),
                      child: pw.Center(child: pill(bandOfScore(r.$2), bandOfScore(r.$2), size: 7))),
                ],
              ),
          ],
        );

    pw.Widget infoCell(String label, String value) => pw.Expanded(
          child: pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 8, right: 8),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(label.toUpperCase(), style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: ink, letterSpacing: .5)),
              pw.SizedBox(height: 3),
              pw.Text(value, style: const pw.TextStyle(fontSize: 10, color: mid)),
            ]),
          ),
        );

    final scale = [
      ('8 \u2013 10', 'green', 'Thriving \u2014 Strong performance, maintain and build from here'),
      ('5 \u2013 7', 'yellow', 'Balancing \u2014 Functional but with room for improvement'),
      ('3 \u2013 4', 'orange', 'Struggling \u2014 Needs attention and focused effort'),
      ('1 \u2013 2', 'red', 'Critical \u2014 Requires immediate action and support'),
    ];

    final ds = a.domainScores;
    pw.Widget bullet(String? s) => (s ?? '').trim().isEmpty
        ? pw.SizedBox()
        : pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 3, left: 6),
            child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('\u2022  ', style: const pw.TextStyle(fontSize: 10, color: mid)),
              pw.Expanded(child: pw.Text(s!, style: const pw.TextStyle(fontSize: 10, color: mid))),
            ]),
          );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(2 * PdfPageFormat.cm, 2 * PdfPageFormat.cm, 2 * PdfPageFormat.cm, 2.5 * PdfPageFormat.cm),
        build: (ctx) => [
          pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 10),
            margin: const pw.EdgeInsets.only(bottom: 18),
            decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: ink, width: 1.5))),
            child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('Personal Life Audit Report', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: ink)),
                pw.SizedBox(height: 4),
                pw.Text('Comprehensive assessment summary and guidance',
                    style: pw.TextStyle(fontSize: 10, color: const PdfColor.fromInt(0xFF444444), fontStyle: pw.FontStyle.italic)),
              ]),
              pw.Row(children: [
                pill(a.overallStatus, bandOfStatus(a.overallStatus), size: 9),
                pw.SizedBox(width: 6),
                plainPill(fmtMmmmDYyyy(a.assessmentDate)),
              ]),
            ]),
          ),
          pw.Row(children: [
            stat(pw.Text(numText(a.overallScore), style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: ink)), 'Overall Score'),
            stat(pill(a.overallStatus, bandOfStatus(a.overallStatus)), 'Status'),
            stat(plainPill(a.priorityLevel), 'Priority'),
            stat(pw.Text(a.weakestDomain, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF8A1A1A))), 'Weakest (${a.weakestScore})'),
            stat(pw.Text(a.strongestDomain, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF1A7A5A))), 'Strongest (${a.strongestScore})'),
          ]),
          pw.SizedBox(height: 18),
          heading('Assessment Details', 'Place Information'),
          pw.Row(children: [infoCell('PSGC Code', place?.psgcCode ?? a.psgcCode), infoCell('Place Name', place?.name ?? a.placeName)]),
          pw.Row(children: [
            infoCell('Assessment Date', fmtMmmmDYyyy(a.assessmentDate)),
            infoCell('Next Review', a.nextReviewDate == null ? '' : fmtMmmmDYyyy(a.nextReviewDate!)),
          ]),
          pw.SizedBox(height: 10),
          heading('Scoring Guide', 'Rating Scale'),
          for (final s in scale)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 7),
              child: pw.Row(children: [
                pill(s.$1, s.$2, size: 8, minWidth: 56),
                pw.SizedBox(width: 10),
                pw.Expanded(child: pw.Text(s.$3, style: const pw.TextStyle(fontSize: 9.5, color: mid))),
              ]),
            ),
          pw.SizedBox(height: 12),
          heading('Detailed breakdown', '11-Domain Scorecard'),
          pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Expanded(child: scoreTable(ds.take(6).toList())),
            pw.SizedBox(width: 16),
            pw.Expanded(child: scoreTable(ds.skip(6).toList())),
          ]),
          pw.SizedBox(height: 16),
          pw.Container(
            width: double.infinity,
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              heading('Insights', 'Automated Guidance'),
              pw.Text(a.automatedAdvice ?? '', style: const pw.TextStyle(fontSize: 10.5, color: mid, lineSpacing: 3)),
            ]),
          ),
          pw.SizedBox(height: 16),
          pw.Container(
            width: double.infinity,
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              heading('Direction', 'North Star \u00B7 Priorities'),
              pw.RichText(
                text: pw.TextSpan(children: [
                  pw.TextSpan(text: 'North Star: ', style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold, color: ink)),
                  pw.TextSpan(text: a.northStarStatement ?? '', style: const pw.TextStyle(fontSize: 10.5, color: mid)),
                ]),
              ),
              pw.SizedBox(height: 6),
              bullet(a.topPriority1),
              bullet(a.topPriority2),
              bullet(a.topPriority3),
              pw.SizedBox(height: 4),
              pw.RichText(
                text: pw.TextSpan(children: [
                  pw.TextSpan(text: 'Stop / Reduce: ', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: ink)),
                  pw.TextSpan(text: a.stopReduce ?? '', style: const pw.TextStyle(fontSize: 10, color: mid)),
                ]),
              ),
            ]),
          ),
          pw.SizedBox(height: 24),
          pw.Container(
            padding: const pw.EdgeInsets.only(top: 12),
            decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: ink, width: 1.5))),
            child: pw.Center(
              child: pw.Text(
                'Planning/tracking tool only. Not a medical, psychological, legal, or financial diagnosis. '
                'Generated by Area Incident Tracker \u00B7 ${fmtMmmmDYyyy(DateTime.now())}',
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(fontSize: 9, color: grey),
              ),
            ),
          ),
        ],
      ),
    );
    return doc.save();
  }
}
