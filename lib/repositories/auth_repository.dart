import '../models/user.dart';
import '../services/api_service.dart';

/// 인증 도메인 데이터 접근 계층.
///
/// 네트워크 클라이언트(`ApiService`)를 감싸 인증 관련 호출만 노출한다.
/// 상태(currentUser·loading 등)는 `AuthProvider`가 보유하고, 이 클래스는 무상태다.
/// 화면/프로바이더가 `ApiService` 전역 싱글톤에 직접 의존하지 않도록 하는 것이 목적이다.
class AuthRepository {
  AuthRepository({ApiService? apiService}) : _api = apiService ?? ApiService();

  final ApiService _api;

  bool get isLoggedIn => _api.isLoggedIn;

  Future<void> loadTokens() => _api.loadTokens();
  Future<void> clearTokens() => _api.clearTokens();

  Future<AuthResponse> register(RegisterRequest request) => _api.register(request);
  Future<AuthResponse> login(LoginRequest request) => _api.login(request);
  Future<User> getProfile() => _api.getProfile();
  Future<void> logout() => _api.logout();
  Future<void> deleteAccount() => _api.deleteAccount();
  Future<bool> verifyPassword(String password) => _api.verifyPassword(password);

  Future<User> updateProfile({
    String? name,
    String? email,
    String? password,
    String? phone,
    String? location,
  }) =>
      _api.updateProfile(
        name: name,
        email: email,
        password: password,
        phone: phone,
        location: location,
      );
}
