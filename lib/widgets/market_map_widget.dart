import 'dart:async';
import 'dart:collection';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/market.dart';
import '../models/weather.dart';
import '../services/location_service.dart';

/// 단순 LRU 캐시 (insertion-order LinkedHashMap 기반).
class _LruCache<K, V> {
  final int maxSize;
  final LinkedHashMap<K, V> _map = LinkedHashMap<K, V>();

  _LruCache(this.maxSize);

  V? operator [](K key) {
    final v = _map.remove(key);
    if (v != null) _map[key] = v; // touch
    return v;
  }

  void operator []=(K key, V value) {
    _map.remove(key);
    _map[key] = value;
    while (_map.length > maxSize) {
      _map.remove(_map.keys.first);
    }
  }

  bool containsKey(K key) => _map.containsKey(key);
  void removeWhere(bool Function(K, V) test) => _map.removeWhere(test);
}

class MarketMapWidget extends StatefulWidget {
  final List<UserMarketInterest> markets;
  final Map<int, WeatherData> weatherData;
  final bool isWeatherLoading;
  final String? weatherError;
  final Future<void> Function()? onRefresh;
  final void Function(UserMarketInterest market)? onMarketTap;
  final VoidCallback? onAddMarket;
  final VoidCallback? onDismissError;

  const MarketMapWidget({
    super.key,
    required this.markets,
    required this.weatherData,
    this.isWeatherLoading = false,
    this.weatherError,
    this.onRefresh,
    this.onMarketTap,
    this.onAddMarket,
    this.onDismissError,
  });

  @override
  State<MarketMapWidget> createState() => _MarketMapWidgetState();
}

class _MarketMapWidgetState extends State<MarketMapWidget> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  bool _markersReady = false;
  bool _initialCameraDone = false;
  int? _selectedMarketId;

  double _currentZoom = 8.0;
  int _currentZoomBucket = -1;
  bool _isRegenerating = false;
  bool _pendingRegen = false;

  // 마커 비트맵 LRU 캐시 (메모리 누수 방지)
  static const int _bitmapCacheMaxSize = 300;
  final _LruCache<String, BitmapDescriptor> _bitmapCache =
      _LruCache<String, BitmapDescriptor>(_bitmapCacheMaxSize);

  // 줌 이벤트 debounce 타이머 (livelock 방지 + 잦은 zoom 변경 흡수)
  Timer? _zoomDebounce;

  static const CameraPosition _kDefaultPosition = CameraPosition(
    target: LatLng(36.5, 127.8),
    zoom: 7.0,
  );

  int _getZoomBucket(double zoom) {
    if (zoom <= 7) return 0;
    if (zoom <= 9) return 1;
    if (zoom <= 10) return 2;
    if (zoom <= 11) return 3;
    if (zoom <= 13) return 4;
    if (zoom <= 15) return 5;
    return 6;
  }

  double _getScaleFactor(int bucket) {
    switch (bucket) {
      case 0: return 0.45;
      case 1: return 0.55;
      case 2: return 0.7;
      case 3: return 0.85;
      case 4: return 1.0;
      case 5: return 1.15;
      case 6: return 1.3;
      default: return 0.85;
    }
  }

  // 줌 버킷별 시장명 최대 길이 (0이면 이름 숨김)
  int _maxNameLength(int bucket) {
    if (bucket <= 1) return 0;   // 점만 표시
    if (bucket <= 3) return 7;   // 짧게
    return 14;                    // 거의 전체
  }

  // 클러스터링용 그리드 셀 크기 (도 단위, 0이면 클러스터링 안 함)
  double _clusterGridSize(int bucket) {
    switch (bucket) {
      case 0: return 0.30; // ~33km @ Korea lat
      case 1: return 0.15; // ~16km
      case 2: return 0.07; // ~8km
      default: return 0;
    }
  }

  String _cacheKey(UserMarketInterest market, WeatherData? weather, int bucket,
      {required bool selected, required int maxNameLen}) {
    final pty = weather?.pty ?? '_';
    final sky = weather?.sky ?? '_';
    final temp = weather?.temp != null ? weather!.temp!.round().toString() : '_';
    return '${market.marketId}|$bucket|$pty|$sky|$temp|n$maxNameLen|s${selected ? 1 : 0}';
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
    final oldIds = oldWidget.markets.map((m) => m.marketId).toSet();
    final newIds = widget.markets.map((m) => m.marketId).toSet();
    if (oldIds.length != newIds.length || !oldIds.containsAll(newIds)) {
      _bitmapCache.removeWhere((key, _) {
        if (key.startsWith('cluster:')) return true;
        final id = int.tryParse(key.split('|').first);
        return id == null || !newIds.contains(id);
      });
    }

    if (oldWidget.markets != widget.markets ||
        oldWidget.weatherData != widget.weatherData) {
      _createMarkers();
    }
  }

  void _onCameraIdle() {
    _zoomDebounce?.cancel();
    _zoomDebounce = Timer(const Duration(milliseconds: 200), () async {
      if (!mounted || _mapController == null) return;
      final zoom = await _mapController!.getZoomLevel();
      final newBucket = _getZoomBucket(zoom);
      if (newBucket != _currentZoomBucket) {
        _currentZoom = zoom;
        _currentZoomBucket = newBucket;
        _createMarkers();
      }
    });
  }

  @override
  void dispose() {
    _zoomDebounce?.cancel();
    super.dispose();
  }

  String _getWeatherLabel(WeatherData weather) {
    if (weather.pty != null && weather.pty != '0') {
      return weather.precipitationType;
    }
    if (['1', '3', '4'].contains(weather.sky)) {
      return weather.skyCondition;
    }
    return '알 수 없음(${weather.sky ?? "null"})';
  }

  void _drawWeatherIcon(Canvas canvas, Offset offset, double size, WeatherData weather) {
    final paint = Paint()..style = PaintingStyle.fill;
    bool hasPrecipitation = weather.pty != null && weather.pty != '0';

    if (hasPrecipitation) {
      paint.color = Colors.grey[300]!;
      canvas.drawCircle(offset + Offset(size * 0.3, size * 0.5), size * 0.25, paint);
      canvas.drawCircle(offset + Offset(size * 0.5, size * 0.4), size * 0.3, paint);
      canvas.drawCircle(offset + Offset(size * 0.7, size * 0.5), size * 0.25, paint);

      paint.strokeWidth = size * 0.1;
      paint.strokeCap = StrokeCap.round;

      if (weather.pty == '1' || weather.pty == '4') {
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
      } else if (weather.pty == '3') {
        paint.color = Colors.white;
        paint.style = PaintingStyle.fill;
        canvas.drawCircle(offset + Offset(size * 0.3, size * 0.8), size * 0.08, paint);
        canvas.drawCircle(offset + Offset(size * 0.5, size * 0.8), size * 0.08, paint);
        canvas.drawCircle(offset + Offset(size * 0.7, size * 0.8), size * 0.08, paint);
      } else {
        paint.color = Colors.blue[300]!;
        paint.style = PaintingStyle.stroke;
        canvas.drawLine(Offset(offset.dx + size * 0.3, offset.dy + size * 0.7),
                       Offset(offset.dx + size * 0.2, offset.dy + size * 0.9), paint);
        paint.style = PaintingStyle.fill;
        paint.color = Colors.white;
        canvas.drawCircle(offset + Offset(size * 0.6, size * 0.8), size * 0.08, paint);
      }
    } else {
      if (weather.sky == '1') {
        paint.color = Colors.orange;
        canvas.drawCircle(offset + Offset(size * 0.5, size * 0.5), size * 0.35, paint);
      } else if (weather.sky == '3') {
        paint.color = Colors.orange;
        canvas.drawCircle(offset + Offset(size * 0.4, size * 0.4), size * 0.2, paint);
        paint.color = Colors.grey[300]!;
        canvas.drawCircle(offset + Offset(size * 0.5, size * 0.6), size * 0.25, paint);
        canvas.drawCircle(offset + Offset(size * 0.7, size * 0.55), size * 0.2, paint);
      } else {
        paint.color = Colors.grey[400]!;
        canvas.drawCircle(offset + Offset(size * 0.3, size * 0.5), size * 0.25, paint);
        canvas.drawCircle(offset + Offset(size * 0.5, size * 0.4), size * 0.3, paint);
        canvas.drawCircle(offset + Offset(size * 0.7, size * 0.5), size * 0.25, paint);
      }
    }
  }

  Color _getMarkerColor(WeatherData? weather) {
    if (weather == null) return const Color(0xFF78909C);
    if (weather.pty != null && weather.pty != '0') {
      return const Color(0xFF455A64);
    }
    switch (weather.sky) {
      case '1': return const Color(0xFFFF8F00);
      case '3': return const Color(0xFF00897B);
      case '4': return const Color(0xFF546E7A);
    }
    return const Color(0xFF00897B);
  }

  // 커스텀 마커 비트맵 생성
  Future<BitmapDescriptor> _createCustomMarkerBitmap({
    required String name,
    required WeatherData? weather,
    required double scale,
    required int maxNameLen,
    required bool selected,
  }) async {
    // 이름 길이 정책
    String marketName;
    if (maxNameLen == 0) {
      marketName = '';
    } else if (name.length > maxNameLen) {
      marketName = '${name.substring(0, maxNameLen - 1)}…';
    } else {
      marketName = name;
    }

    String weatherText = '';
    if (weather != null) {
      final label = _getWeatherLabel(weather);
      final tempStr = weather.temp != null ? '${weather.temp!.toStringAsFixed(0)}°' : '-°';
      weatherText = '$label 🌡️$tempStr';
    }

    final Color bgColor = _getMarkerColor(weather);
    const double pixelRatio = 2.5;

    // 사이즈 일괄 조정 노브
    const double popupShrink = 0.6;
    final double s = scale * popupShrink;

    final double baseFontSize = 13 * s;
    final double smallFontSize = 12 * s;
    final double paddingH = 12 * s;
    final double paddingV = 8 * s;
    final double arrowHeight = 8 * s;
    final double borderRadius = 8 * s;
    final double arrowHalfWidth = 6 * s;

    final double iconSize = weather != null ? 16 * s : 0;
    final double iconSpacing = weather != null ? 4 * s : 0;

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

    double contentHeight = 0;
    double maxContentWidth = 0;

    ui.Paragraph? nameP;
    if (marketName.isNotEmpty) {
      final builder = ui.ParagraphBuilder(ui.ParagraphStyle(textAlign: ui.TextAlign.center))
        ..pushStyle(nameStyle)
        ..addText(marketName);
      nameP = builder.build()..layout(const ui.ParagraphConstraints(width: 300));
      contentHeight += nameP.height;
      maxContentWidth = math.max(maxContentWidth, nameP.maxIntrinsicWidth);
    }

    ui.Paragraph? weatherP;
    if (weatherText.isNotEmpty) {
      final builder = ui.ParagraphBuilder(ui.ParagraphStyle(textAlign: ui.TextAlign.left))
        ..pushStyle(weatherStyle)
        ..addText(weatherText);
      weatherP = builder.build()..layout(const ui.ParagraphConstraints(width: 300));

      contentHeight += math.max(weatherP.height, iconSize) + (nameP != null ? 2 * s : 0);

      final weatherRowWidth = iconSize + iconSpacing + weatherP.maxIntrinsicWidth;
      maxContentWidth = math.max(maxContentWidth, weatherRowWidth);
    }

    // 이름·날씨 모두 빈 경우 작은 점 마커
    if (contentHeight == 0) {
      contentHeight = 6 * s;
      maxContentWidth = 6 * s;
    }

    final double bubbleWidth = maxContentWidth + paddingH * 2;
    final double bubbleHeight = contentHeight + paddingV * 2;
    final double totalHeight = bubbleHeight + arrowHeight;

    final int canvasWidth = (bubbleWidth * pixelRatio).ceil();
    final int canvasHeight = (totalHeight * pixelRatio).ceil();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, canvasWidth.toDouble(), canvasHeight.toDouble()));
    canvas.scale(pixelRatio);

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 * s);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(1, 1, bubbleWidth, bubbleHeight),
        Radius.circular(borderRadius),
      ),
      shadowPaint,
    );

    final bgPaint = Paint()..color = bgColor;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, bubbleWidth, bubbleHeight),
        Radius.circular(borderRadius),
      ),
      bgPaint,
    );

    // 선택된 마커는 흰색 테두리 추가
    if (selected) {
      final borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * s;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, bubbleWidth, bubbleHeight),
          Radius.circular(borderRadius),
        ),
        borderPaint,
      );
    }

    final arrowPath = Path()
      ..moveTo(bubbleWidth / 2 - arrowHalfWidth, bubbleHeight)
      ..lineTo(bubbleWidth / 2, bubbleHeight + arrowHeight)
      ..lineTo(bubbleWidth / 2 + arrowHalfWidth, bubbleHeight)
      ..close();
    canvas.drawPath(arrowPath, bgPaint);

    double currentY = paddingV;
    if (nameP != null) {
      nameP.layout(ui.ParagraphConstraints(width: bubbleWidth - paddingH * 2));
      canvas.drawParagraph(nameP, Offset(paddingH + (bubbleWidth - paddingH * 2 - nameP.maxIntrinsicWidth) / 2, currentY));
      currentY += nameP.height + 2 * s;
    }

    if (weatherP != null && weather != null) {
      final totalRowWidth = iconSize + iconSpacing + weatherP.maxIntrinsicWidth;
      final startX = (bubbleWidth - totalRowWidth) / 2;
      _drawWeatherIcon(canvas, Offset(startX, currentY - 2 * s), iconSize, weather);
      canvas.drawParagraph(
        weatherP,
        Offset(startX + iconSize + iconSpacing, currentY + (iconSize - weatherP.height) / 2 - 2 * s),
      );
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(canvasWidth, canvasHeight);
    try {
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      return BitmapDescriptor.bytes(byteData!.buffer.asUint8List());
    } finally {
      img.dispose();
      picture.dispose();
    }
  }

  // 클러스터 마커 비트맵 생성
  Future<BitmapDescriptor> _createClusterBitmap(int count, Color color, double scale) async {
    const double pixelRatio = 2.5;
    final double s = scale * 0.85;
    final double radius = 18 * s;
    final double fontSize = 13 * s;
    final double padding = 4;
    final double canvasSize = (radius + padding) * 2 * pixelRatio;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, canvasSize, canvasSize));
    canvas.scale(pixelRatio);

    final center = Offset(radius + padding, radius + padding);

    final ringPaint = Paint()..color = color.withValues(alpha: 0.25);
    canvas.drawCircle(center, radius + 4 * s, ringPaint);
    final ringPaint2 = Paint()..color = color.withValues(alpha: 0.45);
    canvas.drawCircle(center, radius + 2 * s, ringPaint2);

    final bgPaint = Paint()..color = color;
    canvas.drawCircle(center, radius, bgPaint);

    final builder = ui.ParagraphBuilder(ui.ParagraphStyle(textAlign: ui.TextAlign.center))
      ..pushStyle(ui.TextStyle(
        color: Colors.white,
        fontSize: fontSize,
        fontWeight: ui.FontWeight.w700,
      ))
      ..addText('$count');
    final p = builder.build()..layout(ui.ParagraphConstraints(width: radius * 2));
    canvas.drawParagraph(
      p,
      Offset(center.dx - p.maxIntrinsicWidth / 2, center.dy - p.height / 2),
    );

    final picture = recorder.endRecording();
    final img = await picture.toImage(canvasSize.toInt(), canvasSize.toInt());
    try {
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      return BitmapDescriptor.bytes(byteData!.buffer.asUint8List());
    } finally {
      img.dispose();
      picture.dispose();
    }
  }

  Future<void> _createMarkers() async {
    if (_isRegenerating) {
      _pendingRegen = true;
      return;
    }
    _isRegenerating = true;

    try {
      final scale = _getScaleFactor(_currentZoomBucket);
      final bucket = _currentZoomBucket;
      final maxNameLen = _maxNameLength(bucket);
      final gridSize = _clusterGridSize(bucket);
      final markets = widget.markets;
      final weatherData = widget.weatherData;
      final onTap = widget.onMarketTap;
      final selectedId = _selectedMarketId;

      final items = markets
          .where((m) => m.marketCoordinates?.hasCoordinates == true)
          .toList();

      // 그리드 셀로 그룹화 (클러스터링)
      final groups = <String, List<UserMarketInterest>>{};
      for (final m in items) {
        final lat = m.marketCoordinates!.latitude!;
        final lng = m.marketCoordinates!.longitude!;
        String key;
        if (gridSize > 0) {
          key = '${(lat / gridSize).floor()}:${(lng / gridSize).floor()}';
        } else {
          key = 'single:${m.marketId}';
        }
        groups.putIfAbsent(key, () => []).add(m);
      }

      // 캐시된 마커는 즉시, 새로 만들 마커는 await
      final cachedMarkers = <Marker>{};
      final pendingTasks = <Future<Marker?>>[];

      groups.forEach((key, list) {
        if (list.length == 1) {
          final m = list.first;
          final lat = m.marketCoordinates!.latitude!;
          final lng = m.marketCoordinates!.longitude!;
          final weather = weatherData[m.marketId];
          final isSelected = m.marketId == selectedId;
          final cacheKey = _cacheKey(m, weather, bucket,
              selected: isSelected, maxNameLen: maxNameLen);
          final cached = _bitmapCache[cacheKey];
          if (cached != null) {
            cachedMarkers.add(_buildMarker(
              m: m, lat: lat, lng: lng, icon: cached,
              isSelected: isSelected, onTap: onTap,
            ));
          } else {
            pendingTasks.add(() async {
              final icon = await _createCustomMarkerBitmap(
                name: m.marketName ?? '시장',
                weather: weather,
                scale: scale * (isSelected ? 1.18 : 1.0),
                maxNameLen: maxNameLen,
                selected: isSelected,
              );
              _bitmapCache[cacheKey] = icon;
              return _buildMarker(
                m: m, lat: lat, lng: lng, icon: icon,
                isSelected: isSelected, onTap: onTap,
              );
            }());
          }
        } else {
          // 클러스터
          double sumLat = 0, sumLng = 0;
          final colorCount = <int, int>{};
          for (final m in list) {
            sumLat += m.marketCoordinates!.latitude!;
            sumLng += m.marketCoordinates!.longitude!;
            final w = weatherData[m.marketId];
            final c = _getMarkerColor(w).toARGB32();
            colorCount[c] = (colorCount[c] ?? 0) + 1;
          }
          final centerLat = sumLat / list.length;
          final centerLng = sumLng / list.length;
          int domColor = 0xFF78909C;
          int maxC = 0;
          colorCount.forEach((c, n) {
            if (n > maxC) {
              maxC = n;
              domColor = c;
            }
          });

          final cacheKey = 'cluster:${list.length}:$bucket:$domColor';
          final cached = _bitmapCache[cacheKey];
          final clusterId = MarkerId('cluster:$key:${list.length}');
          final pos = LatLng(centerLat, centerLng);

          Marker buildCluster(BitmapDescriptor icon) {
            return Marker(
              markerId: clusterId,
              position: pos,
              icon: icon,
              anchor: const Offset(0.5, 0.5),
              consumeTapEvents: true,
              onTap: () async {
                final c = _mapController;
                if (c == null) return;
                final z = await c.getZoomLevel();
                c.animateCamera(CameraUpdate.newCameraPosition(
                  CameraPosition(target: pos, zoom: z + 2),
                ));
              },
            );
          }

          if (cached != null) {
            cachedMarkers.add(buildCluster(cached));
          } else {
            pendingTasks.add(() async {
              final icon = await _createClusterBitmap(
                list.length,
                Color(domColor),
                scale,
              );
              _bitmapCache[cacheKey] = icon;
              return buildCluster(icon);
            }());
          }
        }
      });

      // 1단계: 캐시 hit 한 마커들 즉시 표시 (깜빡임 완화)
      if (mounted && cachedMarkers.isNotEmpty) {
        setState(() {
          _markers = cachedMarkers;
          _markersReady = true;
        });
      }

      // 2단계: 새로 그릴 마커 await
      if (pendingTasks.isNotEmpty) {
        final fresh = await Future.wait(pendingTasks);
        final freshSet = fresh.whereType<Marker>().toSet();
        if (mounted) {
          setState(() {
            _markers = {...cachedMarkers, ...freshSet};
            _markersReady = true;
          });
        }
      } else if (mounted) {
        setState(() => _markersReady = true);
      }

      // 초기 카메라 (마커가 처음 준비된 후 1회)
      if (!_initialCameraDone && _markers.isNotEmpty && _mapController != null) {
        _initialCameraDone = true;
        _adjustCameraTwoStep();
      }
    } finally {
      _isRegenerating = false;
      if (_pendingRegen) {
        _pendingRegen = false;
        // ignore: unawaited_futures
        _createMarkers();
      }
    }
  }

  Marker _buildMarker({
    required UserMarketInterest m,
    required double lat,
    required double lng,
    required BitmapDescriptor icon,
    required bool isSelected,
    required void Function(UserMarketInterest)? onTap,
  }) {
    return Marker(
      markerId: MarkerId(m.marketId.toString()),
      position: LatLng(lat, lng),
      icon: icon,
      anchor: const Offset(0.5, 1.0),
      zIndexInt: isSelected ? 100 : 0,
      consumeTapEvents: true,
      onTap: onTap == null
          ? null
          : () {
              setState(() => _selectedMarketId = m.marketId);
              _createMarkers();
              onTap(m);
            },
    );
  }

  // 2단계 카메라 이동: 마커 전체 → 잠시 후 → 사용자 위치
  Future<void> _adjustCameraTwoStep() async {
    if (_mapController == null) return;

    // Step 1: 마커 전체 보이게 fit
    _fitAllMarkers();
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted || _mapController == null) return;

    // Step 2: 사용자 위치가 있으면 그쪽으로 이동
    try {
      final position = await LocationService().getCurrentPosition();
      if (position != null && _mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(position.latitude, position.longitude),
              zoom: 12,
            ),
          ),
        );
      }
    } catch (e) {
      // 위치 못 가져와도 무시 (이미 fit 한 상태 유지)
    }
  }

  void _fitAllMarkers() {
    if (_markers.isEmpty || _mapController == null) return;
    double minLat = 90.0, maxLat = -90.0, minLng = 180.0, maxLng = -180.0;
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
        60.0,
      ),
    );
  }

  Future<void> _zoomIn() async {
    final c = _mapController;
    if (c == null) return;
    await c.animateCamera(CameraUpdate.zoomIn());
  }

  Future<void> _zoomOut() async {
    final c = _mapController;
    if (c == null) return;
    await c.animateCamera(CameraUpdate.zoomOut());
  }

  Future<void> _goToMyLocation() async {
    final c = _mapController;
    if (c == null) return;
    try {
      final pos = await LocationService().getCurrentPosition();
      if (pos == null) return;
      await c.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: LatLng(pos.latitude, pos.longitude), zoom: 13.5),
        ),
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEmpty = widget.markets.isEmpty;

    return Stack(
      children: [
        GoogleMap(
          mapType: MapType.normal,
          initialCameraPosition: _kDefaultPosition,
          markers: _markers,
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          style: isDark ? _kDarkMapStyle : null,
          onCameraIdle: _onCameraIdle,
          onTap: (_) {
            if (_selectedMarketId != null) {
              setState(() => _selectedMarketId = null);
              _createMarkers();
            }
          },
          onMapCreated: (GoogleMapController controller) {
            _mapController = controller;
            if (_markers.isNotEmpty && !_initialCameraDone) {
              _initialCameraDone = true;
              _adjustCameraTwoStep();
            }
          },
        ),

        // 빈 상태 오버레이
        if (isEmpty)
          Positioned.fill(
            child: IgnorePointer(
              ignoring: false,
              child: Center(
                child: Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.storefront_outlined,
                            size: 40, color: Colors.blueGrey),
                        const SizedBox(height: 8),
                        const Text(
                          '관심 시장이 없습니다',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          '관심 시장을 추가하면 지도에서 한눈에 볼 수 있어요.',
                          style: TextStyle(fontSize: 12, color: Colors.black54),
                          textAlign: TextAlign.center,
                        ),
                        if (widget.onAddMarket != null) ...[
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: widget.onAddMarket,
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('관심 시장 추가'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

        // 로딩 토스트
        if (!isEmpty &&
            ((!_markersReady && widget.markets.isNotEmpty) ||
                widget.isWeatherLoading))
          Positioned(
            top: 12,
            left: 0,
            right: 0,
            child: Center(
              child: Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 11,
                        height: 11,
                        child: CircularProgressIndicator(strokeWidth: 1.5),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        widget.isWeatherLoading ? '날씨 정보 불러오는 중...' : '마커 로딩 중...',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // 에러 배너
        if (widget.weatherError != null && !widget.isWeatherLoading)
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Material(
              elevation: 3,
              borderRadius: BorderRadius.circular(6),
              color: Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Row(
                  children: [
                    Icon(Icons.error_outline,
                        size: 14, color: Colors.red.shade700),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        widget.weatherError!,
                        style: TextStyle(
                            fontSize: 11, color: Colors.red.shade900),
                      ),
                    ),
                    if (widget.onRefresh != null)
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          minimumSize: const Size(0, 24),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () async {
                          await widget.onRefresh!();
                        },
                        child: const Text('재시도', style: TextStyle(fontSize: 11)),
                      ),
                    if (widget.onDismissError != null)
                      InkWell(
                        onTap: widget.onDismissError,
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: Icon(Icons.close,
                              size: 14, color: Colors.red.shade700),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

        // 범례
        if (!isEmpty)
          const Positioned(
            top: 12,
            left: 12,
            child: _MapLegend(),
          ),

        // 우하단 컨트롤 스택
        if (!isEmpty)
          Positioned(
            bottom: 20,
            right: 12,
            child: Column(
              children: [
                _MapControlButton(
                  icon: Icons.add,
                  tooltip: '확대',
                  onTap: _zoomIn,
                ),
                const SizedBox(height: 4),
                _MapControlButton(
                  icon: Icons.remove,
                  tooltip: '축소',
                  onTap: _zoomOut,
                ),
                const SizedBox(height: 8),
                _MapControlButton(
                  icon: Icons.my_location,
                  tooltip: '내 위치로',
                  onTap: _goToMyLocation,
                ),
                if (widget.onRefresh != null) ...[
                  const SizedBox(height: 8),
                  _MapControlButton(
                    icon: Icons.refresh,
                    tooltip: '날씨 새로고침',
                    primary: true,
                    onTap: widget.isWeatherLoading
                        ? null
                        : () async {
                            await widget.onRefresh!();
                          },
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _MapControlButton extends StatelessWidget {
  final IconData icon;
  final String? tooltip;
  final VoidCallback? onTap;
  final bool primary;

  const _MapControlButton({
    required this.icon,
    this.tooltip,
    this.onTap,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    final bg = primary ? Theme.of(context).colorScheme.primary : Colors.white;
    final fg = primary ? Colors.white : Colors.black87;
    final btn = Material(
      elevation: 3,
      shape: const CircleBorder(),
      color: bg,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            icon,
            size: 18,
            color: disabled ? fg.withValues(alpha: 0.4) : fg,
          ),
        ),
      ),
    );
    return tooltip != null ? Tooltip(message: tooltip!, child: btn) : btn;
  }
}

class _MapLegend extends StatefulWidget {
  const _MapLegend();

  @override
  State<_MapLegend> createState() => _MapLegendState();
}

class _MapLegendState extends State<_MapLegend> {
  bool _expanded = false;

  static const _items = <_LegendItem>[
    _LegendItem(Color(0xFFFF8F00), '맑음'),
    _LegendItem(Color(0xFF00897B), '구름많음'),
    _LegendItem(Color(0xFF546E7A), '흐림'),
    _LegendItem(Color(0xFF455A64), '강수'),
    _LegendItem(Color(0xFF78909C), '날씨 없음'),
  ];

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(6),
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 150),
            alignment: Alignment.topLeft,
            child: _expanded ? _buildExpanded() : _buildCollapsed(),
          ),
        ),
      ),
    );
  }

  Widget _buildCollapsed() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: const [
        Icon(Icons.palette_outlined, size: 12, color: Colors.black54),
        SizedBox(width: 4),
        Text('범례', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildExpanded() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 3),
          child: Text('마커 색상',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
        ),
        for (final item in _items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 1.5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: item.color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 5),
                Text(item.label, style: const TextStyle(fontSize: 10)),
              ],
            ),
          ),
      ],
    );
  }
}

class _LegendItem {
  final Color color;
  final String label;
  const _LegendItem(this.color, this.label);
}

// 다크 모드 지도 스타일 (기본 다크 테마)
const String _kDarkMapStyle = '''
[
  {"elementType": "geometry", "stylers": [{"color": "#212121"}]},
  {"elementType": "labels.icon", "stylers": [{"visibility": "off"}]},
  {"elementType": "labels.text.fill", "stylers": [{"color": "#9e9e9e"}]},
  {"elementType": "labels.text.stroke", "stylers": [{"color": "#212121"}]},
  {"featureType": "administrative", "elementType": "geometry", "stylers": [{"color": "#757575"}]},
  {"featureType": "administrative.country", "elementType": "labels.text.fill", "stylers": [{"color": "#9e9e9e"}]},
  {"featureType": "administrative.land_parcel", "stylers": [{"visibility": "off"}]},
  {"featureType": "administrative.locality", "elementType": "labels.text.fill", "stylers": [{"color": "#bdbdbd"}]},
  {"featureType": "poi", "elementType": "labels.text.fill", "stylers": [{"color": "#757575"}]},
  {"featureType": "poi.park", "elementType": "geometry", "stylers": [{"color": "#1e2724"}]},
  {"featureType": "poi.park", "elementType": "labels.text.fill", "stylers": [{"color": "#616161"}]},
  {"featureType": "road", "elementType": "geometry.fill", "stylers": [{"color": "#2c2c2c"}]},
  {"featureType": "road", "elementType": "labels.text.fill", "stylers": [{"color": "#8a8a8a"}]},
  {"featureType": "road.arterial", "elementType": "geometry", "stylers": [{"color": "#373737"}]},
  {"featureType": "road.highway", "elementType": "geometry", "stylers": [{"color": "#3c3c3c"}]},
  {"featureType": "road.highway.controlled_access", "elementType": "geometry", "stylers": [{"color": "#4e4e4e"}]},
  {"featureType": "road.local", "elementType": "labels.text.fill", "stylers": [{"color": "#616161"}]},
  {"featureType": "transit", "elementType": "labels.text.fill", "stylers": [{"color": "#757575"}]},
  {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#000000"}]},
  {"featureType": "water", "elementType": "labels.text.fill", "stylers": [{"color": "#3d3d3d"}]}
]
''';
