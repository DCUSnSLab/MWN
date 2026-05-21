# MWN (Market Weather Notification) - Project Handover Document

## 📌 프로젝트 소개 (Project Overview)
**MWN(날씨 알림 앱)**은 전통시장 상인 및 관계자들에게 지역(시장)별 맞춤형 기상 정보와 재난 알림(강수, 강풍, 폭염 등)을 실시간으로 제공하고, 시장 내 피해/위험 상황을 신고하여 관리할 수 있는 모바일 애플리케이션입니다.

---

## 🛠 기술 스택 (Tech Stack)
### Frontend (Mobile App)
- **Framework/Language**: Flutter / Dart
- **State Management**: Provider (e.g., `AuthProvider`, `MarketProvider`)
- **Routing**: Flutter Navigator
- **Storage/Local**: `shared_preferences`, `flutter_secure_storage`
- **Network**: `http` (Custom `ApiService` for API & Token management)
- **Push Notifications**: Firebase Cloud Messaging (FCM)

### Backend (Server)
- **Framework/Language**: Python / Flask
- **ORM**: SQLAlchemy (`db.Model` 기반)
- **Database**: PostgreSQL
- **Deployment/Infra**: Docker & Docker Compose (`mwn_backend` 및 `diagnose_notification` 폴더 구조 참고)
- **Auth**: JWT (JSON Web Token - Access/Refresh 발급 및 검증)
- **External API**: 기상청 날씨 단기/초단기 예측 API

---

## 📁 디렉토리 구조 및 핵심 컴포넌트 (Directory Structure)

### 1. Frontend (이 저장소 루트)
- `lib/models/`: 데이터 모델 (`User`, `Weather`, `MarketReport`, `Market` 등)
- `lib/providers/`: 상태 관리 로직 (`auth_provider.dart`, `market_provider.dart` 등)
- `lib/services/`: 외부 통신 및 비즈니스 로직
  - `api_service.dart`: 백엔드 API와의 통신 및 에러/토큰 만료 핸들링 로직. `baseUrl` 은 `--dart-define=API_BASE_URL=...` 빌드 인자로 주입하며, 미지정 시 운영 서버 IP 를 기본값으로 사용한다.
  - `fcm_service.dart`: FCM 알림 수신, 권한 요청, 백그라운드 핸들링
- `lib/screens/`: UI 화면 구성
  - `auth/`: 로그인(`login_screen.dart`), 회원가입, 비밀번호 확인 로직
  - `home/`: 메인 대시보드 및 날씨 정보 표시
  - `admin/`: **관리자 전용 기능** (유저 관리, 시장 별 알림 조건 세팅, 수동 FCM 푸시 전송, 신고 내역 관리 상세페이지 등)

### 2. Backend (별도 저장소 `mwn_backend/`)
*Flutter 앱 저장소 외부에 위치한다. 본 저장소의 `diagnose_notification/` 폴더는 과거에 Docker compose 설정을 참조하던 흔적이며 현재는 비어 있다.*
- `app.py`: Flask 라우팅 엔드포인트 집합 (회원가입/로그인, FCM 발송, 신고 수합, 날씨 API 연동 등)
- `models.py`: 데이터베이스 테이블 명세
  - `User`, `Market`, `MarketReport`, `Weather`, `DamageStatus`, `MarketAlarmLog`, `PasswordVerificationAttempt` 등
- `auth_utils.py`: JWT 토큰 발급/검증 로직 및 `@login_required`, `@admin_required` 데코레이터 포함
- `create_report_table.py` / `test_weather_alerts.py` 등 서버 테스트/마이그레이션 도구 존재

---

## 🚀 주요 기능 (Key Features)
1. **사용자 연동 및 보안**
   - JWT 기반 로그인/자동 로그인 (토큰 갱신 로직 포함).
   - 권한 분리: 일반 사용자(`user`), 관리자(`admin`)

2. **시장 맞춤형 기상 정보 조회**
   - 기상청 XY 격자 좌표를 매핑하여 특정 시장의 실시간 날씨 데이터 및 강수확률 조회. 
   - 사용자는 관심 시장을 등록하여 맞춤형 메인 화면 구축.

3. **기상 재난 알림 (FCM)**
   - 강풍, 한파, 폭우 등에 대한 시장별 알림 임계값(Threshold)을 관리자나 시스템에서 설정.
   - 조건 도달 시 해당 시장을 관심 등록한 사용자에게 FCM 자동/수동 푸시 메시지 전송.
   - 방해금지 시간(Do Not Disturb) 지원.

4. **신고 접수 (Market Report)**
   - 화재, 배수 등 시장 환경 문제에 대한 사진 첨부 신고 기능.
   - 관리자가 **신고 내역 관리** 화면(`ReportListScreen`)에서 특정 시장 이름 기준 및 "사진만 보기" 필터링을 통해 원클릭 모니터링 가능.

---

## 🚨 다른 AI를 위한 인계 및 컨텍스트 (Handover Context & Recent Changes)

### 최근 진행 완료된 작업
- **신고 내역 필터링 추가 UI**: `lib/screens/admin/report_list_screen.dart` 내 Dropdown을 통한 "시장별 필터" 기능 및 "사진만 보기" Toggle 구현 완료.
- **백엔드 신고조회 API 복원**: 분실되었던 `GET /api/reports` 엔드포인트를 백엔드 저장소(`mwn_backend/app.py`)에 정상적으로 추가.
- **Flutter 정적 분석 해결**: Image 위젯 렌더링 과정의 Null Safety 경고 해결 완료.
- **APK / AAB 앱 번들 빌드**: `key.properties` 안의 오타를 패치(`upload-key.jks` -> `upload-keystore.jks`)하여 Release 빌드 성공.

### 주의사항 및 Known Constraints
1. **로컬 백엔드 서버 상태 검증 요망**:
   - Docker 데몬이 꺼져있거나 컨테이너가 내려간 상태에서는 API 호출이 `Connection refused` 로 실패합니다.
   - 백엔드 테스트 전, Docker 데몬을 켜고 `mwn_backend` 컨테이너가 `up` 상태인지 확인해야 합니다.
2. **Base URL 주입**:
   - `lib/services/api_service.dart` 의 `baseUrl` 은 `--dart-define=API_BASE_URL=...` 빌드 인자로 주입한다. 미지정 시 운영 서버 IP 가 기본값으로 사용된다.
   - 로컬 테스트 예시:
     - Android Emulator: `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000`
     - iOS Simulator / Desktop: `flutter run --dart-define=API_BASE_URL=http://localhost:5000`
     - 실기기: 호스트 PC 의 LAN IP 사용 (예: `http://192.168.x.x:5000`).
3. **Workspace 접근 제한**:
   - 백엔드 저장소(`mwn_backend`)는 이 Flutter 저장소 외부에 위치하므로, Agent 가 해당 폴더에서 CLI 커맨드를 실행하지 못할 수 있습니다. DB/Python 실행은 백엔드 저장소를 별도로 열어 진행하거나, Docker-compose 컨텍스트를 명시적으로 지정해야 합니다.

이 문서의 정보를 바탕으로 클라이언트/서버 요구사항을 판단하고 이어서 개발을 안전하게 진행하시기 바랍니다.
