import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'api_service.dart';

class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final ApiService _apiService = ApiService();
  
  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  // FCM 초기화
  Future<void> initialize() async {
    try {
      // 알림 권한 요청
      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('FCM 권한 허용됨');
        
        // iOS에서 APNS 토큰 등록 대기
        if (Platform.isIOS) {
          print('iOS APNS 토큰 등록 대기 중...');
          await _waitForAPNSToken();
        }
        
        // FCM 토큰 획득 (APNS 등록 후)
        await _getFCMToken();
        
        // 토큰 갱신 리스너
        _firebaseMessaging.onTokenRefresh.listen((newToken) {
          print('FCM 토큰 갱신: $newToken');
          _fcmToken = newToken;
          _registerTokenToServer();
        });
        
        // 포그라운드 메시지 처리
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
        
        // 백그라운드 메시지 클릭 처리
        FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessageClick);
        
        // 앱이 종료된 상태에서 알림 클릭으로 앱이 시작된 경우
        FirebaseMessaging.instance.getInitialMessage().then((message) {
          if (message != null) {
            _handleBackgroundMessageClick(message);
          }
        });
        
      } else {
        print('FCM 권한 거부됨');
      }
    } catch (e) {
      print('FCM 초기화 오류: $e');
    }
  }

  // iOS APNS 토큰 등록 대기
  Future<void> _waitForAPNSToken() async {
    if (!Platform.isIOS) return;
    
    try {
      // APNS 토큰 가져오기 시도
      String? apnsToken = await _firebaseMessaging.getAPNSToken();
      
      // APNS 토큰이 없으면 최대 10초 대기
      int attempts = 0;
      while (apnsToken == null && attempts < 20) {
        print('APNS 토큰 대기 중... (${attempts + 1}/20)');
        await Future.delayed(const Duration(milliseconds: 500));
        apnsToken = await _firebaseMessaging.getAPNSToken();
        attempts++;
      }
      
      if (apnsToken != null) {
        print('APNS 토큰 획득 성공: ${apnsToken.substring(0, 20)}...');
      } else {
        print('APNS 토큰 획득 실패 - FCM 토큰 요청을 계속 진행합니다');
      }
    } catch (e) {
      print('APNS 토큰 확인 중 오류: $e');
    }
  }

  // FCM 토큰 획득
  Future<void> _getFCMToken() async {
    try {
      // iOS에서는 APNS 토큰이 있는지 다시 한 번 확인
      if (Platform.isIOS) {
        String? apnsToken = await _firebaseMessaging.getAPNSToken();
        if (apnsToken == null) {
          print('APNS 토큰이 아직 없음 - FCM 토큰 요청을 잠시 지연');
          await Future.delayed(const Duration(seconds: 2));
        }
      }
      
      _fcmToken = await _firebaseMessaging.getToken();
      print('FCM 토큰: $_fcmToken');
      
      if (_fcmToken != null) {
        await _registerTokenToServer();
      }
    } catch (e) {
      print('FCM 토큰 획득 오류: $e');
      // iOS APNS 토큰 오류인 경우 재시도
      if (Platform.isIOS && e.toString().contains('APNS token')) {
        print('APNS 토큰 오류 감지 - 5초 후 재시도');
        await Future.delayed(const Duration(seconds: 5));
        try {
          _fcmToken = await _firebaseMessaging.getToken();
          print('FCM 토큰 재시도 성공: $_fcmToken');
          if (_fcmToken != null) {
            await _registerTokenToServer();
          }
        } catch (retryError) {
          print('FCM 토큰 재시도 실패: $retryError');
        }
      }
    }
  }

  // 서버에 FCM 토큰 등록
  Future<void> _registerTokenToServer() async {
    if (_fcmToken == null || !_apiService.isLoggedIn) return;
    
    try {
      final deviceInfo = {
        'platform': Platform.isIOS ? 'ios' : 'android',
        'timestamp': DateTime.now().toIso8601String(),
      };

      await _apiService.registerFCMToken(_fcmToken!, deviceInfo);
      print('FCM 토큰 서버 등록 성공');
    } catch (e) {
      print('FCM 토큰 서버 등록 실패: $e');
    }
  }

  // 로그인 후 FCM 토큰 등록 (수동 호출용)
  Future<void> registerTokenAfterLogin() async {
    if (_fcmToken != null) {
      await _registerTokenToServer();
    } else {
      await _getFCMToken();
    }
  }

  // 포그라운드 메시지 처리
  void _handleForegroundMessage(RemoteMessage message) {
    print('포그라운드 FCM 메시지 수신:');
    print('제목: ${message.notification?.title}');
    print('내용: ${message.notification?.body}');
    print('데이터: ${message.data}');
    
    // TODO: 포그라운드에서 알림 표시 (선택사항)
    // 앱이 실행 중일 때 알림을 어떻게 처리할지 결정
  }

  // 백그라운드 메시지 클릭 처리
  void _handleBackgroundMessageClick(RemoteMessage message) {
    print('백그라운드 FCM 메시지 클릭:');
    print('제목: ${message.notification?.title}');
    print('내용: ${message.notification?.body}');
    print('데이터: ${message.data}');
    
    // TODO: 특정 화면으로 이동하거나 액션 수행
    // 예: 날씨 상세 화면으로 이동, 알림 목록 화면으로 이동 등
  }

  // 특정 주제 구독
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _firebaseMessaging.subscribeToTopic(topic);
      print('주제 구독 성공: $topic');
    } catch (e) {
      print('주제 구독 실패: $e');
    }
  }

  // 특정 주제 구독 해제
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic(topic);
      print('주제 구독 해제 성공: $topic');
    } catch (e) {
      print('주제 구독 해제 실패: $e');
    }
  }

  // FCM 테스트 알림 요청
  Future<bool> requestTestNotification() async {
    try {
      await _apiService.sendTestFCMNotification();
      return true;
    } catch (e) {
      print('테스트 알림 요청 실패: $e');
      return false;
    }
  }
}

// 백그라운드 메시지 핸들러 (top-level 함수여야 함)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('백그라운드 FCM 메시지 수신:');
  print('제목: ${message.notification?.title}');
  print('내용: ${message.notification?.body}');
  print('데이터: ${message.data}');
}