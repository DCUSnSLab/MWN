import 'package:flutter/foundation.dart';
import '../models/market.dart';
import '../models/weather.dart';
import '../services/market_service.dart';

class MarketProvider with ChangeNotifier {
  final MarketService _marketService = MarketService();
  
  List<UserMarketInterest> _watchlist = [];
  List<Market> _searchResults = [];
  UserMarketInterest? _closestMarket;
  WeatherData? _closestMarketWeather;
  bool _isLoading = false;
  String? _error;

  List<UserMarketInterest> get watchlist => _watchlist;
  List<Market> get searchResults => _searchResults;
  UserMarketInterest? get closestMarket => _closestMarket;
  WeatherData? get closestMarketWeather => _closestMarketWeather;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasWatchedMarkets => _watchlist.isNotEmpty;

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
      
      // 가장 가까운 시장 및 날씨 정보 업데이트
      if (_watchlist.isNotEmpty) {
        await updateClosestMarketWeather();
      } else {
        _closestMarket = null;
        _closestMarketWeather = null;
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
      
      // 첫 번째 관심 시장이 추가된 경우 가장 가까운 시장 업데이트
      if (_watchlist.length == 1) {
        await updateClosestMarketWeather();
      }
      
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
      
      // 제거된 시장이 가장 가까운 시장이었다면 다시 계산
      if (_closestMarket?.marketId == marketId) {
        await updateClosestMarketWeather();
      }
      
      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  // 가장 가까운 관심 시장의 날씨 정보 업데이트
  Future<void> updateClosestMarketWeather() async {
    try {
      _closestMarket = await _marketService.getClosestWatchedMarket();
      
      if (_closestMarket != null) {
        _closestMarketWeather = await _marketService.getMarketCurrentWeather(_closestMarket!);
      } else {
        _closestMarketWeather = null;
      }
      
      notifyListeners();
    } catch (e) {
      print('Error updating closest market weather: $e');
    }
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