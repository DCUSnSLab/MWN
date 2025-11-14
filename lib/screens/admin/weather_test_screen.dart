import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../../models/market.dart';
import '../../services/api_service.dart';

class WeatherTestScreen extends StatefulWidget {
  const WeatherTestScreen({super.key});

  @override
  State<WeatherTestScreen> createState() => _WeatherTestScreenState();
}

class _WeatherTestScreenState extends State<WeatherTestScreen> {
  final ApiService _apiService = ApiService();

  List<User> _users = [];
  List<Market> _markets = [];
  bool _isLoading = true;
  String? _errorMessage;

  User? _selectedUser;
  Market? _selectedMarket;
  String _selectedAlertType = 'rain';
  bool _ignoreDnd = false;
  bool _isSending = false;

  final List<Map<String, dynamic>> _alertTypes = [
    {'value': 'rain', 'label': '강우', 'icon': Icons.water_drop, 'color': Colors.blue},
    {'value': 'heat', 'label': '폭염', 'icon': Icons.wb_sunny, 'color': Colors.orange},
    {'value': 'cold', 'label': '한파', 'icon': Icons.ac_unit, 'color': Colors.cyan},
    {'value': 'wind', 'label': '강풍', 'icon': Icons.air, 'color': Colors.teal},
    {'value': 'snow', 'label': '폭설', 'icon': Icons.cloudy_snowing, 'color': Colors.indigo},
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final users = await _apiService.getAllUsers();
      final markets = await _apiService.getMarkets();

      setState(() {
        _users = users;
        _markets = markets;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '데이터 로드 실패: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _sendTestAlert() async {
    if (_selectedUser == null || _selectedMarket == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('사용자와 시장을 선택해주세요'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      final result = await _apiService.sendWeatherTestAlert(
        userId: _selectedUser!.id,
        marketId: _selectedMarket!.id,
        alertType: _selectedAlertType,
        ignoreDnd: _ignoreDnd,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? '테스트 알림이 전송되었습니다'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );

        // 성공 다이얼로그
        _showSuccessDialog(result);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('알림 전송 실패: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  void _showSuccessDialog(Map<String, dynamic> result) {
    final data = result['data'] as Map<String, dynamic>?;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('전송 성공'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (data != null) ...[
              _buildInfoRow('사용자', data['user_name'] ?? '-'),
              _buildInfoRow('이메일', data['user_email'] ?? '-'),
              _buildInfoRow('시장', data['market_name'] ?? '-'),
              _buildInfoRow('알림 타입', _getAlertTypeLabel(data['alert_type'])),
              if (data['is_dnd_ignored'] == true)
                const Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: Text(
                    '※ 방해금지 시간 무시됨',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  String _getAlertTypeLabel(String? type) {
    final alertType = _alertTypes.firstWhere(
      (item) => item['value'] == type,
      orElse: () => {'label': type ?? '-'},
    );
    return alertType['label'] as String;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('날씨 알림 테스트'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 60, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(_errorMessage!),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _loadData,
                        icon: const Icon(Icons.refresh),
                        label: const Text('다시 시도'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 안내 카드
                      Card(
                        color: Colors.blue.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.blue.shade700),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  '특정 사용자에게 날씨 알림 테스트 메시지를 전송합니다.',
                                  style: TextStyle(
                                    color: Colors.blue.shade900,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // 사용자 선택
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '1. 수신 사용자 선택',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              DropdownButtonFormField<User>(
                                value: _selectedUser,
                                decoration: const InputDecoration(
                                  labelText: '사용자',
                                  prefixIcon: Icon(Icons.person),
                                  border: OutlineInputBorder(),
                                ),
                                items: _users.map((user) {
                                  return DropdownMenuItem(
                                    value: user,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          user.name,
                                          style: const TextStyle(fontWeight: FontWeight.w500),
                                        ),
                                        Text(
                                          user.email,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: (user) {
                                  setState(() {
                                    _selectedUser = user;
                                  });
                                },
                              ),
                              if (_selectedUser != null) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            _selectedUser!.fcmToken != null
                                                ? Icons.check_circle
                                                : Icons.cancel,
                                            size: 16,
                                            color: _selectedUser!.fcmToken != null
                                                ? Colors.green
                                                : Colors.red,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            _selectedUser!.fcmToken != null
                                                ? 'FCM 토큰 등록됨'
                                                : 'FCM 토큰 미등록',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: _selectedUser!.fcmToken != null
                                                  ? Colors.green
                                                  : Colors.red,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (_selectedUser!.location != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          '위치: ${_selectedUser!.location}',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 시장 선택
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '2. 시장 선택',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              DropdownButtonFormField<Market>(
                                value: _selectedMarket,
                                decoration: const InputDecoration(
                                  labelText: '시장',
                                  prefixIcon: Icon(Icons.store),
                                  border: OutlineInputBorder(),
                                ),
                                items: _markets.map((market) {
                                  return DropdownMenuItem(
                                    value: market,
                                    child: Text(market.name),
                                  );
                                }).toList(),
                                onChanged: (market) {
                                  setState(() {
                                    _selectedMarket = market;
                                  });
                                },
                              ),
                              if (_selectedMarket != null) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _selectedMarket!.location,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 알림 타입 선택
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '3. 알림 타입 선택',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _alertTypes.map((alertType) {
                                  final isSelected = _selectedAlertType == alertType['value'];
                                  return ChoiceChip(
                                    label: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          alertType['icon'] as IconData,
                                          size: 18,
                                          color: isSelected
                                              ? Colors.white
                                              : alertType['color'] as Color,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(alertType['label'] as String),
                                      ],
                                    ),
                                    selected: isSelected,
                                    selectedColor: alertType['color'] as Color,
                                    onSelected: (selected) {
                                      if (selected) {
                                        setState(() {
                                          _selectedAlertType = alertType['value'] as String;
                                        });
                                      }
                                    },
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 옵션
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '4. 추가 옵션',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              CheckboxListTile(
                                title: const Text('방해금지 시간 무시'),
                                subtitle: const Text(
                                  '사용자의 방해금지 설정을 무시하고 알림을 전송합니다',
                                  style: TextStyle(fontSize: 12),
                                ),
                                value: _ignoreDnd,
                                onChanged: (value) {
                                  setState(() {
                                    _ignoreDnd = value ?? false;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // 전송 버튼
                      ElevatedButton.icon(
                        onPressed: _isSending ? null : _sendTestAlert,
                        icon: _isSending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.send),
                        label: Text(_isSending ? '전송 중...' : '테스트 알림 전송'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
