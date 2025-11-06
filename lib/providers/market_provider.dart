import 'package:flutter/foundation.dart';
import '../models/market.dart';
import '../models/weather.dart';
import '../services/market_service.dart';

class MarketProvider with ChangeNotifier {
  final MarketService _marketService = MarketService();
  
  List<UserMarketInterest> _watchlist = [];
  List<Market> _searchResults = [];
  List<UserMarketInterest> _nearbyMarkets = [];
  Map<int, WeatherData> _nearbyMarketsWeather = {};
  bool _isLoading = false;
  String? _error;

  List<UserMarketInterest> get watchlist => _watchlist;
  List<Market> get searchResults => _searchResults;
  List<UserMarketInterest> get nearbyMarkets => _nearbyMarkets;
  Map<int, WeatherData> get nearbyMarketsWeather => _nearbyMarketsWeather;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasWatchedMarkets => _watchlist.isNotEmpty;

  // 하위 호환성을 위한 getter (기존 코드와 호환)
  UserMarketInterest? get closestMarket => _nearbyMarkets.isNotEmpty ? _nearbyMarkets.first : null;
  WeatherData? get closestMarketWeather => _nearbyMarkets.isNotEmpty ? _nearbyMarketsWeather[_nearbyMarkets.first.marketId] : null;

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // 관심 시장 목록 로드
  Future<void> loadWatchlist() async {
    _setLoading(true);
    _setError(null);

    try {
      _watchlist = await _marketService.getWatchlist();

      // 가까운 시장 5개 및 날씨 정보 업데이트
      if (_watchlist.isNotEmpty) {
        await updateNearbyMarketsWeather();
      } else {
        _nearbyMarkets = [];
        _nearbyMarketsWeather = {};
      }
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  // 시장 검색
  Future<void> searchMarkets(String query) async {
    _setError(null);

    try {
      _searchResults = await _marketService.searchMarkets(query);
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    }
  }

  // 검색 결과 초기화
  void clearSearchResults() {
    _searchResults = [];
    notifyListeners();
  }

  // 시장을 관심 목록에 추가
  Future<bool> addToWatchlist(Market market) async {
    _setError(null);

    try {
      final interest = await _marketService.addToWatchlist(market.id);
      _watchlist.add(interest);

      // 가까운 시장 목록 업데이트
      await updateNearbyMarketsWeather();

      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  // 시장을 관심 목록에서 제거
  Future<bool> removeFromWatchlist(int marketId) async {
    _setError(null);

    try {
      await _marketService.removeFromWatchlist(marketId);
      _watchlist.removeWhere((interest) => interest.marketId == marketId);

      // 가까운 시장 목록 업데이트
      await updateNearbyMarketsWeather();

      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  // 가까운 관심 시장들의 날씨 정보 업데이트 (최대 5개)
  Future<void> updateNearbyMarketsWeather({int limit = 5}) async {
    try {
      print('🔄 가까운 시장 ${limit}개의 날씨 업데이트 중...');

      // 가까운 시장 N개 가져오기
      _nearbyMarkets = await _marketService.getNearbyWatchedMarkets(limit: limit);

      // 각 시장의 날씨 정보 가져오기
      if (_nearbyMarkets.isNotEmpty) {
        _nearbyMarketsWeather = await _marketService.getMultipleMarketsWeather(_nearbyMarkets);
      } else {
        _nearbyMarketsWeather = {};
      }

      notifyListeners();
      print('✅ ${_nearbyMarkets.length}개 시장의 날씨 업데이트 완료');
    } catch (e) {
      print('❌ 가까운 시장 날씨 업데이트 오류: $e');
    }
  }

  // 하위 호환성을 위한 메서드 (기존 코드와 호환)
  Future<void> updateClosestMarketWeather() async {
    await updateNearbyMarketsWeather(limit: 5);
  }

  // 특정 시장이 관심 목록에 있는지 확인
  bool isInWatchlist(int marketId) {
    return _watchlist.any((interest) => interest.marketId == marketId);
  }

  // 관심 시장의 알림 설정 토글
  Future<bool> toggleNotification(int interestId) async {
    // 백엔드 API 호출이 필요한 경우 여기에 구현
    // 현재는 로컬 상태만 업데이트
    final index = _watchlist.indexWhere((interest) => interest.id == interestId);
    if (index != -1) {
      // Note: UserMarketInterest는 immutable이므로 새 객체를 생성해야 함
      // 실제 구현에서는 백엔드 API를 호출하고 응답으로 업데이트
      notifyListeners();
      return true;
    }
    return false;
  }
}