import 'package:json_annotation/json_annotation.dart';

part 'alert_conditions.g.dart';

@JsonSerializable()
class AlertConditions {
  final bool enabled;
  @JsonKey(name: 'rain_probability')
  final int? rainProbability;
  @JsonKey(name: 'high_temp')
  final int? highTemp;
  @JsonKey(name: 'low_temp')
  final int? lowTemp;
  @JsonKey(name: 'wind_speed')
  final int? windSpeed;
  @JsonKey(name: 'snow_enabled')
  final bool snowEnabled;
  @JsonKey(name: 'rain_enabled')
  final bool rainEnabled;
  @JsonKey(name: 'temp_enabled')
  final bool tempEnabled;
  @JsonKey(name: 'wind_enabled')
  final bool windEnabled;

  AlertConditions({
    required this.enabled,
    this.rainProbability,
    this.highTemp,
    this.lowTemp,
    this.windSpeed,
    required this.snowEnabled,
    required this.rainEnabled,
    required this.tempEnabled,
    required this.windEnabled,
  });

  factory AlertConditions.fromJson(Map<String, dynamic> json) =>
      _$AlertConditionsFromJson(json);

  Map<String, dynamic> toJson() => _$AlertConditionsToJson(this);

  // 기본값 생성
  factory AlertConditions.defaultConditions() {
    return AlertConditions(
      enabled: true,
      rainProbability: 70,
      highTemp: 35,
      lowTemp: -10,
      windSpeed: 15,
      snowEnabled: true,
      rainEnabled: true,
      tempEnabled: true,
      windEnabled: true,
    );
  }

  // copyWith 메서드
  AlertConditions copyWith({
    bool? enabled,
    int? rainProbability,
    int? highTemp,
    int? lowTemp,
    int? windSpeed,
    bool? snowEnabled,
    bool? rainEnabled,
    bool? tempEnabled,
    bool? windEnabled,
  }) {
    return AlertConditions(
      enabled: enabled ?? this.enabled,
      rainProbability: rainProbability ?? this.rainProbability,
      highTemp: highTemp ?? this.highTemp,
      lowTemp: lowTemp ?? this.lowTemp,
      windSpeed: windSpeed ?? this.windSpeed,
      snowEnabled: snowEnabled ?? this.snowEnabled,
      rainEnabled: rainEnabled ?? this.rainEnabled,
      tempEnabled: tempEnabled ?? this.tempEnabled,
      windEnabled: windEnabled ?? this.windEnabled,
    );
  }
}

@JsonSerializable()
class MarketAlertConditionsResponse {
  final String status;
  @JsonKey(name: 'market_id')
  final int marketId;
  @JsonKey(name: 'market_name')
  final String marketName;
  @JsonKey(name: 'alert_conditions')
  final AlertConditions alertConditions;

  MarketAlertConditionsResponse({
    required this.status,
    required this.marketId,
    required this.marketName,
    required this.alertConditions,
  });

  factory MarketAlertConditionsResponse.fromJson(Map<String, dynamic> json) =>
      _$MarketAlertConditionsResponseFromJson(json);

  Map<String, dynamic> toJson() => _$MarketAlertConditionsResponseToJson(this);
}
