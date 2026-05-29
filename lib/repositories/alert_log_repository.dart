import '../services/api_service.dart';

/// 알림 발송 이력(Alert log) 도메인 데이터 접근 계층.
/// 관리자/사용자 모드 모두에서 사용한다.
class AlertLogRepository {
  AlertLogRepository({ApiService? apiService}) : _api = apiService ?? ApiService();

  final ApiService _api;

  Future<Map<String, dynamic>> getAlertLogs({
    required bool isAdmin,
    int page = 1,
    int perPage = 20,
    int? marketId,
  }) =>
      _api.getAlertLogs(
        isAdmin: isAdmin,
        page: page,
        perPage: perPage,
        marketId: marketId,
      );
}
