import 'dart:math';
import '../models/market.dart';
import '../models/weather.dart';
import 'api_service.dart';
import 'location_service.dart';

class MarketService {
  final ApiService _apiService = ApiService();
  final LocationService _locationService = LocationService();

  // 싱글톤 패턴
  static final MarketService _instance = MarketService._internal();
  factory MarketService() => _instance;
  MarketService._internal();

  // 시장 검색
  Future<List<Market>> searchMarkets(String query) async {
    if (query.trim().isEmpty) return [];
    return await _apiService.searchMarkets(query);
  }

  // 관심 시장 목록 조회
  Future<List<UserMarketInterest>> getWatchlist() async {
    return await _apiService.getWatchlist();
  }

  // 시장을 관심 목록에 추가
  Future<UserMarketInterest> addToWatchlist(int marketId) async {
    return await _apiService.addToWatchlist(marketId);
  }

  // 시장을 관심 목록에서 제거
  Future<void> removeFromWatchlist(int marketId) async {
    await _apiService.removeFromWatchlist(marketId);
  }

  // 두 좌표 간의 거리 계산 (하버사인 공식)
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // 지구 반지름 (km)
    
    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);
    
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
        sin(dLon / 2) * sin(dLon / 2);
    
    double c = 2 * asin(sqrt(a));
    
    return earthRadius * c;
  }

  double _toRadians(double degrees) {
    return degrees * (pi / 180);
  }

  // 현재 위치에서 가장 가까운 관심 시장 찾기
  Future<UserMarketInterest?> getClosestWatchedMarket() async {
    try {
      // 현재 위치 가져오기
      final position = await _locationService.getCurrentPosition();
      if (position == null) return null;

      // 관심 시장 목록 가져오기
      final watchlist = await getWatchlist();
      if (watchlist.isEmpty) return null;

      // 좌표가 있는 관심 시장들만 필터링
      final marketsWithCoordinates = watchlist.where((interest) {
        return interest.marketCoordinates?.hasCoordinates == true;
      }).toList();

      if (marketsWithCoordinates.isEmpty) return null;

      // 가장 가까운 시장 찾기
      UserMarketInterest? closestMarket;
      double minDistance = double.infinity;

      for (final interest in marketsWithCoordinates) {
        final coords = interest.marketCoordinates!;
        final distance = calculateDistance(
          position.latitude,
          position.longitude,
          coords.latitude!,
          coords.longitude!,
        );

        if (distance < minDistance) {
          minDistance = distance;
          closestMarket = interest;
        }
      }

      return closestMarket;
    } catch (e) {
      print('Error finding closest market: $e');
      return null;
    }
  }

  // 특정 시장의 현재 날씨 조회
  Future<WeatherData?> getMarketCurrentWeather(UserMarketInterest interest) async {
    final coords = interest.marketCoordinates;
    if (coords == null || !coords.hasCoordinates) return null;

    try {
      final request = WeatherRequest(
        latitude: coords.latitude!,
        longitude: coords.longitude!,
        locationName: interest.marketName ?? '관심 시장',
      );

      return await _apiService.getCurrentWeather(request);
    } catch (e) {
      print('Error getting market weather: $e');
      return null;
    }
  }

  // 특정 시장의 날씨 예보 조회
  Future<List<WeatherData>> getMarketForecastWeather(UserMarketInterest interest) async {
    final coords = interest.marketCoordinates;
    if (coords == null || !coords.hasCoordinates) return [];

    try {
      final request = WeatherRequest(
        latitude: coords.latitude!,
        longitude: coords.longitude!,
        locationName: interest.marketName ?? '관심 시장',
      );

      return await _apiService.getForecastWeather(request);
    } catch (e) {
      print('Error getting market forecast: $e');
      return [];
    }
  }
}