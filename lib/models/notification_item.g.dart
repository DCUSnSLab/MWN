// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

NotificationItem _$NotificationItemFromJson(Map<String, dynamic> json) =>
    NotificationItem(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      receivedAt: json['received_at'] as String,
      data: json['data'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$NotificationItemToJson(NotificationItem instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'body': instance.body,
      'received_at': instance.receivedAt,
      'data': instance.data,
    };
