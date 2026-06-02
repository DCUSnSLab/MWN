import 'package:flutter/foundation.dart';
import '../models/market.dart';
import '../models/weather.dart';
import '../services/market_service.dart';
import '../utils/logger.dart';

class MarketProvider with ChangeNotifier {
  final MarketService _marketService = MarketService();
  
  List<UserMarketInterest> _watchlist = [];
  List<Market> _searchResults = [];
  
  // Re-adding missing fields
  List<UserMarketInterest> _nearbyMarkets = [];
  Map<int, WeatherData> _nearbyMarketsWeather = {};
  // 지도 뷰용: 관심 시장 전체의 날씨 캐시 (lazy 로드)
  Map<int, WeatherData> _watchlistWeather = {};
  bool _isWatchlistWeatherLoading = false;
  String? _watchlistWeatherError;
  bool _isLoading = false;
  String? _error;

  List<UserMarketInterest> _allNearbyMarkets = []; // 전체 정렬된 시장 목록
  int _visibleCount = 10; // 현재 보여주는 시장 개수 (최대 10개)
  static const int _maxVisibleCount = 10; // 최대 표시 개수
  bool _hasMoreMarkets = false; // 더 불러올 시장이 있는지 여부
  bool _isDebugMode = false; // 디버그 모드 상태

  List<UserMarketInterest> get watchlist => _watchlist;
  List<Market> get searchResults => _searchResults;
  List<UserMarketInterest> get nearbyMarkets => _nearbyMarkets;
  Map<int, WeatherData> get nearbyMarketsWeather => _nearbyMarketsWeather;
  Map<int, WeatherData> get watchlistWeather => _watchlistWeather;
  bool get isWatchlistWeatherLoading => _isWatchlistWeatherLoading;
  String? get watchlistWeatherError => _watchlistWeatherError;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasWatchedMarkets => _watchlist.isNotEmpty;
  bool get hasMoreMarkets => _hasMoreMarkets;
  bool get isDebugMode => _isDebugMode;

  // 디버그 모드 토글
  void toggleDebugMode() {
    _isDebugMode = !_isDebugMode;
    notifyListeners();
  }

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

      // 가까운 시장 목록 및 날씨 정보 업데이트 (초기화 포함)
      if (_watchlist.isNotEmpty) {
        // 초기 로드 시 visibleCount 초기화 및 날씨 캐시 초기화 (새로고침 시 최신 데이터 요청)
        _visibleCount = _maxVisibleCount;
        _nearbyMarketsWeather = {};
        _watchlistWeather = {};
        await updateNearbyMarketsWeather(init: true);
      } else {
        _allNearbyMarkets = [];
        _nearbyMarkets = [];
        _nearbyMarketsWeather = {};
        _watchlistWeather = {};
        _hasMoreMarkets = false;
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

      // 리스트 업데이트
      await updateNearbyMarketsWeather(init: true);

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

      // 리스트 업데이트
      await updateNearbyMarketsWeather(init: true);

      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  // 가까운 관심 시장들의 날씨 정보 업데이트
  // init: true면 전체 리스트를 다시 정렬해서 가져옴
  Future<void> updateNearbyMarketsWeather({bool init = false}) async {
    try {
      if (init) {
        log('🔄 전체 정렬된 시장 목록 업데이트 중...');
        // 전체 정렬된 리스트 가져오기 (이미 fetch 한 _watchlist 재사용)
        _allNearbyMarkets =
            await _marketService.getAllSortedWatchedMarkets(watchlist: _watchlist);
      }

      // 보여줄 시장 개수 조정 (최대 10개로 제한)
      final effectiveMax = _allNearbyMarkets.length < _maxVisibleCount ? _allNearbyMarkets.length : _maxVisibleCount;
      if (_visibleCount > effectiveMax) {
        _visibleCount = effectiveMax;
      }
      
      // 최대 10개까지만 표시하므로 더 보기 비활성화
      _hasMoreMarkets = false;

      // 현재 보여줄 목록 슬라이싱
      _nearbyMarkets = _allNearbyMarkets.take(_visibleCount).toList();
      log('✅ 현재 보여줄 시장: ${_nearbyMarkets.length}개 / 전체 ${_allNearbyMarkets.length}개');

      // 날씨 정보가 없는 시장만 필터링 (불필요한 중복 호출 방지)
      final marketsToFetch = _nearbyMarkets.where((market) {
        return !_nearbyMarketsWeather.containsKey(market.marketId);
      }).toList();

      if (marketsToFetch.isNotEmpty) {
        log('Cloud: ${marketsToFetch.length}개 시장의 날씨 정보를 새로 가져옵니다.');
        final newWeatherMap = await _marketService.getMultipleMarketsWeather(marketsToFetch);

        // 기존 맵에 병합
        _nearbyMarketsWeather.addAll(newWeatherMap);
        // 지도 뷰 캐시에도 반영 (nearby 결과를 재사용)
        _watchlistWeather.addAll(newWeatherMap);
      } else {
        log('Skip: 보여줄 모든 시장의 날씨 정보가 이미 있습니다.');
      }

      notifyListeners();
    } catch (e) {
      log('❌ 시장 날씨 업데이트 오류: $e');
    }
  }

  /// 지도 뷰에서 사용할 관심 시장 전체의 날씨를 로드한다.
  ///
  /// nearby 결과를 시드로 두고, 누락된 시장만 추가로 가져온다.
  /// `force=true` 면 캐시를 비우고 전체를 새로 받는다.
  Future<void> loadWatchlistWeather({bool force = false}) async {
    if (_watchlist.isEmpty) return;
    if (_isWatchlistWeatherLoading) return;

    if (force) {
      _watchlistWeather = {};
    } else {
      // nearby에서 이미 받은 데이터를 시드로 사용
      _watchlistWeather = {..._watchlistWeather, ..._nearbyMarketsWeather};
    }

    final toFetch = _watchlist
        .where((m) => !_watchlistWeather.containsKey(m.marketId))
        .toList();
    if (toFetch.isEmpty) {
      notifyListeners();
      return;
    }

    _isWatchlistWeatherLoading = true;
    _watchlistWeatherError = null;
    notifyListeners();
    try {
      log('🗺️ 지도용 날씨 ${toFetch.length}개 추가 로드...');
      final fetched = await _marketService.getMultipleMarketsWeather(toFetch);
      _watchlistWeather.addAll(fetched);
      // 모두 실패하면 에러로 간주
      if (fetched.isEmpty && toFetch.isNotEmpty) {
        _watchlistWeatherError = '날씨 정보를 가져오지 못했습니다.';
      }
    } catch (e) {
      log('❌ 지도용 날씨 로드 오류: $e');
      _watchlistWeatherError = '날씨 정보를 가져오지 못했습니다.';
    } finally {
      _isWatchlistWeatherLoading = false;
      notifyListeners();
    }
  }

  void clearWatchlistWeatherError() {
    if (_watchlistWeatherError == null) return;
    _watchlistWeatherError = null;
    notifyListeners();
  }

  // 더 보기 (페이지네이션)
  Future<void> loadMoreMarkets() async {
    if (!_hasMoreMarkets || _isLoading) return;

    try {
      // 10개씩 추가 로드
      final nextCount = _visibleCount + 10;
      _visibleCount = nextCount;
      
      log('🔄 시장 목록 더 불러오기 (목표: $_visibleCount개)...');
      
      // 날씨 업데이트 (이미 정렬된 리스트에서 슬라이싱만 변경)
      await updateNearbyMarketsWeather(init: false);
      
    } catch (e) {
      log('❌ 더 보기 오류: $e');
    }
  }

  // 하위 호환성을 위한 메서드 (기존 코드와 호환)
  Future<void> updateClosestMarketWeather() async {
    await updateNearbyMarketsWeather(init: true);
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