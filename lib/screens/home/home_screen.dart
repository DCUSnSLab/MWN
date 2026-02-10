import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/auth_provider.dart';
import '../../providers/market_provider.dart';
import '../../services/market_service.dart';
import '../../models/market.dart';
import '../../widgets/empty_watchlist_widget.dart';
import '../../widgets/market_weather_widget.dart';
import '../auth/login_screen.dart';
import '../admin/admin_dashboard.dart';
import '../admin/alert_history_screen.dart';
import '../notifications/notification_history_screen.dart';
import '../market/watchlist_management_screen.dart';
import '../account/account_management_screen.dart';
import '../market/market_detail_screen.dart';
import '../../widgets/market_map_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _showMap = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadMarketData();
    _scrollController.addListener(_onScroll);
    
    // 화면이 그려진 후 추천 로직 실행
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowRecommendations();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      // 스크롤이 바닥에 가까워지면 더 불러오기
      context.read<MarketProvider>().loadMoreMarkets();
    }
  }

  Future<void> _checkAndShowRecommendations() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeen = prefs.getBool('has_seen_recommendation') ?? false;

    if (!hasSeen) {
      if (!mounted) return;
      
      // 위치 권한 확인 등은 MarketService 내부에서 처리됨 (권한 없으면 빈 리스트 반환)
      // 하지만 사용자 경험을 위해 여기서 미리 권한을 체크하거나 요청하는 것이 좋을 수 있음
      
      final marketService = MarketService();
      final nearbyMarkets = await marketService.getNearbyMarketsFromAll(limit: 5);

      if (nearbyMarkets.isNotEmpty && mounted) {
        _showRecommendationSheet(nearbyMarkets);
        await prefs.setBool('has_seen_recommendation', true);
      }
    }
  }

  void _showRecommendationSheet(List<Market> markets) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2.5),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '내 주변 시장 추천',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '현재 위치에서 가까운 시장을 관심 목록에 추가해보세요.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: markets.length,
                    itemBuilder: (context, index) {
                      final market = markets[index];
                      return ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.store),
                        ),
                        title: Text(market.name),
                        subtitle: Text(market.location),
                        trailing: IconButton(
                          icon: const Icon(Icons.add_circle_outline, color: Colors.blue),
                          onPressed: () async {
                            try {
                              await context.read<MarketProvider>().addToWatchlist(market);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('${market.name}이(가) 추가되었습니다.')),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('추가 실패: $e')),
                                );
                              }
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('닫기'),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _loadMarketData() async {
    final marketProvider = context.read<MarketProvider>();
    await marketProvider.loadWatchlist();
  }


  Future<void> _logout() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.logout();
    
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  void _goToAdminDashboard() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const AdminDashboard()),
    );
  }





  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.notifications_outlined),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const NotificationHistoryScreen(),
              ),
            );
          },
          tooltip: '알림 내역',
        ),
        title: const Text(''),
        actions: [
          IconButton(
            icon: Icon(_showMap ? Icons.list : Icons.map),
            tooltip: _showMap ? '목록 보기' : '지도 보기',
            onPressed: () {
              setState(() {
                _showMap = !_showMap;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: '내 알림 이력',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AlertHistoryScreen(isAdmin: false),
                ),
              );
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') {
                _logout();
              } else if (value == 'admin') {
                _goToAdminDashboard();
              } else if (value == 'settings') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AccountManagementScreen(),
                  ),
                );
              }
            },
            itemBuilder: (context) {
              final authProvider = Provider.of<AuthProvider>(context, listen: false);
              final isAdmin = authProvider.currentUser?.role == 'admin';
              
              return [
                if (isAdmin)
                  const PopupMenuItem(
                    value: 'admin',
                    child: Row(
                      children: [
                        Icon(Icons.admin_panel_settings, color: Colors.purple),
                        SizedBox(width: 8),
                        Text('관리자 모드'),
                      ],
                    ),
                  ),
                const PopupMenuItem(
                  value: 'settings',
                  child: Row(
                    children: [
                      Icon(Icons.settings, color: Colors.grey),
                      SizedBox(width: 8),
                      Text('계정 관리'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, color: Colors.red),
                      SizedBox(width: 8),
                      Text('로그아웃'),
                    ],
                  ),
                ),
              ];
            },
          ),
        ],
      ),

      body: _showMap
          ? Consumer<MarketProvider>(
              builder: (context, marketProvider, child) {
                return MarketMapWidget(
                  markets: marketProvider.watchlist,
                  weatherData: marketProvider.nearbyMarketsWeather,
                );
              },
            )
          : RefreshIndicator(
              onRefresh: _loadMarketData,
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // 관심 시장 추가 버튼 (긴 가로 바)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const WatchlistManagementScreen(),
                            ),
                          ).then((_) {
                            _loadMarketData();
                          });
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('관심 시장 추가'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.all(16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 관심 시장 날씨
                    Text(
                      '관심 시장 날씨',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Consumer<MarketProvider>(
                      builder: (context, marketProvider, child) {
                        if (marketProvider.isLoading && marketProvider.nearbyMarkets.isEmpty) {
                          return const Card(
                            child: Padding(
                              padding: EdgeInsets.all(24.0),
                              child: Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                          );
                        }

                        if (marketProvider.error != null && marketProvider.nearbyMarkets.isEmpty) {
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                children: [
                                  const Icon(
                                    Icons.error,
                                    color: Colors.red,
                                    size: 48,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    '오류가 발생했습니다',
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    marketProvider.error!,
                                    style: Theme.of(context).textTheme.bodySmall,
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: () {
                                      marketProvider.clearError();
                                      _loadMarketData();
                                    },
                                    child: const Text('다시 시도'),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        if (!marketProvider.hasWatchedMarkets) {
                          return const EmptyWatchlistWidget();
                        }

                        // 가까운 시장 목록 표시
                        if (marketProvider.nearbyMarkets.isNotEmpty) {
                          return Column(
                            children: [
                              ...marketProvider.nearbyMarkets.asMap().entries.map((entry) {
                                final market = entry.value;
                                final weather = marketProvider.nearbyMarketsWeather[market.marketId];

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12.0),
                                  child: MarketWeatherWidget(
                                    market: market,
                                    weather: weather,
                                    onRefresh: () {
                                      marketProvider.updateNearbyMarketsWeather(init: false); // 전체 새로고침은 비용이 크므로, 개별로 하거나 전체 갱신 호출
                                    },
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => MarketDetailScreen(
                                            market: market,
                                            weather: weather,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                );
                              }),
                              
                              if (marketProvider.hasMoreMarkets)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16.0),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                            ],
                          );
                        }

                        return const Card(
                          child: Padding(
                            padding: EdgeInsets.all(24.0),
                            child: Text('날씨 정보를 가져올 수 없습니다'),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                  ],
                ),
              ),
            ),
    );
  }
}