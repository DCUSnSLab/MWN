import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/market_provider.dart';
import '../../services/api_service.dart';
import '../../models/market.dart';
import '../../models/alert_conditions.dart';

class WeatherManagementScreen extends StatefulWidget {
  const WeatherManagementScreen({super.key});

  @override
  State<WeatherManagementScreen> createState() => _WeatherManagementScreenState();
}

class _WeatherManagementScreenState extends State<WeatherManagementScreen> {
  final ApiService _apiService = ApiService();
  List<UserMarketInterest> _watchlist = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMarkets();
  }

  Future<void> _loadMarkets() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // 관심 시장 목록 가져오기
      final watchlist = await _apiService.getWatchlist();
      setState(() {
        _watchlist = watchlist;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('날씨 알림 관리'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMarkets,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorWidget()
              : _buildMarketList(),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text('데이터 로드 실패', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(_error!),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadMarkets,
            child: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }

  Widget _buildMarketList() {
    if (_watchlist.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.store_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('관리할 시장이 없습니다'),
            SizedBox(height: 8),
            Text(
              '시장을 추가하려면 홈 화면에서\n관심 시장을 등록해주세요',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _watchlist.length,
      itemBuilder: (context, index) {
        final interest = _watchlist[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.orange,
              child: Icon(Icons.store, color: Colors.white),
            ),
            title: Text(
              interest.marketName ?? '시장 ${interest.marketId}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(interest.marketLocation ?? ''),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _showAlertConditionsDialog(interest),
          ),
        );
      },
    );
  }

  void _showAlertConditionsDialog(UserMarketInterest interest) async {
    showDialog(
      context: context,
      builder: (context) => _AlertConditionsDialog(
        marketId: interest.marketId,
        marketName: interest.marketName ?? '시장 ${interest.marketId}',
        apiService: _apiService,
      ),
    );
  }
}

class _AlertConditionsDialog extends StatefulWidget {
  final int marketId;
  final String marketName;
  final ApiService apiService;

  const _AlertConditionsDialog({
    required this.marketId,
    required this.marketName,
    required this.apiService,
  });

  @override
  State<_AlertConditionsDialog> createState() => _AlertConditionsDialogState();
}

class _AlertConditionsDialogState extends State<_AlertConditionsDialog> {
  AlertConditions? _conditions;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  // 컨트롤러들
  late TextEditingController _rainProbabilityController;
  late TextEditingController _highTempController;
  late TextEditingController _lowTempController;
  late TextEditingController _windSpeedController;

  bool _enabled = true;
  bool _snowEnabled = true;
  bool _rainEnabled = true;
  bool _tempEnabled = true;
  bool _windEnabled = true;

  @override
  void initState() {
    super.initState();
    _rainProbabilityController = TextEditingController();
    _highTempController = TextEditingController();
    _lowTempController = TextEditingController();
    _windSpeedController = TextEditingController();
    _loadAlertConditions();
  }

  @override
  void dispose() {
    _rainProbabilityController.dispose();
    _highTempController.dispose();
    _lowTempController.dispose();
    _windSpeedController.dispose();
    super.dispose();
  }

  Future<void> _loadAlertConditions() async {
    try {
      final response = await widget.apiService.getMarketAlertConditions(widget.marketId);
      setState(() {
        _conditions = response.alertConditions;
        _enabled = _conditions!.enabled;
        _snowEnabled = _conditions!.snowEnabled;
        _rainEnabled = _conditions!.rainEnabled;
        _tempEnabled = _conditions!.tempEnabled;
        _windEnabled = _conditions!.windEnabled;

        _rainProbabilityController.text = _conditions!.rainProbability?.toString() ?? '70';
        _highTempController.text = _conditions!.highTemp?.toString() ?? '35';
        _lowTempController.text = _conditions!.lowTemp?.toString() ?? '-10';
        _windSpeedController.text = _conditions!.windSpeed?.toString() ?? '15';

        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _saveAlertConditions() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final updateData = {
        'enabled': _enabled,
        'rain_probability': int.tryParse(_rainProbabilityController.text) ?? 70,
        'high_temp': int.tryParse(_highTempController.text) ?? 35,
        'low_temp': int.tryParse(_lowTempController.text) ?? -10,
        'wind_speed': int.tryParse(_windSpeedController.text) ?? 15,
        'snow_enabled': _snowEnabled,
        'rain_enabled': _rainEnabled,
        'temp_enabled': _tempEnabled,
        'wind_enabled': _windEnabled,
      };

      await widget.apiService.updateMarketAlertConditions(
        widget.marketId,
        updateData,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('알림 조건이 저장되었습니다'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('저장 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        '${widget.marketName} 알림 설정',
        style: const TextStyle(fontSize: 18),
      ),
      content: _isLoading
          ? const SizedBox(
              width: 300,
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            )
          : _error != null
              ? SizedBox(
                  width: 300,
                  height: 200,
                  child: Center(child: Text('로드 실패: $_error')),
                )
              : SingleChildScrollView(
                  child: SizedBox(
                    width: 400,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 전체 활성화
                        SwitchListTile(
                          title: const Text('알림 활성화', style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: const Text('이 시장의 날씨 알림을 받습니다'),
                          value: _enabled,
                          onChanged: (value) {
                            setState(() {
                              _enabled = value;
                            });
                          },
                        ),
                        const Divider(),

                        // 강수 확률
                        SwitchListTile(
                          title: const Text('비/눈 알림'),
                          value: _rainEnabled,
                          onChanged: _enabled
                              ? (value) {
                                  setState(() {
                                    _rainEnabled = value;
                                  });
                                }
                              : null,
                        ),
                        if (_rainEnabled && _enabled)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: TextField(
                              controller: _rainProbabilityController,
                              decoration: const InputDecoration(
                                labelText: '강수 확률 임계치 (%)',
                                helperText: '이 값 이상이면 알림을 전송합니다',
                              ),
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.done,
                            ),
                          ),
                        const SizedBox(height: 16),

                        // 고온 알림
                        SwitchListTile(
                          title: const Text('온도 알림'),
                          value: _tempEnabled,
                          onChanged: _enabled
                              ? (value) {
                                  setState(() {
                                    _tempEnabled = value;
                                  });
                                }
                              : null,
                        ),
                        if (_tempEnabled && _enabled)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              children: [
                                TextField(
                                  controller: _highTempController,
                                  decoration: const InputDecoration(
                                    labelText: '고온 임계치 (°C)',
                                    helperText: '이 온도 이상이면 알림을 전송합니다',
                                  ),
                                  keyboardType: TextInputType.number,
                                  textInputAction: TextInputAction.done,
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _lowTempController,
                                  decoration: const InputDecoration(
                                    labelText: '저온 임계치 (°C)',
                                    helperText: '이 온도 이하면 알림을 전송합니다',
                                  ),
                                  keyboardType: TextInputType.number,
                                  textInputAction: TextInputAction.done,
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 16),

                        // 풍속 알림
                        SwitchListTile(
                          title: const Text('바람 알림'),
                          value: _windEnabled,
                          onChanged: _enabled
                              ? (value) {
                                  setState(() {
                                    _windEnabled = value;
                                  });
                                }
                              : null,
                        ),
                        if (_windEnabled && _enabled)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: TextField(
                              controller: _windSpeedController,
                              decoration: const InputDecoration(
                                labelText: '풍속 임계치 (m/s)',
                                helperText: '이 풍속 이상이면 알림을 전송합니다',
                              ),
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.done,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _saveAlertConditions,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('저장'),
        ),
      ],
    );
  }
}
