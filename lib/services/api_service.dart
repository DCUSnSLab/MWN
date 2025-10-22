import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../models/weather.dart';
import '../models/api_error.dart';
import '../utils/coordinate_converter.dart';

class ApiService {
  static const String baseUrl = 'http://203.250.35.243:32462';
  
  // 싱글톤 패턴
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  String? _accessToken;
  String? _refreshToken;

  // 토큰 저장
  Future<void> _saveTokens(AuthTokens tokens) async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = tokens.accessToken;
    _refreshToken = tokens.refreshToken;
    await prefs.setString('access_token', tokens.accessToken);
    await prefs.setString('refresh_token', tokens.refreshToken);
  }

  // 토큰 로드
  Future<void> loadTokens() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('access_token');
    _refreshToken = prefs.getString('refresh_token');
  }

  // 토큰 삭제
  Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = null;
    _refreshToken = null;
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
  }

  // 인증이 필요한 요청에 헤더 추가
  Map<String, String> get _authHeaders {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (_accessToken != null) {
      headers['Authorization'] = 'Bearer $_accessToken';
    }
    return headers;
  }

  // HTTP 응답 처리
  T _handleResponse<T>(http.Response response, T Function(Map<String, dynamic>) fromJson) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final Map<String, dynamic> data = json.decode(response.body);
      return fromJson(data);
    } else {
      final Map<String, dynamic> errorData = json.decode(response.body);
      final apiError = ApiError.fromJson(errorData);
      throw ApiException(apiError.error, response.statusCode);
    }
  }

  // 서버 상태 확인
  Future<bool> checkHealth() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/health'));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // 회원가입
  Future<AuthResponse> register(RegisterRequest request) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(request.toJson()),
    );

    final authResponse = _handleResponse(response, AuthResponse.fromJson);
    await _saveTokens(authResponse.tokens);
    return authResponse;
  }

  // 로그인
  Future<AuthResponse> login(LoginRequest request) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(request.toJson()),
    );

    final authResponse = _handleResponse(response, AuthResponse.fromJson);
    await _saveTokens(authResponse.tokens);
    return authResponse;
  }

  // 프로필 조회
  Future<User> getProfile() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/auth/me'),
      headers: _authHeaders,
    );

    final Map<String, dynamic> data = json.decode(response.body);
    if (response.statusCode == 200) {
      return User.fromJson(data['user']);
    } else {
      final apiError = ApiError.fromJson(data);
      throw ApiException(apiError.error, response.statusCode);
    }
  }

  // 토큰 갱신
  Future<AuthTokens> refreshToken() async {
    if (_refreshToken == null) {
      throw ApiException('리프레시 토큰이 없습니다.');
    }

    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/refresh'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'refresh_token': _refreshToken}),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      final tokens = AuthTokens.fromJson(data['tokens']);
      await _saveTokens(tokens);
      return tokens;
    } else {
      await clearTokens(); // 리프레시 실패시 토큰 삭제
      final Map<String, dynamic> errorData = json.decode(response.body);
      final apiError = ApiError.fromJson(errorData);
      throw ApiException(apiError.error, response.statusCode);
    }
  }

  // 로그아웃
  Future<void> logout() async {
    await http.post(
      Uri.parse('$baseUrl/api/auth/logout'),
      headers: _authHeaders,
    );
    await clearTokens();
  }

  // 현재 날씨 조회
  Future<WeatherData> getCurrentWeather(WeatherRequest request) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/weather/current'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(request.toJson()),
    );

    final weatherResponse = _handleResponse(response, WeatherResponse.fromJson);
    final currentWeather = weatherResponse.currentWeather;
    if (currentWeather != null) {
      return currentWeather;
    } else {
      throw ApiException('날씨 데이터를 가져올 수 없습니다.');
    }
  }

  // 날씨 예보 조회
  Future<List<WeatherData>> getForecastWeather(WeatherRequest request) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/weather/forecast'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(request.toJson()),
    );

    final weatherResponse = _handleResponse(response, WeatherResponse.fromJson);
    return weatherResponse.forecastList;
  }

  // 날씨 히스토리 조회
  Future<WeatherHistoryResponse> getWeatherHistory({
    String? locationName,
    String? apiType,
    int? limit,
  }) async {
    final queryParams = <String, String>{};
    if (locationName != null) queryParams['location_name'] = locationName;
    if (apiType != null) queryParams['api_type'] = apiType;
    if (limit != null) queryParams['limit'] = limit.toString();

    final uri = Uri.parse('$baseUrl/api/weather').replace(queryParameters: queryParams);
    final response = await http.get(uri);

    return _handleResponse(response, WeatherHistoryResponse.fromJson);
  }

  // 로그인 상태 확인
  bool get isLoggedIn => _accessToken != null;

  // FCM 토큰 등록
  Future<void> registerFCMToken(String token, Map<String, dynamic> deviceInfo) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/fcm/register'),
      headers: _authHeaders,
      body: json.encode({
        'token': token,
        'device_info': deviceInfo,
        'subscribe_topics': ['weather_alerts'], // 기본 주제 구독
      }),
    );

    if (response.statusCode != 200) {
      final Map<String, dynamic> errorData = json.decode(response.body);
      final apiError = ApiError.fromJson(errorData);
      throw ApiException(apiError.error, response.statusCode);
    }
  }

  // FCM 테스트 알림 전송
  Future<void> sendTestFCMNotification() async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/fcm/test'),
      headers: _authHeaders,
    );

    if (response.statusCode != 200) {
      final Map<String, dynamic> errorData = json.decode(response.body);
      final apiError = ApiError.fromJson(errorData);
      throw ApiException(apiError.error, response.statusCode);
    }
  }

  // ===== 관리자 전용 API =====

  // 전체 사용자 목록 조회 (관리자)
  Future<List<User>> getAllUsers() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/users'),
      headers: _authHeaders,
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => User.fromJson(json)).toList();
    } else {
      final Map<String, dynamic> errorData = json.decode(response.body);
      final apiError = ApiError.fromJson(errorData);
      throw ApiException(apiError.error, response.statusCode);
    }
  }

  // 관리자용 FCM 브로드캐스트 전송
  Future<void> sendAdminFCMBroadcast({
    required String title,
    required String body,
    String? topic,
    List<int>? userIds,
    Map<String, dynamic>? data,
  }) async {
    final requestBody = <String, dynamic>{
      'title': title,
      'body': body,
    };

    if (topic != null) {
      requestBody['topic'] = topic;
    }
    if (userIds != null && userIds.isNotEmpty) {
      requestBody['user_ids'] = userIds;
    }
    if (data != null) {
      requestBody['data'] = data;
    }

    final response = await http.post(
      Uri.parse('$baseUrl/api/admin/fcm/send'),
      headers: _authHeaders,
      body: json.encode(requestBody),
    );

    if (response.statusCode != 200) {
      final Map<String, dynamic> errorData = json.decode(response.body);
      final apiError = ApiError.fromJson(errorData);
      throw ApiException(apiError.error, response.statusCode);
    }
  }

  // 사용자 생성 (관리자)
  Future<User> createUser({
    required String name,
    required String email,
    required String password,
    String? phone,
    String? location,
    String role = 'user',
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/admin/users'),
      headers: _authHeaders,
      body: json.encode({
        'name': name,
        'email': email,
        'password': password,
        'phone': phone,
        'location': location,
        'role': role,
      }),
    );

    if (response.statusCode == 201) {
      final Map<String, dynamic> data = json.decode(response.body);
      return User.fromJson(data['user']);
    } else {
      final Map<String, dynamic> errorData = json.decode(response.body);
      final apiError = ApiError.fromJson(errorData);
      throw ApiException(apiError.error, response.statusCode);
    }
  }

  // 토큰 자동 갱신을 포함한 인증된 요청
  Future<http.Response> _authenticatedRequest(
    Future<http.Response> Function() request,
  ) async {
    var response = await request();
    
    // 토큰 만료시 자동 갱신 시도
    if (response.statusCode == 401 && _refreshToken != null) {
      try {
        await refreshToken();
        response = await request(); // 새 토큰으로 재시도
      } catch (e) {
        // 갱신 실패시 로그아웃 처리
        await clearTokens();
        rethrow;
      }
    }
    
    return response;
  }
}