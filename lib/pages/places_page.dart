import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/palette.dart';
import '../theme/theme.dart';
import '../widgets/anim.dart';
import '../widgets/common.dart';
import '../widgets/icons.dart';
import '../widgets/modal.dart';

// ---------------------------------------------------------------------------
// Places list
// ---------------------------------------------------------------------------
class PlacesPage extends StatefulWidget {
  const PlacesPage({super.key, required this.app, required this.route});
  final AppState app;
  final AppRoute route;
  @override
  State<PlacesPage> createState() => _PlacesPageState();
}

class _PlacesPageState extends State<PlacesPage> {
  final _actions = PageActions();
  final _search = TextEditingController();
  final _searchNode = FocusNode();
  final _parent = TextEditingController();
  final _tableFocus = FocusNode(debugLabel: 'places-table');
  final _scroll = ScrollController();
  String _level = '';
  bool _loading = true;
  PagedResult<PlaceDto> _result = PagedResult(<PlaceDto>[], 0, 1, 15);
  int _sel = 0;

  AppState get app => widget.app;
  AppRoute get r => widget.route;

  @override
  void initState() {
    super.initState();
    _search.text = r.search ?? '';
    _level = r.level ?? '';
    _parent.text = r.parentPlaceId?.toString() ?? '';
    _actions.focusSearch = () {
      _searchNode.requestFocus();
    };
    _actions.newItem = () {
      app.go(PageId.placeCreate);
    };
    app.registerPage(_actions);
    _tableFocus.addListener(() {
      if (mounted) setState(() {});
    });
    _load();
  }

  @override
  void dispose() {
    app.unregisterPage(_actions);
    _search.dispose();
    _searchNode.dispose();
    _parent.dispose();
    _tableFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    var url = 'api/places?page=${r.pageNo}&pageSize=15';
    if ((r.search ?? '').trim().isNotEmpty) url += '&search=${Uri.encodeComponent(r.search!)}';
    if ((r.level ?? '').trim().isNotEmpty) url += '&level=${Uri.encodeComponent(r.level!)}';
    if (r.parentPlaceId != null) url += '&parentPlaceId=${r.parentPlaceId}';
    final res = await app.api.places(url, page: r.pageNo);
    if (!mounted) return;
    setState(() {
      _result = res;
      _loading = false;
      _sel = 0;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_searchNode.hasFocus && _result.items.isNotEmpty) _tableFocus.requestFocus();
    });
  }

  bool get _filtered => (r.search ?? '').trim().isNotEmpty || (r.level ?? '').trim().isNotEmpty || r.parentPlaceId != null;

  void _go({String? search, String? level, int? parent, int page = 1, bool clear = false}) {
    app.navigate(AppRoute(
      PageId.places,
      search: clear ? null : search,
      level: clear ? null : (level == '' ? null : level),
      parentPlaceId: clear ? null : parent,
      pageNo: page,
    ));
  }

  void _filter() {
    final s = _search.text.trim();
    _go(search: s.isEmpty ? null : _search.text, level: _level, parent: int.tryParse(_parent.text.trim()));
  }

  void _toPage(int page) {
    final total = _totalPages;
    if (page < 1 || page > total || page == _result.page) return;
    _go(search: r.search, level: r.level, parent: r.parentPlaceId, page: page);
  }

  int get _totalPages => (_result.totalCount / _result.pageSize).ceil();

  Future<void> _delete(PlaceDto pl) async {
    final ok = await laConfirm(
      app,
      title: 'Remove place?',
      message: 'This will permanently remove ${pl.name} (${pl.psgcCode}) and all associated assessments. This action cannot be undone.',
      confirmText: 'Delete',
      danger: true,
    );
    if (!ok) return;
    await app.api.delete('api/places/${pl.placeId}');
    app.toast('success', 'Place removed.', title: 'Success');
    app.reload();
  }

  KeyEventResult _tableKey(FocusNode n, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    final items = _result.items;
    if (items.isEmpty) return KeyEventResult.ignored;
    final k = e.logicalKey;
    final ctrl = HardwareKeyboard.instance.isControlPressed;
    if (ctrl) return KeyEventResult.ignored;
    if (k == LogicalKeyboardKey.arrowDown) {
      setState(() => _sel = math.min(items.length - 1, _sel + 1));
    } else if (k == LogicalKeyboardKey.arrowUp) {
      setState(() => _sel = math.max(0, _sel - 1));
    } else if (k == LogicalKeyboardKey.home) {
      setState(() => _sel = 0);
    } else if (k == LogicalKeyboardKey.end) {
      setState(() => _sel = items.length - 1);
    } else if (k == LogicalKeyboardKey.pageDown) {
      _toPage(_result.page + 1);
    } else if (k == LogicalKeyboardKey.pageUp) {
      _toPage(_result.page - 1);
    } else if (k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.numpadEnter) {
      app.goDashboard(placeId: items[_sel].placeId);
    } else if (k == LogicalKeyboardKey.keyE) {
      app.navigate(AppRoute(PageId.placeEdit, id: items[_sel].placeId));
    } else if (k == LogicalKeyboardKey.delete) {
      _delete(items[_sel]);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final total = _result.totalCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TopBar(
          title: 'Places',
          subtitle: '$total area${total == 1 ? '' : 's'} in the database.',
          trailing: LaButton(label: '+ Add Place', tooltip: 'Add Place (Ctrl+N)', onTap: () => app.go(PageId.placeCreate)),
        ),
        LaCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LaGrid(cols: 3, gap: 8, minColWidth: 200, children: [
                Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const LaLabel('Search', hi: false, bottom: 4),
                  LaInput(
                    controller: _search,
                    focusNode: _searchNode,
                    hint: 'Name or PSGC code',
                    onSubmitted: (_) => _filter(),
                  ),
                ]),
                Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const LaLabel('Level', hi: false, bottom: 4),
                  LaSelect<String>(
                    value: _level,
                    items: const [
                      ('', 'All levels'),
                      ('region', 'Region'),
                      ('province', 'Province'),
                      ('city', 'City'),
                      ('municipality', 'Municipality'),
                      ('barangay', 'Barangay'),
                    ],
                    onChanged: (v) => setState(() => _level = v ?? ''),
                  ),
                ]),
                Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const LaLabel('Parent Place ID', hi: false, bottom: 4),
                  LaInput(
                    controller: _parent,
                    hint: 'Optional',
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onSubmitted: (_) => _filter(),
                  ),
                ]),
              ]),
              const SizedBox(height: 12),
              Wrap(spacing: 8, children: [
                LaButton(label: 'Filter', kind: BtnKind.outline, onTap: _filter),
                if (_filtered) LaButton(label: 'Clear', kind: BtnKind.outline, onTap: () => _go(clear: true)),
              ]),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _table(context),
        if (_totalPages > 1) ...[const SizedBox(height: 16), _pager(context)],
      ],
    );
  }

  Widget _table(BuildContext context) {
    final p = context.pal;
    final narrow = isNarrow(context);
    final items = _result.items;
    final cols = <(String, double)>[
      ('PSGC Code', 130),
      ('Name', 220),
      ('Level', 120),
      ('Parent', 90),
      ('Classification', 150),
      ('', 270),
    ];
    final minW = cols.fold<double>(0, (a, b) => a + b.$2);
    return LaCard(
      child: LayoutBuilder(builder: (context, c) {
        final width = math.max(c.maxWidth, narrow ? 700.0 : minW);
        Widget headCell(String t, double w, {bool flex = false}) => Container(
              width: flex ? null : w,
              padding: const EdgeInsets.all(10),
              child: Text(t.toUpperCase(), style: ts(context, size: 11, weight: FontWeight.w600, color: p.textLow, spacing: .66)),
            );
        final head = Container(
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.line))),
          child: Row(children: [
            headCell('PSGC Code', 130),
            Expanded(flex: 3, child: headCell('Name', 0, flex: true)),
            headCell('Level', 120),
            headCell('Parent', 90),
            Expanded(flex: 2, child: headCell('Classification', 0, flex: true)),
            const SizedBox(width: 270),
          ]),
        );
        Widget body;
        if (_loading) {
          body = const LoadingBlock();
        } else if (items.isEmpty) {
          body = Padding(
            padding: const EdgeInsets.all(30),
            child: Center(child: Text('No places found.', style: ts(context, color: p.textLow, size: 13.5))),
          );
        } else {
          body = Focus(
            focusNode: _tableFocus,
            onKeyEvent: _tableKey,
            child: Column(children: [
              for (var i = 0; i < items.length; i++) _row(context, items[i], i),
            ]),
          );
        }
        final table = SizedBox(width: width, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [head, body]));
        return width > c.maxWidth
            ? Scrollbar(controller: _scroll, child: SingleChildScrollView(controller: _scroll, scrollDirection: Axis.horizontal, child: table))
            : table;
      }),
    );
  }

  Widget _row(BuildContext context, PlaceDto pl, int i) {
    final p = context.pal;
    final selected = i == _sel && _tableFocus.hasFocus;
    Widget cell(Widget child, {double? w, int? flex}) {
      final box = Container(width: w, padding: const EdgeInsets.all(10), alignment: Alignment.centerLeft, child: child);
      return flex != null ? Expanded(flex: flex, child: box) : box;
    }

    final classification = pl.isCapital ? 'Capital' : (pl.cityType ?? pl.incomeClass ?? pl.urbanRural ?? '\u2014');
    return _HoverRow(
      selected: selected,
      onTap: () {
        _tableFocus.requestFocus();
        setState(() => _sel = i);
      },
      child: Container(
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.line))),
        child: Row(children: [
          cell(Text(pl.psgcCode, style: ts(context, size: 13.5, weight: FontWeight.w700, color: p.textHi)), w: 130),
          cell(Text(pl.name, style: ts(context, size: 13.5)), flex: 3),
          cell(Text(pl.level, style: ts(context, size: 13.5)), w: 120),
          cell(Text(pl.parentPlaceId?.toString() ?? '\u2014', style: ts(context, size: 13.5)), w: 90),
          cell(Text(classification, style: ts(context, size: 13.5)), flex: 2),
          Container(
            width: 270,
            padding: const EdgeInsets.all(10),
            alignment: Alignment.centerRight,
            child: Wrap(spacing: 4, children: [
              LaButton(label: 'Dashboard', kind: BtnKind.outline, small: true, onTap: () => app.goDashboard(placeId: pl.placeId)),
              LaButton(label: 'Edit', kind: BtnKind.outline, small: true, onTap: () => app.navigate(AppRoute(PageId.placeEdit, id: pl.placeId))),
              LaButton(
                label: 'Delete',
                kind: BtnKind.outline,
                small: true,
                textColor: AppPalette.red,
                borderColor: alphaPct(AppPalette.red, .4),
                onTap: () => _delete(pl),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _pager(BuildContext context) {
    final p = context.pal;
    final page = _result.page;
    final totalPages = _totalPages;
    int startPage, endPage;
    if (totalPages <= 10) {
      startPage = 1;
      endPage = totalPages;
    } else {
      startPage = math.max(1, math.min(page - 4, totalPages - 9));
      endPage = startPage + 9;
      if (endPage > totalPages) {
        endPage = totalPages;
        startPage = totalPages - 9;
      }
    }
    Widget btn(String label, int? target, {bool disabled = false, bool current = false}) {
      final b = LaButton(
        label: label,
        kind: current ? BtnKind.gold : BtnKind.outline,
        minWidth: 40,
        onTap: (disabled || current || target == null) ? null : () => _toPage(target),
      );
      return disabled ? Opacity(opacity: .4, child: IgnorePointer(child: b)) : (current ? IgnorePointer(child: b) : b);
    }

    final from = (page - 1) * _result.pageSize + 1;
    final to = math.min(page * _result.pageSize, _result.totalCount);
    return LaCard(
      child: Column(
        children: [
          Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, children: [
            btn('\u00AB First', 1),
            btn('\u2039 Prev', page - 1, disabled: page <= 1),
            for (var i = startPage; i <= endPage; i++) btn('$i', i, current: i == page),
            btn('Next \u203A', page + 1, disabled: page >= totalPages),
            btn('Last \u00BB', totalPages),
          ]),
          const SizedBox(height: 10),
          Text('Showing $from \u2013 $to of ${_result.totalCount}', style: ts(context, size: 13, color: p.textMid)),
        ],
      ),
    );
  }
}

class _HoverRow extends StatefulWidget {
  const _HoverRow({required this.child, required this.selected, required this.onTap});
  final Widget child;
  final bool selected;
  final VoidCallback onTap;
  @override
  State<_HoverRow> createState() => _HoverRowState();
}

class _HoverRowState extends State<_HoverRow> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return MouseRegion(
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          decoration: BoxDecoration(
            color: widget.selected ? alphaPct(p.teal, .14) : (_h ? const Color.fromRGBO(255, 255, 255, .02) : null),
            border: widget.selected ? Border(left: BorderSide(color: p.teal, width: 3)) : null,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Add / Edit place
// ---------------------------------------------------------------------------
class PlaceFormPage extends StatefulWidget {
  const PlaceFormPage({super.key, required this.app, this.editId});
  final AppState app;
  final int? editId;
  @override
  State<PlaceFormPage> createState() => _PlaceFormPageState();
}

class _PlaceFormPageState extends State<PlaceFormPage> {
  final _actions = PageActions();
  final _psgc = TextEditingController();
  final _name = TextEditingController();
  final _level = TextEditingController(text: 'province');
  final _parent = TextEditingController();
  final _income = TextEditingController();
  final _cityType = TextEditingController();
  final _urban = TextEditingController();
  final _old = TextEditingController();
  final _nameNode = FocusNode();
  final _psgcNode = FocusNode();
  bool _isCapital = false;
  bool _loading = false;
  bool _busy = false;
  String? _guid;
  List<String> _errors = [];
  final Set<String> _bad = {};

  AppState get app => widget.app;
  bool get _edit => widget.editId != null;

  @override
  void initState() {
    super.initState();
    _actions.save = _save;
    app.registerPage(_actions);
    if (_edit) {
      _loading = true;
      _loadExisting();
    }
  }

  Future<void> _loadExisting() async {
    final pl = await app.api.place(widget.editId!);
    if (!mounted) return;
    if (pl == null) {
      app.toast('error', 'Place not found.', title: 'Error');
      app.back();
      return;
    }
    final u = PlaceUpsert.fromPlace(pl);
    setState(() {
      _psgc.text = u.psgcCode;
      _name.text = u.name;
      _level.text = u.level;
      _parent.text = u.parentPlaceId?.toString() ?? '';
      _income.text = u.incomeClass ?? '';
      _cityType.text = u.cityType ?? '';
      _urban.text = u.urbanRural ?? '';
      _old.text = u.oldName ?? '';
      _isCapital = u.isCapital;
      _guid = u.clientGuid;
      _loading = false;
    });
  }

  @override
  void dispose() {
    app.unregisterPage(_actions);
    for (final c in [_psgc, _name, _level, _parent, _income, _cityType, _urban, _old]) {
      c.dispose();
    }
    _nameNode.dispose();
    _psgcNode.dispose();
    super.dispose();
  }

  String? _nullIfEmpty(String s) => s.isEmpty ? null : s;

  Future<void> _save() async {
    if (_busy || _loading) return;
    final errs = <String>[];
    _bad.clear();
    if (_psgc.text.trim().isEmpty && !_edit) {
      errs.add('The PsgcCode field is required.');
      _bad.add('psgc');
    }
    if (_name.text.trim().isEmpty) {
      errs.add('The Name field is required.');
      _bad.add('name');
    }
    if (_level.text.trim().isEmpty) {
      errs.add('The Level field is required.');
      _bad.add('level');
    }
    if (_parent.text.trim().isNotEmpty && int.tryParse(_parent.text.trim()) == null) {
      errs.add('The field ParentPlaceId must be a number.');
      _bad.add('parent');
    }
    if (errs.isNotEmpty) {
      setState(() => _errors = errs);
      return;
    }
    setState(() {
      _busy = true;
      _errors = [];
    });
    final dto = PlaceUpsert(
      psgcCode: _psgc.text,
      name: _name.text,
      level: _level.text,
      parentPlaceId: int.tryParse(_parent.text.trim()),
      incomeClass: _nullIfEmpty(_income.text),
      cityType: _nullIfEmpty(_cityType.text),
      isCapital: _isCapital,
      urbanRural: _nullIfEmpty(_urban.text),
      oldName: _nullIfEmpty(_old.text),
      clientGuid: _guid,
    );
    if (_edit) {
      final (ok, err) = await app.api.put('api/places/${widget.editId}', dto.toJson());
      if (!mounted) return;
      if (!ok) {
        setState(() {
          _busy = false;
          _errors = [_apiError(err, 'Could not update place.')];
        });
        return;
      }
      app.toast('success', 'Place updated.', title: 'Success');
    } else {
      final (ok, _, err) = await app.api.post('api/places', dto.toJson());
      if (!mounted) return;
      if (!ok) {
        setState(() {
          _busy = false;
          _errors = [_apiError(err, 'Could not save place.')];
        });
        return;
      }
      app.toast('success', "Place '${dto.name}' created.", title: 'Success');
    }
    app.navigate(AppRoute(PageId.places), replace: true);
  }

  String _apiError(String? e, String fallback) => (e == null || e.trim().isEmpty) ? fallback : e;

  Widget _field(String label, TextEditingController c, {String? hint, bool number = false, String? badKey, bool disabled = false, FocusNode? node, bool autofocus = false, TextInputAction? action}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      LaLabel(label, hi: !_edit),
      LaInput(
        controller: c,
        hint: hint,
        enabled: !disabled,
        focusNode: node,
        autofocus: autofocus,
        keyboardType: number ? TextInputType.number : null,
        inputFormatters: number ? [FilteringTextInputFormatter.digitsOnly] : null,
        invalid: badKey != null && _bad.contains(badKey),
        textInputAction: TextInputAction.next,
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    if (_edit) return _buildEdit(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TopBar(title: 'Add Place', subtitle: 'Register an area using its PSGC and classification details.'),
        FormCard(
          avatar: Text('+', style: ts(context, size: 28, color: p.teal, height: 1)),
          heroTitle: 'Place Information',
          heroText: 'Enter the place hierarchy and reference data used by assessments.',
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            ValidationSummary(_errors),
            FormSection(
              title: 'Identity',
              child: LaGrid(cols: 2, gap: 20, children: [
                _field('PSGC Code', _psgc, badKey: 'psgc', autofocus: true),
                _field('Name', _name, badKey: 'name'),
                _field('Level', _level, hint: 'region, province, city', badKey: 'level'),
                _field('Parent Place ID', _parent, number: true, badKey: 'parent'),
              ]),
            ),
            FormSection(
              title: 'Classification',
              last: true,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                LaGrid(cols: 2, gap: 20, children: [
                  _field('Income Class', _income),
                  _field('City Type', _cityType),
                  _field('Urban / Rural', _urban),
                  _field('Old Name', _old),
                ]),
                const SizedBox(height: 16),
                Align(alignment: Alignment.centerLeft, child: LaCheckbox(value: _isCapital, label: 'Is capital', onChanged: (v) => setState(() => _isCapital = v))),
              ]),
            ),
            FormActions(children: [
              LaButton(label: _busy ? 'Saving...' : 'Save Place', tooltip: 'Save (Ctrl+S)', onTap: _busy ? null : _save),
              LaButton(label: 'Cancel', kind: BtnKind.outline, tooltip: 'Cancel (Esc)', onTap: () => app.navigate(AppRoute(PageId.places), replace: true)),
            ]),
          ]),
        ),
      ],
    );
  }

  Widget _buildEdit(BuildContext context) {
    final p = context.pal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TopBar(title: 'Edit Place \u2014 ${_psgc.text}'),
        if (_loading)
          const LoadingBlock()
        else
          Align(
            alignment: Alignment.topLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: LaCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  ValidationSummary(_errors),
                  LaGrid(cols: 2, gap: 22, children: [
                    _field('PSGC Code', _psgc, disabled: true),
                    _field('Name', _name, badKey: 'name', autofocus: true),
                  ]),
                  const SizedBox(height: 14),
                  LaGrid(cols: 2, gap: 22, children: [
                    _field('Level', _level, badKey: 'level'),
                    _field('Parent Place ID', _parent, number: true, badKey: 'parent'),
                  ]),
                  const SizedBox(height: 14),
                  LaGrid(cols: 2, gap: 22, children: [
                    _field('Income Class', _income),
                    _field('City Type', _cityType),
                  ]),
                  const SizedBox(height: 14),
                  LaGrid(cols: 2, gap: 22, children: [
                    _field('Urban / Rural', _urban),
                    _field('Old Name', _old),
                  ]),
                  const SizedBox(height: 14),
                  Align(alignment: Alignment.centerLeft, child: LaCheckbox(value: _isCapital, label: 'Is capital', onChanged: (v) => setState(() => _isCapital = v))),
                  const SizedBox(height: 22),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    LaButton(label: _busy ? 'Saving...' : 'Save Changes', tooltip: 'Save (Ctrl+S)', onTap: _busy ? null : _save),
                    LaButton(label: 'Cancel', kind: BtnKind.outline, tooltip: 'Cancel (Esc)', onTap: () => app.navigate(AppRoute(PageId.places), replace: true)),
                  ]),
                ]),
              ),
            ),
          ),
      ],
    );
  }
}
