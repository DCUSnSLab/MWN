
class ApiError {
  final String error;

  ApiError({required this.error});

  factory ApiError.fromJson(Map<String, dynamic> json) {
    return ApiError(
      error: json['error'] as String? ?? json['message'] as String? ?? '알 수 없는 오류가 발생했습니다.',
    );
  }

  Map<String, dynamic> toJson() => {
    'error': error,
  };
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, [this.statusCode]);

  @override
  String toString() {
    if (statusCode != null) {
      return 'API Error ($statusCode): $message';
    }
    return 'API Error: $message';
  }
}