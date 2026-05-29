import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user.dart';
import '../models/weather.dart';
import '../models/api_error.dart';
import '../models/market.dart';
import '../models/alert_conditions.dart';

class ApiService {
  // 빌드 시 `--dart-define=API_BASE_URL=http://...` 로 주입한다.
  // 미지정 시 운영 서버 IP 를 기본값으로 사용한다.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://203.250.33.77',
  );
  
  // 싱글톤 패턴
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // 토큰은 OS 키스토어 기반 보안 저장소에 보관한다.
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  String? _accessToken;
  String? _refreshToken;

  // 현재 액세스 토큰 (헤더를 직접 구성하는 화면에서 사용)
  String? get accessToken => _accessToken;

  // 토큰 저장
  Future<void> _saveTokens(AuthTokens tokens) async {
    _accessToken = tokens.accessToken;
    _refreshToken = tokens.refreshToken;
    await _secureStorage.write(key: _accessTokenKey, value: tokens.accessToken);
    await _secureStorage.write(key: _refreshTokenKey, value: tokens.refreshToken);
  }

  // 토큰 로드
  Future<void> loadTokens() async {
    _accessToken = await _secureStorage.read(key: _accessTokenKey);
    _refreshToken = await _secureStorage.read(key: _refreshTokenKey);

    // 구버전(SharedPreferences 평문 저장)에서 1회 마이그레이션
    if (_accessToken == null && _refreshToken == null) {
      final prefs = await SharedPreferences.getInstance();
      final legacyAccess = prefs.getString(_accessTokenKey);
      final legacyRefresh = prefs.getString(_refreshTokenKey);
      if (legacyAccess != null || legacyRefresh != null) {
        _accessToken = legacyAccess;
        _refreshToken = legacyRefresh;
        if (legacyAccess != null) {
          await _secureStorage.write(key: _accessTokenKey, value: legacyAccess);
        }
        if (legacyRefresh != null) {
          await _secureStorage.write(key: _refreshTokenKey, value: legacyRefresh);
        }
        await prefs.remove(_accessTokenKey);
        await prefs.remove(_refreshTokenKey);
      }
    }
  }

  // 토큰 삭제
  Future<void> clearTokens() async {
    _accessToken = null;
    _refreshToken = null;
    await _secureStorage.delete(key: _accessTokenKey);
    await _secureStorage.delete(key: _refreshTokenKey);
    // 구버전 평문 토큰이 남아 있을 경우 함께 정리
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
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
  
  // 타임아웃 설정
  static const Duration _timeout = Duration(seconds: 30);

  // HTTP 응답 처리
  T _handleResponse<T>(http.Response response, T Function(Map<String, dynamic>) fromJson) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) {
        throw ApiException('응답 본문이 비어있습니다.', response.statusCode);
      }
      try {
        // UTF-8 디코딩 처리 (한글 깨짐 방지)
        final String decodedBody = utf8.decode(response.bodyBytes);
        final Map<String, dynamic> data = json.decode(decodedBody);
        return fromJson(data);
      } catch (e) {
        print('❌ JSON 파싱 오류: $e');
        print('📄 응답 본문: ${utf8.decode(response.bodyBytes)}');
        rethrow;
      }
    } else {
      try {
        final String decodedBody = utf8.decode(response.bodyBytes);
        final Map<String, dynamic> errorData = json.decode(decodedBody);
        final apiError = ApiError.fromJson(errorData);
        throw ApiException(apiError.error, response.statusCode);
      } catch (e) {
        final String rawBody = utf8.decode(response.bodyBytes, allowMalformed: true);
        print('❌ API Error Parsing Failed: $e');
        print('📄 Raw Error Body: $rawBody');
        throw ApiException('오류 발생 (${response.statusCode}): $rawBody', response.statusCode);
      }
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
    ).timeout(_timeout);

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
    ).timeout(_timeout);

    final authResponse = _handleResponse(response, AuthResponse.fromJson);
    await _saveTokens(authResponse.tokens);
    return authResponse;
  }

  // 프로필 조회
  Future<User> getProfile() async {
    final response = await _authenticatedRequest(() => http.get(
      Uri.parse('$baseUrl/api/auth/me'),
      headers: _authHeaders,
    ));

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
    ).timeout(_timeout);

    final weatherResponse = _handleResponse(response, WeatherResponse.fromJson);
    final currentWeather = weatherResponse.currentWeather;
    if (currentWeather != null) {
      return currentWeather;
    } else {
      print('❌ 날씨 데이터 없음: ${weatherResponse.status}');
      throw ApiException('날씨 데이터를 가져올 수 없습니다.');
    }
  }

  // 날씨 예보 조회
  Future<List<WeatherData>> getForecastWeather(WeatherRequest request) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/weather/forecast'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(request.toJson()),
    ).timeout(_timeout);

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
    final response = await http.get(uri).timeout(_timeout);

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
    // 인증 상태 미리 확인
    print('🔒 현재 로그인 상태: ${isLoggedIn}');
    print('🔑 액세스 토큰 존재: ${_accessToken != null}');
    if (_accessToken != null) {
      print('🔑 토큰 길이: ${_accessToken!.length}');
      print('🔑 토큰 앞부분: ${_accessToken!.substring(0, 20)}...');
    }

    final requestBody = <String, dynamic>{
      'title': title,
      'body': body,
    };

    // 전체 전송인지, 특정 타겟 전송인지 구분
    if (topic != null && topic.isNotEmpty) {
      requestBody['topic'] = topic;
    } else if (userIds != null && userIds.isNotEmpty) {
      requestBody['user_ids'] = userIds;
    } else {
      // 전체 전송인 경우 명시적으로 플래그 설정
      requestBody['broadcast_all'] = true;
    }
    
    if (data != null) {
      requestBody['data'] = data;
    }

    print('FCM 브로드캐스트 요청: ${json.encode(requestBody)}');
    print('🔑 요청 헤더: ${_authHeaders}');

    final response = await http.post(
      Uri.parse('$baseUrl/api/admin/fcm/send'),
      headers: _authHeaders,
      body: json.encode(requestBody),
    );

    print('FCM 브로드캐스트 응답: ${response.statusCode} - ${response.body}');

    // 401 오류인 경우 토큰 갱신 시도
    if (response.statusCode == 401 && _refreshToken != null) {
      print('🔄 401 오류 감지 - 토큰 갱신 시도');
      try {
        await refreshToken();
        print('✅ 토큰 갱신 성공 - 재시도');
        
        // 갱신된 토큰으로 재시도
        final retryResponse = await http.post(
          Uri.parse('$baseUrl/api/admin/fcm/send'),
          headers: _authHeaders,
          body: json.encode(requestBody),
        );
        
        print('FCM 브로드캐스트 재시도 응답: ${retryResponse.statusCode} - ${retryResponse.body}');
        
        if (retryResponse.statusCode != 200) {
          final Map<String, dynamic> errorData = json.decode(retryResponse.body);
          final apiError = ApiError.fromJson(errorData);
          throw ApiException(apiError.error, retryResponse.statusCode);
        }
        return; // 성공하면 여기서 종료
      } catch (refreshError) {
        print('💥 토큰 갱신 실패: $refreshError');
      }
    }

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

  // ===== 시장 관련 API =====

  // 전체 시장 목록 조회
  Future<List<Market>> getMarkets({int page = 1, int perPage = 100, bool? isActive}) async {
    final queryParams = {
      'page': page.toString(),
      'per_page': perPage.toString(),
    };

    if (isActive != null) {
      queryParams['is_active'] = isActive.toString();
    }

    final uri = Uri.parse('$baseUrl/api/markets').replace(
      queryParameters: queryParams,
    );

    final response = await http.get(uri, headers: _authHeaders).timeout(_timeout);

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = json.decode(response.body);
      final List<dynamic> markets = responseData['data'];
      return markets.map((json) => Market.fromJson(json)).toList();
    } else {
      final Map<String, dynamic> errorData = json.decode(response.body);
      final apiError = ApiError.fromJson(errorData);
      throw ApiException(apiError.error, response.statusCode);
    }
  }

  // 시장 검색
  Future<List<Market>> searchMarkets(String query, {int limit = 20}) async {
    final uri = Uri.parse('$baseUrl/api/markets/search').replace(
      queryParameters: {
        'q': query,
        'limit': limit.toString(),
      },
    );

    final response = await http.get(uri).timeout(_timeout);

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      final List<dynamic> markets = data['markets'];
      return markets.map((json) => Market.fromJson(json)).toList();
    } else {
      final Map<String, dynamic> errorData = json.decode(response.body);
      final apiError = ApiError.fromJson(errorData);
      throw ApiException(apiError.error, response.statusCode);
    }
  }

  // 관심 시장 목록 조회
  Future<List<UserMarketInterest>> getWatchlist() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/watchlist'),
      headers: _authHeaders,
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      final List<dynamic> watchlist = data['watchlist'];
      return watchlist.map((json) => UserMarketInterest.fromJson(json)).toList();
    } else {
      final Map<String, dynamic> errorData = json.decode(response.body);
      final apiError = ApiError.fromJson(errorData);
      throw ApiException(apiError.error, response.statusCode);
    }
  }

  // 시장을 관심 목록에 추가
  Future<UserMarketInterest> addToWatchlist(int marketId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/watchlist'),
      headers: _authHeaders,
      body: json.encode({'market_id': marketId}),
    );

    if (response.statusCode == 201) {
      final Map<String, dynamic> data = json.decode(response.body);
      return UserMarketInterest.fromJson(data['interest']);
    } else {
      final Map<String, dynamic> errorData = json.decode(response.body);
      final apiError = ApiError.fromJson(errorData);
      throw ApiException(apiError.error, response.statusCode);
    }
  }

  // 시장을 관심 목록에서 제거
  Future<void> removeFromWatchlist(int marketId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/api/watchlist/$marketId'),
      headers: _authHeaders,
    );

    if (response.statusCode != 200) {
      final Map<String, dynamic> errorData = json.decode(response.body);
      final apiError = ApiError.fromJson(errorData);
      throw ApiException(apiError.error, response.statusCode);
    }
  }

  // 계정 삭제
  Future<void> deleteAccount() async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/delete'),
      headers: _authHeaders,
    );

    if (response.statusCode != 200) {
      print('⛔ 계정 삭제 실패 응답: ${response.statusCode}');
      print('응답 내용: ${response.body}');
      final Map<String, dynamic> errorData = json.decode(response.body);
      final apiError = ApiError.fromJson(errorData);
      throw ApiException(apiError.error, response.statusCode);
    }

    await clearTokens();
  }

  // 비밀번호 확인
  Future<bool> verifyPassword(String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/verify-password'),
      headers: _authHeaders,
      body: json.encode({'password': password}),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      return data['valid'] ?? false;
    } else if (response.statusCode == 401) {
      return false;
    } else {
      final Map<String, dynamic> errorData = json.decode(response.body);
      final apiError = ApiError.fromJson(errorData);
      throw ApiException(apiError.error, response.statusCode);
    }
  }

  // 프로필 업데이트
  Future<User> updateProfile({
    String? name,
    String? email,
    String? password,
    String? phone,
    String? location,
  }) async {
    final Map<String, dynamic> requestBody = {};
    
    if (name != null) requestBody['name'] = name;
    if (email != null) requestBody['email'] = email;
    if (password != null) requestBody['password'] = password;
    if (phone != null) requestBody['phone'] = phone;
    if (location != null) requestBody['location'] = location;

    final response = await http.put(
      Uri.parse('$baseUrl/api/auth/profile'),
      headers: _authHeaders,
      body: json.encode(requestBody),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      return User.fromJson(data['user']);
    } else {
      final Map<String, dynamic> errorData = json.decode(response.body);
      final apiError = ApiError.fromJson(errorData);
      throw ApiException(apiError.error, response.statusCode);
    }
  }

  // ===== 알림 조건 관리 API =====

  // 시장의 알림 조건 조회
  Future<MarketAlertConditionsResponse> getMarketAlertConditions(int marketId) async {
    final url = '$baseUrl/api/markets/$marketId/alert-conditions';
    print('🌐 알림 조건 조회 URL: $url');
    print('🔑 헤더: $_authHeaders');

    final response = await http.get(
      Uri.parse(url),
      headers: _authHeaders,
    );

    print('📡 응답 코드: ${response.statusCode}');
    print('📄 응답 본문 (처음 200자): ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}');

    if (response.statusCode == 200) {
      try {
        final Map<String, dynamic> data = json.decode(response.body);
        return MarketAlertConditionsResponse.fromJson(data);
      } catch (e) {
        print('💥 JSON 파싱 오류: $e');
        print('📄 전체 응답: ${response.body}');
        throw Exception('JSON 파싱 실패: $e');
      }
    } else {
      print('❌ 오류 응답: ${response.body}');
      try {
        final Map<String, dynamic> errorData = json.decode(response.body);
        final apiError = ApiError.fromJson(errorData);
        throw ApiException(apiError.error, response.statusCode);
      } catch (e) {
        throw Exception('서버 오류 (${response.statusCode}): ${response.body.substring(0, 100)}');
      }
    }
  }

  // 시장의 알림 조건 업데이트 (관리자)
  Future<MarketAlertConditionsResponse> updateMarketAlertConditions(
    int marketId,
    Map<String, dynamic> conditions,
  ) async {
    print('🔄 알림 조건 업데이트 시작 - 시장 ID: $marketId');
    print('📝 업데이트 조건: ${json.encode(conditions)}');

    final response = await http.put(
      Uri.parse('$baseUrl/api/admin/markets/$marketId/alert-conditions'),
      headers: _authHeaders,
      body: json.encode(conditions),
    );

    print('📡 응답 코드: ${response.statusCode}');
    print('📄 응답 본문: ${response.body}');

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      return MarketAlertConditionsResponse.fromJson(data);
    } else {
      final Map<String, dynamic> errorData = json.decode(response.body);
      final apiError = ApiError.fromJson(errorData);
      throw ApiException(apiError.error, response.statusCode);
    }
  }

  // 여러 시장의 알림 조건 일괄 업데이트 (관리자)
  Future<void> bulkUpdateAlertConditions(
    List<int> marketIds,
    Map<String, dynamic> conditions,
  ) async {
    print('🔄 일괄 알림 조건 업데이트 시작');
    print('🏪 대상 시장 수: ${marketIds.length}');
    print('📝 업데이트 조건: ${json.encode(conditions)}');

    final requestBody = {
      'market_ids': marketIds,
      'conditions': conditions,
    };

    final response = await http.post(
      Uri.parse('$baseUrl/api/admin/markets/alert-conditions/bulk-update'),
      headers: _authHeaders,
      body: json.encode(requestBody),
    );

    print('📡 응답 코드: ${response.statusCode}');
    print('📄 응답 본문: ${response.body}');

    if (response.statusCode != 200) {
      final Map<String, dynamic> errorData = json.decode(response.body);
      final apiError = ApiError.fromJson(errorData);
      throw ApiException(apiError.error, response.statusCode);
    }
  }

  // 사용자에게 날씨 테스트 알림 전송 (관리자)
  Future<Map<String, dynamic>> sendWeatherTestAlert({
    required int userId,
    required int marketId,
    required String alertType, // rain, heat, cold, wind, snow
    bool ignoreDnd = false,
    String? customTitle,
    String? customBody,
  }) async {
    print('🔄 날씨 테스트 알림 전송 시작');
    print('👤 사용자 ID: $userId');
    print('🏪 시장 ID: $marketId');
    print('🌤️ 알림 타입: $alertType');

    final requestBody = {
      'user_id': userId,
      'market_id': marketId,
      'alert_type': alertType,
      'ignore_dnd': ignoreDnd,
    };

    if (customTitle != null) {
      requestBody['custom_title'] = customTitle;
    }
    if (customBody != null) {
      requestBody['custom_body'] = customBody;
    }

    final response = await http.post(
      Uri.parse('$baseUrl/api/admin/weather-alerts/test-to-user'),
      headers: _authHeaders,
      body: json.encode(requestBody),
    );

    print('📡 응답 코드: ${response.statusCode}');
    print('📄 응답 본문: ${response.body}');

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      return data;
    } else {
      final Map<String, dynamic> errorData = json.decode(response.body);
      if (errorData.containsKey('error')) {
        throw Exception(errorData['error']);
      }
      throw Exception('날씨 테스트 알림 전송 실패 (${response.statusCode})');
    }
  }

  // 신고 목록 조회 (관리자)
  Future<List<Map<String, dynamic>>> getReports() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/reports'),
      headers: _authHeaders,
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      final Map<String, dynamic> errorData = json.decode(response.body);
      final apiError = ApiError.fromJson(errorData);
      throw ApiException(apiError.error, response.statusCode);
    }
  }

  // 신고 접수
  Future<void> submitReport({
    required int marketId,
    required String reportType,
    required String description,
    required String imagePath, // 로컬 파일 경로
  }) async {
    // 1. MultipartRequest 생성
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/api/reports'),
    );

    // 2. 헤더 추가 (Authorization)
    if (_accessToken != null) {
      request.headers['Authorization'] = 'Bearer $_accessToken';
    }

    // 3. 텍스트 필드 추가
    request.fields['market_id'] = marketId.toString();
    request.fields['report_type'] = reportType;
    request.fields['description'] = description;

    // 4. 파일 추가
    if (imagePath.isNotEmpty) {
      request.files.add(await http.MultipartFile.fromPath(
        'image',
        imagePath,
        contentType: MediaType('image', 'jpeg'),
      ));

    }

    // 5. 전송
    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 201) {
      final Map<String, dynamic> errorData = json.decode(response.body);
      final apiError = ApiError.fromJson(errorData);
      throw ApiException(apiError.error, response.statusCode);
    }
  }

  // 토큰 자동 갱신을 포함한 인증된 요청
  // 알림 발송 이력 조회 (관리자/사용자). 401 시 토큰 자동 갱신.
  Future<Map<String, dynamic>> getAlertLogs({
    required bool isAdmin,
    int page = 1,
    int perPage = 20,
    int? marketId,
  }) async {
    final endpoint = isAdmin ? '/api/admin/logs/alerts' : '/api/user/logs/alerts';
    final params = <String, String>{'page': '$page', 'per_page': '$perPage'};
    if (marketId != null) params['market_id'] = '$marketId';
    final uri = Uri.parse('$baseUrl$endpoint').replace(queryParameters: params);

    final response =
        await _authenticatedRequest(() => http.get(uri, headers: _authHeaders));
    if (response.statusCode == 200) {
      return json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    }
    throw ApiException('알림 이력 조회 실패', response.statusCode);
  }

  Future<http.Response> _authenticatedRequest(
    Future<http.Response> Function() request,
  ) async {
    var response = await request().timeout(_timeout);

    // 토큰 만료시 자동 갱신 시도
    if (response.statusCode == 401 && _refreshToken != null) {
      try {
        await refreshToken();
        response = await request().timeout(_timeout); // 새 토큰으로 재시도
      } catch (e) {
        // 갱신 실패시 로그아웃 처리
        await clearTokens();
        rethrow;
      }
    }

    return response;
  }
}