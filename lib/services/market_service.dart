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

  // 현재 위치에서 가까운 순으로 N개의 관심 시장 가져오기
  Future<List<UserMarketInterest>> getNearbyWatchedMarkets({int limit = 5}) async {
    try {
      // 현재 위치 가져오기
      final position = await _locationService.getCurrentPosition();
      if (position == null) {
        print('⚠️ 현재 위치를 가져올 수 없습니다');
        return [];
      }

      // 관심 시장 목록 가져오기
      final watchlist = await getWatchlist();
      if (watchlist.isEmpty) {
        print('⚠️ 관심 시장이 없습니다');
        return [];
      }

      // 좌표가 있는 관심 시장들만 필터링
      final marketsWithCoordinates = watchlist.where((interest) {
        return interest.marketCoordinates?.hasCoordinates == true;
      }).toList();

      if (marketsWithCoordinates.isEmpty) {
        print('⚠️ 좌표가 있는 관심 시장이 없습니다');
        return [];
      }

      // 각 시장의 거리 계산 및 정렬
      final marketsWithDistance = marketsWithCoordinates.map((interest) {
        final coords = interest.marketCoordinates!;
        final distance = calculateDistance(
          position.latitude,
          position.longitude,
          coords.latitude!,
          coords.longitude!,
        );
        return {'interest': interest, 'distance': distance};
      }).toList();

      // 거리순으로 정렬
      marketsWithDistance.sort((a, b) =>
        (a['distance'] as double).compareTo(b['distance'] as double)
      );

      // 상위 N개 선택
      final nearbyMarkets = marketsWithDistance
          .take(limit)
          .map((item) => item['interest'] as UserMarketInterest)
          .toList();

      print('✅ 가까운 시장 ${nearbyMarkets.length}개 찾음');
      return nearbyMarkets;
    } catch (e) {
      print('❌ 가까운 시장 찾기 오류: $e');
      return [];
    }
  }

  // 현재 위치에서 가까운 순으로 모든 관심 시장 가져오기 (페이지네이션용)
  Future<List<UserMarketInterest>> getAllSortedWatchedMarkets() async {
    try {
      // 현재 위치 가져오기
      final position = await _locationService.getCurrentPosition();
      if (position == null) return [];

      // 관심 시장 목록 가져오기
      final watchlist = await getWatchlist();
      if (watchlist.isEmpty) return [];

      // 좌표가 있는 관심 시장들만 필터링
      final marketsWithCoordinates = watchlist.where((interest) {
        return interest.marketCoordinates?.hasCoordinates == true;
      }).toList();

      if (marketsWithCoordinates.isEmpty) return [];

      // 각 시장의 거리 계산 및 정렬
      final marketsWithDistance = marketsWithCoordinates.map((interest) {
        final coords = interest.marketCoordinates!;
        final distance = calculateDistance(
          position.latitude,
          position.longitude,
          coords.latitude!,
          coords.longitude!,
        );
        return {'interest': interest, 'distance': distance};
      }).toList();

      // 거리순으로 정렬
      marketsWithDistance.sort((a, b) =>
        (a['distance'] as double).compareTo(b['distance'] as double)
      );

      return marketsWithDistance
          .map((item) => item['interest'] as UserMarketInterest)
          .toList();
    } catch (e) {
      print('❌ 전체 정렬 시장 조회 오류: $e');
      return [];
    }
  }

  // 전체 시장 중 현재 위치에서 가까운 순으로 N개 가져오기 (추천용)
  Future<List<Market>> getNearbyMarketsFromAll({int limit = 5}) async {
    try {
      // 1. 현재 위치 가져오기
      final position = await _locationService.getCurrentPosition();
      if (position == null) {
        print('⚠️ 현재 위치를 가져올 수 없습니다');
        return [];
      }

      // 2. 전체 활성 시장 목록 가져오기
      // TODO: API가 전체 목록을 주지 않고 페이징한다면, 
      // 위치 기반 검색 API가 필요할 수 있음.
      // 일단은 getMarkets로 가져와서 클라이언트에서 계산 (데이터가 많지 않다고 가정)
      final allMarkets = await _apiService.getMarkets(isActive: true, perPage: 1000);
      
      if (allMarkets.isEmpty) return [];

      // 3. 거리 계산 및 정렬
      final marketsWithDistance = allMarkets.where((m) => m.hasCoordinates).map((market) {
        final distance = calculateDistance(
          position.latitude,
          position.longitude,
          market.latitude!,
          market.longitude!,
        );
        return {'market': market, 'distance': distance};
      }).toList();

      marketsWithDistance.sort((a, b) =>
        (a['distance'] as double).compareTo(b['distance'] as double)
      );

      // 4. 상위 N개 반환
      return marketsWithDistance
          .take(limit)
          .map((item) => item['market'] as Market)
          .toList();
          
    } catch (e) {
      print('❌ 전체 시장 중 가까운 시장 찾기 오류: $e');
      return [];
    }
  }

  // 여러 시장의 날씨 정보를 한 번에 가져오기
  Future<Map<int, WeatherData>> getMultipleMarketsWeather(
    List<UserMarketInterest> markets
  ) async {
    final weatherMap = <int, WeatherData>{};

    try {
      // 각 시장의 날씨를 병렬로 조회
      final weatherFutures = markets.map((interest) async {
        final coords = interest.marketCoordinates;
        if (coords == null || !coords.hasCoordinates) return null;

        try {
          final request = WeatherRequest(
            latitude: coords.latitude!,
            longitude: coords.longitude!,
            locationName: interest.marketName ?? '관심 시장',
          );

          final weather = await _apiService.getCurrentWeather(request);
          return {'marketId': interest.marketId, 'weather': weather};
        } catch (e, stackTrace) {
          print('❌ ${interest.marketName} (${interest.marketId}) 날씨 조회 실패: $e');
          print(stackTrace);
          return null;
        }
      });

      // 모든 날씨 조회 완료 대기
      final results = await Future.wait(weatherFutures);

      // 결과를 Map으로 변환
      for (final result in results) {
        if (result != null) {
          final marketId = result['marketId'] as int;
          final weather = result['weather'] as WeatherData;
          weatherMap[marketId] = weather;
        }
      }

      print('✅ ${weatherMap.length}개 시장의 날씨 조회 완료');
    } catch (e) {
      print('❌ 날씨 조회 오류: $e');
    }

    return weatherMap;
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