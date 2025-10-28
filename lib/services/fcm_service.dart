import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io';
import 'api_service.dart';

class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final ApiService _apiService = ApiService();
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  // FCM 초기화
  Future<void> initialize() async {
    try {
      print('🔥 FCM 초기화 시작 (${Platform.isIOS ? 'iOS' : 'Android'})');
      
      // 로컬 알림 초기화
      await _initializeLocalNotifications();
      
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

      print('📱 FCM 권한 상태: ${settings.authorizationStatus}');
      print('📱 알림 설정 - Alert: ${settings.alert}, Badge: ${settings.badge}, Sound: ${settings.sound}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('✅ FCM 권한 허용됨');
        
        // iOS에서 APNS 토큰 등록 대기
        if (Platform.isIOS) {
          print('🍎 iOS APNS 토큰 등록 대기 중...');
          await _waitForAPNSToken();
        }
        
        // FCM 토큰 획득 (APNS 등록 후)
        await _getFCMToken();
        
        // 토큰 갱신 리스너
        _firebaseMessaging.onTokenRefresh.listen((newToken) {
          print('🔄 FCM 토큰 갱신: ${newToken?.substring(0, 50)}...');
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
            print('📬 앱 시작 시 메시지 있음: ${message.messageId}');
            _handleBackgroundMessageClick(message);
          }
        });
        
        print('🎯 FCM 초기화 완료');
        
      } else if (settings.authorizationStatus == AuthorizationStatus.denied) {
        print('❌ FCM 권한 거부됨 - 설정에서 알림을 허용해주세요');
      } else {
        print('⚠️ FCM 권한 상태: ${settings.authorizationStatus}');
      }
    } catch (e) {
      print('💥 FCM 초기화 오류: $e');
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
        print('🍎 APNS 토큰 대기 중... (${attempts + 1}/20)');
        await Future.delayed(const Duration(milliseconds: 500));
        apnsToken = await _firebaseMessaging.getAPNSToken();
        attempts++;
      }
      
      if (apnsToken != null) {
        print('✅ APNS 토큰 획득 성공: ${apnsToken.substring(0, 20)}...');
      } else {
        print('⚠️ APNS 토큰 획득 실패 - AppDelegate.swift 설정을 확인해주세요');
        print('💡 해결 방법: iOS Simulator에서는 APNS가 작동하지 않습니다. 실제 기기를 사용해주세요.');
      }
    } catch (e) {
      print('💥 APNS 토큰 확인 중 오류: $e');
    }
  }

  // FCM 토큰 획득
  Future<void> _getFCMToken() async {
    try {
      // iOS에서는 APNS 토큰이 있는지 다시 한 번 확인
      if (Platform.isIOS) {
        String? apnsToken = await _firebaseMessaging.getAPNSToken();
        if (apnsToken == null) {
          print('⚠️ APNS 토큰이 아직 없음 - FCM 토큰 요청을 잠시 지연');
          await Future.delayed(const Duration(seconds: 2));
        } else {
          print('✅ APNS 토큰 확인됨 - FCM 토큰 요청 진행');
        }
      }
      
      _fcmToken = await _firebaseMessaging.getToken();
      
      if (_fcmToken != null) {
        print('🎯 FCM 토큰 획득 성공: ${_fcmToken!.substring(0, 50)}...');
        await _registerTokenToServer();
      } else {
        print('❌ FCM 토큰 획득 실패');
      }
    } catch (e) {
      print('💥 FCM 토큰 획득 오류: $e');
      // iOS APNS 토큰 오류인 경우 재시도
      if (Platform.isIOS && e.toString().contains('APNS token')) {
        print('🔄 APNS 토큰 오류 감지 - 5초 후 재시도');
        await Future.delayed(const Duration(seconds: 5));
        try {
          _fcmToken = await _firebaseMessaging.getToken();
          if (_fcmToken != null) {
            print('✅ FCM 토큰 재시도 성공: ${_fcmToken!.substring(0, 50)}...');
            await _registerTokenToServer();
          }
        } catch (retryError) {
          print('💥 FCM 토큰 재시도 실패: $retryError');
        }
      }
    }
  }

  // 서버에 FCM 토큰 등록
  Future<void> _registerTokenToServer() async {
    if (_fcmToken == null) {
      print('❌ FCM 토큰이 없어서 서버 등록을 건너뜁니다');
      return;
    }
    
    if (!_apiService.isLoggedIn) {
      print('❌ 로그인되지 않아서 FCM 토큰 등록을 건너뜁니다');
      return;
    }
    
    try {
      final deviceInfo = {
        'platform': Platform.isIOS ? 'ios' : 'android',
        'timestamp': DateTime.now().toIso8601String(),
      };

      print('🔄 FCM 토큰 서버 등록 시작 - 토큰: ${_fcmToken!.substring(0, 50)}...');
      await _apiService.registerFCMToken(_fcmToken!, deviceInfo);
      print('✅ FCM 토큰 서버 등록 성공');
    } catch (e) {
      print('💥 FCM 토큰 서버 등록 실패: $e');
      // 등록 실패해도 앱 동작은 계속
    }
  }

  // 로그인 후 FCM 토큰 등록 (수동 호출용)
  Future<void> registerTokenAfterLogin() async {
    print('🔄 로그인 후 FCM 토큰 등록 프로세스 시작');
    
    if (_fcmToken != null) {
      print('✅ 기존 FCM 토큰 있음 - 서버 등록 시도');
      await _registerTokenToServer();
    } else {
      print('⚠️ FCM 토큰 없음 - 새로 생성 후 등록');
      await _getFCMToken();
    }
    
    // 등록 후 최종 상태 확인
    if (_fcmToken != null) {
      print('✅ FCM 토큰 등록 프로세스 완료 - 토큰: ${_fcmToken!.substring(0, 50)}...');
    } else {
      print('❌ FCM 토큰 등록 프로세스 실패 - 토큰이 여전히 없음');
    }
  }

  // 로컬 알림 초기화
  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );
    
    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );
    
    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
  }

  // 알림 탭 처리
  void _onNotificationTapped(NotificationResponse notificationResponse) {
    print('알림 탭됨: ${notificationResponse.payload}');
    // TODO: 특정 화면으로 이동하거나 액션 수행
  }

  // 포그라운드 메시지 처리
  void _handleForegroundMessage(RemoteMessage message) {
    print('📨 포그라운드 FCM 메시지 수신:');
    print('📬 메시지 ID: ${message.messageId}');
    print('📰 제목: ${message.notification?.title}');
    print('📝 내용: ${message.notification?.body}');
    print('📦 데이터: ${message.data}');
    print('🏷️ From: ${message.from}');
    print('⏰ 전송 시간: ${message.sentTime}');
    
    // 포그라운드에서 로컬 알림 표시
    _showLocalNotification(message);
  }

  // 로컬 알림 표시
  Future<void> _showLocalNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'weather_alerts',
      'Weather Alerts',
      channelDescription: '날씨 알림',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: false,
    );
    
    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails();
    
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );
    
    await _localNotifications.show(
      message.hashCode,
      message.notification?.title ?? '날씨 알림',
      message.notification?.body ?? '새로운 날씨 정보가 있습니다',
      platformChannelSpecifics,
      payload: message.data.toString(),
    );
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

  // iOS 디버깅용 - FCM 상태 확인
  Future<Map<String, dynamic>> getIOSFCMStatus() async {
    if (!Platform.isIOS) {
      return {'platform': 'android', 'message': 'Android 환경'};
    }

    try {
      print('🔍 iOS FCM 상태 진단 시작...');
      
      final settings = await _firebaseMessaging.getNotificationSettings();
      final apnsToken = await _firebaseMessaging.getAPNSToken();
      final fcmToken = await _firebaseMessaging.getToken();

      // 추가 진단 정보
      final isSimulator = await _isIOSSimulator();
      final bundleId = await _getBundleIdentifier();
      
      print('📱 기기 타입: ${isSimulator ? "시뮬레이터" : "실기기"}');
      print('📦 Bundle ID: $bundleId');
      print('🔐 권한 상태: ${settings.authorizationStatus}');
      print('🍎 APNS 토큰: ${apnsToken != null ? "있음" : "없음"}');
      print('🔥 FCM 토큰: ${fcmToken != null ? "있음" : "없음"}');

      return {
        'platform': 'ios',
        'is_simulator': isSimulator,
        'bundle_id': bundleId,
        'authorization_status': settings.authorizationStatus.toString(),
        'authorization_status_raw': settings.authorizationStatus.name,
        'alert_setting': settings.alert.toString(),
        'badge_setting': settings.badge.toString(),
        'sound_setting': settings.sound.toString(),
        'critical_alert_setting': settings.criticalAlert.toString(),
        'has_apns_token': apnsToken != null,
        'apns_token_preview': apnsToken?.substring(0, 20),
        'apns_token_length': apnsToken?.length,
        'has_fcm_token': fcmToken != null,
        'fcm_token_preview': fcmToken?.substring(0, 50),
        'fcm_token_length': fcmToken?.length,
        'current_fcm_token': _fcmToken,
        'firebase_app_check': await _checkFirebaseConnection(),
      };
    } catch (e) {
      print('💥 iOS FCM 상태 확인 오류: $e');
      return {
        'platform': 'ios',
        'error': e.toString(),
        'error_type': e.runtimeType.toString(),
      };
    }
  }

  // iOS 시뮬레이터 여부 확인
  Future<bool> _isIOSSimulator() async {
    try {
      // iOS에서 시뮬레이터인지 확인하는 간단한 방법
      // 실제로는 더 정확한 방법이 있지만, APNS 토큰 유무로도 판단 가능
      final apnsToken = await _firebaseMessaging.getAPNSToken();
      return apnsToken == null;
    } catch (e) {
      return true; // 오류 시 시뮬레이터로 가정
    }
  }

  // Bundle Identifier 확인
  Future<String> _getBundleIdentifier() async {
    try {
      // Flutter에서 Bundle ID를 직접 가져오는 방법은 제한적
      // 일반적으로 플랫폼 채널을 사용해야 하지만, 여기서는 간단히 처리
      return 'com.example.mwn'; // 실제 Bundle ID로 교체 필요
    } catch (e) {
      return 'unknown';
    }
  }

  // Firebase 연결 상태 확인
  Future<String> _checkFirebaseConnection() async {
    try {
      // Firebase App이 제대로 초기화되었는지 확인
      final app = Firebase.app();
      return 'connected (${app.name})';
    } catch (e) {
      return 'error: $e';
    }
  }

  // iOS 알림 설정 페이지로 이동하는 도우미 메서드
  void openIOSNotificationSettings() {
    if (Platform.isIOS) {
      print('💡 iOS 알림 설정을 확인하려면:');
      print('   설정 > 알림 > MWN > 알림 허용을 ON으로 설정하세요');
      print('   또한 포그라운드에서 알림을 보려면 "배너" 또는 "알림"을 활성화해야 합니다');
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