// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'alert_conditions.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AlertConditions _$AlertConditionsFromJson(Map<String, dynamic> json) =>
    AlertConditions(
      enabled: json['enabled'] as bool,
      rainProbability: (json['rain_probability'] as num?)?.toInt(),
      highTemp: (json['high_temp'] as num?)?.toInt(),
      lowTemp: (json['low_temp'] as num?)?.toInt(),
      windSpeed: (json['wind_speed'] as num?)?.toInt(),
      snowEnabled: json['snow_enabled'] as bool,
      rainEnabled: json['rain_enabled'] as bool,
      tempEnabled: json['temp_enabled'] as bool,
      windEnabled: json['wind_enabled'] as bool,
    );

Map<String, dynamic> _$AlertConditionsToJson(AlertConditions instance) =>
    <String, dynamic>{
      'enabled': instance.enabled,
      'rain_probability': instance.rainProbability,
      'high_temp': instance.highTemp,
      'low_temp': instance.lowTemp,
      'wind_speed': instance.windSpeed,
      'snow_enabled': instance.snowEnabled,
      'rain_enabled': instance.rainEnabled,
      'temp_enabled': instance.tempEnabled,
      'wind_enabled': instance.windEnabled,
    };

MarketAlertConditionsResponse _$MarketAlertConditionsResponseFromJson(
  Map<String, dynamic> json,
) => MarketAlertConditionsResponse(
  status: json['status'] as String,
  marketId: (json['market_id'] as num).toInt(),
  marketName: json['market_name'] as String,
  alertConditions: AlertConditions.fromJson(
    json['alert_conditions'] as Map<String, dynamic>,
  ),
);

Map<String, dynamic> _$MarketAlertConditionsResponseToJson(
  MarketAlertConditionsResponse instance,
) => <String, dynamic>{
  'status': instance.status,
  'market_id': instance.marketId,
  'market_name': instance.marketName,
  'alert_conditions': instance.alertConditions,
};
