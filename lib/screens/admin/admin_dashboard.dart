import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../providers/auth_provider.dart';
import '../../providers/market_provider.dart';
import '../../services/api_service.dart';
import '../../services/fcm_service.dart';
import '../../models/user.dart';
import 'user_management_screen.dart';
import 'fcm_broadcast_screen.dart';
import 'weather_management_screen.dart';
import 'weather_test_screen.dart';
import '../home/home_screen.dart';
import 'alert_history_screen.dart';
import 'report_list_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final ApiService _apiService = ApiService();
  final FCMService _fcmService = FCMService();
  List<User> _users = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final users = await _apiService.getAllUsers();
      setState(() {
        _users = users;
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
        title: const Text('관리자 대시보드'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboardData,
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') {
                _logout();
              } else if (value == 'user_mode') {
                _goToUserMode();
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'user_mode',
                child: Row(
                  children: [
                    Icon(Icons.home, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('일반 모드'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red),
                    SizedBox(width: 8),
                    Text('로그아웃'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorWidget()
              : _buildDashboardContent(),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red,
          ),
          const SizedBox(height: 16),
          Text(
            '데이터 로드 실패',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(_error!),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadDashboardData,
            child: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 통계 카드들
          _buildStatsSection(),
          SizedBox(height: 24.h),

          // 주요 기능 메뉴
          _buildMainMenuSection(),
          SizedBox(height: 24.h),

          // 최근 사용자 목록
          _buildRecentUsersSection(),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    final totalUsers = _users.length;
    final activeUsers = _users.where((user) => user.fcmToken != null).length;
    final adminUsers = _users.where((user) => user.role == 'admin').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '시스템 통계',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 20.sp,
              ),
        ),
        SizedBox(height: 16.h),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: '전체 사용자',
                value: totalUsers.toString(),
                icon: Icons.people,
                color: Colors.blue,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: _buildStatCard(
                title: 'FCM 활성',
                value: activeUsers.toString(),
                icon: Icons.notifications_active,
                color: Colors.green,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: _buildStatCard(
                title: '관리자',
                value: adminUsers.toString(),
                icon: Icons.admin_panel_settings,
                color: Colors.purple,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(12.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20.sp),
                const Spacer(),
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: color,
                        fontSize: 24.sp,
                      ),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                    fontSize: 12.sp,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainMenuSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '관리 메뉴',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 20.sp,
              ),
        ),
        SizedBox(height: 16.h),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12.w,
          mainAxisSpacing: 12.h,
          childAspectRatio: 1.4,
          children: [
            _buildMenuCard(
              title: '사용자 관리',
              subtitle: '사용자 목록 및 권한 관리',
              icon: Icons.people_outline,
              color: Colors.blue,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const UserManagementScreen(),
                  ),
                );
              },
            ),
            _buildMenuCard(
              title: 'FCM 브로드캐스트',
              subtitle: '전체 알림 전송',
              icon: Icons.notifications_none,
              color: Colors.green,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const FCMBroadcastScreen(),
                  ),
                );
              },
            ),
            _buildMenuCard(
              title: '날씨 관리',
              subtitle: '날씨 알림 설정',
              icon: Icons.cloud_outlined,
              color: Colors.orange,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const WeatherManagementScreen(),
                  ),
                );
              },
            ),
            _buildMenuCard(
              title: '날씨 테스트',
              subtitle: '알림 테스트 전송',
              icon: Icons.notifications_active_outlined,
              color: Colors.purple,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const WeatherTestScreen(),
                  ),
                );
              },
            ),
            _buildMenuCard(
              title: '시스템 설정',
              subtitle: '앱 설정 및 관리',
              icon: Icons.settings_outlined,
              color: Colors.grey,
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => const _SystemSettingsDialog(),
                );
              },
            ),
            _buildMenuCard(
              title: '알림 발송 이력',
              subtitle: '전체 알림 내역 조회',
              icon: Icons.history,
              color: Colors.blueGrey,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AlertHistoryScreen(isAdmin: true),
                  ),
                );
              },
            ),
            _buildMenuCard(
              title: '신고 내역 관리',
              subtitle: '접수된 신고 및 이미지 조회',
              icon: Icons.report_problem_outlined,
              color: Colors.redAccent,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ReportListScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMenuCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8.r),
        child: Padding(
          padding: EdgeInsets.all(12.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 28.sp),
              SizedBox(height: 8.h),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 15.sp,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                          fontSize: 11.sp,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentUsersSection() {
    final recentUsers = _users.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '최근 사용자',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 20.sp,
                  ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const UserManagementScreen(),
                  ),
                );
              },
              child: Text('전체 보기', style: TextStyle(fontSize: 14.sp)),
            ),
          ],
        ),
        SizedBox(height: 16.h),
        Card(
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: recentUsers.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final user = recentUsers[index];
              return ListTile(
                leading: CircleAvatar(
                  radius: 20.r,
                  backgroundColor: user.role == 'admin' ? Colors.purple : Colors.blue,
                  child: Text(
                    user.name.substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16.sp,
                    ),
                  ),
                ),
                title: Text(user.name, style: TextStyle(fontSize: 14.sp)),
                subtitle: Text(user.email, style: TextStyle(fontSize: 12.sp)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (user.role == 'admin')
                      Icon(Icons.admin_panel_settings, size: 16.sp, color: Colors.purple),
                    if (user.fcmToken != null)
                      Icon(Icons.notifications_active, size: 16.sp, color: Colors.green),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _logout() async {
    try {
      await Provider.of<AuthProvider>(context, listen: false).logout();
    } catch (e) {
      if (mounted) {
                showDialog(
                  context: context,
                  builder: (context) => const _SystemSettingsDialog(),
                );
              }
            }
          }

  void _goToUserMode() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const HomeScreen()),
    );
  }


}

class _SystemSettingsDialog extends StatelessWidget {
  const _SystemSettingsDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('시스템 설정'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Consumer<MarketProvider>(
            builder: (context, provider, child) {
              return SwitchListTile(
                title: const Text('개발자 디버그 모드'),
                subtitle: const Text('시장 ID, 좌표 등 상세 정보를 표시합니다'),
                value: provider.isDebugMode,
                onChanged: (value) {
                  provider.toggleDebugMode();
                },
              );
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('닫기'),
        ),
      ],
    );
  }
}