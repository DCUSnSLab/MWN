import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../providers/auth_provider.dart';
import '../../providers/market_provider.dart';
import '../../repositories/admin_repository.dart';
import '../../repositories/report_repository.dart';
import '../../repositories/alert_log_repository.dart';
import '../../widgets/async_view.dart';
import '../../models/user.dart';
import '../../utils/logger.dart';
import 'user_management_screen.dart';
import 'fcm_broadcast_screen.dart';
import 'weather_management_screen.dart';
import 'weather_test_screen.dart';
import '../home/home_screen.dart';
import '../auth/login_screen.dart';
import 'alert_history_screen.dart';
import 'report_list_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final AdminRepository _adminRepository = AdminRepository();
  final ReportRepository _reportRepository = ReportRepository();
  final AlertLogRepository _alertLogRepository = AlertLogRepository();

  List<User> _users = [];
  List<Map<String, dynamic>> _reports = [];
  int _todayAlertCount = 0;
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
      // 병렬로 fetch
      final results = await Future.wait([
        _adminRepository.getAllUsers(),
        _reportRepository.getReports(),
        // 최근 알림 1페이지만 받아 오늘자만 카운트
        _alertLogRepository.getAlertLogs(isAdmin: true, page: 1, perPage: 100),
      ]);

      final users = results[0] as List<User>;
      final reports = results[1] as List<Map<String, dynamic>>;
      final alertLogsRes = results[2] as Map<String, dynamic>;
      final alertLogs =
          (alertLogsRes['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];

      final today = DateTime.now();
      final todayAlerts = alertLogs.where((log) {
        final created = _parseDate(log['created_at']);
        return created != null && _isSameDay(created, today);
      }).length;

      setState(() {
        _users = users;
        _reports = reports;
        _todayAlertCount = todayAlerts;
        _isLoading = false;
      });
    } catch (e) {
      log('❌ 대시보드 로드 실패: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  DateTime? _parseDate(dynamic v) {
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // 타이틀 long-press → 개발자 도구 (popup 메뉴에도 노출)
        title: GestureDetector(
          onLongPress: _showDeveloperToolsSheet,
          behavior: HitTestBehavior.opaque,
          child: const Text('관리자 대시보드'),
        ),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        // AppBar refresh 제거 — pull-to-refresh 와 중복
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') {
                _logout();
              } else if (value == 'user_mode') {
                _goToUserMode();
              } else if (value == 'dev_tools') {
                _showDeveloperToolsSheet();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem<String>(
                value: 'user_mode',
                child: Row(
                  children: [
                    Icon(Icons.home, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('일반 모드'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'dev_tools',
                child: Row(
                  children: [
                    Icon(Icons.developer_mode, color: Colors.deepPurple),
                    SizedBox(width: 8),
                    Text('개발자 도구'),
                  ],
                ),
              ),
              PopupMenuDivider(),
              PopupMenuItem<String>(
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
      body: AsyncView(
        isLoading: _isLoading,
        error: _error,
        onRetry: _loadDashboardData,
        errorTitle: '데이터 로드 실패',
        builder: (context) => _buildDashboardContent(),
      ),
    );
  }

  Widget _buildDashboardContent() {
    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatsSection(),
            SizedBox(height: 24.h),
            _buildMainMenuSection(),
            SizedBox(height: 24.h),
            _buildPendingReportsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection() {
    final totalUsers = _users.length;
    final activeUsers = _users.where((u) => u.fcmToken != null).length;
    final adminUsers = _users.where((u) => u.role == 'admin').length;

    final pendingReports =
        _reports.where((r) => r['status'] == 'pending').length;
    final today = DateTime.now();
    final todayReports = _reports.where((r) {
      final created = _parseDate(r['created_at']);
      return created != null && _isSameDay(created, today);
    }).length;

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
        SizedBox(height: 12.h),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          crossAxisSpacing: 10.w,
          mainAxisSpacing: 10.h,
          childAspectRatio: 1.05,
          children: [
            _statCard('전체 사용자', totalUsers.toString(), Icons.people, Colors.blue),
            _statCard('FCM 활성', activeUsers.toString(),
                Icons.notifications_active, Colors.green),
            _statCard('관리자', adminUsers.toString(),
                Icons.admin_panel_settings, Colors.purple),
            _statCard('오늘 발송 알림', _todayAlertCount.toString(),
                Icons.outgoing_mail, Colors.teal),
            _statCard('대기 신고', pendingReports.toString(),
                Icons.pending_actions, Colors.redAccent,
                showDot: pendingReports > 0),
            _statCard('오늘 신고', todayReports.toString(),
                Icons.report_problem_outlined, Colors.orange),
          ],
        ),
      ],
    );
  }

  Widget _statCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    /// 0이 아닐 때 작은 점 배지로만 강조. 빨간 테두리 대신.
    bool showDot = false,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
      child: Padding(
        padding: EdgeInsets.all(10.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, color: color, size: 18.sp),
                if (showDot)
                  Positioned(
                    top: -2,
                    right: -4,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.2),
                      ),
                    ),
                  ),
              ],
            ),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 22.sp,
                  ),
            ),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[700],
                    fontSize: 11.sp,
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
        SizedBox(height: 12.h),
        // 핵심 메뉴 4개 (2x2 그리드)
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12.w,
          mainAxisSpacing: 12.h,
          childAspectRatio: 1.4,
          children: [
            _menuCard(
              title: '사용자 관리',
              subtitle: '계정 및 권한 관리',
              icon: Icons.people_outline,
              color: Colors.blue,
              onTap: () => _push(const UserManagementScreen()),
            ),
            _menuCard(
              title: '신고 내역 관리',
              subtitle: '접수된 신고 관리',
              icon: Icons.report_problem_outlined,
              color: Colors.redAccent,
              onTap: () => _push(const ReportListScreen()),
            ),
            _menuCard(
              title: '알림 발송 이력',
              subtitle: '전체 알림 내역 조회',
              icon: Icons.history,
              color: Colors.blueGrey,
              onTap: () => _push(const AlertHistoryScreen(isAdmin: true)),
            ),
            _menuCard(
              title: '날씨 관리',
              subtitle: '시장별 임계값 설정',
              icon: Icons.cloud_outlined,
              color: Colors.orange,
              onTap: () => _push(const WeatherManagementScreen()),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        // 보조 메뉴: 가로 wide bar (홀수 카드 빈공간 회피)
        _menuWideCard(
          title: 'FCM 발송',
          subtitle: '선택 사용자에게 알림 전송',
          icon: Icons.send_outlined,
          color: Colors.green,
          onTap: () => _push(const FCMBroadcastScreen()),
        ),
      ],
    );
  }

  Widget _menuWideCard({
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
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
          child: Row(
            children: [
              Container(
                width: 38.w,
                height: 38.w,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(icon, color: color, size: 22.sp),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 15.sp,
                          ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                            fontSize: 11.sp,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  color: Colors.grey[400], size: 20.sp),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuCard({
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
        ),
      ),
    );
  }

  Widget _buildPendingReportsSection() {
    final pending = _reports
        .where((r) => r['status'] == 'pending')
        .take(5)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '처리 대기 신고',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 20.sp,
                  ),
            ),
            const Spacer(),
            if (_reports.where((r) => r['status'] == 'pending').isNotEmpty)
              TextButton(
                onPressed: () => _push(const ReportListScreen()),
                child: Text('전체 보기', style: TextStyle(fontSize: 14.sp)),
              ),
          ],
        ),
        SizedBox(height: 12.h),
        if (pending.isEmpty)
          Card(
            child: Padding(
              padding: EdgeInsets.all(20.w),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline,
                      color: Colors.green, size: 22.sp),
                  SizedBox(width: 10.w),
                  Text(
                    '대기 중인 신고가 없습니다',
                    style: TextStyle(fontSize: 14.sp, color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
          )
        else
          Column(
            children: [
              for (int i = 0; i < pending.length; i++)
                Padding(
                  padding: EdgeInsets.only(bottom: i == pending.length - 1 ? 0 : 8.h),
                  child: _PendingReportTile(
                    report: pending[i],
                    typeLabel: _reportTypeLabel(pending[i]['report_type']),
                    createdAt: _parseDate(pending[i]['created_at']),
                    formatRelative: _formatRelative,
                    onTap: () => _push(const ReportListScreen()),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  String _reportTypeLabel(dynamic type) {
    switch (type) {
      case 'drainage':
        return '배수 문제';
      case 'fire':
        return '화재 위험';
      case 'odor':
        return '악취';
      case 'other':
        return '기타 신고';
    }
    return '신고';
  }

  String _formatRelative(DateTime? d) {
    if (d == null) return '';
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    // 7일 이상은 풀어 쓰기 (예: 2월 24일 / 작년이면 연 포함)
    final isThisYear = d.year == now.year;
    return isThisYear
        ? '${d.month}월 ${d.day}일'
        : '${d.year}년 ${d.month}월 ${d.day}일';
  }

  void _push(Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    ).then((_) {
      // 신고 처리 등 다녀온 뒤 통계 갱신
      _loadDashboardData();
    });
  }

  void _showDeveloperToolsSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Row(
                    children: [
                      const Icon(Icons.developer_mode,
                          size: 18, color: Colors.deepPurple),
                      const SizedBox(width: 8),
                      Text(
                        '개발자 도구',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Consumer<MarketProvider>(
                  builder: (_, provider, __) {
                    return SwitchListTile(
                      title: const Text('디버그 모드'),
                      subtitle: const Text('시장 카드에 ID·좌표·격자를 표시'),
                      value: provider.isDebugMode,
                      onChanged: (_) => provider.toggleDebugMode(),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.notifications_active_outlined,
                      color: Colors.purple),
                  title: const Text('날씨 알림 테스트'),
                  subtitle: const Text('특정 사용자에게 테스트 알림 전송'),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _push(const WeatherTestScreen());
                  },
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _logout() async {
    try {
      await Provider.of<AuthProvider>(context, listen: false).logout();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    } catch (e) {
      log('❌ 로그아웃 실패: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('로그아웃 실패: $e')),
      );
    }
  }

  void _goToUserMode() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }
}

class _PendingReportTile extends StatelessWidget {
  final Map<String, dynamic> report;
  final String typeLabel;
  final DateTime? createdAt;
  final String Function(DateTime?) formatRelative;
  final VoidCallback onTap;

  const _PendingReportTile({
    required this.report,
    required this.typeLabel,
    required this.createdAt,
    required this.formatRelative,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final marketName = report['market_name'] ?? '시장';
    final userName = report['user_name'] ?? '알 수 없음';
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10.r),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
          child: Row(
            children: [
              Container(
                width: 36.w,
                height: 36.w,
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(Icons.report_outlined,
                    color: Colors.redAccent, size: 20.sp),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            marketName,
                            style: TextStyle(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: 6.w),
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 6.w, vertical: 1.h),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(4.r),
                          ),
                          child: Text(
                            typeLabel,
                            style: TextStyle(
                              fontSize: 10.sp,
                              color: Colors.redAccent.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 3.h),
                    Text(
                      '$userName · ${formatRelative(createdAt)}',
                      style: TextStyle(
                          fontSize: 11.sp, color: Colors.grey[600]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  color: Colors.grey[400], size: 18.sp),
            ],
          ),
        ),
      ),
    );
  }
}
