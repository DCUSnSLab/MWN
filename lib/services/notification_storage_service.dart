import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/notification_item.dart';

class NotificationStorageService {
  static const String _key = 'notifications_history';
  static const int _maxItems = 50; // 최대 50개 저장

  // 싱글톤 패턴
  static final NotificationStorageService _instance = NotificationStorageService._internal();
  factory NotificationStorageService() => _instance;
  NotificationStorageService._internal();

  // 알림 저장
  Future<void> saveNotification(NotificationItem item) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 기존 알림 가져오기
      List<NotificationItem> notifications = await getNotifications();

      // 새 알림 추가 (맨 앞에)
      notifications.insert(0, item);

      // 최대 개수 제한
      if (notifications.length > _maxItems) {
        notifications = notifications.take(_maxItems).toList();
      }

      // JSON으로 변환해서 저장
      final jsonList = notifications.map((n) => n.toJson()).toList();
      await prefs.setString(_key, json.encode(jsonList));

      print('✅ 알림 저장 완료: ${item.title}');
    } catch (e) {
      print('❌ 알림 저장 실패: $e');
    }
  }

  // 저장된 알림 가져오기
  Future<List<NotificationItem>> getNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_key);

      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }

      final List<dynamic> jsonList = json.decode(jsonString);
      return jsonList
          .map((json) => NotificationItem.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('❌ 알림 불러오기 실패: $e');
      return [];
    }
  }

  // 특정 알림 삭제
  Future<void> deleteNotification(String id) async {
    try {
      final notifications = await getNotifications();
      notifications.removeWhere((n) => n.id == id);

      final prefs = await SharedPreferences.getInstance();
      final jsonList = notifications.map((n) => n.toJson()).toList();
      await prefs.setString(_key, json.encode(jsonList));

      print('✅ 알림 삭제 완료: $id');
    } catch (e) {
      print('❌ 알림 삭제 실패: $e');
    }
  }

  // 모든 알림 삭제
  Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
      print('✅ 모든 알림 삭제 완료');
    } catch (e) {
      print('❌ 알림 전체 삭제 실패: $e');
    }
  }

  // 알림 개수 가져오기
  Future<int> getNotificationCount() async {
    final notifications = await getNotifications();
    return notifications.length;
  }

  // 읽지 않은 알림 개수 (추후 확장용)
  Future<int> getUnreadCount() async {
    // 현재는 전체 개수 반환, 추후 읽음/안읽음 필드 추가 시 구현
    return await getNotificationCount();
  }
}
