import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/alarm.dart';
import 'auth_service.dart';

class AlarmApiService {
  static const String _baseUrl = 'https://api.siagaturun.web.id';
  final http.Client _client;

  AlarmApiService({http.Client? client}) : _client = client ?? http.Client();

  Future<List<Alarm>> fetchAlarms({int page = 0, int size = 100}) async {
    final token = await AuthService().getValidAccessToken();
    if (token == null) throw Exception('Not authenticated');

    final url = '$_baseUrl/api/alarm?page=$page&size=$size';
    print('[AlarmApiService] Fetching alarms from: $url');
    final resp = await _client.get(
      Uri.parse(url),
      headers: _authHeaders(token),
    );
    print('[AlarmApiService] Response status: ${resp.statusCode}');
    print('[AlarmApiService] Response body: ${resp.body}');
    _throwIfFailed(resp, 'Gagal mengambil daftar alarm');
    final body = jsonDecode(resp.body);
    
    // Parse paginated response
    if (body is Map && body.containsKey('content')) {
      final content = body['content'];
      if (content is List) {
        print('[AlarmApiService] Parsed ${content.length} alarms from content');
        return content.map((e) => _mapFromApi(e)).toList();
      }
    }
    print('[AlarmApiService] No content field or not a list, returning empty');
    return [];
  }

  Future<Alarm> getAlarm(String id) async {
    final token = await AuthService().getValidAccessToken();
    if (token == null) throw Exception('Not authenticated');

    final url = '$_baseUrl/api/alarm/$id';
    print('[AlarmApiService] GET $url');
    final resp = await _client.get(Uri.parse(url), headers: _authHeaders(token));
    print('[AlarmApiService] Response status: ${resp.statusCode}');
    print('[AlarmApiService] Response body: ${resp.body}');
    _throwIfFailed(resp, 'Gagal mengambil detail alarm');
    final body = jsonDecode(resp.body);
    return _mapFromApi(body);
  }

  Future<Alarm> createAlarm(Map<String, dynamic> payload) async {
    final token = await AuthService().getValidAccessToken();
    if (token == null) throw Exception('Not authenticated');
    final url = '$_baseUrl/api/alarm';
    final encodedBody = jsonEncode(payload);
    final headers = _authHeaders(token);
    print('[AlarmApiService] POST $url');
    print('[AlarmApiService] Headers: $headers');
    print('[AlarmApiService] Payload: $payload');
    print('[AlarmApiService] Encoded Body: $encodedBody');
    final resp = await _client.post(Uri.parse(url), headers: headers, body: encodedBody);
    print('[AlarmApiService] Response status: ${resp.statusCode}');
    print('[AlarmApiService] Response body: ${resp.body}');
    _throwIfFailed(resp, 'Gagal membuat alarm');
    final body = jsonDecode(resp.body);
    return _mapFromApi(body);
  }

  Future<Alarm> updateAlarm(String id, Map<String, dynamic> payload) async {
    final token = await AuthService().getValidAccessToken();
    if (token == null) throw Exception('Not authenticated');
    final url = '$_baseUrl/api/alarm/$id';
    final encodedBody = jsonEncode(payload);
    final headers = _authHeaders(token);
    print('[AlarmApiService] PUT $url');
    print('[AlarmApiService] Headers: $headers');
    print('[AlarmApiService] Payload: $payload');
    print('[AlarmApiService] Encoded Body: $encodedBody');
    final resp = await _client.put(Uri.parse(url), headers: headers, body: encodedBody);
    print('[AlarmApiService] Response status: ${resp.statusCode}');
    print('[AlarmApiService] Response body: ${resp.body}');
    _throwIfFailed(resp, 'Gagal mengupdate alarm');
    final body = jsonDecode(resp.body);
    return _mapFromApi(body);
  }

  Future<void> deleteAlarm(String id) async {
    final token = await AuthService().getValidAccessToken();
    if (token == null) throw Exception('Not authenticated');
    final url = '$_baseUrl/api/alarm/$id';
    print('[AlarmApiService] DELETE $url');
    final resp = await _client.delete(Uri.parse(url), headers: _authHeaders(token));
    print('[AlarmApiService] Response status: ${resp.statusCode}');
    print('[AlarmApiService] Response body: ${resp.body}');
    _throwIfFailed(resp, 'Gagal menghapus alarm');
  }

  Future<void> toggleActive(String id, bool active) async {
    // Use dedicated toggle endpoint from API
    final token = await AuthService().getValidAccessToken();
    if (token == null) throw Exception('Not authenticated');
    final url = '$_baseUrl/api/alarm/$id/toggle';
    print('[AlarmApiService] PATCH $url (toggle)');
    final resp = await _client.patch(Uri.parse(url), headers: _authHeaders(token));
    print('[AlarmApiService] Response status: ${resp.statusCode}');
    print('[AlarmApiService] Response body: ${resp.body}');
    _throwIfFailed(resp, 'Gagal toggle alarm');
  }

  Alarm _mapFromApi(dynamic json) {
    try {
      final id = json['id']?.toString() ?? json['uuid']?.toString() ?? '';
      // Support both 'lat'/'lon' and 'latitude'/'longitude' keys from API
      final latVal = json['lat'] ?? json['latitude'] ?? json['Latitude'];
      final lonVal = json['lon'] ?? json['longitude'] ?? json['Longitude'];
      final lat = (latVal is num) ? latVal.toDouble() : double.tryParse('${latVal}') ?? 0.0;
      final lon = (lonVal is num) ? lonVal.toDouble() : double.tryParse('${lonVal}') ?? 0.0;
      final label = json['label']?.toString() ?? json['name']?.toString() ?? json['Name']?.toString() ?? '';
      final isActive = json['isActive'] ?? json['active'] ?? true;
      final radius = json['radius'] is int
          ? json['radius']
          : (json['radius'] is String ? int.tryParse(json['radius']) ?? 500 : 500);
      
      // Parse createdDate
      DateTime? createdDate;
      final createdDateStr = json['createdDate'];
      if (createdDateStr != null) {
        try {
          createdDate = DateTime.parse(createdDateStr.toString());
        } catch (_) {}
      }
      
      return Alarm(
        id: id,
        lat: lat,
        lon: lon,
        label: label,
        isActive: isActive == true || isActive.toString() == '1',
        radius: radius,
        createdDate: createdDate,
      );
    } catch (_) {
      return Alarm(id: '', label: 'Unknown');
    }
  }

  Map<String, String> _jsonHeaders() => {'Content-Type': 'application/json'};

  Map<String, String> _authHeaders(String token) => {..._jsonHeaders(), 'Authorization': 'Bearer $token'};

  void _throwIfFailed(http.Response resp, String fallback) {
    if (resp.statusCode >= 200 && resp.statusCode < 300) return;
    String msg = fallback;
    try {
      final body = jsonDecode(resp.body);
      if (body is Map && body.containsKey('message')) msg = body['message'];
    } catch (_) {}
    throw Exception('$msg (HTTP ${resp.statusCode})');
  }
}
