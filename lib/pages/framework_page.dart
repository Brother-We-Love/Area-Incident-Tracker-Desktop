import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/palette.dart';
import '../theme/theme.dart';
import '../widgets/anim.dart';
import '../widgets/common.dart';
import '../widgets/icons.dart';

class FrameworkPage extends StatefulWidget {
  const FrameworkPage({super.key, required this.app});
  final AppState app;
  @override
  State<FrameworkPage> createState() => _FrameworkPageState();
}

class _FrameworkPageState extends State<FrameworkPage> {
  final _actions = PageActions();
  final _search = TextEditingController();
  final _searchNode = FocusNode();
  final _pageFocus = FocusNode(debugLabel: 'framework');
  FrameworkData _data = FrameworkData.empty();
  bool _loading = true;
  String _active = 'all';
  String? _open; // "<domainIndex>|<levelKey>"

  AppState get app => widget.app;

  static const _levelColors = {
    'critical_1_2': AppPalette.red,
    'struggling_3_4': AppPalette.orange,
    'balancing_5_7': AppPalette.yellow,
    'thriving_8_10': AppPalette.green,
  };

  @override
  void initState() {
    super.initState();
    _actions.focusSearch = () => _searchNode.requestFocus();
    app.registerPage(_actions);
    _search.addListener(() => setState(() {}));
    _load();
  }

  Future<void> _load() async {
    try {
      final text = await rootBundle.loadString('assets/domain_assessment_framework.json');
      final d = FrameworkData.parse(text);
      if (mounted) setState(() => _data = d);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    app.unregisterPage(_actions);
    _search.dispose();
    _searchNode.dispose();
    _pageFocus.dispose();
    super.dispose();
  }

  KeyEventResult _key(FocusNode n, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.escape && _searchNode.hasFocus) {
      if (_search.text.isNotEmpty) {
        _search.clear();
      } else {
        _pageFocus.requestFocus();
      }
      return KeyEventResult.handled;
    }
    if (typingInTextField()) return KeyEventResult.ignored;
    if (HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isAltPressed) return KeyEventResult.ignored;
    final keys = _data.levels.keys.toList();
    final digits = {
      LogicalKeyboardKey.digit0: 'all',
      LogicalKeyboardKey.numpad0: 'all',
      LogicalKeyboardKey.digit1: keys.isNotEmpty ? keys[0] : null,
      LogicalKeyboardKey.numpad1: keys.isNotEmpty ? keys[0] : null,
      LogicalKeyboardKey.digit2: keys.length > 1 ? keys[1] : null,
      LogicalKeyboardKey.numpad2: keys.length > 1 ? keys[1] : null,
      LogicalKeyboardKey.digit3: keys.length > 2 ? keys[2] : null,
      LogicalKeyboardKey.numpad3: keys.length > 2 ? keys[2] : null,
      LogicalKeyboardKey.digit4: keys.length > 3 ? keys[3] : null,
      LogicalKeyboardKey.numpad4: keys.length > 3 ? keys[3] : null,
    };
    if (digits.containsKey(k)) {
      final v = digits[k];
      if (v != null) setState(() => _active = v);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.slash) {
      _searchNode.requestFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final w = vw(context);
    final q = _search.text.toLowerCase().trim();
    final levels = _data.levels;
    final cols = w <= 640 ? 1 : (w <= 1180 ? 2 : 3);

    final cards = <Widget>[];
    for (var di = 0; di < _data.domains.length; di++) {
      final d = _data.domains[di];
      final domainMatch = q.isEmpty || d.domain.toLowerCase().contains(q);
      var anyAdvice = false;
      final items = <Widget>[];
      for (final key in levels.keys) {
        final label = levels[key] ?? key;
        final advice = d.byLevel[key] ?? '';
        final textMatch = q.isEmpty || '$label $advice'.toLowerCase().contains(q);
        if (textMatch) anyAdvice = true;
        final levelMatch = _active == 'all' || _active == key;
        if (!levelMatch) continue;
        final id = '$di|$key';
        items.add(_AdviceItem(
          label: label,
          advice: advice,
          color: _levelColors[key] ?? p.textMid,
          open: _open == id,
          last: false,
          onToggle: () => setState(() => _open = _open == id ? null : id),
        ));
      }
      if (!(domainMatch || anyAdvice)) continue;
      cards.add(_DomainCard(name: d.domain, children: items));
    }

    // Distribute cards across columns like CSS grid rows (row-major).
    Widget grid;
    if (cards.isEmpty) {
      grid = const SizedBox.shrink();
    } else {
      final rows = <Widget>[];
      for (var i = 0; i < cards.length; i += cols) {
        final slice = cards.sublist(i, (i + cols).clamp(0, cards.length).toInt());
        rows.add(Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (var j = 0; j < cols; j++) ...[
            if (j > 0) const SizedBox(width: 22),
            Expanded(child: j < slice.length ? slice[j] : const SizedBox.shrink()),
          ]
        ]));
        if (i + cols < cards.length) rows.add(const SizedBox(height: 22));
      }
      grid = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
    }

    final chips = Wrap(spacing: 8, runSpacing: 8, children: [
      _Chip(label: 'All Levels', color: p.gold, active: _active == 'all', onTap: () => setState(() => _active = 'all')),
      for (final key in levels.keys)
        _Chip(
          label: levels[key]!,
          color: _levelColors[key] ?? p.textMid,
          active: _active == key,
          onTap: () => setState(() => _active = key),
        ),
    ]);

    final searchBox = LaInput(
      controller: _search,
      focusNode: _searchNode,
      hint: 'Search domains, advice, or keywords...',
      icon: LaIcons.search,
      rounded: 5,
      fill: p.ink700,
    );

    return Focus(
      focusNode: _pageFocus,
      autofocus: true,
      onKeyEvent: _key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const TopBar(
            title: 'Category Assessment Framework',
            subtitle: '11 life categories \u00B7 4 score levels \u00B7 Actionable guidance for every score range',
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 22),
            child: w <= 760
                ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [searchBox, const SizedBox(height: 14), chips])
                : Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                    ConstrainedBox(constraints: const BoxConstraints(minWidth: 220, maxWidth: 460), child: SizedBox(width: 340, child: searchBox)),
                    const SizedBox(width: 14),
                    Expanded(child: chips),
                  ]),
          ),
          if (_loading) const LoadingBlock() else grid,
        ],
      ),
    );
  }
}

class _Chip extends StatefulWidget {
  const _Chip({required this.label, required this.color, required this.active, required this.onTap});
  final String label;
  final Color color;
  final bool active;
  final VoidCallback onTap;
  @override
  State<_Chip> createState() => _ChipState();
}

class _ChipState extends State<_Chip> {
  bool _hover = false;
  bool _focus = false;
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final a = widget.active;
    return FocusableActionDetector(
      mouseCursor: SystemMouseCursors.click,
      onShowHoverHighlight: (v) => setState(() => _hover = v),
      onShowFocusHighlight: (v) => setState(() => _focus = v),
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
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
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: a ? widget.color : p.ink700,
            border: Border.all(color: a || _hover || _focus ? widget.color : p.line, width: _focus ? 2 : 1),
            borderRadius: BorderRadius.circular(4),
            boxShadow: a ? [BoxShadow(color: alphaPct(widget.color, .28), blurRadius: 14, offset: const Offset(0, 4))] : null,
          ),
          child: Text(
            widget.label.toUpperCase(),
            style: TextStyle(
              fontFamily: kFont,
              fontSize: 12,
              height: 1,
              fontWeight: FontWeight.w600,
              letterSpacing: .36,
              color: a ? Colors.white : (_hover ? p.textHi : p.textMid),
            ),
          ),
        ),
      ),
    );
  }
}

class _DomainCard extends StatelessWidget {
  const _DomainCard({required this.name, required this.children});
  final String name;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return LaCard(
      clip: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(color: p.ink600, border: Border(bottom: BorderSide(color: p.line))),
            child: Row(children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [alphaPct(p.teal, .28), alphaPct(p.gold, .18)],
                  ),
                  border: Border.all(color: alphaPct(p.teal, .38)),
                ),
                child: LaIcon(LaIcons.clock, size: 20, color: p.teal),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(name, style: ts(context, size: 18, weight: FontWeight.w700, color: p.textHi, height: 1.2))),
            ]),
          ),
          for (var i = 0; i < children.length; i++)
            Container(
              decoration: BoxDecoration(border: i == children.length - 1 ? null : Border(bottom: BorderSide(color: p.line))),
              child: children[i],
            ),
        ],
      ),
    );
  }
}

class _AdviceItem extends StatefulWidget {
  const _AdviceItem({required this.label, required this.advice, required this.color, required this.open, required this.last, required this.onToggle});
  final String label;
  final String advice;
  final Color color;
  final bool open;
  final bool last;
  final VoidCallback onToggle;
  @override
  State<_AdviceItem> createState() => _AdviceItemState();
}

class _AdviceItemState extends State<_AdviceItem> {
  bool _hover = false;
  bool _focus = false;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final c = widget.color;
    final on = widget.open || _hover || _focus;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FocusableActionDetector(
          mouseCursor: SystemMouseCursors.click,
          onShowHoverHighlight: (v) => setState(() => _hover = v),
          onShowFocusHighlight: (v) => setState(() => _focus = v),
          shortcuts: const {
            SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
            SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
          },
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
              widget.onToggle();
              return null;
            })
          },
          child: GestureDetector(
            onTap: widget.onToggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: EdgeInsets.symmetric(horizontal: isNarrow(context) ? 16 : 20, vertical: 12),
              decoration: BoxDecoration(
                color: on ? p.ink600 : Colors.transparent,
                border: _focus ? Border.all(color: c, width: 1.5) : null,
              ),
              child: Row(children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: alphaPct(c, .45), blurRadius: 8)],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(widget.label,
                      style: ts(context, size: 13, weight: FontWeight.w600, color: on ? p.textHi : p.textMid, spacing: .26, height: 1.55)),
                ),
                AnimatedRotation(
                  turns: widget.open ? .5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: LaIcon(LaIcons.chevronDown, size: 16, color: p.textLow),
                ),
              ]),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: const Cubic(.4, 0, .2, 1),
          alignment: Alignment.topCenter,
          child: widget.open
              ? Padding(
                  padding: EdgeInsets.fromLTRB(isNarrow(context) ? 16 : 20, 4, isNarrow(context) ? 16 : 20, 16),
                  child: Text(widget.advice, style: ts(context, size: 13.5, height: 1.6)),
                )
              : const SizedBox(width: double.infinity, height: 0),
        ),
      ],
    );
  }
}
