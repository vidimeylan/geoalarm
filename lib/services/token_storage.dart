import 'package:shared_preferences/shared_preferences.dart';

import '../models/token_response.dart';

class TokenStorage {
  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _otpAccessTokenKey = 'otp_access_token';
  static const _accessExpiresAtKey = 'access_expires_at_ms';
  static const _otpRequestedAtKey = 'otp_requested_at_ms';

  static Future<void> saveTokens(TokenResponse token) async {
    final prefs = await SharedPreferences.getInstance();
    if (token.accessToken != null) {
      await prefs.setString(_accessTokenKey, token.accessToken!);
    }
    if (token.refreshToken != null) {
      await prefs.setString(_refreshTokenKey, token.refreshToken!);
    }
    if (token.expiresIn != null) {
      final expiresAt =
          DateTime.now().millisecondsSinceEpoch + (token.expiresIn! * 1000);
      await prefs.setInt(_accessExpiresAtKey, expiresAt);
    }
  }

  static Future<void> saveOtpAccessToken(String accessToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_otpAccessTokenKey, accessToken);
  }

  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_accessTokenKey);
  }

  static Future<int?> getAccessExpiresAtMillis() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_accessExpiresAtKey);
  }

  static Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_refreshTokenKey);
  }

  static Future<String?> getOtpAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_otpAccessTokenKey);
  }

  static Future<void> saveOtpRequestedAtNow() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _otpRequestedAtKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  static Future<int?> getOtpRequestedAtMillis() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_otpRequestedAtKey);
  }

  static Future<void> clearAuthTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
    await prefs.remove(_accessExpiresAtKey);
  }

  static Future<void> clearOtpToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_otpAccessTokenKey);
    await prefs.remove(_otpRequestedAtKey);
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
    await prefs.remove(_otpAccessTokenKey);
    await prefs.remove(_otpRequestedAtKey);
    await prefs.remove(_accessExpiresAtKey);
  }
}
