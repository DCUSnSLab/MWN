import 'package:flutter/widgets.dart';

/// iPad/태블릿 대응 유틸리티.
///
/// 이 앱은 iPhone 기준(logical width 375)으로 flutter_screenutil 스케일링이 돼 있다.
/// 태블릿(shortestSide >= [kTabletBreakpoint])에서 같은 designSize 를 그대로 쓰면
/// 가로 스케일 비율이 최대 2.7배까지 벌어져 패딩/폰트/아이콘/버튼이 과도하게 커진다.
/// 이 파일은 두 가지로 대응한다:
///
/// 1) [resolveDesignSize] — ScreenUtilInit 의 designSize 를 기기 클래스별로 다르게 줘서
///    태블릿에서 스케일 배율 자체를 1배 근처로 낮춘다. main.dart 에서 runApp 전에 호출한다.
/// 2) [TabletConstrained] — 폼/리스트/대시보드처럼 화면 폭 100%를 가정한 레이아웃을,
///    태블릿에서는 가운데 정렬 + 최대폭 제한으로 감싼다. 폰에서는 원본 그대로 통과(no-op)
///    라서 기존 폰 UX 는 전혀 바뀌지 않는다.

/// 이 폭(shortestSide, 논리 픽셀) 이상을 태블릿으로 간주한다.
/// Flutter Material 의 표준 태블릿 브레이크포인트(600dp)를 따른다.
const double kTabletBreakpoint = 600;

/// 로그인/회원가입/설정 등 단일 폼 화면에 쓰는 최대폭.
const double kFormMaxWidth = 480;

/// 리스트/카드 화면(시장 목록, 알림 내역, 관심 시장 등)에 쓰는 최대폭.
const double kListMaxWidth = 680;

/// 관리자 대시보드처럼 그리드/통계가 많은 화면에 쓰는 최대폭.
const double kDashboardMaxWidth = 900;

/// runApp 이전, 첫 프레임이 그려지기 전에 물리 화면 크기로 태블릿 여부를 판단한다.
/// (이 시점엔 BuildContext 가 없어 MediaQuery 를 쓸 수 없다.)
bool isTabletDevice() {
  final view = WidgetsBinding.instance.platformDispatcher.views.first;
  final size = view.physicalSize / view.devicePixelRatio;
  return size.shortestSide >= kTabletBreakpoint;
}

/// ScreenUtilInit(designSize: ...) 에 넘길 기준 크기.
/// 태블릿에서는 실제 iPad 세로 기준 크기에 가깝게 잡아 .w/.h/.sp/.r 스케일이
/// 1배 근처로 유지되게 한다(폰과 같은 비율로 커지지 않도록 하는 것이 핵심).
Size resolveDesignSize() {
  return isTabletDevice() ? const Size(768, 1024) : const Size(375, 812);
}

/// BuildContext 기준 태블릿 판정. 빌드 이후 화면 어디서든 사용 가능.
bool isTablet(BuildContext context) {
  return MediaQuery.of(context).size.shortestSide >= kTabletBreakpoint;
}

/// 폼/리스트/대시보드처럼 폭 100%를 가정한 화면 콘텐츠를 태블릿에서
/// 가운데 정렬 + 최대폭으로 제한한다.
///
/// 폰(shortestSide < [kTabletBreakpoint])에서는 [child] 를 그대로 반환하는
/// no-op 이라 기존 폰 레이아웃/픽셀은 전혀 바뀌지 않는다.
///
/// Scaffold.body 에 직접 쓰거나 SingleChildScrollView 의 child 로 써도 안전하다 —
/// Align 은 축마다 독립적으로 동작해서, 세로 스크롤 컨테이너 안에서도 가로축(폭)만
/// 제한되고 세로축은 그대로 스크롤된다.
class TabletConstrained extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const TabletConstrained({
    super.key,
    required this.child,
    this.maxWidth = kListMaxWidth,
  });

  @override
  Widget build(BuildContext context) {
    if (!isTablet(context)) return child;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
