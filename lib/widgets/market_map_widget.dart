import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/market.dart';
import '../models/weather.dart';
import '../services/location_service.dart';

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
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  bool _markersReady = false;

  double _currentZoom = 11.0;
  int _currentZoomBucket = -1; // 현재 줌 버킷 (변경 감지용)
  bool _isRegenerating = false; // 중복 재생성 방지

  // 서울 시청을 기본 위치로 설정
  static const CameraPosition _kDefaultPosition = CameraPosition(
    target: LatLng(37.5665, 126.9780),
    zoom: 11.0,
  );

  // 줌 레벨을 버킷으로 변환 (불필요한 재생성 방지)
  int _getZoomBucket(double zoom) {
    if (zoom <= 7) return 0;
    if (zoom <= 9) return 1;
    if (zoom <= 10) return 2;
    if (zoom <= 11) return 3;
    if (zoom <= 13) return 4;
    if (zoom <= 15) return 5;
    return 6;
  }

  // 줌 버킷에 따른 스케일 팩터 반환
  double _getScaleFactor(int bucket) {
    switch (bucket) {
      case 0: return 0.45; // 아주 축소
      case 1: return 0.55;
      case 2: return 0.7;
      case 3: return 0.85; // 기본 (zoom ~11)
      case 4: return 1.0;
      case 5: return 1.15;
      case 6: return 1.3;  // 아주 확대
      default: return 0.85;
    }
  }

  @override
  void initState() {
    super.initState();
    _currentZoomBucket = _getZoomBucket(_currentZoom);
    _createMarkers();
  }

  @override
  void didUpdateWidget(covariant MarketMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.markets != widget.markets || oldWidget.weatherData != widget.weatherData) {
      _createMarkers();
    }
  }

  // 줌 변경 시 마커 재생성
  void _onCameraIdle() async {
    if (_mapController == null) return;
    final zoom = await _mapController!.getZoomLevel();
    final newBucket = _getZoomBucket(zoom);

    if (newBucket != _currentZoomBucket) {
      _currentZoom = zoom;
      _currentZoomBucket = newBucket;
      _createMarkers();
    }
  }

  // 날씨 상태에 따른 이모지 반환
  String _getWeatherEmoji(WeatherData weather) {
    switch (weather.pty) {
      case '1': return '🌧️';
      case '2': return '🌨️';
      case '3': return '❄️';
      case '4': return '🌦️';
    }
    switch (weather.sky) {
      case '1': return '☀️';
      case '3': return '⛅';
      case '4': return '☁️';
    }
    return '🌡️';
  }

  // 날씨 상태에 따른 마커 배경색 반환
  Color _getMarkerColor(WeatherData? weather) {
    if (weather == null) return const Color(0xFF78909C);
    switch (weather.pty) {
      case '1': return const Color(0xFF1976D2);
      case '2': return const Color(0xFF5C6BC0);
      case '3': return const Color(0xFF4FC3F7);
      case '4': return const Color(0xFF0288D1);
    }
    switch (weather.sky) {
      case '1': return const Color(0xFFFF8F00);
      case '3': return const Color(0xFF00897B);
      case '4': return const Color(0xFF546E7A);
    }
    return const Color(0xFF00897B);
  }

  // 커스텀 마커 비트맵 생성 (스케일 팩터 적용)
  Future<BitmapDescriptor> _createCustomMarkerBitmap({
    required String name,
    required WeatherData? weather,
    required double scale,
  }) async {
    final String marketName = name.length > 8 ? '${name.substring(0, 7)}…' : name;
    String weatherText = '';
    if (weather != null) {
      final emoji = _getWeatherEmoji(weather);
      final tempStr = weather.temp != null ? '${weather.temp!.toStringAsFixed(0)}°' : '-°';
      weatherText = '$emoji $tempStr';
    }

    final Color bgColor = _getMarkerColor(weather);
    const double pixelRatio = 2.5;

    // 스케일 적용된 폰트 크기
    final double nameFontSize = 13 * scale;
    final double weatherFontSize = 12 * scale;
    final double paddingH = 12 * scale;
    final double paddingV = 8 * scale;
    final double arrowHeight = 8 * scale;
    final double borderRadius = 8 * scale;
    final double arrowHalfWidth = 6 * scale;

    final nameStyle = ui.TextStyle(
      color: const Color(0xFFFFFFFF),
      fontSize: nameFontSize,
      fontWeight: ui.FontWeight.w700,
    );
    final weatherStyle = ui.TextStyle(
      color: const Color(0xFFFFFFFF),
      fontSize: weatherFontSize,
      fontWeight: ui.FontWeight.w500,
    );

    final nameParagraph = ui.ParagraphBuilder(ui.ParagraphStyle(textAlign: ui.TextAlign.center))
      ..pushStyle(nameStyle)
      ..addText(marketName);
    final nameP = nameParagraph.build()..layout(const ui.ParagraphConstraints(width: 300));

    double contentHeight = nameP.height;
    double contentWidth = nameP.maxIntrinsicWidth;

    ui.Paragraph? weatherP;
    if (weatherText.isNotEmpty) {
      final weatherParagraph = ui.ParagraphBuilder(ui.ParagraphStyle(textAlign: ui.TextAlign.center))
        ..pushStyle(weatherStyle)
        ..addText(weatherText);
      weatherP = weatherParagraph.build()..layout(const ui.ParagraphConstraints(width: 300));
      contentHeight += weatherP.height + 2 * scale;
      if (weatherP.maxIntrinsicWidth > contentWidth) {
        contentWidth = weatherP.maxIntrinsicWidth;
      }
    }

    final double bubbleWidth = contentWidth + paddingH * 2;
    final double bubbleHeight = contentHeight + paddingV * 2;
    final double totalHeight = bubbleHeight + arrowHeight;

    final int canvasWidth = (bubbleWidth * pixelRatio).ceil();
    final int canvasHeight = (totalHeight * pixelRatio).ceil();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, canvasWidth.toDouble(), canvasHeight.toDouble()));
    canvas.scale(pixelRatio);

    // 그림자
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 * scale);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(1, 1, bubbleWidth, bubbleHeight),
        Radius.circular(borderRadius),
      ),
      shadowPaint,
    );

    // 버블 배경
    final bgPaint = Paint()..color = bgColor;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, bubbleWidth, bubbleHeight),
        Radius.circular(borderRadius),
      ),
      bgPaint,
    );

    // 아래쪽 삼각형 화살표
    final arrowPath = Path()
      ..moveTo(bubbleWidth / 2 - arrowHalfWidth, bubbleHeight)
      ..lineTo(bubbleWidth / 2, bubbleHeight + arrowHeight)
      ..lineTo(bubbleWidth / 2 + arrowHalfWidth, bubbleHeight)
      ..close();
    canvas.drawPath(arrowPath, bgPaint);

    // 텍스트
    double textY = paddingV;
    nameP.layout(ui.ParagraphConstraints(width: bubbleWidth - paddingH * 2));
    canvas.drawParagraph(nameP, Offset(paddingH, textY));
    textY += nameP.height + 2 * scale;

    if (weatherP != null) {
      weatherP.layout(ui.ParagraphConstraints(width: bubbleWidth - paddingH * 2));
      final weatherX = paddingH + (bubbleWidth - paddingH * 2 - weatherP.maxIntrinsicWidth) / 2;
      canvas.drawParagraph(weatherP, Offset(weatherX < paddingH ? paddingH : weatherX, textY));
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(canvasWidth, canvasHeight);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.bytes(byteData!.buffer.asUint8List());
  }

  Future<void> _createMarkers() async {
    if (_isRegenerating) return;
    _isRegenerating = true;

    final scale = _getScaleFactor(_currentZoomBucket);
    final newMarkers = <Marker>{};

    for (var market in widget.markets) {
      if (market.marketCoordinates?.hasCoordinates == true) {
        final lat = market.marketCoordinates!.latitude!;
        final lng = market.marketCoordinates!.longitude!;
        final weather = widget.weatherData[market.marketId];

        final icon = await _createCustomMarkerBitmap(
          name: market.marketName ?? '시장',
          weather: weather,
          scale: scale,
        );

        final marker = Marker(
          markerId: MarkerId(market.marketId.toString()),
          position: LatLng(lat, lng),
          icon: icon,
          anchor: const Offset(0.5, 1.0),
          infoWindow: InfoWindow(
            title: market.marketName,
            snippet: market.marketLocation ?? '',
          ),
        );
        newMarkers.add(marker);
      }
    }

    _isRegenerating = false;

    if (mounted) {
      setState(() {
        _markers = newMarkers;
        _markersReady = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GoogleMap(
          mapType: MapType.normal,
          initialCameraPosition: _kDefaultPosition,
          markers: _markers,
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          zoomControlsEnabled: true,
          onCameraIdle: _onCameraIdle,
          onMapCreated: (GoogleMapController controller) {
            _mapController = controller;
            if (_markers.isNotEmpty) {
              _adjustCameraBounds();
            }
          },
        ),
        if (!_markersReady && widget.markets.isNotEmpty)
          const Positioned(
            top: 16,
            left: 0,
            right: 0,
            child: Center(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 8),
                      Text('마커 로딩 중...', style: TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _adjustCameraBounds() async {
    if (_markers.isEmpty || _mapController == null) return;

    try {
      final position = await LocationService().getCurrentPosition();

      if (position == null) {
        _fitAllMarkers();
        return;
      }

      final userLatLng = LatLng(position.latitude, position.longitude);

      double minDistance = double.infinity;
      LatLng? nearestMarketLatLng;

      for (var marker in _markers) {
        final distance = LocationService().calculateDistance(
          userLatLng.latitude,
          userLatLng.longitude,
          marker.position.latitude,
          marker.position.longitude,
        );

        if (distance < minDistance) {
          minDistance = distance;
          nearestMarketLatLng = marker.position;
        }
      }

      if (nearestMarketLatLng != null) {
        final double minLat = userLatLng.latitude < nearestMarketLatLng.latitude
            ? userLatLng.latitude : nearestMarketLatLng.latitude;
        final double maxLat = userLatLng.latitude > nearestMarketLatLng.latitude
            ? userLatLng.latitude : nearestMarketLatLng.latitude;
        final double minLng = userLatLng.longitude < nearestMarketLatLng.longitude
            ? userLatLng.longitude : nearestMarketLatLng.longitude;
        final double maxLng = userLatLng.longitude > nearestMarketLatLng.longitude
            ? userLatLng.longitude : nearestMarketLatLng.longitude;

        _mapController!.animateCamera(
          CameraUpdate.newLatLngBounds(
            LatLngBounds(
              southwest: LatLng(minLat, minLng),
              northeast: LatLng(maxLat, maxLng),
            ),
            100.0,
          ),
        );
      } else {
        _fitAllMarkers();
      }
    } catch (e) {
      print('카메라 이동 중 오류: $e');
      _fitAllMarkers();
    }
  }

  void _fitAllMarkers() {
    if (_markers.isEmpty || _mapController == null) return;

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

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        50.0,
      ),
    );
  }
}

