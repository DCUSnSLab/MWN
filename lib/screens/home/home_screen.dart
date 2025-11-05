import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/market_provider.dart';
import '../../widgets/empty_watchlist_widget.dart';
import '../../widgets/market_weather_widget.dart';
import '../auth/login_screen.dart';
import '../admin/admin_dashboard.dart';
import '../notifications/notification_history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    _loadMarketData();
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
        title: const Text('날씨 알림'),
        actions: [
          IconButton(
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
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMarketData,
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') {
                _logout();
              } else if (value == 'admin') {
                _goToAdminDashboard();
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
      body: RefreshIndicator(
        onRefresh: _loadMarketData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 사용자 정보
              Consumer<AuthProvider>(
                builder: (context, authProvider, child) {
                  if (authProvider.currentUser != null) {
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            CircleAvatar(
                              child: Text(
                                authProvider.currentUser!.name[0].toUpperCase(),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '안녕하세요, ${authProvider.currentUser!.name}님',
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                  if (authProvider.currentUser!.location != null)
                                    Text(
                                      authProvider.currentUser!.location!,
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
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
                  if (marketProvider.isLoading) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                    );
                  }

                  if (marketProvider.error != null) {
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

                  if (marketProvider.closestMarket != null) {
                    return MarketWeatherWidget(
                      market: marketProvider.closestMarket!,
                      weather: marketProvider.closestMarketWeather,
                      onRefresh: () {
                        marketProvider.updateClosestMarketWeather();
                      },
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