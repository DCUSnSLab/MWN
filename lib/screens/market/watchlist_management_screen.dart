import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/market.dart';
import '../../providers/market_provider.dart';
import '../../services/location_service.dart';
import '../../services/market_service.dart';
import 'market_search_screen.dart';

class WatchlistManagementScreen extends StatefulWidget {
  const WatchlistManagementScreen({super.key});

  @override
  State<WatchlistManagementScreen> createState() => _WatchlistManagementScreenState();
}

class _WatchlistManagementScreenState extends State<WatchlistManagementScreen> {
  final LocationService _locationService = LocationService();
  final MarketService _marketService = MarketService();
  Map<int, double> _distances = {};
  bool _isLoadingDistances = false;

  @override
  void initState() {
    super.initState();
    _loadMarketDistances();
  }

  Future<void> _loadMarketDistances() async {
    setState(() {
      _isLoadingDistances = true;
    });

    try {
      final position = await _locationService.getCurrentPosition();
      if (position == null) {
        setState(() {
          _isLoadingDistances = false;
        });
        return;
      }

      final marketProvider = context.read<MarketProvider>();
      final watchlist = marketProvider.watchlist;

      final distances = <int, double>{};
      for (final interest in watchlist) {
        final coords = interest.marketCoordinates;
        if (coords != null && coords.hasCoordinates) {
          final distance = _marketService.calculateDistance(
            position.latitude,
            position.longitude,
            coords.latitude!,
            coords.longitude!,
          );
          distances[interest.marketId] = distance;
        }
      }

      setState(() {
        _distances = distances;
        _isLoadingDistances = false;
      });
    } catch (e) {
      print('거리 계산 오류: $e');
      setState(() {
        _isLoadingDistances = false;
      });
    }
  }

  Future<void> _removeFromWatchlist(UserMarketInterest interest) async {
    final marketProvider = context.read<MarketProvider>();

    // 삭제 확인 다이얼로그
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('관심 시장 제거'),
        content: Text('${interest.marketName ?? "이 시장"}을(를) 관심 목록에서 제거하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              '제거',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await marketProvider.removeFromWatchlist(interest.marketId);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${interest.marketName ?? "시장"}이(가) 제거되었습니다'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
          // 거리 정보 다시 로드
          _loadMarketDistances();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(marketProvider.error ?? '시장 제거에 실패했습니다'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _goToMarketSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const MarketSearchScreen(),
      ),
    ).then((_) {
      // 검색 화면에서 돌아왔을 때 목록 새로고침
      context.read<MarketProvider>().loadWatchlist();
      _loadMarketDistances();
    });
  }

  String _formatDistance(double distance) {
    if (distance < 1) {
      return '${(distance * 1000).round()}m';
    } else {
      return '${distance.toStringAsFixed(1)}km';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('관심 시장 관리'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<MarketProvider>().loadWatchlist();
              _loadMarketDistances();
            },
            tooltip: '새로고침',
          ),
        ],
      ),
      body: Consumer<MarketProvider>(
        builder: (context, marketProvider, child) {
          if (marketProvider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (marketProvider.error != null) {
            return _buildErrorWidget(marketProvider);
          }

          if (marketProvider.watchlist.isEmpty) {
            return _buildEmptyState();
          }

          return RefreshIndicator(
            onRefresh: () async {
              await marketProvider.loadWatchlist();
              await _loadMarketDistances();
            },
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: marketProvider.watchlist.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final interest = marketProvider.watchlist[index];
                return _buildMarketItem(interest);
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _goToMarketSearch,
        tooltip: '시장 추가',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildMarketItem(UserMarketInterest interest) {
    final distance = _distances[interest.marketId];

    return Dismissible(
      key: Key('market_${interest.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        await _removeFromWatchlist(interest);
        return false; // 우리가 직접 처리하므로 자동 삭제 방지
      },
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(
          Icons.delete,
          color: Colors.white,
        ),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(
            Icons.store,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        title: Text(
          interest.marketName ?? '관심 시장',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (interest.marketLocation != null) ...[
              const SizedBox(height: 4),
              Text(
                interest.marketLocation!,
                style: TextStyle(
                  color: Colors.grey[700],
                ),
              ),
            ],
            if (distance != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.location_on,
                    size: 14,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatDistance(distance),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ] else if (_isLoadingDistances) ...[
              const SizedBox(height: 4),
              Text(
                '거리 계산 중...',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (interest.notificationEnabled)
              Icon(
                Icons.notifications_active,
                size: 20,
                color: Colors.green[600],
              ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _removeFromWatchlist(interest),
              tooltip: '제거',
            ),
          ],
        ),
        onTap: () {
          _showMarketDetail(interest);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.store_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              '관심 시장이 없습니다',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '아래 + 버튼을 눌러\n관심있는 시장을 추가해보세요',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _goToMarketSearch,
              icon: const Icon(Icons.add),
              label: const Text('시장 추가하기'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget(MarketProvider marketProvider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              '오류가 발생했습니다',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              marketProvider.error!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                marketProvider.clearError();
                marketProvider.loadWatchlist();
                _loadMarketDistances();
              },
              child: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }

  void _showMarketDetail(UserMarketInterest interest) {
    final distance = _distances[interest.marketId];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(interest.marketName ?? '관심 시장'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (interest.marketLocation != null) ...[
                _buildDetailRow(
                  Icons.location_on,
                  '위치',
                  interest.marketLocation!,
                ),
                const SizedBox(height: 12),
              ],
              if (distance != null) ...[
                _buildDetailRow(
                  Icons.straighten,
                  '거리',
                  _formatDistance(distance),
                ),
                const SizedBox(height: 12),
              ],
              if (interest.marketCoordinates != null) ...[
                if (interest.marketCoordinates!.latitude != null &&
                    interest.marketCoordinates!.longitude != null) ...[
                  _buildDetailRow(
                    Icons.map,
                    '좌표',
                    '${interest.marketCoordinates!.latitude!.toStringAsFixed(4)}, ${interest.marketCoordinates!.longitude!.toStringAsFixed(4)}',
                  ),
                  const SizedBox(height: 12),
                ],
                if (interest.marketCoordinates!.nx != null &&
                    interest.marketCoordinates!.ny != null) ...[
                  _buildDetailRow(
                    Icons.grid_on,
                    '격자',
                    'NX: ${interest.marketCoordinates!.nx}, NY: ${interest.marketCoordinates!.ny}',
                  ),
                  const SizedBox(height: 12),
                ],
              ],
              _buildDetailRow(
                interest.notificationEnabled ? Icons.notifications_active : Icons.notifications_off,
                '알림',
                interest.notificationEnabled ? '활성화됨' : '비활성화됨',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
