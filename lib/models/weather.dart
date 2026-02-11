import 'package:json_annotation/json_annotation.dart';

part 'weather.g.dart';

@JsonSerializable()
class WeatherData {
  final int? id;
  @JsonKey(name: 'base_date')
  final String? baseDate;
  @JsonKey(name: 'base_time')
  final String? baseTime;
  @JsonKey(name: 'fcst_date')
  final String? fcstDate;
  @JsonKey(name: 'fcst_time')
  final String? fcstTime;
  final int? nx;
  final int? ny;
  final double? temp;
  final double? humidity;
  @JsonKey(name: 'rain_1h')
  final double? rain1h;
  @JsonKey(name: 'wind_speed')
  final double? windSpeed;
  @JsonKey(name: 'wind_direction')
  final double? windDirection;
  final double? pop;
  final String? pty;
  final String? sky;
  final String? lightning;
  @JsonKey(name: 'api_type')
  final String? apiType;
  @JsonKey(name: 'location_name')
  final String? locationName;
  @JsonKey(name: 'created_at')
  final String? createdAt;

  WeatherData({
    this.id,
    this.baseDate,
    this.baseTime,
    this.fcstDate,
    this.fcstTime,
    this.nx,
    this.ny,
    this.temp,
    this.humidity,
    this.rain1h,
    this.windSpeed,
    this.windDirection,
    this.pop,
    this.pty,
    this.sky,
    this.lightning,
    this.apiType,
    this.locationName,
    this.createdAt,
  });

  factory WeatherData.fromJson(Map<String, dynamic> json) => _$WeatherDataFromJson(json);
  Map<String, dynamic> toJson() => _$WeatherDataToJson(this);

  // 날씨 상태 텍스트 변환
  String get skyCondition {
    switch (sky) {
      case '1':
        return '맑음';
      case '3':
        return '구름많음';
      case '4':
        return '흐림';
      default:
        return '알 수 없음';
    }
  }

  // 강수 형태 텍스트 변환
  String get precipitationType {
    switch (pty) {
      case '0':
        return '없음';
      case '1':
        return '비';
      case '2':
        return '비/눈';
      case '3':
        return '눈';
      case '4':
        return '소나기';
      default:
        return '알 수 없음';
    }
  }
}

@JsonSerializable()
class WeatherRequest {
  final int nx;
  final int ny;
  @JsonKey(name: 'location_name')
  final String? locationName;

  WeatherRequest({
    required this.nx,
    required this.ny,
    this.locationName,
  });

  factory WeatherRequest.fromJson(Map<String, dynamic> json) => _$WeatherRequestFromJson(json);
  Map<String, dynamic> toJson() => _$WeatherRequestToJson(this);
}

@JsonSerializable()
class WeatherResponse {
  final String status;
  final dynamic data; // WeatherData or List<WeatherData>

  WeatherResponse({
    required this.status,
    required this.data,
  });

  factory WeatherResponse.fromJson(Map<String, dynamic> json) => _$WeatherResponseFromJson(json);
  Map<String, dynamic> toJson() => _$WeatherResponseToJson(this);

  // 단일 날씨 데이터 가져오기
  WeatherData? get currentWeather {
    if (data is Map<String, dynamic>) {
      return WeatherData.fromJson(data as Map<String, dynamic>);
    }
    return null;
  }

  // 예보 데이터 리스트 가져오기
  List<WeatherData> get forecastList {
    if (data is List) {
      return (data as List)
          .map((item) => WeatherData.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return [];
  }
}

@JsonSerializable()
class WeatherHistoryResponse {
  final String status;
  final int count;
  final List<WeatherData> data;

  WeatherHistoryResponse({
    required this.status,
    required this.count,
    required this.data,
  });

  factory WeatherHistoryResponse.fromJson(Map<String, dynamic> json) => _$WeatherHistoryResponseFromJson(json);
  Map<String, dynamic> toJson() => _$WeatherHistoryResponseToJson(this);
}