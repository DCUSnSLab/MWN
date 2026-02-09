import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../models/market.dart';
import '../../models/weather.dart';
import '../../widgets/market_weather_widget.dart';
import '../report/report_screen.dart';

class MarketDetailScreen extends StatelessWidget {
  final UserMarketInterest market;
  final WeatherData? weather;

  const MarketDetailScreen({
    super.key,
    required this.market,
    this.weather,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(market.marketName ?? '시장 상세'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Reusing the Weather Widget for consistency
            MarketWeatherWidget(
              market: market,
              weather: weather,
              // Disable refresh in detail view or implement if needed
              onRefresh: null, 
            ),
            
            SizedBox(height: 24.h),
            
            _buildInfoSection(context),
            
            SizedBox(height: 32.h),
            
            // Report Button
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ReportScreen(
                      preSelectedMarketId: market.marketId,
                      preSelectedMarketName: market.marketName,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.report_problem, color: Colors.white),
              label: Text(
                '이 시장에 대해 문제 신고하기',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                padding: EdgeInsets.symmetric(vertical: 16.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '시장 정보',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12.h),
            _buildInfoRow(Icons.location_on, '주소', market.marketLocation ?? '정보 없음'),
            if (market.createdAt != null) ...[
              SizedBox(height: 8.h),
              _buildInfoRow(Icons.calendar_today, '등록일', _formatDate(market.createdAt!)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        SizedBox(width: 8.w),
        SizedBox(
          width: 60.w,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.year}.${date.month}.${date.day}';
    } catch (_) {
      return dateStr;
    }
  }
}
