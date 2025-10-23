import 'package:flutter/material.dart';
import '../models/market.dart';
import '../models/weather.dart';
import '../screens/market/market_search_screen.dart';

class MarketWeatherWidget extends StatelessWidget {
  final UserMarketInterest market;
  final WeatherData? weather;
  final VoidCallback? onRefresh;

  const MarketWeatherWidget({
    super.key,
    required this.market,
    this.weather,
    this.onRefresh,
  });

  String _getWeatherIcon(WeatherData weather) {
    // SKY 코드: 1(맑음), 3(구름많음), 4(흐림)
    // PTY 코드: 0(없음), 1(비), 2(비/눈), 3(눈), 4(소나기)
    
    if (weather.pty != null && weather.pty != "0") {
      switch (weather.pty) {
        case "1":
        case "4":
          return "🌧️"; // 비
        case "2":
          return "🌨️"; // 비/눈
        case "3":
          return "❄️"; // 눈
        default:
          return "🌧️";
      }
    }
    
    if (weather.sky != null) {
      switch (weather.sky) {
        case "1":
          return "☀️"; // 맑음
        case "3":
          return "⛅"; // 구름많음
        case "4":
          return "☁️"; // 흐림
        default:
          return "☀️";
      }
    }
    
    return "☀️";
  }

  String _getWeatherDescription(WeatherData weather) {
    if (weather.pty != null && weather.pty != "0") {
      switch (weather.pty) {
        case "1":
          return "비";
        case "2":
          return "비/눈";
        case "3":
          return "눈";
        case "4":
          return "소나기";
        default:
          return "강수";
      }
    }
    
    if (weather.sky != null) {
      switch (weather.sky) {
        case "1":
          return "맑음";
        case "3":
          return "구름많음";
        case "4":
          return "흐림";
        default:
          return "맑음";
      }
    }
    
    return "맑음";
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 16,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              market.marketName ?? '관심 시장',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (market.marketLocation != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          market.marketLocation!,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const MarketSearchScreen(),
                          ),
                        );
                      },
                      tooltip: '시장 추가',
                    ),
                    if (onRefresh != null)
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: onRefresh,
                        tooltip: '새로고침',
                      ),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // 날씨 정보
            if (weather != null) ...[
              Row(
                children: [
                  // 날씨 아이콘과 온도
                  Text(
                    _getWeatherIcon(weather!),
                    style: const TextStyle(fontSize: 48),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (weather!.temp != null)
                          Text(
                            '${weather!.temp!.round()}°C',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        Text(
                          _getWeatherDescription(weather!),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // 상세 날씨 정보
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        if (weather!.humidity != null)
                          _buildWeatherDetail(
                            '습도',
                            '${weather!.humidity!.round()}%',
                            Icons.water_drop,
                          ),
                        if (weather!.windSpeed != null)
                          _buildWeatherDetail(
                            '풍속',
                            '${weather!.windSpeed!.toStringAsFixed(1)}m/s',
                            Icons.air,
                          ),
                        if (weather!.pop != null)
                          _buildWeatherDetail(
                            '강수확률',
                            '${weather!.pop!.round()}%',
                            Icons.umbrella,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ] else ...[
              // 날씨 정보를 불러올 수 없는 경우
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.cloud_off,
                      size: 48,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '날씨 정보를 불러올 수 없습니다',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                    if (onRefresh != null) ...[
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: onRefresh,
                        icon: const Icon(Icons.refresh),
                        label: const Text('다시 시도'),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWeatherDetail(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(
          icon,
          size: 20,
          color: Colors.grey[600],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}