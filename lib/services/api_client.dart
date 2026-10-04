import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';
import 'session_store.dart';

class _CacheEntry {
  _CacheEntry(this.value, this.expires);
  final dynamic value;
  final DateTime expires;
}

/// Talks to the Area Incident Tracker API on behalf of the signed-in user.
/// Mirrors the website's ApiClient: bearer token, silent refresh using the
/// long-lived refresh token, and short-lived in-memory caching.
class ApiClient {
  ApiClient(this.session);

  static const String baseUrl = 'http://areatrackerapi.runasp.net/';
  static const _timeout = Duration(seconds: 30);

  final SessionStore session;
  final http.Client _http = http.Client();
  final Map<String, _CacheEntry> _cache = {};
  Future<String?>? _refreshing;

  /// Called when the refresh token is rejected, so the app can return to Sign in.
  void Function()? onSessionExpired;

  Uri _uri(String url) => Uri.parse(baseUrl + url);

  Future<String?> _validAccessToken() async {
    if (!session.isAuthenticated) return null;
    final exp = session.expiresAt;
    if (exp != null && DateTime.now().toUtc().isBefore(exp.subtract(const Duration(seconds: 30)))) {
      return session.accessToken;
    }
    // Access token expired (or about to) — silently refresh (single flight).
    return _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);
  }

  Future<String?> _doRefresh() async {
    try {
      final resp = await _http
          .post(
            _uri('api/auth/refresh'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refreshToken': session.refreshToken, 'deviceInfo': 'Website'}),
          )
          .timeout(_timeout);
      if (resp.statusCode == 401 || resp.statusCode == 400 || resp.statusCode == 403) {
        onSessionExpired?.call();
        return null;
      }
      if (resp.statusCode < 200 || resp.statusCode >= 300 || resp.body.isEmpty) return null;
      final auth = AuthResponse.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
      await session.updateTokens(auth);
      return auth.accessToken;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, String>> _headers({bool json = false}) async {
    final h = <String, String>{'Accept': 'application/json'};
    if (json) h['Content-Type'] = 'application/json';
    final token = await _validAccessToken();
    if (token != null && token.isNotEmpty) h['Authorization'] = 'Bearer $token';
    return h;
  }

  /// GET \u2192 decoded JSON, or null on any failure (same as the website).
  Future<dynamic> get(String url) async {
    try {
      final resp = await _http.get(_uri(url), headers: await _headers()).timeout(_timeout);
      if (resp.statusCode < 200 || resp.statusCode >= 300) return null;
      if (resp.body.isEmpty) return null;
      return jsonDecode(utf8.decode(resp.bodyBytes));
    } catch (_) {
      return null;
    }
  }

  /// GET with an in-memory cache for [duration].
  Future<dynamic> getCached(String url, Duration duration) async {
    final hit = _cache[url];
    if (hit != null && hit.expires.isAfter(DateTime.now()) && hit.value != null) {
      return hit.value;
    }
    final result = await get(url);
    if (result != null) _cache[url] = _CacheEntry(result, DateTime.now().add(duration));
    return result;
  }

  void invalidate(String key) => _cache.remove(key);

  void _invalidateFor(String url) {
    final u = url.toLowerCase();
    if (u.contains('assessments')) invalidate('api/assessments');
    if (u.contains('places')) {
      invalidate('api/places');
      invalidate(url);
    }
  }

  Future<(bool, dynamic, String?)> post(String url, Object body) async {
    try {
      final resp = await _http
          .post(_uri(url), headers: await _headers(json: true), body: jsonEncode(body))
          .timeout(_timeout);
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        return (false, null, utf8.decode(resp.bodyBytes));
      }
      dynamic data;
      if (resp.body.isNotEmpty) {
        try {
          data = jsonDecode(utf8.decode(resp.bodyBytes));
        } catch (_) {}
      }
      _invalidateFor(url);
      return (true, data, null);
    } catch (e) {
      return (false, null, e.toString());
    }
  }

  Future<(bool, String?)> put(String url, Object body) async {
    try {
      final resp = await _http
          .put(_uri(url), headers: await _headers(json: true), body: jsonEncode(body))
          .timeout(_timeout);
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        _invalidateFor(url);
        return (true, null);
      }
      return (false, utf8.decode(resp.bodyBytes));
    } catch (e) {
      return (false, e.toString());
    }
  }

  Future<bool> delete(String url) async {
    try {
      final resp = await _http.delete(_uri(url), headers: await _headers()).timeout(_timeout);
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        _invalidateFor(url);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Login does not need an existing token.
  Future<(bool, AuthResponse?, String?)> login(String username, String password) async {
    try {
      final resp = await _http
          .post(
            _uri('api/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'username': username, 'password': password, 'deviceInfo': 'Website'}),
          )
          .timeout(_timeout);
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        return (false, null, 'Incorrect username or password.');
      }
      final auth = resp.body.isEmpty
          ? null
          : AuthResponse.fromJson(jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>);
      return (true, auth, null);
    } catch (e) {
      return (false, null, e.toString());
    }
  }

  Future<void> logout() async {
    final refresh = session.refreshToken;
    if (refresh == null || refresh.isEmpty) return;
    await post('api/auth/logout', {'refreshToken': refresh, 'deviceInfo': null});
  }

  // ---- Typed helpers --------------------------------------------------------

  Future<PagedResult<PlaceDto>> places(String url, {int page = 1, int pageSize = 15}) async =>
      PagedResult.places(await get(url), page: page, pageSize: pageSize);

  Future<PlaceDto?> place(int id) async {
    final j = await getCached('api/places/$id', const Duration(minutes: 5));
    return j is Map<String, dynamic> ? PlaceDto.fromJson(j) : null;
  }

  Future<List<AssessmentDto>> assessmentsCached() async {
    final j = await getCached('api/assessments', const Duration(seconds: 60));
    return _assessmentList(j);
  }

  Future<List<AssessmentDto>> assessmentsFor(int placeId) async =>
      _assessmentList(await get('api/assessments?placeId=$placeId'));

  Future<AssessmentDto?> latestFor(int placeId) async {
    final j = await get('api/assessments/latest/$placeId');
    return j is Map<String, dynamic> ? AssessmentDto.fromJson(j) : null;
  }

  List<AssessmentDto> _assessmentList(dynamic j) {
    if (j is! List) return <AssessmentDto>[];
    return j.map((e) => AssessmentDto.fromJson(e as Map<String, dynamic>)).toList();
  }
}
