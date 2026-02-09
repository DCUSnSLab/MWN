import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/api_error.dart';

class ReportListScreen extends StatefulWidget {
  const ReportListScreen({super.key});

  @override
  State<ReportListScreen> createState() => _ReportListScreenState();
}

class _ReportListScreenState extends State<ReportListScreen> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _reports = [];
  bool _isLoading = true;
  String? _error;

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
      final reports = await _apiService.getReports();
      setState(() {
        _reports = reports;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
      if (e is ApiException && e.statusCode == 401) {
        // 토큰 만료 등 처리 필요시
      }
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('정보를 불러오는데 실패했습니다.\n$_error', textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadReports,
                        child: const Text('다시 시도'),
                      ),
                    ],
                  ),
                )
              : _reports.isEmpty
                  ? const Center(child: Text('접수된 신고가 없습니다.'))
                  : ListView.builder(
                      itemCount: _reports.length,
                      itemBuilder: (context, index) {
                        final report = _reports[index];
                        final marketName = report['market_name'] ?? '알 수 없음';
                        final reportType = report['report_type'] ?? '기타';
                        final description = report['description'] ?? '';
                        final createdAt = report['created_at'] ?? '';
                        final imagePath = report['image_path'];
                        final hasImage = imagePath != null && imagePath.isNotEmpty;
                        
                        // 이미지 URL 구성 (백엔드 URL + 경로)
                        final imageUrl = hasImage ? '${ApiService.baseUrl}$imagePath' : null;

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
                                      createdAt.substring(0, 10), // 날짜만 표시
                                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(description),
                                if (hasImage) ...[
                                  const SizedBox(height: 12),
                                  GestureDetector(
                                    onTap: () => _showImageDialog(imageUrl!),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        imageUrl!,
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
                    ),
    );
  }
}
