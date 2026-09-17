# 릴리즈 체크리스트

`docs/DEPLOYMENT.md` 와 함께 사용. 매 빌드 업로드 전 한 번씩 훑어본다.

---

## 사전 점검 (모든 빌드)

- [ ] `flutter analyze` — error 0, warning 0
- [ ] `flutter test` — 통과 (테스트가 있다면)
- [ ] 디바이스/시뮬레이터에서 골든 패스 1회 (로그인 → 홈 → 지도 → 상세 → 신고)
- [ ] `pubspec.yaml` 의 `version` 의 **build 번호 (+N)** 를 이전 업로드보다 큰 값으로 증가
- [ ] 변경사항을 정리한 짧은 릴리즈 노트 준비 (한국어)
- [ ] `--dart-define=API_BASE_URL=...` 가 의도한 백엔드(스테이징/운영) 를 가리키는지 확인
- [ ] 사용 중인 시크릿 파일이 모두 제자리에 있는지
  - `android/key.properties`
  - `android/upload-keystore.jks`
  - `android/secrets.properties` (또는 `MAPS_API_KEY` 환경변수)
  - `android/app/google-services.json`
  - `ios/Runner/GoogleService-Info.plist`

---

## Android (Firebase App Distribution)

- [ ] `firebase login` 으로 인증된 상태인지 (`firebase projects:list` 로 `mwn-fb` 보이면 OK)
- [ ] 빌드: `flutter build appbundle --release --dart-define=API_BASE_URL=...`
- [ ] 또는 헬퍼: `./scripts/build_android.sh "<group>" "<release notes>"`
- [ ] 업로드 후 콘솔의 배포 URL 확인 / 테스터 그룹에 알림이 갔는지 확인
- [ ] (선택) Firebase 콘솔 → App Distribution 에서 해당 릴리즈가 표시되는지 검증

---

## iOS (TestFlight)

> macOS + Xcode 필수. Linux/Windows 에서는 이 섹션 스킵 불가능 — macOS 환경 필요.

- [ ] `flutter build ios --release --dart-define=API_BASE_URL=...` 가 성공
- [ ] `ios/Runner.xcworkspace` 를 Xcode 로 열고 디바이스를 "Any iOS Device (arm64)" 로 설정
- [ ] Product → Archive 가 에러 없이 끝나는지
- [ ] Organizer → Distribute App → App Store Connect → Upload
- [ ] 업로드 후 App Store Connect → TestFlight 탭에서 "Processing" → "Ready to Test" 로 바뀌는지 (10~30 분)
- [ ] 처음 업로드 시 수출 규정 (Export Compliance) 답변
- [ ] 내부 테스터에게 노출되는지 확인

---

## Tester Onboarding (한 번만)

### Android (Firebase App Distribution)

- [ ] Firebase 콘솔 → App Distribution → **Testers & Groups**
- [ ] 그룹 (`internal-testers` 등) 에 새 테스터 이메일 추가
- [ ] 테스터가 받은 초대 이메일에서 "Get Started" 클릭
- [ ] 안내된 절차로 **Firebase App Tester** 앱 설치 후 같은 Google 계정으로 로그인
- [ ] 첫 빌드를 발송하여 테스터 디바이스에서 설치까지 확인

### iOS (TestFlight)

- [ ] App Store Connect → 사용자 및 액세스에서 테스터 추가 (Apple ID 이메일)
- [ ] App Store Connect → TestFlight → **Internal Testing** 그룹에 이 테스터 추가
- [ ] 테스터가 받은 초대 이메일에서 "View in TestFlight" → TestFlight 앱 설치 후 수락
- [ ] 첫 빌드를 발송하여 TestFlight 에서 보이는지 확인

> **Tip**: TestFlight 외부 테스트로 100 명 넘게 모집할 경우 Apple 베타 리뷰가 필요하며 1~2 일 소요된다. 일정 잡을 때 고려.

---

## 릴리즈 후 확인

- [ ] 테스터에게 알림 도착 → 설치 성공 → 앱 실행 → 골든 패스 1회 (적어도 1 명)
- [ ] 크래시 리포트 (Firebase Crashlytics / TestFlight) 확인 — 새 빌드에서 크래시 0건
- [ ] `pubspec.yaml` 의 version 변경분을 `main` 에 커밋했는지
- [ ] (선택) GitHub Releases 에 태그 + 릴리즈 노트 등록
