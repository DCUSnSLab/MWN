import 'package:flutter_test/flutter_test.dart';
import 'package:mwn/models/weather.dart';

void main() {
  WeatherData weather({String? sky, String? pty}) => WeatherData(
        sky: sky,
        pty: pty,
      );

  group('WeatherData.skyCondition', () {
    test('maps known KMA sky codes', () {
      expect(weather(sky: '1').skyCondition, '맑음');
      expect(weather(sky: '3').skyCondition, '구름많음');
      expect(weather(sky: '4').skyCondition, '흐림');
    });

    test('falls back to 알 수 없음 for unknown/absent codes', () {
      expect(weather(sky: '0').skyCondition, '알 수 없음');
      expect(weather(sky: null).skyCondition, '알 수 없음');
      expect(weather(sky: '99').skyCondition, '알 수 없음');
    });
  });

  group('WeatherData.precipitationType', () {
    test('maps known KMA precipitation codes', () {
      expect(weather(pty: '0').precipitationType, '없음');
      expect(weather(pty: '1').precipitationType, '비');
      expect(weather(pty: '2').precipitationType, '비/눈');
      expect(weather(pty: '3').precipitationType, '눈');
      expect(weather(pty: '4').precipitationType, '소나기');
    });

    test('falls back to 알 수 없음 for unknown/absent codes', () {
      expect(weather(pty: null).precipitationType, '알 수 없음');
      expect(weather(pty: '9').precipitationType, '알 수 없음');
    });
  });

  group('WeatherData.fromJson', () {
    test('reads snake_case API fields', () {
      final w = WeatherData.fromJson({
        'id': 10,
        'base_date': '20260530',
        'base_time': '0600',
        'nx': 92,
        'ny': 90,
        'temp': 26.4,
        'humidity': 42.0,
        'rain_1h': 0.0,
        'wind_speed': 3.6,
        'wind_direction': 180.0,
        'pop': 30.0,
        'pty': '0',
        'sky': '1',
        'api_type': 'current',
        'location_name': '경산공설시장',
        'created_at': '2026-05-30T06:10:00',
      });

      expect(w.temp, 26.4);
      expect(w.humidity, 42.0);
      expect(w.windSpeed, 3.6);
      expect(w.nx, 92);
      expect(w.skyCondition, '맑음');
      expect(w.precipitationType, '없음');
      expect(w.locationName, '경산공설시장');
    });
  });
}
