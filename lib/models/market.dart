import 'package:json_annotation/json_annotation.dart';

part 'market.g.dart';

@JsonSerializable()
class Market {
  final int id;
  final String name;
  final String location;
  final double? latitude;
  final double? longitude;
  final int? nx;
  final int? ny;
  final String? category;
  @JsonKey(name: 'created_at')
  final String? createdAt;
  @JsonKey(name: 'updated_at')
  final String? updatedAt;
  @JsonKey(name: 'is_active')
  final bool isActive;

  Market({
    required this.id,
    required this.name,
    required this.location,
    this.latitude,
    this.longitude,
    this.nx,
    this.ny,
    this.category,
    this.createdAt,
    this.updatedAt,
    required this.isActive,
  });

  factory Market.fromJson(Map<String, dynamic> json) => _$MarketFromJson(json);
  Map<String, dynamic> toJson() => _$MarketToJson(this);

  // 좌표가 있는지 확인
  bool get hasCoordinates => latitude != null && longitude != null;

  // 격자 좌표가 있는지 확인  
  bool get hasGridCoordinates => nx != null && ny != null;
}

@JsonSerializable()
class UserMarketInterest {
  final int id;
  @JsonKey(name: 'user_id')
  final int userId;
  @JsonKey(name: 'market_id')
  final int marketId;
  @JsonKey(name: 'market_name')
  final String? marketName;
  @JsonKey(name: 'market_location')
  final String? marketLocation;
  @JsonKey(name: 'market_coordinates')
  final MarketCoordinates? marketCoordinates;
  @JsonKey(name: 'created_at')
  final String? createdAt;
  @JsonKey(name: 'is_active')
  final bool isActive;
  @JsonKey(name: 'notification_enabled')
  final bool notificationEnabled;

  UserMarketInterest({
    required this.id,
    required this.userId,
    required this.marketId,
    this.marketName,
    this.marketLocation,
    this.marketCoordinates,
    this.createdAt,
    required this.isActive,
    required this.notificationEnabled,
  });

  factory UserMarketInterest.fromJson(Map<String, dynamic> json) => _$UserMarketInterestFromJson(json);
  Map<String, dynamic> toJson() => _$UserMarketInterestToJson(this);
}

@JsonSerializable()
class MarketCoordinates {
  final double? latitude;
  final double? longitude;
  final int? nx;
  final int? ny;

  MarketCoordinates({
    this.latitude,
    this.longitude,
    this.nx,
    this.ny,
  });

  factory MarketCoordinates.fromJson(Map<String, dynamic> json) => _$MarketCoordinatesFromJson(json);
  Map<String, dynamic> toJson() => _$MarketCoordinatesToJson(this);

  // 좌표가 있는지 확인
  bool get hasCoordinates => latitude != null && longitude != null;

  // 격자 좌표가 있는지 확인
  bool get hasGridCoordinates => nx != null && ny != null;
}