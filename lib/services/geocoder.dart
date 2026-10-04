import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

/// OpenStreetMap Nominatim geocoder with a persistent local cache and a
/// 1 request/second throttle (Nominatim usage policy) — same behaviour as
/// the website's area-map.js, with SharedPreferences instead of localStorage.
class Geocoder {
  Geocoder(this._prefs) {
    try {
      final raw = _prefs.getString(_cacheKey);
      if (raw != null && raw.isNotEmpty) {
        final m = jsonDecode(raw) as Map<String, dynamic>;
        m.forEach((k, v) {
          final mv = v as Map<String, dynamic>;
          _cache[k] = ((mv['lat'] as num).toDouble(), (mv['lng'] as num).toDouble());
        });
      }
    } catch (_) {}
  }

  static const _cacheKey = 'la-area-map-geocode-cache-v1';
  static const _minInterval = Duration(milliseconds: 1100);
  static const _userAgent = 'AreaIncidentTracker-Desktop/1.0 (Flutter Windows)';

  final SharedPreferences _prefs;
  final Map<String, (double, double)> _cache = {};
  final http.Client _http = http.Client();
  Future<void> _gate = Future.value();
  DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);
  int _unsaved = 0;

  (double, double)? cached(String psgcCode) => _cache[psgcCode];

  Future<void> _throttle() async {
    final prev = _gate;
    final done = Completer<void>();
    _gate = done.future;
    await prev;
    final elapsed = DateTime.now().difference(_last);
    if (elapsed < _minInterval) await Future.delayed(_minInterval - elapsed);
    _last = DateTime.now();
    done.complete();
  }

  /// Resolves coordinates for [point]; null when not found / offline.
  Future<(double, double)?> geocode(AreaMapPoint point) async {
    final hit = _cache[point.psgcCode];
    if (hit != null) return hit;
    await _throttle();
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'format': 'json',
      'limit': '1',
      'countrycodes': 'ph',
      'q': point.geocodeQuery,
    });
    try {
      final resp = await _http
          .get(uri, headers: {'Accept': 'application/json', 'User-Agent': _userAgent})
          .timeout(const Duration(seconds: 20));
      if (resp.statusCode != 200) return null;
      final results = jsonDecode(utf8.decode(resp.bodyBytes));
      if (results is! List || results.isEmpty) return null;
      final first = results.first as Map<String, dynamic>;
      final lat = double.tryParse('${first['lat']}');
      final lng = double.tryParse('${first['lon']}');
      if (lat == null || lng == null) return null;
      _cache[point.psgcCode] = (lat, lng);
      _unsaved++;
      if (_unsaved >= 5) await flush();
      return (lat, lng);
    } catch (_) {
      return null;
    }
  }

  Future<void> flush() async {
    _unsaved = 0;
    try {
      final m = <String, dynamic>{
        for (final e in _cache.entries) e.key: {'lat': e.value.$1, 'lng': e.value.$2}
      };
      await _prefs.setString(_cacheKey, jsonEncode(m));
    } catch (_) {}
  }
}
