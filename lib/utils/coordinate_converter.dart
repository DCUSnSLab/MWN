import 'dart:math' as math;

class CoordinateConverter {
  // 기상청 격자 변환 상수
  static const double RE = 6371.00877; // 지구 반경(km)
  static const double GRID = 5.0; // 격자 간격(km)
  static const double SLAT1 = 30.0; // 투영 위도1(degree)
  static const double SLAT2 = 60.0; // 투영 위도2(degree)
  static const double OLON = 126.0; // 기준점 경도(degree)
  static const double OLAT = 38.0; // 기준점 위도(degree)
  static const double XO = 43; // 기준점 X좌표(GRID)
  static const double YO = 136; // 기준점 Y좌표(GRID)

  /// 위경도를 기상청 격자좌표로 변환
  /// 
  /// [lat] 위도
  /// [lon] 경도
  /// 
  /// Returns: [GridCoordinate] 격자 좌표 (nx, ny)
  static GridCoordinate convertToGrid(double lat, double lon) {
    const double degrad = math.pi / 180.0;
    
    double re = RE / GRID;
    double slat1 = SLAT1 * degrad;
    double slat2 = SLAT2 * degrad;
    double olon = OLON * degrad;
    double olat = OLAT * degrad;
    
    double sn = math.tan(math.pi * 0.25 + slat2 * 0.5) / math.tan(math.pi * 0.25 + slat1 * 0.5);
    sn = math.log(math.cos(slat1) / math.cos(slat2)) / math.log(sn);
    
    double sf = math.tan(math.pi * 0.25 + slat1 * 0.5);
    sf = math.pow(sf, sn) * math.cos(slat1) / sn;
    
    double ro = math.tan(math.pi * 0.25 + olat * 0.5);
    ro = re * sf / math.pow(ro, sn);
    
    double ra = math.tan(math.pi * 0.25 + lat * degrad * 0.5);
    ra = re * sf / math.pow(ra, sn);
    
    double theta = lon * degrad - olon;
    if (theta > math.pi) {
      theta -= 2.0 * math.pi;
    }
    if (theta < -math.pi) {
      theta += 2.0 * math.pi;
    }
    theta *= sn;
    
    double x = (ra * math.sin(theta) + XO + 0.5).floorToDouble();
    double y = (ro - ra * math.cos(theta) + YO + 0.5).floorToDouble();
    
    return GridCoordinate(nx: x.toInt(), ny: y.toInt());
  }
}

class GridCoordinate {
  final int nx;
  final int ny;
  
  GridCoordinate({required this.nx, required this.ny});
  
  @override
  String toString() => 'GridCoordinate(nx: $nx, ny: $ny)';
}