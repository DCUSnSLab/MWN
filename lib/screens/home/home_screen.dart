import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/location_service.dart';
import '../../models/weather.dart';
import '../auth/login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  final LocationService _locationService = LocationService();
  
  WeatherData? _currentWeather;
  List<WeatherData> _forecastWeather = [];
  Position? _currentPosition;
  bool _isLoadingWeather = false;
  String? _weatherError;

  @override
  void initState() {
    super.initState();
    _getCurrentLocationAndWeather();
  }

  Future<void> _getCurrentLocationAndWeather() async {
    setState(() {
      _isLoadingWeather = true;
      _weatherError = null;
    });

    try {
      // 현재 위치 가져오기
      final position = await _locationService.getCurrentPosition();
      if (position == null) {
        throw Exception('위치를 가져올 수 없습니다. 위치 권한을 확인해주세요.');
      }

      // 한국 좌표 검증 및 보정
      final correctedPosition = _locationService.validateAndCorrectKoreanLocation(position);
      
      setState(() {
        _currentPosition = correctedPosition;
      });

      // 좌표값 로그 출력
      print('원본 좌표 - 위도: ${position.latitude}, 경도: ${position.longitude}');
      if (correctedPosition != null) {
        print('보정된 좌표 - 위도: ${correctedPosition.latitude}, 경도: ${correctedPosition.longitude}');
      }

      // 현재 날씨 조회
      final weatherRequest = WeatherRequest(
        latitude: correctedPosition?.latitude ?? 35.915451,
        longitude: correctedPosition?.longitude ?? 128.819720,
        locationName: _locationService.formatLocation(
          correctedPosition?.latitude ?? 35.915451,
          correctedPosition?.longitude ?? 128.819720,
        ),
      );

      final currentWeather = await _apiService.getCurrentWeather(weatherRequest);
      final forecastWeather = await _apiService.getForecastWeather(weatherRequest);

      setState(() {
        _currentWeather = currentWeather;
        _forecastWeather = forecastWeather;
      });

    } catch (e) {
      setState(() {
        _weatherError = e.toString();
      });
    } finally {
      setState(() {
        _isLoadingWeather = false;
      });
    }
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

  Widget _buildWeatherCard() {
    if (_isLoadingWeather) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (_weatherError != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Icon(
                Icons.error,
                color: Colors.red,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                '날씨 정보를 가져올 수 없습니다',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                _weatherError!,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _getCurrentLocationAndWeather,
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      );
    }

    if (_currentWeather == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text('날씨 정보가 없습니다'),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.location_on,
                  color: Colors.grey.shade600,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _currentWeather!.locationName ?? '알 수 없는 위치',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  _getWeatherIcon(_currentWeather!.sky),
                  size: 64,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_currentWeather!.temp?.toStringAsFixed(1) ?? '--'}°C',
                        style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _currentWeather!.skyCondition,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildWeatherDetail('습도', '${_currentWeather!.humidity?.toStringAsFixed(0) ?? '--'}%'),
                _buildWeatherDetail('풍속', '${_currentWeather!.windSpeed?.toStringAsFixed(1) ?? '--'}m/s'),
                _buildWeatherDetail('강수량', '${_currentWeather!.rain1h?.toStringAsFixed(1) ?? '0'}mm'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeatherDetail(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  IconData _getWeatherIcon(String? sky) {
    switch (sky) {
      case '1':
        return Icons.wb_sunny;
      case '3':
        return Icons.cloud_queue;
      case '4':
        return Icons.cloud;
      default:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('날씨 알림'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _getCurrentLocationAndWeather,
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') {
                _logout();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'logout',
                child: Text('로그아웃'),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _getCurrentLocationAndWeather,
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

              // 현재 날씨
              Text(
                '현재 날씨',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              _buildWeatherCard(),
              const SizedBox(height: 24),

              // 예보 (간단히)
              if (_forecastWeather.isNotEmpty) ...[
                Text(
                  '시간별 예보',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _forecastWeather.length.clamp(0, 6),
                    itemBuilder: (context, index) {
                      final forecast = _forecastWeather[index];
                      return Container(
                        width: 80,
                        margin: const EdgeInsets.only(right: 8),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  forecast.fcstTime ?? '--',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(height: 4),
                                Icon(
                                  _getWeatherIcon(forecast.sky),
                                  size: 24,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${forecast.temp?.toStringAsFixed(0) ?? '--'}°',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}