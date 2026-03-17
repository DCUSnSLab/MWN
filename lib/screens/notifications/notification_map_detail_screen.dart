import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../models/notification_item.dart';
import '../../models/market.dart';
import '../../providers/market_provider.dart';

class NotificationMapDetailScreen extends StatefulWidget {
  final NotificationItem notification;

  const NotificationMapDetailScreen({
    super.key,
    required this.notification,
  });

  @override
  State<NotificationMapDetailScreen> createState() => _NotificationMapDetailScreenState();
}

class _NotificationMapDetailScreenState extends State<NotificationMapDetailScreen> {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final List<UserMarketInterest> _relatedMarkets = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _parseAndLoadMarkets();
  }

  Future<void> _parseAndLoadMarkets() async {
    final data = widget.notification.data;
    if (data == null) {
      setState(() => _isLoading = false);
      return;
    }

    final marketProvider = Provider.of<MarketProvider>(context, listen: false);
    // Ensure watchlist is loaded
    if (!marketProvider.hasWatchedMarkets) {
      await marketProvider.loadWatchlist();
    }
    
    final Set<int> marketIds = {};

    // 1. 단일 market_id 확인
    if (data.containsKey('market_id')) {
      final id = data['market_id'];
      if (id is int) {
        marketIds.add(id);
      } else if (id is String) {
        marketIds.add(int.tryParse(id) ?? 0);
      }
    }

    // 2. 리스트 market_ids 확인
    if (data.containsKey('market_ids')) {
      final ids = data['market_ids'];
      if (ids is List) {
        for (var id in ids) {
          if (id is int) {
            marketIds.add(id);
          } else if (id is String) {
            marketIds.add(int.tryParse(id) ?? 0);
          }
        }
      }
    }

    // 3. 시장 정보 찾기 (관심 목록에서)
    for (var id in marketIds) {
      try {
        final market = marketProvider.watchlist.firstWhere(
          (m) => m.marketId == id,
          orElse: () => UserMarketInterest(
            id: 0, userId: 0, marketId: id, isActive: false, notificationEnabled: false
          ), // Dummy
        );
        if (market.id != 0 && market.marketCoordinates?.hasCoordinates == true) {
          _relatedMarkets.add(market);
        }
      } catch (e) {
        // 시장 찾기 실패: 무시
      }
    }

    // 4. 마커 생성
    for (var market in _relatedMarkets) {
      _markers.add(Marker(
        markerId: MarkerId(market.marketId.toString()),
        position: LatLng(
          market.marketCoordinates!.latitude!,
          market.marketCoordinates!.longitude!,
        ),
        infoWindow: InfoWindow(
          title: market.marketName ?? '시장',
          snippet: market.marketLocation,
        ),
        onTap: () {
          _moveCamera(market);
        },
      ));
    }

    setState(() => _isLoading = false);
  }

  void _moveCamera(UserMarketInterest market) {
    if (_mapController != null && market.marketCoordinates?.hasCoordinates == true) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(
            market.marketCoordinates!.latitude!,
            market.marketCoordinates!.longitude!,
          ),
          15.0, // 상세 보기 적절한 줌 레벨
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // 관련된 시장 정보가 없으면 기존처럼 텍스트만 보여주거나 안내 메시지
    if (_relatedMarkets.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('알림 상세')),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.notification.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text(widget.notification.body, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 20),
              const Text('⚠️ 관련된 시장 위치 정보를 찾을 수 없습니다.', style: TextStyle(color: Colors.grey)),
              if (widget.notification.data != null)
                Text('Data: ${widget.notification.data}'),
            ],
          ),
        ),
      );
    }

    final initialMarket = _relatedMarkets.first;
    final initialPosition = LatLng(
      initialMarket.marketCoordinates!.latitude!,
      initialMarket.marketCoordinates!.longitude!,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.notification.title),
      ),
      body: Column(
        children: [
          // 1. Google Map (상단)
          Expanded(
            flex: 2,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: initialPosition,
                zoom: 15.0,
              ),
              markers: _markers,
              onMapCreated: (controller) => _mapController = controller,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
            ),
          ),
          
          // 2. 정보 및 리스트 (하단)
          Expanded(
            flex: 1,
            child: Container(
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 알림 본문
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      widget.notification.body,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                  const Divider(height: 1),
                  // 시장 리스트 (2개 이상인 경우 유용, 1개여도 정보 표시)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Text(
                      '관련된 시장 (${_relatedMarkets.length})',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _relatedMarkets.length,
                      itemBuilder: (context, index) {
                        final market = _relatedMarkets[index];
                        return ListTile(
                          leading: const Icon(Icons.store_mall_directory, color: Colors.blue),
                          title: Text(market.marketName ?? '시장'),
                          subtitle: Text(market.marketLocation ?? ''),
                          trailing: const Icon(Icons.my_location),
                          onTap: () => _moveCamera(market),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
