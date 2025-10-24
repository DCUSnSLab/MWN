import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/fcm_service.dart';
import '../../models/user.dart';
import 'user_management_screen.dart';
import 'fcm_broadcast_screen.dart';
import '../home/home_screen.dart';

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
          const SizedBox(height: 24),

          // 주요 기능 메뉴
          _buildMainMenuSection(),
          const SizedBox(height: 24),

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
              ),
        ),
        const SizedBox(height: 16),
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
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                title: 'FCM 활성',
                value: activeUsers.toString(),
                icon: Icons.notifications_active,
                color: Colors.green,
              ),
            ),
            const SizedBox(width: 12),
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const Spacer(),
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
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
              ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.5,
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
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('날씨 관리 기능 준비 중입니다')),
                );
              },
            ),
            _buildMenuCard(
              title: 'iOS FCM 디버깅',
              subtitle: 'iOS 알림 설정 확인',
              icon: Icons.bug_report_outlined,
              color: Colors.red,
              onTap: () => _showIOSFCMDebugDialog(),
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
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 32),
              const Spacer(),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
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
              child: const Text('전체 보기'),
            ),
          ],
        ),
        const SizedBox(height: 16),
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
                  backgroundColor: user.role == 'admin' ? Colors.purple : Colors.blue,
                  child: Text(
                    user.name.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(user.name),
                subtitle: Text(user.email),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (user.role == 'admin')
                      const Icon(Icons.admin_panel_settings, size: 16, color: Colors.purple),
                    if (user.fcmToken != null)
                      const Icon(Icons.notifications_active, size: 16, color: Colors.green),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('로그아웃 실패: $e')),
        );
      }
    }
  }

  void _goToUserMode() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const HomeScreen()),
    );
  }

  void _showIOSFCMDebugDialog() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.bug_report, color: Colors.red),
              SizedBox(width: 8),
              Text('iOS FCM 디버깅'),
            ],
          ),
          content: FutureBuilder<Map<String, dynamic>>(
            future: _fcmService.getIOSFCMStatus(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  width: 300,
                  height: 200,
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError) {
                return SizedBox(
                  width: 300,
                  height: 200,
                  child: Text('오류: ${snapshot.error}'),
                );
              }

              final data = snapshot.data ?? {};
              return SizedBox(
                width: 300,
                height: 400,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDebugItem('플랫폼', data['platform'] ?? 'unknown'),
                      if (data['platform'] == 'ios') ...[
                        _buildDebugItem('기기 타입', data['is_simulator'] == true ? '❌ 시뮬레이터' : '✅ 실기기'),
                        _buildDebugItem('Bundle ID', data['bundle_id'] ?? 'unknown'),
                        _buildDebugItem('Firebase 연결', data['firebase_app_check'] ?? 'unknown'),
                        const Divider(),
                        _buildDebugItem('권한 상태', _getAuthStatusDisplay(data['authorization_status_raw'])),
                        _buildDebugItem('알림 설정', data['alert_setting'] ?? 'unknown'),
                        _buildDebugItem('배지 설정', data['badge_setting'] ?? 'unknown'),
                        _buildDebugItem('사운드 설정', data['sound_setting'] ?? 'unknown'),
                        const Divider(),
                        _buildDebugItem('APNS 토큰', data['has_apns_token'] == true ? '✅ 있음 (${data['apns_token_length']}자)' : '❌ 없음'),
                        if (data['apns_token_preview'] != null)
                          _buildDebugItem('APNS 미리보기', data['apns_token_preview']),
                        _buildDebugItem('FCM 토큰', data['has_fcm_token'] == true ? '✅ 있음 (${data['fcm_token_length']}자)' : '❌ 없음'),
                        if (data['fcm_token_preview'] != null)
                          _buildDebugItem('FCM 미리보기', data['fcm_token_preview']),
                      ],
                      if (data['error'] != null) ...[
                        const Divider(),
                        _buildDebugItem('오류 타입', data['error_type'] ?? 'unknown'),
                        _buildDebugItem('오류 내용', data['error']),
                      ],
                      const SizedBox(height: 16),
                      _buildTroubleshootingGuide(data),
                    ],
                  ),
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                _fcmService.openIOSNotificationSettings();
              },
              child: const Text('설정 도움말'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('닫기'),
            ),
          ],
        );
      },
    );
  }

  String _getAuthStatusDisplay(String? status) {
    switch (status) {
      case 'authorized':
        return '✅ 허용됨';
      case 'denied':
        return '❌ 거부됨';
      case 'notDetermined':
        return '⚠️ 미결정';
      case 'provisional':
        return '🔄 임시 허용';
      default:
        return '❓ 알 수 없음 ($status)';
    }
  }

  Widget _buildTroubleshootingGuide(Map<String, dynamic> data) {
    List<String> issues = [];
    List<String> solutions = [];

    // 문제 진단
    if (data['is_simulator'] == true) {
      issues.add('❌ iOS 시뮬레이터 사용 중');
      solutions.add('→ 실제 iOS 기기에서 테스트하세요');
    }

    if (data['authorization_status_raw'] != 'authorized') {
      issues.add('❌ 알림 권한이 허용되지 않음');
      solutions.add('→ 설정 > 알림 > MWN > 알림 허용을 ON으로 설정');
    }

    if (data['has_apns_token'] != true) {
      issues.add('❌ APNS 토큰 없음');
      solutions.add('→ 실기기에서 테스트하고 Apple Developer 인증서 확인');
    }

    if (data['has_fcm_token'] != true) {
      issues.add('❌ FCM 토큰 없음');
      solutions.add('→ Firebase Console 설정 및 GoogleService-Info.plist 확인');
    }

    if (data['firebase_app_check']?.contains('error') == true) {
      issues.add('❌ Firebase 연결 오류');
      solutions.add('→ Firebase 초기화 및 구성 파일 확인');
    }

    // 추가 권장사항
    solutions.addAll([
      '',
      '📋 추가 확인사항:',
      '• Firebase Console > 프로젝트 설정 > Cloud Messaging',
      '• APNs 인증 키 또는 인증서 업로드 확인',
      '• Bundle ID 일치 여부 확인',
      '• iOS 앱 ID에서 Push Notifications 활성화',
      '• Xcode에서 Capabilities > Push Notifications 활성화',
    ]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '🔍 진단 결과:',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
        ),
        const SizedBox(height: 8),
        if (issues.isEmpty)
          const Text('✅ 모든 기본 설정이 정상입니다', style: TextStyle(color: Colors.green))
        else
          ...issues.map((issue) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(issue, style: const TextStyle(color: Colors.red)),
          )),
        const SizedBox(height: 12),
        const Text(
          '💡 해결 방법:',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
        ),
        const SizedBox(height: 8),
        ...solutions.map((solution) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: Text(
            solution,
            style: TextStyle(
              fontSize: solution.startsWith('📋') || solution.startsWith('•') ? 12 : 14,
              color: solution.isEmpty ? Colors.transparent : null,
            ),
          ),
        )),
      ],
    );
  }

  Widget _buildDebugItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontFamily: 'monospace',
                color: value.contains('✅') ? Colors.green : 
                       value.contains('❌') ? Colors.red :
                       value.contains('⚠️') ? Colors.orange : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}