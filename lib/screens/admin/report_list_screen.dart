import 'package:flutter/material.dart';
import '../../repositories/report_repository.dart';
import '../../widgets/async_view.dart';

class ReportListScreen extends StatefulWidget {
  const ReportListScreen({super.key});

  @override
  State<ReportListScreen> createState() => _ReportListScreenState();
}

class _ReportListScreenState extends State<ReportListScreen> {
  final ReportRepository _reportRepository = ReportRepository();
  List<Map<String, dynamic>> _reports = [];
  bool _isLoading = true;
  String? _error;

  List<String> _marketNames = ['전체 시장'];
  String _selectedMarket = '전체 시장';
  bool _showOnlyWithImages = false;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final reports = await _reportRepository.getReports();
      final Set<String> marketSet = {'전체 시장'};
      for (var report in reports) {
        if (report['market_name'] != null) {
          marketSet.add(report['market_name']);
        }
      }
      
      setState(() {
        _reports = reports;
        _marketNames = marketSet.toList();
        if (!_marketNames.contains(_selectedMarket)) {
          _selectedMarket = '전체 시장';
        }
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showImageDialog(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InteractiveViewer(
              child: Image.network(
                imageUrl,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(child: CircularProgressIndicator());
                },
                errorBuilder: (context, error, stackTrace) {
                  return const Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Icon(Icons.broken_image, size: 50, color: Colors.grey),
                  );
                },
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('닫기'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 필터링 적용
    var filteredReports = _reports.where((r) {
      if (_selectedMarket != '전체 시장' && r['market_name'] != _selectedMarket) {
        return false;
      }
      if (_showOnlyWithImages) {
        final imagePath = r['image_path'];
        if (imagePath == null || imagePath.toString().trim().isEmpty) {
          return false;
        }
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('신고 내역 관리'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReports,
          ),
        ],
      ),
      body: Column(
        children: [
          // 필터 UI
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.grey[50],
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedMarket,
                      items: _marketNames.map((String market) {
                        return DropdownMenuItem<String>(
                          value: market,
                          child: Text(market, overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedMarket = newValue;
                          });
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('사진만 보기', style: TextStyle(fontSize: 14)),
                    Switch(
                      value: _showOnlyWithImages,
                      onChanged: (value) {
                        setState(() {
                          _showOnlyWithImages = value;
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // 리스트 영역
          Expanded(
            child: AsyncView(
              isLoading: _isLoading,
              error: _error,
              onRetry: _loadReports,
              errorTitle: '정보를 불러오는데 실패했습니다',
              builder: (context) {
                if (filteredReports.isEmpty) {
                  return const Center(child: Text('해당 조건의 신고 내역이 없습니다.'));
                }
                return ListView.builder(
                            itemCount: filteredReports.length,
                            itemBuilder: (context, index) {
                              final report = filteredReports[index];
                              final marketName = report['market_name'] ?? '알 수 없음';
                              final reportType = report['report_type'] ?? '기타';
                              final description = report['description'] ?? '';
                              final createdAt = report['created_at'] ?? '';
                              final imagePath = report['image_path'];
                              final hasImage = imagePath != null && imagePath.toString().trim().isNotEmpty;
                              
                              // 이미지 URL 구성 (백엔드 URL + 경로)
                              final String imageUrl = '${_reportRepository.imageBaseUrl}$imagePath';

                              return Card(
                                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              '[$reportType] $marketName',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                            ),
                                          ),
                                          Text(
                                            createdAt.length >= 10 ? createdAt.substring(0, 10) : createdAt,
                                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(description),
                                      if (hasImage) ...[
                                        const SizedBox(height: 12),
                                        GestureDetector(
                                          onTap: () => _showImageDialog(imageUrl),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: Image.network(
                                              imageUrl,
                                              height: 200,
                                              width: double.infinity,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) {
                                                return Container(
                                                  height: 200,
                                                  color: Colors.grey[200],
                                                  child: const Center(
                                                    child: Column(
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      children: [
                                                        Icon(Icons.broken_image, color: Colors.grey),
                                                        Text('이미지를 불러올 수 없습니다'),
                                                      ],
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
              },
            ),
          ),
        ],
      ),
    );
  }
}
