import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

/// Holds the signed-in user's tokens. Equivalent of the website's auth cookie:
/// persisted (60-day style "stay signed in") when "Keep me signed in" is ticked,
/// memory-only otherwise.
class SessionStore {
  SessionStore(this._prefs);
  final SharedPreferences _prefs;

  static const _kAccess = 'auth.access';
  static const _kRefresh = 'auth.refresh';
  static const _kExpires = 'auth.expires';
  static const _kUser = 'auth.username';
  static const _kDisplay = 'auth.display';
  static const _kRole = 'auth.role';
  static const _kSavedAt = 'auth.savedAt';

  String? accessToken;
  String? refreshToken;
  DateTime? expiresAt;
  String username = '';
  String displayName = '';
  String role = '';
  bool persistent = true;

  bool get isAuthenticated =>
      (accessToken ?? '').isNotEmpty && (refreshToken ?? '').isNotEmpty;

  void load() {
    accessToken = _prefs.getString(_kAccess);
    refreshToken = _prefs.getString(_kRefresh);
    final e = _prefs.getString(_kExpires);
    expiresAt = e == null ? null : DateTime.tryParse(e);
    username = _prefs.getString(_kUser) ?? '';
    displayName = _prefs.getString(_kDisplay) ?? '';
    role = _prefs.getString(_kRole) ?? '';
    persistent = true;
    // Sliding 60-day expiry, like the cookie.
    final savedAt = _prefs.getInt(_kSavedAt);
    if (savedAt != null) {
      final age = DateTime.now().millisecondsSinceEpoch - savedAt;
      if (age > const Duration(days: 60).inMilliseconds) {
        accessToken = null;
        refreshToken = null;
      }
    }
  }

  Future<void> signIn(AuthResponse a, {required bool remember}) async {
    persistent = remember;
    _apply(a);
    await _persist();
  }

  Future<void> updateTokens(AuthResponse a) async {
    _apply(a);
    await _persist();
  }

  void _apply(AuthResponse a) {
    accessToken = a.accessToken;
    refreshToken = a.refreshToken;
    expiresAt = a.accessTokenExpiresAt;
    if (a.username.isNotEmpty) username = a.username;
    if (a.displayName.isNotEmpty) displayName = a.displayName;
    if (a.role.isNotEmpty) role = a.role;
  }

  Future<void> _persist() async {
    if (!persistent) {
      await _wipePrefs();
      return;
    }
    await _prefs.setString(_kAccess, accessToken ?? '');
    await _prefs.setString(_kRefresh, refreshToken ?? '');
    await _prefs.setString(_kExpires, (expiresAt ?? DateTime.now().toUtc()).toIso8601String());
    await _prefs.setString(_kUser, username);
    await _prefs.setString(_kDisplay, displayName);
    await _prefs.setString(_kRole, role);
    await _prefs.setInt(_kSavedAt, DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> _wipePrefs() async {
    for (final k in [_kAccess, _kRefresh, _kExpires, _kUser, _kDisplay, _kRole, _kSavedAt]) {
      await _prefs.remove(k);
    }
  }

  Future<void> clear() async {
    accessToken = null;
    refreshToken = null;
    expiresAt = null;
    username = '';
    displayName = '';
    role = '';
    await _wipePrefs();
  }
}
