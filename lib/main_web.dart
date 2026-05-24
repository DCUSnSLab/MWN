import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import 'models/user.dart';
import 'providers/market_provider.dart';
import 'services/api_service.dart';
import 'screens/admin/web/admin_web_login.dart';
import 'screens/admin/web/admin_web_dashboard.dart';

/// 관리자 전용 웹 진입점.
///
/// 실행: `flutter run -d chrome -t lib/main_web.dart`
/// 빌드: `flutter build web -t lib/main_web.dart`
///
/// 모바일 앱(`main.dart`)과 코드베이스를 공유하되, FCM 수신·지도·위치 등
/// 웹에서 불필요하거나 미지원인 의존성은 끌어오지 않도록 `ApiService` 만
/// 직접 사용한다. 따라서 Firebase 초기화도 수행하지 않는다.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AdminWebApp());
}

class AdminWebApp extends StatelessWidget {
  const AdminWebApp({super.key});

  /// 모바일 레이아웃 기준으로 작성된 관리자 화면을 웹에서 그대로 쓰기 위해
  /// 앱을 휴대폰 폭의 중앙 프레임 안에 렌더링한다.
  static const double _frameWidth = 480;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MWN 관리자',
      home: Builder(
        builder: (context) {
          final media = MediaQuery.of(context);
          return ColoredBox(
            color: const Color(0xFFE9E9EC),
            child: Center(
              child: SizedBox(
                width: _frameWidth,
                child: MediaQuery(
                  data: media.copyWith(
                    size: Size(_frameWidth, media.size.height),
                  ),
                  child: ScreenUtilInit(
                    designSize: const Size(375, 812),
                    minTextAdapt: true,
                    builder: (_, __) => const _AdminWebShell(),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AdminWebShell extends StatelessWidget {
  const _AdminWebShell();

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MarketProvider(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'MWN 관리자',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepPurple,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(centerTitle: true),
        ),
        home: const AdminWebGate(),
      ),
    );
  }
}

enum _GateStatus { loading, login, denied, ready }

/// 세션 복원 → 권한 확인 → 적절한 화면으로 분기한다.
class AdminWebGate extends StatefulWidget {
  const AdminWebGate({super.key});

  @override
  State<AdminWebGate> createState() => _AdminWebGateState();
}

class _AdminWebGateState extends State<AdminWebGate> {
  final ApiService _api = ApiService();
  _GateStatus _status = _GateStatus.loading;
  User? _user;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    try {
      await _api.loadTokens();
      if (!_api.isLoggedIn) {
        if (mounted) setState(() => _status = _GateStatus.login);
        return;
      }
      _applyUser(await _api.getProfile());
    } catch (_) {
      await _api.clearTokens();
      if (mounted) setState(() => _status = _GateStatus.login);
    }
  }

  void _applyUser(User user) {
    if (!mounted) return;
    setState(() {
      _user = user;
      _status =
          user.role == 'admin' ? _GateStatus.ready : _GateStatus.denied;
    });
  }

  Future<void> _logout() async {
    try {
      await _api.logout();
    } catch (_) {
      // 서버 측 로그아웃 실패와 무관하게 로컬 세션은 정리한다.
    } finally {
      await _api.clearTokens();
      if (mounted) {
        setState(() {
          _user = null;
          _status = _GateStatus.login;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_status) {
      case _GateStatus.loading:
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      case _GateStatus.login:
        return AdminWebLogin(onAuthenticated: _applyUser);
      case _GateStatus.denied:
        return _AccessDeniedView(onLogout: _logout);
      case _GateStatus.ready:
        return AdminWebDashboard(user: _user!, onLogout: _logout);
    }
  }
}

class _AccessDeniedView extends StatelessWidget {
  const _AccessDeniedView({required this.onLogout});

  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline,
                  size: 64, color: Colors.redAccent),
              const SizedBox(height: 16),
              const Text(
                '관리자 권한이 필요합니다',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                '이 페이지는 관리자 계정만 접근할 수 있습니다.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onLogout,
                child: const Text('다른 계정으로 로그인'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
