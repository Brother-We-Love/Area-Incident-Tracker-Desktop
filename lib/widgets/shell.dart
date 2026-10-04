import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../state/app_state.dart';
import '../theme/palette.dart';
import '../theme/theme.dart';
import 'common.dart';

/// Body background: two soft green/gold gradients over ink-800.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: p.ink800),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: const Alignment(-1, -.6),
              end: const Alignment(1, .6),
              colors: [alphaPct(p.teal, .11), const Color(0x00000000)],
              stops: const [0, .42],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: const Alignment(1, .6),
              end: const Alignment(-1, -.6),
              colors: [alphaPct(p.gold, .08), const Color(0x00000000)],
              stops: const [0, .48],
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _NavEntry {
  const _NavEntry(this.page, this.label, this.shortcut);
  final PageId page;
  final String label;
  final String shortcut;
}

const _navEntries = [
  _NavEntry(PageId.dashboard, '\u{1F4CA} Dashboard', 'Ctrl+1'),
  _NavEntry(PageId.places, 'Places', 'Ctrl+2'),
  _NavEntry(PageId.areaMap, '\u{1F5FA}\uFE0F Area Map', 'Ctrl+3'),
  _NavEntry(PageId.assessmentNew, '\u{1F4DD} New Assessment', 'Ctrl+4'),
  _NavEntry(PageId.framework, '\u{1F9ED} Assessment', 'Ctrl+5'),
];

/// Right-hand sidebar (the website's final CSS places it in the right column).
class Sidebar extends StatelessWidget {
  const Sidebar({super.key, required this.app});
  final AppState app;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final w = vw(context);
    final width = w <= 640 ? (w * .88).clamp(0.0, 300.0).toDouble() : (w <= 1180 && w > 900 ? 224.0 : 270.0);
    final highlight = app.route.navHighlight;
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: p.ink900,
        border: Border(left: BorderSide(color: p.line)),
        boxShadow: w <= 900 ? const [BoxShadow(color: Color.fromRGBO(0, 0, 0, .4), offset: Offset(-20, 0), blurRadius: 40)] : null,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 34),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Brand
            Container(
              padding: const EdgeInsets.only(bottom: 26),
              margin: const EdgeInsets.only(bottom: 26),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.line))),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [BoxShadow(color: alphaPct(p.teal, .22), offset: const Offset(0, 8), blurRadius: 20)],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset('assets/images/web_icon.png', width: 36, height: 36, fit: BoxFit.cover, filterQuality: FilterQuality.medium),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Area Incident Tracker',
                            style: ts(context, size: 20, weight: FontWeight.w700, color: p.textHi, height: 1.2)),
                        Text('DATABASE', style: ts(context, size: 10, color: p.teal, spacing: .8, height: 1.55)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            for (final n in _navEntries)
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: _NavItem(
                  entry: n,
                  active: highlight == n.page,
                  onTap: () {
                    app.go(n.page);
                  },
                ),
              ),
            const SizedBox(height: 15),
            _ThemeToggle(app: app),
            Container(
              margin: const EdgeInsets.only(top: 32),
              padding: const EdgeInsets.only(top: 16),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: p.line))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Signed in as', style: ts(context, size: 13)),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(app.displayName, style: ts(context, size: 13, weight: FontWeight.w700, color: p.textHi)),
                  ),
                  LaButton(
                    label: 'Log out',
                    kind: BtnKind.outline,
                    expand: true,
                    tooltip: 'Log out (Ctrl+Shift+Q)',
                    onTap: () => app.requestLogout?.call(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  const _NavItem({required this.entry, required this.active, required this.onTap});
  final _NavEntry entry;
  final bool active;
  final VoidCallback onTap;
  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hover = false;
  bool _focus = false;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final on = widget.active || _hover;
    return Tooltip(
      message: '${widget.entry.label.replaceAll(RegExp(r'^[^A-Za-z]+'), '')}  (${widget.entry.shortcut})',
      waitDuration: const Duration(milliseconds: 700),
      child: FocusableActionDetector(
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
          child: Container(
            constraints: const BoxConstraints(minHeight: 46),
            decoration: BoxDecoration(
              color: on ? p.ink600 : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _focus ? p.gold : Colors.transparent),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: Stack(
                children: [
                  if (widget.active)
                    Positioned(left: 0, top: 0, bottom: 0, child: Container(width: 4, color: p.teal)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(widget.entry.label,
                          style: ts(context,
                              size: 14,
                              weight: FontWeight.w500,
                              color: on ? p.textHi : p.textMid,
                              height: 1.55)),
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

class _ThemeToggle extends StatefulWidget {
  const _ThemeToggle({required this.app});
  final AppState app;
  @override
  State<_ThemeToggle> createState() => _ThemeToggleState();
}

class _ThemeToggleState extends State<_ThemeToggle> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final dark = p.isDark;
    return Tooltip(
      message: dark ? 'Switch to light theme (Ctrl+T)' : 'Switch to dark theme (Ctrl+T)',
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        onShowHoverHighlight: (v) => setState(() => _hover = v),
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
            widget.app.toggleTheme();
            return null;
          })
        },
        child: GestureDetector(
          onTap: widget.app.toggleTheme,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(color: _hover ? p.gold : p.line),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(dark ? 'Dark theme' : 'Light theme',
                      style: ts(context, size: 13, color: _hover ? p.textHi : p.textMid)),
                ),
                Text(dark ? '\u263E' : '\u263C', style: ts(context, size: 16, color: p.gold, height: 1)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Mobile/narrow top bar (.la-mobile-topbar) with hamburger + theme toggle.
class MobileTopBar extends StatelessWidget {
  const MobileTopBar({super.key, required this.app});
  final AppState app;
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: p.ink900, border: Border(bottom: BorderSide(color: p.line))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Tooltip(
            message: 'Menu (Ctrl+B)',
            child: GestureDetector(
              onTap: () => app.setSidebar(!app.sidebarOpen),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(border: Border.all(color: p.line), borderRadius: BorderRadius.circular(9)),
                  child: Text('\u2630', style: ts(context, size: 18, color: p.textHi, height: 1.2)),
                ),
              ),
            ),
          ),
          Text('Life Audit', style: ts(context, size: 16, weight: FontWeight.w700, color: p.textHi)),
          GestureDetector(
            onTap: app.toggleTheme,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(border: Border.all(color: p.line), borderRadius: BorderRadius.circular(6)),
                child: Text(p.isDark ? '\u263E' : '\u263C', style: ts(context, size: 16, color: p.gold, height: 1.3)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The page frame for authenticated pages: sidebar + scrollable main area.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.app, required this.child});
  final AppState app;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final w = vw(context);
    final mobile = w <= 900;
    final narrow = w <= 640;
    final hPad = narrow ? 14.0 : (mobile ? 24.0 : (w * 0.05).clamp(20.0, 72.0).toDouble());
    final top = narrow ? 24.0 : (mobile ? 30.0 : 52.0);
    final bottom = narrow ? 44.0 : (mobile ? 56.0 : 76.0);
    final main = Scrollbar(
      thumbVisibility: false,
      child: SingleChildScrollView(
        primary: true,
        padding: EdgeInsets.fromLTRB(hPad, top, hPad, bottom),
        child: Align(alignment: Alignment.topLeft, child: child),
      ),
    );

    if (!mobile) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [Expanded(child: main), Sidebar(app: app)],
      );
    }
    return Stack(
      children: [
        Column(children: [MobileTopBar(app: app), Expanded(child: main)]),
        if (app.sidebarOpen)
          Positioned.fill(
            child: GestureDetector(
              onTap: () => app.setSidebar(false),
              child: const ColoredBox(color: Color.fromRGBO(0, 0, 0, .25)),
            ),
          ),
        AnimatedPositioned(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          top: 0,
          bottom: 0,
          right: app.sidebarOpen ? 0.0 : -(w <= 640 ? w : 300.0),
          child: Sidebar(app: app),
        ),
      ],
    );
  }
}
