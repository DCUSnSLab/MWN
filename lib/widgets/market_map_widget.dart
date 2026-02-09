import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/market.dart';
import '../models/weather.dart';

class MarketMapWidget extends StatefulWidget {
  final List<UserMarketInterest> markets;
  final Map<int, WeatherData> weatherData;

  const MarketMapWidget({
    super.key,
    required this.markets,
    required this.weatherData,
  });

  @override
  State<MarketMapWidget> createState() => _MarketMapWidgetState();
}

class _MarketMapWidgetState extends State<MarketMapWidget> {
  late GoogleMapController _mapController;
  final Set<Marker> _markers = {};
  
  // 서울 시청을 기본 위치로 설정
  static const CameraPosition _kDefaultPosition = CameraPosition(
    target: LatLng(37.5665, 126.9780),
    zoom: 11.0,
  );

  @override
  void initState() {
    super.initState();
    _createMarkers();
  }

  @override
  void didUpdateWidget(covariant MarketMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.markets != widget.markets || oldWidget.weatherData != widget.weatherData) {
      _createMarkers();
    }
  }

  void _createMarkers() {
    _markers.clear();
    for (var market in widget.markets) {
      if (market.marketCoordinates?.hasCoordinates == true) {
        final lat = market.marketCoordinates!.latitude!;
        final lng = market.marketCoordinates!.longitude!;
        final weather = widget.weatherData[market.marketId];
        
        // 날씨 정보가 있으면 스니펫에 포함
        String snippet = market.marketLocation ?? '';
        if (weather != null) {
          snippet += '\n🌡️ ${weather.temp ?? '-'}°C  ${weather.skyCondition}';
        }

        final marker = Marker(
          markerId: MarkerId(market.marketId.toString()),
          position: LatLng(lat, lng),
          infoWindow: InfoWindow(
            title: market.marketName,
            snippet: snippet,
          ),
        );
        _markers.add(marker);
      }
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      mapType: MapType.normal,
      initialCameraPosition: _kDefaultPosition,
      markers: _markers,
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      zoomControlsEnabled: true,
      onMapCreated: (GoogleMapController controller) {
        _mapController = controller;
        // 마커가 있으면 마커들이 다 보이도록 카메라 이동
        if (_markers.isNotEmpty) {
          _fitBounds();
        }
      },
    );
  }

  void _fitBounds() {
    if (_markers.isEmpty) return;

    double minLat = 90.0;
    double maxLat = -90.0;
    double minLng = 180.0;
    double maxLng = -180.0;

    for (var marker in _markers) {
      final lat = marker.position.latitude;
      final lng = marker.position.longitude;
      if (lat < minLat) minLat = lat;
      if (lat > maxLat) maxLat = lat;
      if (lng < minLng) minLng = lng;
      if (lng > maxLng) maxLng = lng;
    }

    _mapController.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        50.0, // padding
      ),
    );
  }
}
