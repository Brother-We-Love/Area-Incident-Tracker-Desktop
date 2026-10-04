import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import '../models/models.dart';
import '../services/api_client.dart';
import '../services/geocoder.dart';
import '../services/session_store.dart';

enum PageId {
  login,
  dashboard,
  places,
  placeCreate,
  placeEdit,
  assessmentNew,
  history,
  report,
  framework,
  areaMap,
}

class AppRoute {
  AppRoute(
    this.page, {
    this.placeId,
    this.id,
    this.search,
    this.level,
    this.parentPlaceId,
    this.pageNo = 1,
  }) : uid = ++_seq;

  static int _seq = 0;
  final int uid;
  final PageId page;
  final int? placeId;
  final int? id;
  final String? search;
  final String? level;
  final int? parentPlaceId;
  final int pageNo;

  String get title {
    switch (page) {
      case PageId.login:
        return 'Sign in';
      case PageId.dashboard:
        return 'Dashboard';
      case PageId.places:
        return 'Places';
      case PageId.placeCreate:
        return 'Add Place';
      case PageId.placeEdit:
        return 'Edit Place';
      case PageId.assessmentNew:
        return 'New Assessment';
      case PageId.history:
        return 'History';
      case PageId.report:
        return 'Print Report';
      case PageId.framework:
        return 'Domain Assessment Framework';
      case PageId.areaMap:
        return 'Area Map';
    }
  }

  /// Which sidebar entry is highlighted (website highlights by controller:
  /// Assessments covers New + History; Print Report highlights nothing).
  PageId? get navHighlight {
    switch (page) {
      case PageId.dashboard:
        return PageId.dashboard;
      case PageId.places:
      case PageId.placeCreate:
      case PageId.placeEdit:
        return PageId.places;
      case PageId.areaMap:
        return PageId.areaMap;
      case PageId.assessmentNew:
      case PageId.history:
        return PageId.assessmentNew;
      case PageId.framework:
        return PageId.framework;
      default:
        return null;
    }
  }
}

/// Handlers the current page registers so global shortcuts can reach it.
class PageActions {
  VoidCallback? focusSearch;
  VoidCallback? save;
  VoidCallback? print;
  VoidCallback? savePdf;
  VoidCallback? openHistory;
  VoidCallback? newItem;
  Future<void> Function(PlaceDto place)? placePicked;
}

class ToastData {
  ToastData(this.id, this.type, this.title, this.message, this.durationMs);
  final int id;
  final String type;
  final String? title;
  final String message;
  final int durationMs;
}

class AppState extends ChangeNotifier {
  late final SharedPreferences prefs;
  late final SessionStore session;
  late final ApiClient api;
  late final Geocoder geocoder;

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  final ValueNotifier<bool> darkMode = ValueNotifier(false);
  final ValueNotifier<List<ToastData>> toasts = ValueNotifier(<ToastData>[]);
  final FocusNode mainFocus = FocusNode(debugLabel: 'main');

  AppRoute route = AppRoute(PageId.login);
  final List<AppRoute> history = [];

  int modalDepth = 0;
  bool helpOpen = false;
  bool sidebarOpen = false;
  PageActions? pageActions;
  /// Set by the root widget so the sidebar's Log out button shares the confirm flow.
  VoidCallback? requestLogout;
  int? contextPlaceId;
  int _toastSeq = 0;

  static const _themeKey = 'area-incident-tracker-theme';

  bool get isAuthed => session.isAuthenticated;
  bool get modalOpen => modalDepth > 0;
  String get displayName => session.displayName;

  Future<void> init() async {
    prefs = await SharedPreferences.getInstance();
    session = SessionStore(prefs)..load();
    api = ApiClient(session);
    geocoder = Geocoder(prefs);
    darkMode.value = (prefs.getString(_themeKey) ?? 'light') == 'dark';
    api.onSessionExpired = () {
      if (!isAuthed && route.page == PageId.login) return;
      signOutLocal();
    };
    route = AppRoute(isAuthed ? PageId.dashboard : PageId.login);
    _syncTitle();
  }

  // ---- Theme ----------------------------------------------------------------

  Future<void> toggleTheme() async {
    darkMode.value = !darkMode.value;
    await prefs.setString(_themeKey, darkMode.value ? 'dark' : 'light');
  }

  // ---- Navigation -----------------------------------------------------------

  void navigate(AppRoute r, {bool replace = false}) {
    if (!replace) {
      history.add(route);
      if (history.length > 60) history.removeAt(0);
    }
    route = r;
    sidebarOpen = false;
    _syncTitle();
    notifyListeners();
  }

  void go(PageId page, {int? placeId}) => navigate(AppRoute(page, placeId: placeId));

  void goDashboard({int? placeId}) => navigate(AppRoute(PageId.dashboard, placeId: placeId));

  bool get canGoBack => history.isNotEmpty || route.page != PageId.dashboard;

  void back() {
    if (!isAuthed) return;
    if (history.isNotEmpty) {
      route = history.removeLast();
    } else if (route.page != PageId.dashboard) {
      route = AppRoute(PageId.dashboard);
    } else {
      return;
    }
    sidebarOpen = false;
    _syncTitle();
    notifyListeners();
  }

  void reload() {
    final r = route;
    route = AppRoute(r.page,
        placeId: r.placeId,
        id: r.id,
        search: r.search,
        level: r.level,
        parentPlaceId: r.parentPlaceId,
        pageNo: r.pageNo);
    notifyListeners();
  }

  void setSidebar(bool open) {
    if (sidebarOpen == open) return;
    sidebarOpen = open;
    notifyListeners();
  }

  void _syncTitle() {
    if (kIsWeb) return;
    try {
      if (Platform.isWindows) {
        windowManager.setTitle('${route.title} — Area Incident Tracker - Database - Web');
      }
    } catch (_) {}
  }

  // ---- Auth -----------------------------------------------------------------

  Future<void> signIn(AuthResponse auth, {required bool remember}) async {
    await session.signIn(auth, remember: remember);
    history.clear();
    route = AppRoute(PageId.dashboard);
    _syncTitle();
    notifyListeners();
  }

  Future<void> signOut() async {
    await api.logout();
    await signOutLocal();
  }

  Future<void> signOutLocal() async {
    await session.clear();
    history.clear();
    pageActions = null;
    contextPlaceId = null;
    sidebarOpen = false;
    route = AppRoute(PageId.login);
    _syncTitle();
    notifyListeners();
  }

  // ---- Page action registry --------------------------------------------------

  void registerPage(PageActions actions) => pageActions = actions;

  void unregisterPage(PageActions actions) {
    if (identical(pageActions, actions)) pageActions = null;
  }

  // ---- Toasts ----------------------------------------------------------------

  void toast(String type, String message, {String? title, int duration = 4200}) {
    final t = ToastData(++_toastSeq, type, title, message, duration);
    toasts.value = [...toasts.value, t];
  }

  void dismissToast(int id) {
    toasts.value = toasts.value.where((t) => t.id != id).toList();
  }

  // ---- Modal bookkeeping ------------------------------------------------------

  void modalOpened() => modalDepth++;
  void modalClosed() {
    if (modalDepth > 0) modalDepth--;
  }
}
