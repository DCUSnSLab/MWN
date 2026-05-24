# MWN — Market Weather Notification

전통시장 상인·관계자에게 시장별 맞춤 기상 정보와 재난 알림(강수·강풍·폭염 등)을 실시간으로 제공하고,
시장 내 피해/위험 상황을 신고·관리하는 Flutter 모바일 앱.

## 주요 기능

- JWT 기반 로그인 / 자동 로그인, 일반 사용자·관리자 권한 분리
- 시장별 실시간 날씨 및 강수확률 조회 (기상청 단기/초단기 예보 API)
- 관심 시장 등록 기반 맞춤 대시보드
- 기상 임계값 도달 시 FCM 푸시 알림 (방해금지 시간 지원)
- 사진 첨부 현장 신고 및 관리자 모니터링

## 기술 스택

- Flutter / Dart
- 상태 관리: Provider
- 네트워크: `http` (`ApiService`)
- 푸시 알림: Firebase Cloud Messaging
- 로컬 저장: `shared_preferences`, `flutter_secure_storage`
- 백엔드(별도 저장소): Python / Flask + PostgreSQL

## 시작하기

사전 준비: Flutter SDK (버전은 `pubspec.yaml`의 `environment` 참고)

```bash
flutter pub get
flutter run
```

릴리즈 빌드:

```bash
flutter build apk        # Android APK
flutter build appbundle  # Android App Bundle
```

## 관리자 웹

관리자 기능은 동일 코드베이스를 Flutter Web으로 빌드해 웹에서도 사용할 수 있습니다.
`lib/main_web.dart`가 관리자 전용 진입점입니다.

```bash
flutter run -d chrome -t lib/main_web.dart   # 개발 실행
flutter build web -t lib/main_web.dart       # 웹 빌드 (build/web)
```

> 웹 관리자는 브라우저에서 백엔드 API를 호출하므로 백엔드의 CORS 허용이 필요하며,
> `http://` 백엔드 특성상 웹 관리자도 HTTP로 서빙해야 합니다(HTTPS는 혼합 콘텐츠로 차단됨).

## 더 보기

프로젝트 구조, 백엔드 연동, 배포 관련 상세 내용은 [PROJECT_HANDOVER.md](PROJECT_HANDOVER.md)를 참고하세요.
