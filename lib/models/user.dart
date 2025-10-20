import 'package:json_annotation/json_annotation.dart';

part 'user.g.dart';

@JsonSerializable()
class User {
  final int id;
  final String name;
  final String email;
  final String? phone;
  final String? location;
  @JsonKey(name: 'is_active')
  final bool isActive;
  @JsonKey(name: 'email_verified')
  final bool emailVerified;
  @JsonKey(name: 'last_login')
  final String? lastLogin;
  @JsonKey(name: 'created_at')
  final String? createdAt;
  @JsonKey(name: 'notification_preferences')
  final Map<String, dynamic>? notificationPreferences;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.location,
    required this.isActive,
    required this.emailVerified,
    this.lastLogin,
    this.createdAt,
    this.notificationPreferences,
  });

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
  Map<String, dynamic> toJson() => _$UserToJson(this);
}

@JsonSerializable()
class AuthTokens {
  @JsonKey(name: 'access_token')
  final String accessToken;
  @JsonKey(name: 'refresh_token')
  final String refreshToken;
  @JsonKey(name: 'token_type')
  final String tokenType;
  @JsonKey(name: 'expires_in')
  final int expiresIn;

  AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.expiresIn,
  });

  factory AuthTokens.fromJson(Map<String, dynamic> json) => _$AuthTokensFromJson(json);
  Map<String, dynamic> toJson() => _$AuthTokensToJson(this);
}

@JsonSerializable()
class AuthResponse {
  final String message;
  final User user;
  final AuthTokens tokens;

  AuthResponse({
    required this.message,
    required this.user,
    required this.tokens,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) => _$AuthResponseFromJson(json);
  Map<String, dynamic> toJson() => _$AuthResponseToJson(this);
}

@JsonSerializable()
class RegisterRequest {
  final String name;
  final String email;
  final String password;
  final String? phone;
  final String? location;

  RegisterRequest({
    required this.name,
    required this.email,
    required this.password,
    this.phone,
    this.location,
  });

  factory RegisterRequest.fromJson(Map<String, dynamic> json) => _$RegisterRequestFromJson(json);
  Map<String, dynamic> toJson() => _$RegisterRequestToJson(this);
}

@JsonSerializable()
class LoginRequest {
  final String email;
  final String password;

  LoginRequest({
    required this.email,
    required this.password,
  });

  factory LoginRequest.fromJson(Map<String, dynamic> json) => _$LoginRequestFromJson(json);
  Map<String, dynamic> toJson() => _$LoginRequestToJson(this);
}