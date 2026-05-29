import '../models/user.dart';
import '../models/market.dart';
import '../models/alert_conditions.dart';
import '../services/api_service.dart';

/// 관리자(admin) 도메인 데이터 접근 계층.
/// `ApiService`(네트워크 클라이언트)를 감싸 관리자 전용 호출을 노출한다.
class AdminRepository {
  AdminRepository({ApiService? apiService}) : _api = apiService ?? ApiService();

  final ApiService _api;

  /// 현재 로그인한 관리자 프로필 (권한 확인 등에 사용).
  Future<User> getProfile() => _api.getProfile();

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

  Future<void> sendAdminFCMBroadcast({
    required String title,
    required String body,
    String? topic,
    List<int>? userIds,
    Map<String, dynamic>? data,
  }) =>
      _api.sendAdminFCMBroadcast(
        title: title,
        body: body,
        topic: topic,
        userIds: userIds,
        data: data,
      );

  Future<List<Market>> getMarkets({
    int page = 1,
    int perPage = 100,
    bool? isActive,
  }) =>
      _api.getMarkets(page: page, perPage: perPage, isActive: isActive);

  Future<Map<String, dynamic>> sendWeatherTestAlert({
    required int userId,
    required int marketId,
    required String alertType,
    bool ignoreDnd = false,
    String? customTitle,
    String? customBody,
  }) =>
      _api.sendWeatherTestAlert(
        userId: userId,
        marketId: marketId,
        alertType: alertType,
        ignoreDnd: ignoreDnd,
        customTitle: customTitle,
        customBody: customBody,
      );

  Future<List<UserMarketInterest>> getWatchlist() => _api.getWatchlist();

  Future<MarketAlertConditionsResponse> getMarketAlertConditions(int marketId) =>
      _api.getMarketAlertConditions(marketId);

  Future<MarketAlertConditionsResponse> updateMarketAlertConditions(
    int marketId,
    Map<String, dynamic> conditions,
  ) =>
      _api.updateMarketAlertConditions(marketId, conditions);
}
