import '../models/user.dart';
import '../services/api_service.dart';

/// 관리자(admin) 도메인 데이터 접근 계층.
/// `ApiService`(네트워크 클라이언트)를 감싸 관리자 전용 호출을 노출한다.
class AdminRepository {
  AdminRepository({ApiService? apiService}) : _api = apiService ?? ApiService();

  final ApiService _api;

  Future<List<User>> getAllUsers() => _api.getAllUsers();

  Future<User> createUser({
    required String name,
    required String email,
    required String password,
    String? phone,
    String? location,
    String role = 'user',
  }) =>
      _api.createUser(
        name: name,
        email: email,
        password: password,
        phone: phone,
        location: location,
        role: role,
      );
}
