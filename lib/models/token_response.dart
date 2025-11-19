class TokenResponse {
  final String? accessToken;
  final String? refreshToken;
  final int? expiresIn;

  TokenResponse({
    this.accessToken,
    this.refreshToken,
    this.expiresIn,
  });

  factory TokenResponse.fromJson(Map<String, dynamic> json) {
    return TokenResponse(
      accessToken: json['accessToken'] as String?,
      refreshToken: json['refreshToken'] as String?,
      expiresIn: json['expiresIn'] is int
          ? json['expiresIn'] as int
          : int.tryParse('${json['expiresIn']}'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'expiresIn': expiresIn,
    };
  }
}
