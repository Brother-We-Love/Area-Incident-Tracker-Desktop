import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/palette.dart';
import '../theme/theme.dart';
import '../widgets/anim.dart';
import '../widgets/common.dart';
import '../widgets/icons.dart';
import '../widgets/pickers.dart';

class _GradientTrack extends RoundedRectSliderTrackShape {
  const _GradientTrack(this.colors);
  final List<Color> colors;

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 2,
  }) {
    final rect = getPreferredRect(parentBox: parentBox, offset: offset, sliderTheme: sliderTheme, isEnabled: isEnabled, isDiscrete: isDiscrete);
    final r = RRect.fromRectAndRadius(rect, const Radius.circular(99));
    final paint = Paint()
      ..shader = LinearGradient(colors: colors).createShader(rect);
    context.canvas.drawRRect(r, paint);
  }
}

class _SliderField extends StatefulWidget {
  const _SliderField({required this.index, required this.value, required this.onChanged});
  final int index;
  final int value;
  final ValueChanged<int> onChanged;
  @override
  State<_SliderField> createState() => _SliderFieldState();
}

class _SliderFieldState extends State<_SliderField> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final i = widget.index;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: p.ink800,
          border: Border.all(color: p.line),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    LaIcon(LaIcons.domains[i], size: 16, color: _hover ? p.gold : p.textLow),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(kDomainLabels[i],
                          overflow: TextOverflow.ellipsis,
                          style: ts(context, size: 13, weight: FontWeight.w600, color: p.textMid)),
                    ),
                  ]),
                ),
                Text('${widget.value}', style: ts(context, size: 18, weight: FontWeight.w700, color: p.gold, height: 1.2)),
              ],
            ),
            const SizedBox(height: 6),
            Focus(
              // Type 1-9 (0 = 10) to jump straight to a score.
              onKeyEvent: (n, e) {
                if (e is! KeyDownEvent) return KeyEventResult.ignored;
                if (HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isAltPressed) {
                  return KeyEventResult.ignored;
                }
                final label = e.character;
                if (label != null && label.length == 1 && RegExp(r'[0-9]').hasMatch(label)) {
                  final d = int.parse(label);
                  widget.onChanged(d == 0 ? 10 : d);
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: 6,
                  trackShape: _GradientTrack([AppPalette.red, AppPalette.orange, p.gold, p.teal]),
                  thumbShape: _ThumbShape(p),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                  overlayColor: alphaPct(p.teal, .18),
                  activeTickMarkColor: Colors.transparent,
                  inactiveTickMarkColor: Colors.transparent,
                  tickMarkShape: SliderTickMarkShape.noTickMark,
                ),
                child: Slider(
                  value: widget.value.toDouble(),
                  min: 1,
                  max: 10,
                  divisions: 9,
                  onChanged: (v) => widget.onChanged(v.round()),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThumbShape extends SliderComponentShape {
  const _ThumbShape(this.p);
  final AppPalette p;
  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => const Size(20, 20);
  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final c = context.canvas;
    c.drawCircle(center, 10, Paint()..color = p.teal);
    c.drawCircle(center, 7, Paint()..color = p.textHi);
  }
}

class NewAssessmentPage extends StatefulWidget {
  const NewAssessmentPage({super.key, required this.app, this.placeId});
  final AppState app;
  final int? placeId;
  @override
  State<NewAssessmentPage> createState() => _NewAssessmentPageState();
}

class _NewAssessmentPageState extends State<NewAssessmentPage> {
  final _actions = PageActions();
  final _northStar = TextEditingController();
  final _p1 = TextEditingController();
  final _p2 = TextEditingController();
  final _p3 = TextEditingController();
  final _stop = TextEditingController();
  final _notes = TextEditingController();
  final _placeNode = FocusNode();

  final List<int> _scores = List<int>.filled(11, 5);
  bool _loading = true;
  bool _busy = false;
  PlaceDto? _place;
  int _placeId = 0;
  late DateTime _date;
  late DateTime _next;
  String _freq = 'Monthly';
  List<String> _errors = [];

  AppState get app => widget.app;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _date = DateTime(now.year, now.month, now.day);
    _next = DateTime(now.year, now.month + 1, now.day);
    // Clamp like .NET AddMonths (e.g. Jan 31 -> Feb 28).
    if (_next.month != (now.month % 12) + 1) _next = DateTime(now.year, now.month + 2, 0);
    _actions.save = _save;
    app.registerPage(_actions);
    _load();
  }

  @override
  void dispose() {
    app.unregisterPage(_actions);
    for (final c in [_northStar, _p1, _p2, _p3, _stop, _notes]) {
      c.dispose();
    }
    _placeNode.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final api = app.api;
    PlaceDto? place;
    if (widget.placeId != null) {
      place = await api.place(widget.placeId!);
    }
    if (place == null) {
      final list = await api.places('api/places');
      place = list.items.isEmpty ? null : list.items.first;
    }
    if (!mounted) return;
    setState(() {
      _place = place;
      _placeId = place?.placeId ?? widget.placeId ?? 0;
      _loading = false;
    });
    app.contextPlaceId = _placeId == 0 ? null : _placeId;
  }

  Future<void> _pick() async {
    final pl = await showPlacePicker(app);
    if (pl != null && mounted) {
      setState(() {
        _place = pl;
        _placeId = pl.placeId;
      });
      app.contextPlaceId = pl.placeId;
    }
  }

  String? _nz(String s) => s.trim().isEmpty ? null : s;

  Future<void> _save() async {
    if (_busy || _loading) return;
    if (_placeId == 0) {
      setState(() => _errors = ['Please select a place.']);
      return;
    }
    setState(() {
      _busy = true;
      _errors = [];
    });
    final dto = AssessmentUpsert(
      placeId: _placeId,
      assessmentDate: _date,
      scores: List<int>.from(_scores),
      northStarStatement: _nz(_northStar.text),
      topPriority1: _nz(_p1.text),
      topPriority2: _nz(_p2.text),
      topPriority3: _nz(_p3.text),
      stopReduce: _nz(_stop.text),
      nextReviewDate: _next,
      reviewFrequency: _freq,
      notes: _nz(_notes.text),
    );
    final (ok, data, err) = await app.api.post('api/assessments', dto.toJson());
    if (!mounted) return;
    if (!ok || data == null) {
      setState(() {
        _busy = false;
        _errors = [(err == null || err.trim().isEmpty) ? 'Could not save assessment.' : err];
      });
      return;
    }
    app.toast('success', 'Assessment saved and scored.', title: 'Success');
    app.navigate(AppRoute(PageId.dashboard, placeId: _placeId));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TopBar(
          title: 'New Incident',
          subtitle: 'Score all 11 categories from 1 (critical) to 10 (thriving). Results calculate automatically on save.',
        ),
        if (_loading)
          const LoadingBlock()
        else
          FormCard(
            avatar: LaIcon(LaIcons.doc, size: 32, color: p.teal),
            heroTitle: 'Area Incident Tracker Incident',
            heroText: 'Evaluate the selected area across all categories and define its action plan.',
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              ValidationSummary(_errors),
              FormSection(
                title: 'Incident Info',
                child: LaGrid(cols: 2, gap: 20, children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const LaLabel('Place'),
                    PlacePickerButton(
                      label: _place != null ? _place!.label : 'Select a place...',
                      onTap: _pick,
                      focusNode: _placeNode,
                      autofocus: true,
                    ),
                  ]),
                  Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const LaLabel('Assessment Date'),
                    DateField(app: app, value: _date, onChanged: (d) => setState(() => _date = d)),
                  ]),
                ]),
              ),
              FormSection(
                title: '11-Category Scorecard',
                child: LaGrid(
                  cols: 2,
                  gap: 20,
                  children: [
                    for (var i = 0; i < 11; i++)
                      _SliderField(index: i, value: _scores[i], onChanged: (v) => setState(() => _scores[i] = v)),
                  ],
                ),
              ),
              FormSection(
                title: 'North Star & Planning',
                last: true,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const LaLabel('North Star Statement'),
                  LaInput(controller: _northStar, icon: LaIcons.star, maxLines: 2, hint: 'Define the overarching life purpose...'),
                  const SizedBox(height: 16),
                  LaGrid(cols: 3, gap: 20, children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      const LaLabel('Top Priority 1'),
                      LaInput(
                        controller: _p1,
                        hint: 'Most important action',
                        iconWidget: Text('1', style: ts(context, size: 14, weight: FontWeight.w700, color: AppPalette.red, height: 1)),
                      ),
                    ]),
                    Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      const LaLabel('Top Priority 2'),
                      LaInput(
                        controller: _p2,
                        hint: 'Second priority',
                        iconWidget: Text('2', style: ts(context, size: 14, weight: FontWeight.w700, color: AppPalette.orange, height: 1)),
                      ),
                    ]),
                    Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      const LaLabel('Top Priority 3'),
                      LaInput(
                        controller: _p3,
                        hint: 'Third priority',
                        iconWidget: Text('3', style: ts(context, size: 14, weight: FontWeight.w700, color: p.gold, height: 1)),
                      ),
                    ]),
                  ]),
                  const SizedBox(height: 16),
                  const LaLabel('Stop / Reduce'),
                  LaInput(controller: _stop, icon: LaIcons.ban, hint: 'Habits or activities to stop or reduce'),
                  const SizedBox(height: 16),
                  LaGrid(cols: 2, gap: 20, children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      const LaLabel('Next Review Date'),
                      DateField(app: app, value: _next, onChanged: (d) => setState(() => _next = d)),
                    ]),
                    Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      const LaLabel('Review Frequency'),
                      LaSelect<String>(
                        value: _freq,
                        items: const [('Monthly', 'Monthly'), ('Quarterly', 'Quarterly')],
                        onChanged: (v) => setState(() => _freq = v ?? 'Monthly'),
                      ),
                    ]),
                  ]),
                  const SizedBox(height: 16),
                  const LaLabel('Notes'),
                  LaInput(controller: _notes, icon: LaIcons.pencil, maxLines: 2, hint: 'Additional observations...'),
                ]),
              ),
              FormActions(children: [
                LaButton(
                  tooltip: 'Save Assessment (Ctrl+S)',
                  onTap: _busy ? null : _save,
                  leading: LaIcon(LaIcons.save, size: 16, color: const Color(0xFFF4FFF4)),
                  label: _busy ? 'Saving...' : 'Save Assessment',
                ),
                LaButton(label: 'Cancel', kind: BtnKind.outline, tooltip: 'Cancel (Esc)', onTap: () => app.goDashboard()),
              ]),
            ]),
          ),
      ],
    );
  }
}
