import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';

class AlertHistoryScreen extends StatefulWidget {
  final bool isAdmin; // 역할 구분 플래그

  const AlertHistoryScreen({Key? key, this.isAdmin = false}) : super(key: key);

  @override
  _AlertHistoryScreenState createState() => _AlertHistoryScreenState();
}

class _AlertHistoryScreenState extends State<AlertHistoryScreen> {
  // ... (기존 변수 유지)
  List<dynamic> _logs = [];
  bool _isLoading = false;
  int _currentPage = 1;
  int _totalPages = 1;
  bool _hasNext = false;
  final ScrollController _scrollController = ScrollController();
  
  // 필터링 상태 (Optional)
  int? _selectedMarketId;

  @override
  void initState() {
    super.initState();
    _fetchLogs();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoading && _hasNext) {
        _fetchLogs(page: _currentPage + 1);
      }
    }
  }

  Future<void> _fetchLogs({int page = 1}) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final baseUrl = ApiService.baseUrl;

      // 역할에 따라 API 엔드포인트 분기
      String endpoint = widget.isAdmin ? '/api/admin/logs/alerts' : '/api/user/logs/alerts';
      String url = '$baseUrl$endpoint?page=$page&per_page=20';
      
      if (_selectedMarketId != null) {
        url += '&market_id=$_selectedMarketId';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> newLogs = data['logs'];
        
        setState(() {
          if (page == 1) {
            _logs = newLogs;
          } else {
            _logs.addAll(newLogs);
          }
          _currentPage = data['current_page'];
          _totalPages = data['pages'];
          _hasNext = data['has_next'];
          _isLoading = false;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('데이터 로드 실패: ${response.statusCode}')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching logs: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('네트워크 오류가 발생했습니다.')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _refresh() async {
    await _fetchLogs(page: 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('알림 발송 이력'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _logs.isEmpty && !_isLoading
            ? const Center(child: Text('발송된 알림이 없습니다.'))
            : ListView.builder(
                controller: _scrollController,
                itemCount: _logs.length + (_hasNext ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _logs.length) {
                    return const Center(child: Padding(
                      padding: EdgeInsets.all(8.0),
                      child: CircularProgressIndicator(),
                    ));
                  }

                  final log = _logs[index];
                  return _buildLogTile(log);
                },
              ),
      ),
    );
  }

  Widget _buildLogTile(dynamic log) {
    Color typeColor = Colors.grey;
    IconData typeIcon = Icons.notifications;
    String typeText = log['alert_type'] ?? '알림';

    switch (log['alert_type']) {
      case 'rain':
        typeColor = Colors.blue;
        typeIcon = Icons.water_drop;
        typeText = '강수';
        break;
      case 'high_temp':
        typeColor = Colors.orange;
        typeIcon = Icons.wb_sunny;
        typeText = '폭염';
        break;
      case 'low_temp':
        typeColor = Colors.cyan;
        typeIcon = Icons.ac_unit;
        typeText = '한파';
        break;
      case 'strong_wind':
        typeColor = Colors.green;
        typeIcon = Icons.air;
        typeText = '강풍';
        break;
      case 'snow':
        typeColor = Colors.lightBlueAccent;
        typeIcon = Icons.snowing;
        typeText = '대설';
        break;
    }

    // 날짜 포맷팅 (단순화: ISO String -> YYYY-MM-DD HH:mm)
    String dateStr = log['created_at']?.toString().substring(0, 16).replaceAll('T', ' ') ?? '-';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: typeColor.withOpacity(0.2),
          child: Icon(typeIcon, color: typeColor),
        ),
        title: Text(
          log['alert_title'] ?? '제목 없음',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${log['market_name'] ?? '시장?'} | $dateStr',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow('전송 결과', '${log['success_count']}성공 / ${log['failure_count']}실패 (총 ${log['total_users']}명)'),
                const SizedBox(height: 8),
                Text('알림 내용:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[800])),
                const SizedBox(height: 4),
                Text(log['alert_body'] ?? '내용 없음'),
                const SizedBox(height: 8),
                if (log['forecast_time'] != null)
                  _buildInfoRow('예보 시점', log['forecast_time']),
                if (log['temperature'] != null)
                  _buildInfoRow('기온', '${(log['temperature'] as num).toStringAsFixed(1)}°C'),
                if (log['wind_speed'] != null)
                    _buildInfoRow('풍속', '${log['wind_speed']}m/s'),
                if (log['precipitation_type'] != null)
                    _buildInfoRow('강수형태', '${log['precipitation_type']}'),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black54)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
