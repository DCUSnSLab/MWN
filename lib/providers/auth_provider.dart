import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/fcm_service.dart';

class AuthProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  FCMService? _fcmService;
  
  User? _currentUser;
  bool _isLoading = false;
  String? _error;

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _currentUser != null && _apiService.isLoggedIn;

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // 앱 시작시 토큰 로드 및 사용자 정보 확인
  Future<void> initializeAuth() async {
    _setLoading(true);
    try {
      await _apiService.loadTokens();
      if (_apiService.isLoggedIn) {
        _currentUser = await _apiService.getProfile();
      }
    } catch (e) {
      print('Auth initialization failed: $e');
      await _apiService.clearTokens();
    } finally {
      _setLoading(false);
    }
  }

  // 회원가입
  Future<bool> register({
    required String name,
    required String email,
    required String password,
    String? phone,
    String? location,
  }) async {
    _setLoading(true);
    _setError(null);

    try {
      final request = RegisterRequest(
        name: name,
        email: email,
        password: password,
        phone: phone,
        location: location,
      );

      final response = await _apiService.register(request);
      _currentUser = response.user;
      
      // 회원가입 성공 시 FCM 토큰 등록
      try {
        _fcmService ??= FCMService();
        await _fcmService!.registerTokenAfterLogin();
      } catch (e) {
        print('FCM 토큰 등록 실패: $e');
      }
      
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  // 로그인
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    print('🔑 로그인 시도: $email');
    _setLoading(true);
    _setError(null);

    try {
      final request = LoginRequest(
        email: email,
        password: password,
      );

      print('🔑 API 로그인 요청 중...');
      final response = await _apiService.login(request);
      print('✅ API 로그인 성공');
      
      _currentUser = response.user;
      print('✅ 현재 사용자 설정: ${_currentUser?.name}');
      
      // 로그인 성공 시 FCM 토큰 등록
      try {
        print('🔄 로그인 후 FCM 토큰 등록 시작');
        _fcmService ??= FCMService();
        await _fcmService!.registerTokenAfterLogin();
        print('✅ 로그인 후 FCM 토큰 등록 완료');
      } catch (e) {
        print('💥 로그인 후 FCM 토큰 등록 실패: $e');
      }
      
      _setLoading(false);
      notifyListeners(); // 명시적으로 알림
      print('✅ 로그인 완료 - isLoggedIn: $isLoggedIn');
      return true;
    } catch (e) {
      print('🚨 로그인 실패: $e');
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  // 로그아웃
  Future<void> logout() async {
    _setLoading(true);
    try {
      await _apiService.logout();
      
      // 저장된 자격 증명도 삭제
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('saved_email');
      await prefs.remove('saved_password');
      await prefs.setBool('auto_login', false);
      
    } catch (e) {
      print('Logout error: $e');
    } finally {
      _currentUser = null;
      _setLoading(false);
      notifyListeners(); // 명시적으로 알림
    }
  }

  // 프로필 새로고침
  Future<void> refreshProfile() async {
    if (!_apiService.isLoggedIn) return;

    try {
      _currentUser = await _apiService.getProfile();
      notifyListeners();
    } catch (e) {
      print('Profile refresh failed: $e');
      // 토큰이 만료된 경우 로그아웃 처리
      if (e.toString().contains('401')) {
        await logout();
      }
    }
  }

  // 계정 삭제
  Future<void> deleteAccount() async {
    _setLoading(true);
    _setError(null);

    try {
      await _apiService.deleteAccount();
      
      // 저장된 자격 증명 삭제
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('saved_email');
      await prefs.remove('saved_password');
      await prefs.setBool('auto_login', false);
      
      _currentUser = null;
      _setLoading(false);
      notifyListeners(); // 명시적으로 알림
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      rethrow;
    }
  }

  // 비밀번호 확인
  Future<bool> verifyPassword(String password) async {
    try {
      return await _apiService.verifyPassword(password);
    } catch (e) {
      print('비밀번호 확인 실패: $e');
      rethrow;
    }
  }

  // 프로필 업데이트
  Future<void> updateProfile({
    String? name,
    String? email,
    String? password,
    String? phone,
    String? location,
  }) async {
    _setLoading(true);
    _setError(null);

    try {
      final updatedUser = await _apiService.updateProfile(
        name: name,
        email: email,
        password: password,
        phone: phone,
        location: location,
      );
      
      _currentUser = updatedUser;
      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      rethrow;
    }
  }
}