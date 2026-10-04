import 'dart:io' show Platform;
import 'dart:ui' show PointerDeviceKind;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'pages/area_map_page.dart';
import 'pages/assessment_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/framework_page.dart';
import 'pages/history_page.dart';
import 'pages/login_page.dart';
import 'pages/places_page.dart';
import 'pages/report_page.dart';
import 'state/app_state.dart';
import 'theme/palette.dart';
import 'theme/theme.dart';
import 'widgets/common.dart';
import 'widgets/help_dialog.dart';
import 'widgets/modal.dart';
import 'widgets/pickers.dart';
import 'widgets/shell.dart';
import 'widgets/toast.dart';

class AreaTrackerApp extends StatelessWidget {
  const AreaTrackerApp({super.key, required this.app});
  final AppState app;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: app.darkMode,
      builder: (context, dark, _) {
        final pal = dark ? AppPalette.darkPalette : AppPalette.lightPalette;
        return MaterialApp(
          title: 'Area Incident Tracker - Database - Web',
          debugShowCheckedModeBanner: false,
          navigatorKey: app.navigatorKey,
          theme: buildTheme(pal),
          scrollBehavior: const _DesktopScroll(),
          home: _Root(app: app),
        );
      },
    );
  }
}

class _DesktopScroll extends MaterialScrollBehavior {
  const _DesktopScroll();
  @override
  Set<PointerDeviceKind> get dragDevices => {PointerDeviceKind.touch, PointerDeviceKind.stylus, PointerDeviceKind.trackpad};
}

class _Root extends StatefulWidget {
  const _Root({required this.app});
  final AppState app;
  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  AppState get app => widget.app;
  bool _loggingOut = false;

  @override
  void initState() {
    super.initState();
    app.addListener(_rebuild);
    app.requestLogout = () => _logout(confirm: false);
  }

  @override
  void dispose() {
    app.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (!mounted) return;
    setState(() {});
    // Keep keyboard shortcuts alive: if focus was lost (e.g. the focused widget
    // was replaced by navigation), park it on the root node.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || app.modalOpen) return;
      final f = FocusManager.instance.primaryFocus;
      if (f == null || f is FocusScopeNode) app.mainFocus.requestFocus();
    });
  }

  // Plain-character shortcuts are handled here (not via Shortcuts) so they never
  // swallow typing in text fields.
  KeyEventResult _plainKeys(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    if (typingInTextField() || app.modalOpen) return KeyEventResult.ignored;
    final hk = HardwareKeyboard.instance;
    if (hk.isControlPressed || hk.isAltPressed || hk.isMetaPressed) return KeyEventResult.ignored;
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.slash && !hk.isShiftPressed) {
      if (!_canNav) return KeyEventResult.ignored;
      _focusSearch();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.question || (k == LogicalKeyboardKey.slash && hk.isShiftPressed)) {
      showShortcutHelp(app);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // ---- global actions -------------------------------------------------------

  bool get _canNav => app.isAuthed && !app.modalOpen;

  void _nav(PageId id) {
    if (!_canNav) return;
    if (app.route.page == id && id != PageId.assessmentNew) {
      app.reload();
    } else {
      app.go(id);
    }
  }

  Future<void> _pickPlace() async {
    if (!_canNav) return;
    final pl = await showPlacePicker(app);
    if (pl != null) {
      if (app.route.page == PageId.assessmentNew) {
        app.navigate(AppRoute(PageId.assessmentNew, placeId: pl.placeId), replace: true);
      } else {
        app.goDashboard(placeId: pl.placeId);
      }
    }
  }

  void _newItem() {
    if (!_canNav) return;
    final a = app.pageActions;
    if (a?.newItem != null) {
      a!.newItem!();
    } else {
      app.navigate(AppRoute(PageId.assessmentNew, placeId: app.contextPlaceId));
    }
  }

  void _save() {
    if (!_canNav) return;
    app.pageActions?.save?.call();
  }

  void _print() {
    if (!_canNav) return;
    app.pageActions?.print?.call();
  }

  void _savePdf() {
    if (!_canNav) return;
    app.pageActions?.savePdf?.call();
  }

  void _history() {
    if (!_canNav) return;
    final a = app.pageActions;
    if (a?.openHistory != null) {
      a!.openHistory!();
    } else if (app.contextPlaceId != null) {
      app.navigate(AppRoute(PageId.history, placeId: app.contextPlaceId));
    }
  }

  void _focusSearch() {
    if (!_canNav) return;
    app.pageActions?.focusSearch?.call();
  }

  Future<void> _logout({bool confirm = true}) async {
    if (!app.isAuthed || _loggingOut || (confirm && app.modalOpen)) return;
    _loggingOut = true;
    try {
      if (confirm) {
        final ok = await laConfirm(app,
            title: 'Log out?', message: 'You will need to sign in again to continue.', confirmText: 'Log out');
        if (!ok) return;
      }
      await app.signOut();
    } finally {
      _loggingOut = false;
    }
  }

  void _escape() {
    if (app.modalOpen) return; // dialogs handle their own Esc
    if (typingInTextField()) {
      FocusManager.instance.primaryFocus?.unfocus();
      return;
    }
    if (app.sidebarOpen) {
      app.setSidebar(false);
      return;
    }
    if (app.isAuthed) app.back();
  }

  Future<void> _fullscreen() async {
    if (kIsWeb || !Platform.isWindows) return;
    final fs = await windowManager.isFullScreen();
    await windowManager.setFullScreen(!fs);
  }

  Map<ShortcutActivator, VoidCallback> get _bindings => {
        const SingleActivator(LogicalKeyboardKey.digit1, control: true): () => _nav(PageId.dashboard),
        const SingleActivator(LogicalKeyboardKey.digit2, control: true): () => _nav(PageId.places),
        const SingleActivator(LogicalKeyboardKey.digit3, control: true): () => _nav(PageId.areaMap),
        const SingleActivator(LogicalKeyboardKey.digit4, control: true): () => _nav(PageId.assessmentNew),
        const SingleActivator(LogicalKeyboardKey.digit5, control: true): () => _nav(PageId.framework),
        const SingleActivator(LogicalKeyboardKey.numpad1, control: true): () => _nav(PageId.dashboard),
        const SingleActivator(LogicalKeyboardKey.numpad2, control: true): () => _nav(PageId.places),
        const SingleActivator(LogicalKeyboardKey.numpad3, control: true): () => _nav(PageId.areaMap),
        const SingleActivator(LogicalKeyboardKey.numpad4, control: true): () => _nav(PageId.assessmentNew),
        const SingleActivator(LogicalKeyboardKey.numpad5, control: true): () => _nav(PageId.framework),
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): _pickPlace,
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): _newItem,
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): _save,
        const SingleActivator(LogicalKeyboardKey.keyP, control: true): _print,
        const SingleActivator(LogicalKeyboardKey.keyP, control: true, shift: true): _savePdf,
        const SingleActivator(LogicalKeyboardKey.keyH, control: true): _history,
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): _focusSearch,
        const SingleActivator(LogicalKeyboardKey.keyT, control: true): () => app.toggleTheme(),
        const SingleActivator(LogicalKeyboardKey.keyQ, control: true, shift: true): _logout,
        const SingleActivator(LogicalKeyboardKey.keyB, control: true): () {
          if (_canNav) app.setSidebar(!app.sidebarOpen);
        },
        const SingleActivator(LogicalKeyboardKey.keyR, control: true): () {
          if (_canNav) app.reload();
        },
        const SingleActivator(LogicalKeyboardKey.f5): () {
          if (_canNav) app.reload();
        },
        const SingleActivator(LogicalKeyboardKey.f1): () => showShortcutHelp(app),
        const SingleActivator(LogicalKeyboardKey.f11): _fullscreen,
        const SingleActivator(LogicalKeyboardKey.escape): _escape,
        const SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true): () {
          if (_canNav) app.back();
        },
      };

  Widget _page() {
    final r = app.route;
    if (!app.isAuthed || r.page == PageId.login) {
      return KeyedSubtree(key: ValueKey('login-${r.uid}'), child: LoginPage(app: app));
    }
    final Widget child;
    switch (r.page) {
      case PageId.dashboard:
        child = DashboardPage(app: app, placeId: r.placeId);
        break;
      case PageId.places:
        child = PlacesPage(app: app, route: r);
        break;
      case PageId.placeCreate:
        child = PlaceFormPage(app: app);
        break;
      case PageId.placeEdit:
        child = PlaceFormPage(app: app, editId: r.id);
        break;
      case PageId.assessmentNew:
        child = NewAssessmentPage(app: app, placeId: r.placeId);
        break;
      case PageId.history:
        child = HistoryPage(app: app, placeId: r.placeId ?? app.contextPlaceId ?? 0);
        break;
      case PageId.report:
        child = ReportPage(app: app, placeId: r.placeId ?? app.contextPlaceId ?? 0);
        break;
      case PageId.framework:
        child = FrameworkPage(app: app);
        break;
      case PageId.areaMap:
        child = AreaMapPage(app: app);
        break;
      case PageId.login:
        child = const SizedBox.shrink();
        break;
    }
    return AppShell(app: app, child: KeyedSubtree(key: ValueKey('page-${r.uid}'), child: child));
  }

  @override
  Widget build(BuildContext context) {
    final authed = app.isAuthed && app.route.page != PageId.login;
    return CallbackShortcuts(
      bindings: _bindings,
      child: Focus(
        focusNode: app.mainFocus,
        autofocus: true,
        onKeyEvent: _plainKeys,
        child: Scaffold(
          backgroundColor: context.pal.ink800,
          body: Stack(
            fit: StackFit.expand,
            children: [
              authed ? AppBackground(child: _page()) : _page(),
              ToastHost(app: app),
            ],
          ),
        ),
      ),
    );
  }
}
