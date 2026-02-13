// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'weather.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WeatherData _$WeatherDataFromJson(Map<String, dynamic> json) => WeatherData(
  id: (json['id'] as num?)?.toInt(),
  baseDate: json['base_date'] as String?,
  baseTime: json['base_time'] as String?,
  fcstDate: json['fcst_date'] as String?,
  fcstTime: json['fcst_time'] as String?,
  nx: (json['nx'] as num?)?.toInt(),
  ny: (json['ny'] as num?)?.toInt(),
  temp: (json['temp'] as num?)?.toDouble(),
  humidity: (json['humidity'] as num?)?.toDouble(),
  rain1h: (json['rain_1h'] as num?)?.toDouble(),
  windSpeed: (json['wind_speed'] as num?)?.toDouble(),
  windDirection: (json['wind_direction'] as num?)?.toDouble(),
  pop: (json['pop'] as num?)?.toDouble(),
  pty: json['pty']?.toString(),
  sky: json['sky']?.toString(),
  lightning: json['lightning']?.toString(),
  apiType: json['api_type']?.toString(),
  locationName: json['location_name']?.toString(),
  createdAt: json['created_at']?.toString(),
);

Map<String, dynamic> _$WeatherDataToJson(WeatherData instance) =>
    <String, dynamic>{
      'id': instance.id,
      'base_date': instance.baseDate,
      'base_time': instance.baseTime,
      'fcst_date': instance.fcstDate,
      'fcst_time': instance.fcstTime,
      'nx': instance.nx,
      'ny': instance.ny,
      'temp': instance.temp,
      'humidity': instance.humidity,
      'rain_1h': instance.rain1h,
      'wind_speed': instance.windSpeed,
      'wind_direction': instance.windDirection,
      'pop': instance.pop,
      'pty': instance.pty,
      'sky': instance.sky,
      'lightning': instance.lightning,
      'api_type': instance.apiType,
      'location_name': instance.locationName,
      'created_at': instance.createdAt,
    };

WeatherRequest _$WeatherRequestFromJson(Map<String, dynamic> json) =>
    WeatherRequest(
      nx: (json['nx'] as num).toInt(),
      ny: (json['ny'] as num).toInt(),
      locationName: json['location_name'] as String?,
    );

Map<String, dynamic> _$WeatherRequestToJson(WeatherRequest instance) =>
    <String, dynamic>{
      'nx': instance.nx,
      'ny': instance.ny,
      'location_name': instance.locationName,
    };

WeatherResponse _$WeatherResponseFromJson(Map<String, dynamic> json) =>
    WeatherResponse(status: json['status'] as String, data: json['data']);

Map<String, dynamic> _$WeatherResponseToJson(WeatherResponse instance) =>
    <String, dynamic>{'status': instance.status, 'data': instance.data};

WeatherHistoryResponse _$WeatherHistoryResponseFromJson(
  Map<String, dynamic> json,
) => WeatherHistoryResponse(
  status: json['status'] as String,
  count: (json['count'] as num).toInt(),
  data: (json['data'] as List<dynamic>)
      .map((e) => WeatherData.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$WeatherHistoryResponseToJson(
  WeatherHistoryResponse instance,
) => <String, dynamic>{
  'status': instance.status,
  'count': instance.count,
  'data': instance.data,
};
