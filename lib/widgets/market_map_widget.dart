import 'dart:ui' as ui;
import 'dart:math' as math;
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

  // 날씨 상태 텍스트 반환 (모델의 기존 getter 활용 및 디버깅)
  String _getWeatherLabel(WeatherData weather) {
    // 강수가 있으면 강수 형태 표시
    if (weather.pty != null && weather.pty != '0') {
      return weather.precipitationType;
    }
    // 하늘 상태 표시 (유효한 값만)
    if (['1', '3', '4'].contains(weather.sky)) {
      return weather.skyCondition;
    }
    // 디버깅을 위해 값이 이상하면 괄호 안에 표시 (예: "알 수 없음(null)")
    return '알 수 없음(${weather.sky ?? "null"})';
  }

  // 날씨 아이콘 그리기
  void _drawWeatherIcon(Canvas canvas, Offset offset, double size, WeatherData weather) {
    final paint = Paint()..style = PaintingStyle.fill;
    
    // 강수 여부 확인
    bool hasPrecipitation = weather.pty != null && weather.pty != '0';
    
    if (hasPrecipitation) {
      // 구름 베이스
      paint.color = Colors.grey[300]!;
      canvas.drawCircle(offset + Offset(size * 0.3, size * 0.5), size * 0.25, paint);
      canvas.drawCircle(offset + Offset(size * 0.5, size * 0.4), size * 0.3, paint);
      canvas.drawCircle(offset + Offset(size * 0.7, size * 0.5), size * 0.25, paint);
      
      // 강수 형태
      paint.strokeWidth = size * 0.1;
      paint.strokeCap = StrokeCap.round;
      
      if (weather.pty == '1' || weather.pty == '4') { // 비 또는 소나기
        paint.color = Colors.blue[300]!;
        paint.style = PaintingStyle.stroke;
        final path = Path();
        path.moveTo(offset.dx + size * 0.3, offset.dy + size * 0.7);
        path.lineTo(offset.dx + size * 0.2, offset.dy + size * 0.9);
        path.moveTo(offset.dx + size * 0.5, offset.dy + size * 0.7);
        path.lineTo(offset.dx + size * 0.4, offset.dy + size * 0.9);
        path.moveTo(offset.dx + size * 0.7, offset.dy + size * 0.7);
        path.lineTo(offset.dx + size * 0.6, offset.dy + size * 0.9);
        canvas.drawPath(path, paint);
      } else if (weather.pty == '3') { // 눈
        paint.color = Colors.white;
        paint.style = PaintingStyle.fill;
        canvas.drawCircle(offset + Offset(size * 0.3, size * 0.8), size * 0.08, paint);
        canvas.drawCircle(offset + Offset(size * 0.5, size * 0.8), size * 0.08, paint);
        canvas.drawCircle(offset + Offset(size * 0.7, size * 0.8), size * 0.08, paint);
      } else { // 비/눈 (진눈깨비)
        paint.color = Colors.blue[300]!;
        paint.style = PaintingStyle.stroke;
        canvas.drawLine(Offset(offset.dx + size * 0.3, offset.dy + size * 0.7), 
                       Offset(offset.dx + size * 0.2, offset.dy + size * 0.9), paint);
        paint.style = PaintingStyle.fill;
        paint.color = Colors.white;
        canvas.drawCircle(offset + Offset(size * 0.6, size * 0.8), size * 0.08, paint);
      }
    } else {
      // 하늘 상태
      if (weather.sky == '1') { // 맑음
        paint.color = Colors.orange;
        canvas.drawCircle(offset + Offset(size * 0.5, size * 0.5), size * 0.35, paint);
        // 햇살 (선택적)
      } else if (weather.sky == '3') { // 구름많음
        paint.color = Colors.orange; // 해
        canvas.drawCircle(offset + Offset(size * 0.4, size * 0.4), size * 0.2, paint);
        paint.color = Colors.grey[300]!; // 구름
        canvas.drawCircle(offset + Offset(size * 0.5, size * 0.6), size * 0.25, paint);
        canvas.drawCircle(offset + Offset(size * 0.7, size * 0.55), size * 0.2, paint);
      } else { // 흐림 (Sky 4) 또는 기타
        paint.color = Colors.grey[400]!;
        canvas.drawCircle(offset + Offset(size * 0.3, size * 0.5), size * 0.25, paint);
        canvas.drawCircle(offset + Offset(size * 0.5, size * 0.4), size * 0.3, paint);
        canvas.drawCircle(offset + Offset(size * 0.7, size * 0.5), size * 0.25, paint);
      }
    }
  }

  // 날씨 상태에 따른 마커 배경색 반환
  Color _getMarkerColor(WeatherData? weather) {
    if (weather == null) return const Color(0xFF78909C);
    
    // 강수가 있으면 무조건 어두운 파랑/하늘색 계열
    if (weather.pty != null && weather.pty != '0') {
       return const Color(0xFF455A64); // 강수 시 배경을 좀 더 어둡게 하여 아이콘 강조
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
      final label = _getWeatherLabel(weather);
      final tempStr = weather.temp != null ? '${weather.temp!.toStringAsFixed(0)}°' : '-°';
      // 온도계 이모지 추가
      weatherText = '$label 🌡️$tempStr';
    }

    final Color bgColor = _getMarkerColor(weather);
    const double pixelRatio = 2.5;

    // 스케일 적용된 디멘션
    final double baseFontSize = 13 * scale;
    final double smallFontSize = 12 * scale;
    final double paddingH = 12 * scale;
    final double paddingV = 8 * scale;
    final double arrowHeight = 8 * scale;
    final double borderRadius = 8 * scale;
    final double arrowHalfWidth = 6 * scale;
    
    // 아이콘 크기
    final double iconSize = weather != null ? 16 * scale : 0;
    final double iconSpacing = weather != null ? 4 * scale : 0;

    final nameStyle = ui.TextStyle(
      color: const Color(0xFFFFFFFF),
      fontSize: baseFontSize,
      fontWeight: ui.FontWeight.w700,
    );
    final weatherStyle = ui.TextStyle(
      color: const Color(0xFFFFFFFF),
      fontSize: smallFontSize,
      fontWeight: ui.FontWeight.w500,
    );

    // 이름 텍스트 레이아웃
    final nameParagraph = ui.ParagraphBuilder(ui.ParagraphStyle(textAlign: ui.TextAlign.center))
      ..pushStyle(nameStyle)
      ..addText(marketName);
    final nameP = nameParagraph.build()..layout(const ui.ParagraphConstraints(width: 300));

    double contentHeight = nameP.height;
    double maxContentWidth = nameP.maxIntrinsicWidth;

    // 날씨 텍스트 레이아웃
    ui.Paragraph? weatherP;
    if (weatherText.isNotEmpty) {
      final weatherParagraph = ui.ParagraphBuilder(ui.ParagraphStyle(textAlign: ui.TextAlign.left))
        ..pushStyle(weatherStyle)
        ..addText(weatherText);
      weatherP = weatherParagraph.build()..layout(const ui.ParagraphConstraints(width: 300));
      
      contentHeight += math.max(weatherP.height, iconSize) + 2 * scale;
      
      final weatherRowWidth = iconSize + iconSpacing + weatherP.maxIntrinsicWidth;
      if (weatherRowWidth > maxContentWidth) {
        maxContentWidth = weatherRowWidth;
      }
    }

    final double bubbleWidth = maxContentWidth + paddingH * 2;
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

    // 화살표
    final arrowPath = Path()
      ..moveTo(bubbleWidth / 2 - arrowHalfWidth, bubbleHeight)
      ..lineTo(bubbleWidth / 2, bubbleHeight + arrowHeight)
      ..lineTo(bubbleWidth / 2 + arrowHalfWidth, bubbleHeight)
      ..close();
    canvas.drawPath(arrowPath, bgPaint);

    // 텍스트 그리기
    double currentY = paddingV;
    
    // 이름 (가운데 정렬)
    nameP.layout(ui.ParagraphConstraints(width: bubbleWidth - paddingH * 2));
    canvas.drawParagraph(nameP, Offset(paddingH + (bubbleWidth - paddingH * 2 - nameP.maxIntrinsicWidth) / 2, currentY));
    currentY += nameP.height + 2 * scale;

    // 날씨 (아이콘 + 텍스트, 가운데 정렬)
    if (weatherP != null && weather != null) {
      final totalRowWidth = iconSize + iconSpacing + weatherP.maxIntrinsicWidth;
      final startX = (bubbleWidth - totalRowWidth) / 2;
      
      // 아이콘 그리기
      _drawWeatherIcon(canvas, Offset(startX, currentY - 2 * scale), iconSize, weather);
      
      // 날씨 텍스트 
      canvas.drawParagraph(weatherP, Offset(startX + iconSize + iconSpacing, currentY + (iconSize - weatherP.height) / 2 - 2 * scale));
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
            // 마커 존재 여부와 상관없이 사용자 위치로 초기화 시도
            _adjustCameraBounds();
          },
        ),
        // 마커 로딩 표시
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
    if (_mapController == null) return;

    try {
      final position = await LocationService().getCurrentPosition();

      if (position != null) {
        // 사용자 위치로 카메라 이동 (줌 기본 13.5)
        _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(position.latitude, position.longitude),
              zoom: 13.5,
            ),
          ),
        );
      } else if (_markers.isNotEmpty) {
        // 위치를 못 가져오고 마커가 있으면 마커 전체 보기
        _fitAllMarkers();
      }
    } catch (e) {
      print('카메라 이동 중 오류: $e');
      if (_markers.isNotEmpty) {
        _fitAllMarkers();
      }
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
