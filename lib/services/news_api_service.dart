import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/news.dart';
import 'auth_service.dart';

class NewsApiService {
  static const String _baseUrl = 'https://siagaturunbe.isasubani.my.id';
  final http.Client _client;

  NewsApiService({http.Client? client}) : _client = client ?? http.Client();

  Future<NewsResponse> fetchNews({
    int page = 0,
    int size = 20,
  }) async {
    final token = await AuthService().getValidAccessToken();
    if (token == null) throw Exception('Not authenticated');

    final url = '$_baseUrl/api/news?page=$page&size=$size';
    print('[NewsApiService] Fetching news from: $url');

    final response = await _client.get(
      Uri.parse(url),
      headers: _authHeaders(token),
    );

    print('[NewsApiService] Response status: ${response.statusCode}');
    _throwIfFailed(response, 'Gagal mengambil berita');

    final body = jsonDecode(response.body);
    print('[NewsApiService] Parsed ${body['content']?.length ?? 0} news items');

    return NewsResponse.fromJson(body);
  }

  Map<String, String> _authHeaders(String token) => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  void _throwIfFailed(http.Response response, String fallback) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;

    String msg = fallback;
    try {
      final body = jsonDecode(response.body);
      if (body is Map && body.containsKey('message')) {
        msg = body['message'];
      }
    } catch (_) {}
    throw Exception('$msg (HTTP ${response.statusCode})');
  }
}
