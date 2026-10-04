import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/palette.dart';
import '../theme/theme.dart';
import '../widgets/anim.dart';
import '../widgets/common.dart';

class AreaMapPage extends StatefulWidget {
  const AreaMapPage({super.key, required this.app});
  final AppState app;
  @override
  State<AreaMapPage> createState() => _AreaMapPageState();
}

class _AreaMapPageState extends State<AreaMapPage> {
  static const _phCenter = LatLng(12.8797, 121.7740);

  final _actions = PageActions();
  final _map = MapController();
  final _mapFocus = FocusNode(debugLabel: 'area-map');
  final _stackKey = GlobalKey();
  final _searchCtl = TextEditingController();
  final _searchNode = FocusNode();

  final Map<int, AreaMapPoint> _points = {};
  bool _loading = true;
  bool _includeUnassessed = false;
  bool _unassessedLoaded = false;

  // Geocoding progress
  bool _locating = false;
  int _locDone = 0;
  int _locTotal = 0;
  bool _geoRunning = false;
  bool _disposed = false;

  // Hover card
  AreaMapPoint? _hoverPoint;
  Offset _hoverPos = Offset.zero;
  Timer? _hideTimer;

  // Search
  int _searchSeq = 0;
  List<AreaMapPoint> _lastResults = const [];
  static final _noResults = AreaMapPoint(
      placeId: -1, psgcCode: '', name: '', geocodeQuery: '', hasAssessment: false);

  AppState get app => widget.app;

  @override
  void initState() {
    super.initState();
    _actions.focusSearch = () => _searchNode.requestFocus();
    app.registerPage(_actions);
    _load();
  }

  @override
  void dispose() {
    _disposed = true;
    _hideTimer?.cancel();
    app.geocoder.flush();
    app.unregisterPage(_actions);
    _mapFocus.dispose();
    _searchNode.dispose();
    _searchCtl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final assessments = await app.api.assessmentsCached();
    final latest = <int, AssessmentDto>{};
    for (final a in assessments) {
      final cur = latest[a.placeId];
      if (cur == null || a.assessmentDate.isAfter(cur.assessmentDate)) latest[a.placeId] = a;
    }
    if (!mounted) return;
    setState(() {
      for (final a in latest.values) {
        _points[a.placeId] = AreaMapPoint.fromAssessment(a);
      }
      _loading = false;
    });
    _plotWithCache(_points.values.toList());
  }

  void _plotWithCache(List<AreaMapPoint> pts) {
    for (final pt in pts) {
      final c = app.geocoder.cached(pt.psgcCode);
      if (c != null) {
        pt.lat = c.$1;
        pt.lng = c.$2;
      }
    }
    if (mounted) setState(() {});
    _geocodeQueue(pts);
  }

  Future<void> _geocodeQueue(List<AreaMapPoint> pts) async {
    final todo = pts.where((p) => p.lat == null || p.lng == null).toList();
    if (todo.isEmpty) return;
    // Mirror the website: one locating banner for the batch, sequential requests.
    if (mounted) {
      setState(() {
        _locating = true;
        _locTotal = todo.length;
        _locDone = 0;
      });
    }
    for (final pt in todo) {
      if (_disposed) return;
      final geo = await app.geocoder.geocode(pt);
      if (_disposed || !mounted) return;
      setState(() {
        _locDone++;
        if (geo != null) {
          pt.lat = geo.$1;
          pt.lng = geo.$2;
          _points[pt.placeId] = pt;
        }
      });
    }
    await app.geocoder.flush();
    if (mounted) setState(() => _locating = false);
  }

  Future<void> _toggleUnassessed(bool v) async {
    setState(() => _includeUnassessed = v);
    if (!v || _unassessedLoaded) return;
    _unassessedLoaded = true;
    const pageSize = 500;
    final assessments = await app.api.assessmentsCached();
    final assessed = assessments.map((a) => a.placeId).toSet();
    final pages = await Future.wait([
      for (var page = 1; page <= 4; page++) app.api.places('api/places?page=$page&pageSize=$pageSize', page: page, pageSize: pageSize)
    ]);
    final pts = <AreaMapPoint>[];
    for (final r in pages) {
      for (final pl in r.items) {
        if (assessed.contains(pl.placeId) || _points.containsKey(pl.placeId)) continue;
        pts.add(AreaMapPoint.fromPlace(pl, null));
      }
    }
    for (final pt in pts) {
      _points[pt.placeId] = pt;
    }
    _plotWithCache(pts);
  }

  Color _bandColor(BuildContext context, AreaMapPoint pt) {
    if (!pt.hasAssessment) return context.pal.textLow;
    switch ((pt.overallStatus ?? '').toUpperCase()) {
      case 'THRIVING':
        return AppPalette.green;
      case 'BALANCING':
        return AppPalette.yellow;
      case 'STRUGGLING':
        return AppPalette.orange;
      case 'CRITICAL':
        return AppPalette.red;
      default:
        return context.pal.textLow;
    }
  }

  // ---- hover card -----------------------------------------------------------

  void _showCard(AreaMapPoint pt, PointerEvent e) {
    _hideTimer?.cancel();
    final box = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    final local = box == null ? e.position : box.globalToLocal(e.position);
    setState(() {
      _hoverPoint = pt;
      _hoverPos = local;
    });
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _hoverPoint = null);
    });
  }

  Offset _cardOffset(Size stack) {
    const pad = 16.0, cardW = 300.0, cardH = 230.0;
    var left = _hoverPos.dx + pad;
    var top = _hoverPos.dy + pad;
    if (left + cardW > stack.width) left = _hoverPos.dx - cardW - pad;
    if (top + cardH > stack.height) top = _hoverPos.dy - cardH - pad;
    return Offset(math.max(8, left), math.max(8, top));
  }

  // ---- search ---------------------------------------------------------------

  Future<Iterable<AreaMapPoint>> _searchOptions(TextEditingValue v) async {
    final q = v.text.trim();
    final seq = ++_searchSeq;
    if (q.length < 2) return const [];
    await Future.delayed(const Duration(milliseconds: 250));
    if (seq != _searchSeq) return _lastResults;
    final j = await app.api.get('api/places?search=${Uri.encodeComponent(q)}&page=1&pageSize=20');
    if (seq != _searchSeq) return _lastResults;
    final r = PagedResult.places(j, pageSize: 20);
    if (r.items.isEmpty) {
      _lastResults = [_noResults];
      return _lastResults;
    }
    final ids = r.items.map((e) => e.placeId).toSet();
    final all = await app.api.assessmentsCached();
    final latest = <int, AssessmentDto>{};
    for (final a in all.where((a) => ids.contains(a.placeId))) {
      final cur = latest[a.placeId];
      if (cur == null || a.assessmentDate.isAfter(cur.assessmentDate)) latest[a.placeId] = a;
    }
    _lastResults = [for (final pl in r.items) AreaMapPoint.fromPlace(pl, latest[pl.placeId])];
    return _lastResults;
  }

  Future<void> _selectResult(AreaMapPoint pt) async {
    if (pt.placeId == -1) return;
    _mapFocus.requestFocus();
    final existing = _points[pt.placeId];
    final target = existing ?? pt;
    // Prefer the richer record from search (has level / urban-rural).
    target.lat ??= app.geocoder.cached(pt.psgcCode)?.$1;
    target.lng ??= app.geocoder.cached(pt.psgcCode)?.$2;
    if (target.lat == null || target.lng == null) {
      final geo = await app.geocoder.geocode(pt);
      if (geo == null || !mounted) return;
      target.lat = geo.$1;
      target.lng = geo.$2;
    }
    if (!mounted) return;
    setState(() => _points[pt.placeId] = target);
    _map.move(LatLng(target.lat!, target.lng!), 14);
    final box = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    final center = box == null ? Offset.zero : Offset(box.size.width / 2, box.size.height / 2);
    _hideTimer?.cancel();
    setState(() {
      _hoverPoint = target;
      _hoverPos = center;
    });
  }

  // ---- keyboard on the map ---------------------------------------------------

  void _pan(double dx, double dy) {
    final cam = _map.camera;
    final deg = 360 / (256 * math.pow(2, cam.zoom));
    final lat = (cam.center.latitude - dy * deg * math.cos(cam.center.latitude * math.pi / 180)).clamp(-85.0, 85.0).toDouble();
    final lng = cam.center.longitude + dx * deg;
    _map.move(LatLng(lat, lng), cam.zoom);
  }

  KeyEventResult _mapKey(FocusNode n, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    final ctrl = HardwareKeyboard.instance.isControlPressed;
    if (ctrl) return KeyEventResult.ignored;
    final step = HardwareKeyboard.instance.isShiftPressed ? 240.0 : 80.0;
    if (k == LogicalKeyboardKey.arrowLeft) {
      _pan(-step, 0);
    } else if (k == LogicalKeyboardKey.arrowRight) {
      _pan(step, 0);
    } else if (k == LogicalKeyboardKey.arrowUp) {
      _pan(0, -step);
    } else if (k == LogicalKeyboardKey.arrowDown) {
      _pan(0, step);
    } else if (k == LogicalKeyboardKey.equal || k == LogicalKeyboardKey.add || k == LogicalKeyboardKey.numpadAdd) {
      _map.move(_map.camera.center, math.min(18, _map.camera.zoom + 1));
    } else if (k == LogicalKeyboardKey.minus || k == LogicalKeyboardKey.numpadSubtract) {
      _map.move(_map.camera.center, math.max(2, _map.camera.zoom - 1));
    } else if (k == LogicalKeyboardKey.home) {
      _map.move(_phCenter, 6);
    } else if (k == LogicalKeyboardKey.escape) {
      setState(() => _hoverPoint = null);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  // ---- UI ---------------------------------------------------------------------

  Widget _dot(Color c, {double size = 9}) =>
      Container(width: size, height: size, decoration: BoxDecoration(color: c, shape: BoxShape.circle));

  Widget _legend(BuildContext context, Color c, String text) {
    final p = context.pal;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      _dot(c),
      const SizedBox(width: 6),
      Text(text, style: ts(context, size: 12, color: p.textLow)),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final narrow = vw(context) <= 720;
    final markers = <Marker>[
      for (final pt in _points.values)
        if (pt.lat != null && pt.lng != null)
          Marker(
            point: LatLng(pt.lat!, pt.lng!),
            width: 26,
            height: 34,
            alignment: Alignment.topCenter,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (e) => _showCard(pt, e),
              onHover: (e) => _showCard(pt, e),
              onExit: (_) => _scheduleHide(),
              child: GestureDetector(
                onTap: () => app.goDashboard(placeId: pt.placeId),
                child: CustomPaint(
                  size: const Size(26, 34),
                  painter: _PinPainter(_bandColor(context, pt), p.ink900),
                ),
              ),
            ),
          ),
    ];

    final toolbar = Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.line))),
      child: Wrap(
        spacing: 16,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(width: narrow ? double.infinity : 420, child: _searchField(context)),
          LaCheckbox(
            value: _includeUnassessed,
            label: 'Include areas with no assessment yet',
            labelColor: p.textLow,
            onChanged: _toggleUnassessed,
          ),
        ],
      ),
    );

    final locating = _locating
        ? Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Locating areas\u2026 $_locDone of $_locTotal', style: ts(context, size: 12, color: p.textLow)),
              const SizedBox(height: 6),
              Container(
                height: 4,
                decoration: BoxDecoration(color: p.line, borderRadius: BorderRadius.circular(2)),
                clipBehavior: Clip.antiAlias,
                alignment: Alignment.centerLeft,
                child: AnimatedFractionallySizedBox(
                  duration: const Duration(milliseconds: 200),
                  widthFactor: _locTotal == 0 ? 0 : _locDone / _locTotal,
                  child: Container(color: p.gold),
                ),
              ),
            ]),
          )
        : const SizedBox.shrink();

    final mapH = math.max(420.0, MediaQuery.of(context).size.height * (narrow ? .56 : .68));
    final mapBox = SizedBox(
      height: mapH,
      child: Focus(
        focusNode: _mapFocus,
        onKeyEvent: _mapKey,
        child: Listener(
          onPointerDown: (_) => _mapFocus.requestFocus(),
          child: FlutterMap(
            mapController: _map,
            options: const MapOptions(
              initialCenter: _phCenter,
              initialZoom: 6,
              minZoom: 2,
              maxZoom: 18,
              backgroundColor: Color(0xFFDDDDDD),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.areaincidenttracker.desktop',
                maxZoom: 18,
              ),
              MarkerClusterLayerWidget(
                options: MarkerClusterLayerOptions(
                  maxClusterRadius: 55,
                  size: const Size(40, 40),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(50),
                  markers: markers,
                  builder: (context, ms) => Container(
                    decoration: BoxDecoration(shape: BoxShape.circle, color: alphaPct(p.gold, .35)),
                    alignment: Alignment.center,
                    child: Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: p.gold),
                      child: Text('${ms.length}', style: ts(context, size: 12, weight: FontWeight.w700, color: p.ink900, height: 1)),
                    ),
                  ),
                ),
              ),
              RichAttributionWidget(
                alignment: AttributionAlignment.bottomLeft,
                showFlutterMapAttribution: false,
                attributions: [TextSourceAttribution('OpenStreetMap contributors', onTap: () {})],
              ),
            ],
          ),
        ),
      ),
    );

    final footer = Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: p.line))),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 8,
        children: [
          Wrap(spacing: 16, runSpacing: 6, children: [
            _legend(context, AppPalette.green, 'Thriving'),
            _legend(context, AppPalette.yellow, 'Balancing'),
            _legend(context, AppPalette.orange, 'Struggling'),
            _legend(context, AppPalette.red, 'Critical'),
            _legend(context, p.textLow, 'No assessment'),
          ]),
          Opacity(opacity: .75, child: Text('Map data \u00A9 OpenStreetMap contributors', style: ts(context, size: 11, color: p.textLow))),
        ],
      ),
    );

    return Stack(
      key: _stackKey,
      clipBehavior: Clip.none,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const TopBar(
              title: 'Area Map',
              subtitle: 'Pick an area to locate it on the map, or browse pins colored by current status.',
            ),
            LaCard(
              clip: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [toolbar, locating, if (_loading) const SizedBox(height: 420, child: LoadingBlock()) else mapBox, footer],
              ),
            ),
          ],
        ),
        if (_hoverPoint != null) _hoverCardPositioned(context),
      ],
    );
  }

  Widget _hoverCardPositioned(BuildContext context) {
    final box = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    final size = box == null ? const Size(1200, 900) : box.size;
    final off = _cardOffset(Size(size.width, math.max(size.height, 700)));
    return Positioned(
      left: off.dx,
      top: off.dy,
      child: MouseRegion(
        onEnter: (_) => _hideTimer?.cancel(),
        onExit: (_) => _scheduleHide(),
        child: _HoverCard(
          point: _hoverPoint!,
          color: _bandColor(context, _hoverPoint!),
          onOpen: () => app.goDashboard(placeId: _hoverPoint!.placeId),
        ),
      ),
    );
  }

  Widget _searchField(BuildContext context) {
    final p = context.pal;
    return RawAutocomplete<AreaMapPoint>(
      textEditingController: _searchCtl,
      focusNode: _searchNode,
      optionsBuilder: _searchOptions,
      displayStringForOption: (o) => o.placeId == -1 ? _searchCtl.text : o.name,
      onSelected: _selectResult,
      fieldViewBuilder: (context, ctl, node, onSubmit) => ListenableBuilder(
        listenable: ctl,
        builder: (context, _) => LaInput(
          controller: ctl,
          focusNode: node,
          hint: 'Search an area by name or PSGC code\u2026',
          rounded: 8,
          fill: p.ink700,
          onSubmitted: (_) => onSubmit(),
          trailing: ctl.text.isEmpty
              ? null
              : MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () {
                      ctl.clear();
                      _lastResults = const [];
                    },
                    child: Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      child: Text('\u2715', style: ts(context, size: 12, color: p.textLow, height: 1)),
                    ),
                  ),
                ),
        ),
      ),
      optionsViewBuilder: (context, onSelected, options) {
        final list = options.toList();
        return Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 420,
                constraints: const BoxConstraints(maxHeight: 320),
                decoration: BoxDecoration(
                  color: p.ink800,
                  border: Border.all(color: p.line),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: const [BoxShadow(color: Color.fromRGBO(0, 0, 0, .25), offset: Offset(0, 12), blurRadius: 32)],
                ),
                clipBehavior: Clip.antiAlias,
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final r = list[i];
                    if (r.placeId == -1) {
                      return Padding(
                        padding: const EdgeInsets.all(14),
                        child: Text('No areas found.', style: ts(context, size: 13, color: p.textLow)),
                      );
                    }
                    final hi = AutocompleteHighlightedOption.of(context) == i;
                    return GestureDetector(
                      onTap: () => onSelected(r),
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Container(
                          color: hi ? p.line : null,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          child: Row(children: [
                            _dot(_bandColor(context, r)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(r.name, style: ts(context, size: 14, color: p.textHi, height: 1.3)),
                                const SizedBox(height: 1),
                                Text('${r.psgcCode}${(r.level ?? '').isNotEmpty ? ' \u00B7 ${r.level}' : ''}',
                                    style: ts(context, size: 12, color: p.textLow, height: 1.3)),
                              ]),
                            ),
                          ]),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PinPainter extends CustomPainter {
  _PinPainter(this.color, this.border);
  final Color color;
  final Color border;
  @override
  void paint(Canvas canvas, Size size) {
    // 26x26 box with radius 50% 50% 50% 0, rotated -45deg about its centre.
    canvas.save();
    canvas.translate(13, 13);
    canvas.rotate(-math.pi / 4);
    final rr = RRect.fromRectAndCorners(
      const Rect.fromLTWH(-13, -13, 26, 26),
      topLeft: const Radius.circular(13),
      topRight: const Radius.circular(13),
      bottomRight: const Radius.circular(13),
      bottomLeft: Radius.zero,
    );
    canvas.drawShadow(Path()..addRRect(rr), const Color.fromRGBO(0, 0, 0, .5), 3, false);
    canvas.drawRRect(rr, Paint()..color = color);
    canvas.drawRRect(
      rr.deflate(1),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = border,
    );
    canvas.restore();
    canvas.drawCircle(const Offset(13, 13), 5, Paint()..color = border.withOpacity(.85));
  }

  @override
  bool shouldRepaint(covariant _PinPainter old) => old.color != color || old.border != border;
}

class _HoverCard extends StatelessWidget {
  const _HoverCard({required this.point, required this.color, required this.onOpen});
  final AreaMapPoint point;
  final Color color;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final pt = point;
    final sub = '${pt.psgcCode}${(pt.level ?? '').isNotEmpty ? ' \u00B7 ${pt.level}' : ''}${(pt.urbanRural ?? '').isNotEmpty ? ' \u00B7 ${pt.urbanRural}' : ''}';

    Widget statLabel(String t) => Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(t.toUpperCase(), style: ts(context, size: 10, color: p.textLow, spacing: .4, height: 1.3)),
        );

    Widget body;
    if (pt.hasAssessment) {
      body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          margin: const EdgeInsets.only(top: 14),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: p.ink700, border: Border.all(color: p.line), borderRadius: BorderRadius.circular(10)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(pt.overallScore != null ? pt.overallScore!.toStringAsFixed(1) : '\u2014',
                      style: ts(context, size: 18, weight: FontWeight.w800, color: p.gold, height: 1.3)),
                ),
                statLabel('Overall Score'),
              ]),
            ),
            Expanded(
              child: Column(children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: alphaPct(color, .13), borderRadius: BorderRadius.circular(999)),
                    child: Text((pt.overallStatus ?? '').toUpperCase(),
                        style: ts(context, size: 11, weight: FontWeight.w700, color: color, height: 1.5)),
                  ),
                ),
                statLabel('Status'),
              ]),
            ),
            Expanded(
              child: Column(children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(pt.priorityLevel != null ? pt.priorityLevel!.toUpperCase() : '\u2014',
                      style: ts(context, size: 14, weight: FontWeight.w800, color: p.gold, height: 1.6)),
                ),
                statLabel('Priority'),
              ]),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                statLabel('Weakest'),
                Text('${pt.weakestDomain ?? '\u2014'} (${pt.weakestScore ?? '\u2014'})',
                    style: ts(context, size: 13, weight: FontWeight.w700, color: AppPalette.red, height: 1.3)),
              ]),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                statLabel('Strongest'),
                Text('${pt.strongestDomain ?? '\u2014'} (${pt.strongestScore ?? '\u2014'})',
                    style: ts(context, size: 13, weight: FontWeight.w700, color: AppPalette.green, height: 1.3)),
              ]),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text('Last assessed ${pt.lastAssessmentDate ?? '\u2014'}', style: ts(context, size: 11, color: p.textLow, height: 1.3)),
        ),
      ]);
    } else {
      body = Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text('No assessment yet.', style: ts(context, size: 11, color: p.textLow, height: 1.3)),
      );
    }

    return Container(
      width: 300,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.ink800,
        border: Border.all(color: p.line),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Color.fromRGBO(0, 0, 0, .35), offset: Offset(0, 16), blurRadius: 40)],
      ),
      child: Material(
        color: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(pt.name, style: ts(context, size: 15, weight: FontWeight.w600, color: p.textHi, height: 1.4)),
                  const SizedBox(height: 2),
                  Text(sub, style: ts(context, size: 12, color: p.textLow, height: 1.3)),
                ]),
              ),
            ]),
            body,
            const SizedBox(height: 14),
            GestureDetector(
              onTap: onOpen,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: p.gold, borderRadius: BorderRadius.circular(8)),
                  child: Text('${pt.hasAssessment ? 'View Dashboard' : 'Create First Assessment'} \u2192',
                      style: ts(context, size: 13, weight: FontWeight.w700, color: p.ink900, height: 1.3)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
