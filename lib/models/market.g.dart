// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'market.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Market _$MarketFromJson(Map<String, dynamic> json) => Market(
  id: (json['id'] as num).toInt(),
  name: json['name'] as String,
  location: json['location'] as String,
  latitude: (json['latitude'] as num?)?.toDouble(),
  longitude: (json['longitude'] as num?)?.toDouble(),
  nx: (json['nx'] as num?)?.toInt(),
  ny: (json['ny'] as num?)?.toInt(),
  category: json['category'] as String?,
  createdAt: json['created_at'] as String?,
  updatedAt: json['updated_at'] as String?,
  isActive: json['is_active'] as bool,
);

Map<String, dynamic> _$MarketToJson(Market instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'location': instance.location,
  'latitude': instance.latitude,
  'longitude': instance.longitude,
  'nx': instance.nx,
  'ny': instance.ny,
  'category': instance.category,
  'created_at': instance.createdAt,
  'updated_at': instance.updatedAt,
  'is_active': instance.isActive,
};

UserMarketInterest _$UserMarketInterestFromJson(Map<String, dynamic> json) =>
    UserMarketInterest(
      id: (json['id'] as num).toInt(),
      userId: (json['user_id'] as num).toInt(),
      marketId: (json['market_id'] as num).toInt(),
      marketName: json['market_name'] as String?,
      marketLocation: json['market_location'] as String?,
      marketCoordinates: json['market_coordinates'] == null
          ? null
          : MarketCoordinates.fromJson(
              json['market_coordinates'] as Map<String, dynamic>,
            ),
      createdAt: json['created_at'] as String?,
      isActive: json['is_active'] as bool,
      notificationEnabled: json['notification_enabled'] as bool,
    );

Map<String, dynamic> _$UserMarketInterestToJson(UserMarketInterest instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'market_id': instance.marketId,
      'market_name': instance.marketName,
      'market_location': instance.marketLocation,
      'market_coordinates': instance.marketCoordinates,
      'created_at': instance.createdAt,
      'is_active': instance.isActive,
      'notification_enabled': instance.notificationEnabled,
    };

MarketCoordinates _$MarketCoordinatesFromJson(Map<String, dynamic> json) =>
    MarketCoordinates(
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      nx: (json['nx'] as num?)?.toInt(),
      ny: (json['ny'] as num?)?.toInt(),
    );

Map<String, dynamic> _$MarketCoordinatesToJson(MarketCoordinates instance) =>
    <String, dynamic>{
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'nx': instance.nx,
      'ny': instance.ny,
    };
