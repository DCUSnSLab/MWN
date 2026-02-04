import 'package:flutter/material.dart';
import '../models/market.dart';
import '../models/weather.dart';

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

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header: Market Name and Address
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
                            Icons.store_mall_directory,
                            size: 18,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              market.marketName ?? '관심 시장',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Address (using marketLocation)
                      Row(
                         children: [
                           const SizedBox(width: 24), // Indent to align with text above
                           Expanded(
                             child: Text(
                               market.marketLocation ?? '주소 정보 없음',
                               style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                 color: Colors.grey[600],
                               ),
                               overflow: TextOverflow.ellipsis,
                             ),
                           ),
                         ],
                      ),
                    ],
                  ),
                ),
                if (onRefresh != null)
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20, color: Colors.grey),
                    onPressed: onRefresh,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: '새로고침',
                  ),
              ],
            ),
            
            const SizedBox(height: 12),
            const Divider(height: 1, thickness: 0.5),
            const SizedBox(height: 12),
            
            // 2. Weather Info: Single Row
            if (weather != null)
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Icon
                  Text(
                    _getWeatherIcon(weather!),
                    style: const TextStyle(fontSize: 32),
                  ),
                  const SizedBox(width: 8),
                  
                  // Temp
                  if (weather!.temp != null)
                    Text(
                      '${weather!.temp!.round()}°C',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  
                  const Spacer(),
                  
                  // Humidity
                  if (weather!.humidity != null) ...[
                    const Icon(Icons.water_drop, size: 16, color: Colors.blueAccent),
                    const SizedBox(width: 4),
                    Text(
                      '${weather!.humidity!.round()}%',
                      style: TextStyle(fontSize: 14, color: Colors.grey[800]),
                    ),
                    const SizedBox(width: 12),
                  ],
                  
                  // Wind Speed
                  if (weather!.windSpeed != null) ...[
                    const Icon(Icons.air, size: 16, color: Colors.teal),
                    const SizedBox(width: 4),
                    Text(
                      '${weather!.windSpeed!.toStringAsFixed(1)}m/s',
                      style: TextStyle(fontSize: 14, color: Colors.grey[800]),
                    ),
                  ],
                ],
              )
            else
              // No Data
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    '날씨 정보를 불러올 수 없습니다',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}