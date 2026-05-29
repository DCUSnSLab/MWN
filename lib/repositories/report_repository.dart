import '../services/api_service.dart';

/// 신고(Report) 도메인 데이터 접근 계층.
/// `ApiService`(네트워크 클라이언트)를 감싸 신고 관련 호출만 노출한다.
class ReportRepository {
  ReportRepository({ApiService? apiService}) : _api = apiService ?? ApiService();

  final ApiService _api;

  /// 신고 첨부 이미지가 서빙되는 베이스 URL.
  String get imageBaseUrl => ApiService.baseUrl;

  Future<List<Map<String, dynamic>>> getReports() => _api.getReports();

  Future<void> submitReport({
    required int marketId,
    required String reportType,
    required String description,
    required String imagePath,
  }) =>
      _api.submitReport(
        marketId: marketId,
        reportType: reportType,
        description: description,
        imagePath: imagePath,
      );
}
