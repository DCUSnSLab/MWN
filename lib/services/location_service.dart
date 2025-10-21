import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  // 위치 권한 요청
  Future<bool> requestLocationPermission() async {
    final permission = await Permission.location.request();
    return permission.isGranted;
  }

  // 위치 권한 상태 확인
  Future<bool> hasLocationPermission() async {
    final permission = await Permission.location.status;
    return permission.isGranted;
  }

  // 위치 서비스 활성화 확인
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  // 현재 위치 가져오기
  Future<Position?> getCurrentPosition() async {
    try {
      // 위치 서비스 활성화 확인
      if (!await isLocationServiceEnabled()) {
        throw Exception('위치 서비스가 비활성화되어 있습니다. 설정에서 위치 서비스를 활성화해주세요.');
      }

      // 권한 확인 및 요청
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('위치 권한이 거부되었습니다. 설정에서 위치 권한을 허용해주세요.');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('위치 권한이 영구적으로 거부되었습니다. 설정에서 위치 권한을 허용해주세요.');
      }

      // 현재 위치 가져오기
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      return position;
    } catch (e) {
      print('위치 가져오기 실패: $e');
      // 위치 권한 오류 시 null 반환하여 상위에서 처리하도록 함
      return null;
    }
  }

  // 마지막 알려진 위치 가져오기
  Future<Position?> getLastKnownPosition() async {
    try {
      return await Geolocator.getLastKnownPosition();
    } catch (e) {
      print('마지막 위치 가져오기 실패: $e');
      return null;
    }
  }

  // 두 지점 간의 거리 계산 (미터)
  double calculateDistance(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    return Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }

  // 한국 지역 좌표 검증 및 보정
  Position? validateAndCorrectKoreanLocation(Position position) {
    double lat = position.latitude;
    double lon = position.longitude;
    
    // 한국 좌표 범위 확인
    // 위도: 33°-38° (제주도~북한 경계)
    // 경도: 124°-132° (서해~동해)
    
    // 경도가 음수인 경우 보정 (서반구 → 동반구)
    if (lon < 0) {
      lon = lon.abs(); // 절댓값으로 변환
      print('경도 음수값 보정: ${position.longitude} → $lon');
    }
    
    // 한국 범위 밖인 경우 null 반환 (상위에서 처리)
    if (lat < 33.0 || lat > 38.5 || lon < 124.0 || lon > 132.0) {
      print('한국 범위 밖 좌표 감지: 위도 $lat, 경도 $lon');
      return null;
    }
    
    // 좌표가 보정된 경우 새 Position 객체 반환
    if (lon != position.longitude) {
      return Position(
        latitude: lat,
        longitude: lon,
        timestamp: position.timestamp,
        accuracy: position.accuracy,
        altitude: position.altitude,
        heading: position.heading,
        speed: position.speed,
        speedAccuracy: position.speedAccuracy,
        headingAccuracy: position.headingAccuracy,
        altitudeAccuracy: position.altitudeAccuracy,
      );
    }
    
    return position;
  }

  // 위치를 주소로 변환 (역지오코딩) - 간단한 형태
  String formatLocation(double latitude, double longitude) {
    return '위도: ${latitude.toStringAsFixed(4)}, 경도: ${longitude.toStringAsFixed(4)}';
  }
}