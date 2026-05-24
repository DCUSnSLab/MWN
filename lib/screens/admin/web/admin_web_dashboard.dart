import 'package:flutter/material.dart';
import '../../../models/user.dart';
import '../user_management_screen.dart';
import '../fcm_broadcast_screen.dart';
import '../weather_management_screen.dart';
import '../weather_test_screen.dart';
import '../alert_history_screen.dart';
import '../report_list_screen.dart';

/// 웹 관리자 대시보드. 검증된 기존 관리자 기능 화면 6종을 그대로 재사용한다.
///
/// 모바일 `AdminDashboard` 의 "일반 모드"(home_screen) 및 FCMService 의존성은
/// 웹 그래프에 포함하지 않기 위해 별도 셸로 작성했다.
class AdminWebDashboard extends StatelessWidget {
  const AdminWebDashboard({
    super.key,
    required this.user,
    required this.onLogout,
  });

  final User user;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    final menu = <_AdminMenuItem>[
      _AdminMenuItem('사용자 관리', '사용자 목록 및 권한', Icons.people_outline,
          Colors.blue, () => const UserManagementScreen()),
      _AdminMenuItem('FCM 브로드캐스트', '전체 알림 전송', Icons.notifications_none,
          Colors.green, () => const FCMBroadcastScreen()),
      _AdminMenuItem('날씨 관리', '날씨 알림 설정', Icons.cloud_outlined,
          Colors.orange, () => const WeatherManagementScreen()),
      _AdminMenuItem('날씨 테스트', '알림 테스트 전송',
          Icons.notifications_active_outlined, Colors.purple,
          () => const WeatherTestScreen()),
      _AdminMenuItem('알림 발송 이력', '전체 알림 내역 조회', Icons.history,
          Colors.blueGrey, () => const AlertHistoryScreen(isAdmin: true)),
      _AdminMenuItem('신고 내역 관리', '접수된 신고 및 이미지', Icons.report_problem_outlined,
          Colors.redAccent, () => const ReportListScreen()),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('관리자 대시보드'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: '로그아웃',
            icon: const Icon(Icons.logout),
            onPressed: onLogout,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.deepPurple,
                child: Text(
                  user.name.isNotEmpty
                      ? user.name.substring(0, 1).toUpperCase()
                      : '?',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              title: Text(user.name),
              subtitle: Text(user.email),
              trailing: const Chip(label: Text('관리자')),
            ),
          ),
          const SizedBox(height: 16),
          const Text('관리 메뉴',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.3,
            children: [
              for (final item in menu)
                _MenuCard(
                  item: item,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => item.builder()),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AdminMenuItem {
  const _AdminMenuItem(
      this.title, this.subtitle, this.icon, this.color, this.builder);

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Widget Function() builder;
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.item, required this.onTap});

  final _AdminMenuItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(item.icon, color: item.color, size: 30),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(item.subtitle,
                      style: const TextStyle(
                          color: Colors.black54, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
