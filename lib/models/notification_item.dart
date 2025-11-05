import 'package:json_annotation/json_annotation.dart';

part 'notification_item.g.dart';

@JsonSerializable()
class NotificationItem {
  final String id;
  final String title;
  final String body;
  @JsonKey(name: 'received_at')
  final String receivedAt;
  final Map<String, dynamic>? data;

  NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.receivedAt,
    this.data,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) =>
      _$NotificationItemFromJson(json);
  Map<String, dynamic> toJson() => _$NotificationItemToJson(this);

  // DateTime으로 변환하는 헬퍼 메서드
  DateTime get receivedAtDateTime => DateTime.parse(receivedAt);

  // 시간 표시 형식 (예: "2분 전", "3시간 전")
  String getTimeAgo() {
    final now = DateTime.now();
    final difference = now.difference(receivedAtDateTime);

    if (difference.inSeconds < 60) {
      return '방금 전';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}분 전';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}시간 전';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}일 전';
    } else {
      // 7일 이상이면 날짜 표시
      return '${receivedAtDateTime.year}-${receivedAtDateTime.month.toString().padLeft(2, '0')}-${receivedAtDateTime.day.toString().padLeft(2, '0')}';
    }
  }
}
