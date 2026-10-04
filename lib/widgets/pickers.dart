import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/palette.dart';
import '../theme/theme.dart';
import 'common.dart';
import 'icons.dart';
import 'modal.dart';

// ---------------------------------------------------------------------------
// Place picker button (.la-place-picker-btn)
// ---------------------------------------------------------------------------
class PlacePickerButton extends StatefulWidget {
  const PlacePickerButton({super.key, required this.label, required this.onTap, this.focusNode, this.autofocus = false});
  final String label;
  final VoidCallback onTap;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  State<PlacePickerButton> createState() => _PlacePickerButtonState();
}

class _PlacePickerButtonState extends State<PlacePickerButton> {
  bool _hover = false;
  bool _focus = false;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final active = _hover || _focus;
    return FocusableActionDetector(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      mouseCursor: SystemMouseCursors.click,
      onShowHoverHighlight: (v) => setState(() => _hover = v),
      onShowFocusHighlight: (v) => setState(() => _focus = v),
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.arrowDown): ActivateIntent(),
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
          widget.onTap();
          return null;
        })
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: p.ink800,
            border: Border.all(color: active ? p.gold : p.line),
            borderRadius: BorderRadius.circular(6),
            boxShadow: active ? [BoxShadow(color: alphaPct(p.gold, .18), spreadRadius: 3)] : null,
          ),
          child: Row(
            children: [
              LaIcon(LaIcons.mapPin, size: 16, color: p.textLow),
              const SizedBox(width: 10),
              Expanded(
                child: Text(widget.label,
                    overflow: TextOverflow.ellipsis,
                    style: ts(context, size: 14, color: p.textHi, height: 1.4)),
              ),
              const SizedBox(width: 10),
              Text('\u25BE', style: ts(context, size: 11, color: p.textLow)),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Place picker modal
// ---------------------------------------------------------------------------
Future<PlaceDto?> showPlacePicker(AppState app) {
  return showLaModal<PlaceDto>(app, builder: (c) => _PlacePickerDialog(app: app));
}

class _PlacePickerDialog extends StatefulWidget {
  const _PlacePickerDialog({required this.app});
  final AppState app;
  @override
  State<_PlacePickerDialog> createState() => _PlacePickerDialogState();
}

class _PlacePickerDialogState extends State<_PlacePickerDialog> {
  final _search = TextEditingController();
  final _searchNode = FocusNode();
  final _scroll = ScrollController();
  Timer? _debounce;
  bool _loading = true;
  bool _error = false;
  List<PlaceDto> _items = [];
  int _hi = -1; // highlighted row (arrow keys)
  final Map<int, FocusNode> _rowNodes = {};
  int _req = 0;

  @override
  void initState() {
    super.initState();
    _doSearch('');
    _search.addListener(() {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 200), () => _doSearch(_search.text));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _searchNode.requestFocus());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _searchNode.dispose();
    _scroll.dispose();
    for (final n in _rowNodes.values) {
      n.dispose();
    }
    super.dispose();
  }

  Future<void> _doSearch(String q) async {
    final req = ++_req;
    setState(() {
      _loading = true;
      _error = false;
    });
    // Same rules as the website's SearchJson action.
    final trimmed = q.trim();
    final pageSize = trimmed.isEmpty ? 30 : 100;
    var url = 'api/places?pageSize=$pageSize';
    if (q.trim().isNotEmpty) url += '&search=${Uri.encodeQueryComponent(q).replaceAll('+', '%20')}';
    final j = await widget.app.api.get(url);
    if (!mounted || req != _req) return;
    if (j == null) {
      setState(() {
        _loading = false;
        _error = true;
        _items = [];
      });
      return;
    }
    final r = PagedResult.places(j, pageSize: pageSize);
    setState(() {
      _loading = false;
      _items = r.items;
      _hi = r.items.isEmpty ? -1 : 0;
    });
  }

  void _pick(PlaceDto p) => Navigator.of(context).pop(p);

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (_items.isEmpty) return KeyEventResult.ignored;
    if (e.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() => _hi = (_hi + 1).clamp(0, _items.length - 1).toInt());
      _ensureVisible();
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() => _hi = (_hi - 1).clamp(0, _items.length - 1).toInt());
      _ensureVisible();
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.pageDown) {
      setState(() => _hi = (_hi + 6).clamp(0, _items.length - 1).toInt());
      _ensureVisible();
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.pageUp) {
      setState(() => _hi = (_hi - 6).clamp(0, _items.length - 1).toInt());
      _ensureVisible();
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.enter || e.logicalKey == LogicalKeyboardKey.numpadEnter) {
      if (_hi >= 0 && _hi < _items.length) {
        _pick(_items[_hi]);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  void _ensureVisible() {
    if (!_scroll.hasClients) return;
    const rowH = 76.0;
    final top = _hi * rowH;
    final bottom = top + rowH;
    final vp = _scroll.position.viewportDimension;
    if (top < _scroll.offset) {
      _scroll.jumpTo(top);
    } else if (bottom > _scroll.offset + vp) {
      _scroll.jumpTo(bottom - vp);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final narrow = isNarrow(context);
    return Focus(
      onKeyEvent: (n, e) {
        if (e is KeyDownEvent && e.logicalKey == LogicalKeyboardKey.escape) {
          Navigator.of(context).pop();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: LaModal(
        accent: 'info',
        title: 'Select Place',
        maxWidth: 680,
        bodyAlignCenter: false,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Focus(
                onKeyEvent: _onKey,
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    TextField(
                      controller: _search,
                      focusNode: _searchNode,
                      autofocus: true,
                      cursorColor: p.textHi,
                      style: ts(context, size: 14, color: p.textHi, height: 1.5),
                      decoration: InputDecoration(
                        isDense: true,
                        filled: true,
                        fillColor: p.ink800,
                        hintText: 'Search by name, PSGC code, level...',
                        hintStyle: ts(context, size: 14, color: alphaPct(p.textLow, .7), height: 1.5),
                        contentPadding: const EdgeInsets.fromLTRB(38, 10, 12, 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: p.line)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: p.line)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: p.gold)),
                      ),
                    ),
                    Positioned(left: 12, child: IgnorePointer(child: LaIcon(LaIcons.search, size: 16, color: p.textLow))),
                  ],
                ),
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: narrow ? 280 : 380),
              child: _buildList(context),
            ),
          ],
        ),
        actions: [
          LaButton(label: 'Cancel', kind: BtnKind.outline, minWidth: 120, onTap: () => Navigator.of(context).pop()),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context) {
    final p = context.pal;
    if (_loading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: p.gold, backgroundColor: p.line),
            ),
            const SizedBox(width: 8),
            Text('Searching...', style: ts(context, size: 13, color: p.textLow)),
          ],
        ),
      );
    }
    if (_error) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 12),
        child: Center(
            child: Text('Error loading places. Please try again.',
                style: ts(context, size: 13, color: AppPalette.red))),
      );
    }
    if (_items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 12),
        child: Center(
            child: Text('No places found. Try a different search.',
                style: ts(context, size: 13, color: p.textLow))),
      );
    }
    return Scrollbar(
      controller: _scroll,
      thumbVisibility: true,
      child: ListView.separated(
        controller: _scroll,
        shrinkWrap: true,
        padding: const EdgeInsets.only(right: 10),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 6),
        itemBuilder: (context, i) => _PickerItem(
          place: _items[i],
          highlighted: i == _hi,
          onTap: () => _pick(_items[i]),
          onHover: () => setState(() => _hi = i),
          node: _rowNodes.putIfAbsent(i, () => FocusNode(skipTraversal: false)),
        ),
      ),
    );
  }
}

class _PickerItem extends StatefulWidget {
  const _PickerItem({required this.place, required this.highlighted, required this.onTap, required this.onHover, required this.node});
  final PlaceDto place;
  final bool highlighted;
  final VoidCallback onTap;
  final VoidCallback onHover;
  final FocusNode node;
  @override
  State<_PickerItem> createState() => _PickerItemState();
}

class _PickerItemState extends State<_PickerItem> {
  bool _focus = false;

  static const _levelLabels = {
    'region': 'Region',
    'province': 'Province',
    'city': 'City',
    'municipality': 'Municipality',
    'barangay': 'Barangay',
  };

  Color _levelColor(AppPalette p, String level) {
    switch (level) {
      case 'region':
        return p.teal;
      case 'province':
        return const Color(0xFF4A90D9);
      case 'city':
        return p.gold;
      case 'municipality':
        return const Color(0xFF9B6FC0);
      default:
        return p.textLow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final pl = widget.place;
    final on = widget.highlighted || _focus;

    Widget tag(String text, {Color? color, FontWeight w = FontWeight.w500, bool level = false, bool capital = false}) {
      Color border = p.line;
      Color bg = p.ink700;
      Color fg = p.textMid;
      if (level) {
        fg = color ?? p.textLow;
        if (pl.level != 'barangay') {
          border = mixSrgb(fg, .28, p.line);
          bg = mixSrgb(fg, .08, p.ink700);
        }
      }
      if (capital) {
        fg = p.gold;
        border = mixSrgb(p.gold, .35, p.line);
        bg = mixSrgb(p.gold, .10, p.ink700);
        w = FontWeight.w600;
      }
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: bg, border: Border.all(color: border), borderRadius: BorderRadius.circular(999)),
        child: Text(text, style: ts(context, size: 11, color: fg, weight: w, height: 1.5)),
      );
    }

    final tags = <Widget>[
      tag(_levelLabels[pl.level] ?? pl.level, level: true, color: _levelColor(p, pl.level)),
      if ((pl.urbanRural ?? '').isNotEmpty) tag(pl.urbanRural!),
      if ((pl.incomeClass ?? '').isNotEmpty) tag(pl.incomeClass!),
      if (pl.isCapital) tag('Capital', capital: true),
    ];

    return Focus(
      focusNode: widget.node,
      onFocusChange: (v) => setState(() => _focus = v),
      onKeyEvent: (n, e) {
        if (e is KeyDownEvent &&
            (e.logicalKey == LogicalKeyboardKey.enter || e.logicalKey == LogicalKeyboardKey.space)) {
          widget.onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => widget.onHover(),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: on ? p.ink600 : p.ink800,
              border: Border.all(color: on ? p.gold : p.line),
              borderRadius: BorderRadius.circular(6),
              boxShadow: on ? [BoxShadow(color: alphaPct(p.gold, .10), spreadRadius: 2)] : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(pl.psgcCode,
                        style: TextStyle(
                            fontFamily: 'Consolas',
                            fontFamilyFallback: const ['Cascadia Code', 'Courier New', 'monospace'],
                            fontSize: 12,
                            color: p.textLow,
                            letterSpacing: .36,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(pl.name,
                          overflow: TextOverflow.ellipsis,
                          style: ts(context, size: 15, weight: FontWeight.w600, color: p.textHi, height: 1.4)),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Wrap(spacing: 6, runSpacing: 6, children: tags),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Date picker modal (.la-datepicker)
// ---------------------------------------------------------------------------
Future<DateTime?> showLaDatePicker(AppState app, DateTime? initial) {
  return showLaModal<DateTime>(app, builder: (c) => _DatePickerDialog(initial: initial));
}

class _DatePickerDialog extends StatefulWidget {
  const _DatePickerDialog({required this.initial});
  final DateTime? initial;
  @override
  State<_DatePickerDialog> createState() => _DatePickerDialogState();
}

class _DatePickerDialogState extends State<_DatePickerDialog> {
  late DateTime _view;
  late DateTime _cursor; // keyboard cursor day
  DateTime? _selected;
  final _focus = FocusNode(debugLabel: 'datepicker');

  @override
  void initState() {
    super.initState();
    final base = widget.initial ?? DateTime.now();
    _selected = widget.initial == null ? null : DateTime(base.year, base.month, base.day);
    _cursor = DateTime(base.year, base.month, base.day);
    _view = DateTime(base.year, base.month, 1);
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _shiftCursor(int days) {
    setState(() {
      _cursor = _cursor.add(Duration(days: days));
      _cursor = DateTime(_cursor.year, _cursor.month, _cursor.day);
      _view = DateTime(_cursor.year, _cursor.month, 1);
    });
  }

  void _shiftMonth(int delta) {
    setState(() {
      _view = DateTime(_view.year, _view.month + delta, 1);
      final dim = DateTime(_view.year, _view.month + 1, 0).day;
      _cursor = DateTime(_view.year, _view.month, _cursor.day > dim ? dim : _cursor.day);
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final now = DateTime.now();
    final firstWeekday = DateTime(_view.year, _view.month, 1).weekday % 7; // Sunday = 0
    final dim = DateTime(_view.year, _view.month + 1, 0).day;
    final cells = <Widget>[];
    for (var i = 0; i < firstWeekday; i++) {
      cells.add(const SizedBox.shrink());
    }
    for (var d = 1; d <= dim; d++) {
      final date = DateTime(_view.year, _view.month, d);
      final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
      final isSel = _selected != null && date == _selected;
      final isCur = date == _cursor;
      cells.add(_DayCell(
        day: d,
        today: isToday,
        selected: isSel,
        cursor: isCur,
        onTap: () => setState(() {
          _selected = date;
          _cursor = date;
        }),
        onDouble: () => Navigator.of(context).pop(date),
      ));
    }

    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: (n, e) {
        if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
        final k = e.logicalKey;
        if (k == LogicalKeyboardKey.escape) {
          Navigator.of(context).pop();
          return KeyEventResult.handled;
        }
        if (k == LogicalKeyboardKey.arrowLeft) {
          _shiftCursor(-1);
        } else if (k == LogicalKeyboardKey.arrowRight) {
          _shiftCursor(1);
        } else if (k == LogicalKeyboardKey.arrowUp) {
          _shiftCursor(-7);
        } else if (k == LogicalKeyboardKey.arrowDown) {
          _shiftCursor(7);
        } else if (k == LogicalKeyboardKey.pageUp) {
          _shiftMonth(-1);
        } else if (k == LogicalKeyboardKey.pageDown) {
          _shiftMonth(1);
        } else if (k == LogicalKeyboardKey.home) {
          setState(() {
            _cursor = DateTime.now();
            _cursor = DateTime(_cursor.year, _cursor.month, _cursor.day);
            _view = DateTime(_cursor.year, _cursor.month, 1);
          });
        } else if (k == LogicalKeyboardKey.space) {
          setState(() => _selected = _cursor);
        } else if (k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.numpadEnter) {
          Navigator.of(context).pop(_cursor);
        } else {
          return KeyEventResult.ignored;
        }
        return KeyEventResult.handled;
      },
      child: LaModal(
        accent: 'info',
        maxWidth: 420,
        bodyAlignCenter: false,
        body: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _NavBtn('\u2039', () => _shiftMonth(-1), 'Previous month'),
                  Text('${monthName(_view.month)} ${_view.year}',
                      style: ts(context, size: 17, weight: FontWeight.w700, color: p.textHi)),
                  _NavBtn('\u203A', () => _shiftMonth(1), 'Next month'),
                ],
              ),
            ),
            Row(children: [
              for (final d in const ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Center(
                        child: Text(d.toUpperCase(),
                            style: ts(context, size: 11, color: p.textLow, spacing: .44, height: 1.55))),
                  ),
                ),
            ]),
            const SizedBox(height: 4),
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              children: cells,
            ),
          ],
        ),
        actions: [
          LaButton(
            label: 'Today',
            kind: BtnKind.outline,
            onTap: () {
              final t = DateTime.now();
              setState(() {
                _selected = DateTime(t.year, t.month, t.day);
                _cursor = _selected!;
                _view = DateTime(t.year, t.month, 1);
              });
            },
          ),
          LaButton(label: 'Cancel', kind: BtnKind.outline, onTap: () => Navigator.of(context).pop()),
          LaButton(label: 'Select', onTap: () => Navigator.of(context).pop(_selected)),
        ],
      ),
    );
  }
}

class _NavBtn extends StatefulWidget {
  const _NavBtn(this.glyph, this.onTap, this.tooltip);
  final String glyph;
  final VoidCallback onTap;
  final String tooltip;
  @override
  State<_NavBtn> createState() => _NavBtnState();
}

class _NavBtnState extends State<_NavBtn> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: p.ink600,
              border: Border.all(color: _hover ? p.gold : p.line),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(widget.glyph, style: ts(context, size: 20, color: p.textHi, height: 1)),
          ),
        ),
      ),
    );
  }
}

class _DayCell extends StatefulWidget {
  const _DayCell({required this.day, required this.today, required this.selected, required this.cursor, required this.onTap, required this.onDouble});
  final int day;
  final bool today;
  final bool selected;
  final bool cursor;
  final VoidCallback onTap;
  final VoidCallback onDouble;
  @override
  State<_DayCell> createState() => _DayCellState();
}

class _DayCellState extends State<_DayCell> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    Color? bg;
    Gradient? grad;
    Color fg = p.textMid;
    FontWeight w = FontWeight.w400;
    BoxBorder? border;
    if (widget.selected) {
      grad = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [const Color(0xFFF0C765), p.goldDim]);
      fg = const Color(0xFF23180A);
      w = FontWeight.w700;
    } else {
      if (_hover) {
        bg = p.ink600;
        fg = p.textHi;
      }
      if (widget.today) {
        border = Border.all(color: p.gold);
        fg = p.gold;
        w = FontWeight.w600;
      }
    }
    if (widget.cursor && !widget.selected) {
      border = Border.all(color: p.teal, width: 2);
    }
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onDoubleTap: widget.onDouble,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(color: bg, gradient: grad, border: border, borderRadius: BorderRadius.circular(6)),
          child: Text('${widget.day}', style: ts(context, size: 13, color: fg, weight: w, height: 1)),
        ),
      ),
    );
  }
}

/// Read-only date field that opens the date picker (input[data-datepicker]).
class DateField extends StatefulWidget {
  const DateField({super.key, required this.app, required this.value, required this.onChanged, this.focusNode});
  final AppState app;
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;
  final FocusNode? focusNode;

  @override
  State<DateField> createState() => _DateFieldState();
}

class _DateFieldState extends State<DateField> {
  bool _focus = false;

  Future<void> _open() async {
    final d = await showLaDatePicker(widget.app, widget.value);
    if (d != null) widget.onChanged(d);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: (v) => setState(() => _focus = v),
      onKeyEvent: (n, e) {
        if (e is KeyDownEvent &&
            (e.logicalKey == LogicalKeyboardKey.enter ||
                e.logicalKey == LogicalKeyboardKey.numpadEnter ||
                e.logicalKey == LogicalKeyboardKey.space ||
                e.logicalKey == LogicalKeyboardKey.arrowDown)) {
          _open();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () {
            Focus.maybeOf(context)?.requestFocus();
            _open();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(40, 10, 12, 10),
            decoration: BoxDecoration(
              color: p.ink800,
              border: Border.all(color: _focus ? p.teal : p.line),
              borderRadius: BorderRadius.circular(5),
              boxShadow: _focus ? [BoxShadow(color: alphaPct(p.teal, .2), spreadRadius: 3)] : null,
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Text(widget.value == null ? '\u00A0' : ymd(widget.value!), style: ts(context, size: 14, color: p.textHi, height: 1.5)),
                Positioned(
                  left: -28,
                  top: 0,
                  bottom: 0,
                  child: Center(child: LaIcon(LaIcons.calendar, size: 16, color: _focus ? p.teal : p.textLow)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
