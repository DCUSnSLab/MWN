import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/market_provider.dart';
import '../models/market.dart';
import '../models/weather.dart';

class MarketWeatherWidget extends StatelessWidget {
  final UserMarketInterest market;
  final WeatherData? weather;
  final VoidCallback? onRefresh;
  final VoidCallback? onTap;

  const MarketWeatherWidget({
    super.key,
    required this.market,
    this.weather,
    this.onRefresh,
    this.onTap,
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
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), // 마진 축소
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), // 반경 약간 축소
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: onTap,
        child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), // 내부 패딩 축소
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header: Market Name and Address
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.store_mall_directory,
                        size: 16, // 아이콘 크기 축소
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          market.marketName ?? '관심 시장',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 15, // 폰트 크기 약간 축소
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 주소를 이름 옆으로 이동 (공간이 허락한다면) 또는 아래에 작게 표시
                      // 여기서는 이름 옆에 작게 표시하거나, 생략하고 날씨에 집중
                    ],
                  ),
                ),
                if (onRefresh != null)
                  SizedBox(
                    width: 24, 
                    height: 24,
                    child: IconButton(
                      icon: const Icon(Icons.refresh, size: 18, color: Colors.grey),
                      onPressed: onRefresh,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: '새로고침',
                    ),
                  ),
              ],
            ),
            
            // 주소 (선택적 표시 - 너무 길면 생략 가능하지만 정보 유지를 위해 표시하되 여백 줄임)
            if (market.marketLocation != null)
              Padding(
                padding: const EdgeInsets.only(left: 22.0, top: 2.0),
                child: Text(
                  market.marketLocation!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            
            const SizedBox(height: 8), // 간격 축소
            const Divider(height: 1, thickness: 0.5),
            
            // Debug Info
            if (context.watch<MarketProvider>().isDebugMode)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 4, bottom: 4),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('[DEBUG] ID: ${market.marketId}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red)),
                    if (market.marketLocation != null)
                      Text('Loc: ${market.marketLocation}', style: const TextStyle(fontSize: 10)),
                    if (market.marketCoordinates != null) ...[
                      Text('Lat: ${market.marketCoordinates?.latitude?.toStringAsFixed(4)}', style: const TextStyle(fontSize: 10)),
                      Text('Lng: ${market.marketCoordinates?.longitude?.toStringAsFixed(4)}', style: const TextStyle(fontSize: 10)),
                      Text('Grid: (${market.marketCoordinates?.nx}, ${market.marketCoordinates?.ny})', style: const TextStyle(fontSize: 10)),
                    ],
                  ],
                ),
              ),

            const SizedBox(height: 8), // 간격 축소
            
            // 2. Weather Info: Compact Row
            if (weather != null)
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Icon
                  Text(
                    _getWeatherIcon(weather!),
                    style: const TextStyle(fontSize: 24), // 이모지 크기 축소
                  ),
                  const SizedBox(width: 8),
                  
                  // Temp
                  if (weather!.temp != null)
                    Text(
                      '${weather!.temp!.toStringAsFixed(1)}°C',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  
                  const Spacer(),
                  
                  // Humidity
                  if (weather!.humidity != null) ...[
                    const Icon(Icons.water_drop, size: 14, color: Colors.blueAccent),
                    const SizedBox(width: 4),
                    Text(
                      '${weather!.humidity!.round()}%',
                      style: TextStyle(fontSize: 13, color: Colors.grey[800]),
                    ),
                    const SizedBox(width: 12),
                  ],
                  
                  // Wind Speed
                  if (weather!.windSpeed != null) ...[
                    const Icon(Icons.air, size: 14, color: Colors.teal),
                    const SizedBox(width: 4),
                    Text(
                      '${weather!.windSpeed!.toStringAsFixed(1)}m/s',
                      style: TextStyle(fontSize: 13, color: Colors.grey[800]),
                    ),
                  ],
                ],
              )
            else
              // No Data
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Text(
                    '날씨 정보를 불러올 수 없습니다',
                    style: TextStyle(color: Colors.grey[500], fontSize: 11),
                  ),
                ),
              ),
          ],
        ),
        ),
      ),
    );
  }
}