import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/token_response.dart';
import 'token_storage.dart';

class AuthService {
  static const String _baseUrl = 'https://siagaturunbe.isasubani.my.id';
  final http.Client _client;

  AuthService({http.Client? client}) : _client = client ?? http.Client();

  Future<void> sendOtp(String email) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/api/otp/challenge'),
      headers: _jsonHeaders(),
      body: jsonEncode({'email': email}),
    );
    _throwIfFailed(response, 'Gagal mengirim OTP');
  }

  Future<TokenResponse> verifyOtp({
    required String email,
    required String otp,
  }) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/api/otp/authentication'),
      headers: _jsonHeaders(),
      body: jsonEncode({'email': email, 'otp': otp}),
    );
    _throwIfFailed(response, 'OTP tidak valid');
    final token = TokenResponse.fromJson(jsonDecode(response.body));
    if (token.accessToken != null) {
      await TokenStorage.saveOtpAccessToken(token.accessToken!);
    }
    return token;
  }

  Future<void> register({
    required String email,
    required String name,
    required String username,
    required String password,
    String? otpBearer,
  }) async {
    final bearer = otpBearer ?? await TokenStorage.getOtpAccessToken();
    if (bearer == null || bearer.isEmpty) {
      throw Exception('Token OTP belum tersedia. Verifikasi OTP terlebih dahulu.');
    }

    final response = await _client.post(
      Uri.parse('$_baseUrl/api/user/registration'),
      headers: _authHeaders(bearer),
      body: jsonEncode({
        'email': email,
        'name': name,
        'username': username,
        'password': password,
      }),
    );
    _throwIfFailed(response, 'Registrasi gagal');
  }

  Future<TokenResponse> login({
    required String username,
    required String password,
  }) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/api/user/authentication'),
      headers: _jsonHeaders(),
      body: jsonEncode({'username': username, 'password': password}),
    );
    _throwIfFailed(response, 'Login gagal');
    final token = TokenResponse.fromJson(jsonDecode(response.body));
    await TokenStorage.saveTokens(token);
    return token;
  }

  Future<TokenResponse> loginWithGoogle({
    required String idToken,
  }) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/api/user/authentication/google'),
      headers: _jsonHeaders(),
      body: jsonEncode({'idToken': idToken}),
    );
    _throwIfFailed(response, 'Login Google gagal');
    final token = TokenResponse.fromJson(jsonDecode(response.body));
    await TokenStorage.saveTokens(token);
    return token;
  }

  /// Mengambil access token yang masih valid, jika hampir kedaluwarsa mencoba refresh.
  /// Mengembalikan null jika tak ada token atau refresh token tidak tersedia.
  Future<String?> getValidAccessToken() async {
    final accessToken = await TokenStorage.getAccessToken();
    final refreshToken = await TokenStorage.getRefreshToken();

    // Anggap tidak login jika tidak ada refresh token.
    if (accessToken == null ||
        accessToken.isEmpty ||
        refreshToken == null ||
        refreshToken.isEmpty) {
      return null;
    }

    final expiresAt = await TokenStorage.getAccessExpiresAtMillis();
    final now = DateTime.now().millisecondsSinceEpoch;

    // Jika belum ada info expire, pakai apa adanya.
    if (expiresAt == null || now < expiresAt - 5000) {
      return accessToken;
    }

    // Token hampir habis, coba refresh.
    try {
      final newToken = await refresh(refreshToken);
      return newToken.accessToken ?? accessToken;
    } catch (_) {
      // Jangan gagal total; tetap pakai token lama.
      return accessToken;
    }
  }

  Future<TokenResponse> refresh(String refreshToken) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/api/user/refresh-token'),
      headers: _authHeaders(refreshToken),
    );
    _throwIfFailed(response, 'Refresh token gagal');
    final token = TokenResponse.fromJson(jsonDecode(response.body));
    await TokenStorage.saveTokens(token);
    return token;
  }

  Future<void> resetPassword({
    required String newPassword,
    String? otpBearer,
  }) async {
    final bearer = otpBearer ?? await TokenStorage.getOtpAccessToken();
    if (bearer == null || bearer.isEmpty) {
      throw Exception('Token OTP belum tersedia. Verifikasi OTP terlebih dahulu.');
    }

    final response = await _client.post(
      Uri.parse('$_baseUrl/api/user/reset-password'),
      headers: _authHeaders(bearer),
      body: jsonEncode({'password': newPassword}),
    );
    _throwIfFailed(response, 'Reset password gagal');
  }

  Future<void> logout() async {
    await TokenStorage.clearAll();
  }

  Map<String, String> _jsonHeaders() {
    return {'Content-Type': 'application/json'};
  }

  Map<String, String> _authHeaders(String bearer) {
    return {
      ..._jsonHeaders(),
      'Authorization': 'Bearer $bearer',
    };
  }

  void _throwIfFailed(http.Response response, String fallbackMessage) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }
    final body = response.body;
    final message = _parseError(body) ?? fallbackMessage;
    throw Exception('$message (HTTP ${response.statusCode})');
  }

  String? _parseError(String? body) {
    if (body == null || body.isEmpty) return null;
    try {
      final Map<String, dynamic> jsonBody = jsonDecode(body);
      if (jsonBody.containsKey('message')) {
        return '${jsonBody['message']}';
      }
    } catch (_) {
      return null;
    }
    return null;
  }
}
