# MWN 배포 가이드

테스트 빌드를 **Android(Firebase App Distribution)** 와 **iOS(TestFlight)** 로 내보내는 절차.

- 앱 식별자: `snslab.cu.ac.kr.mwn` (Android/iOS 공통)
- Firebase project: `mwn-fb` (number `758520453995`)
- Firebase 앱 ID
  - Android: `1:758520453995:android:9be1c6b286f449acb78a2e`
  - iOS: `1:758520453995:ios:7b09805871338a62b78a2e`

---

## 1. 공통 사전 준비

### 1.1 도구

| 도구 | 용도 | 비고 |
| --- | --- | --- |
| Flutter SDK | 빌드 | `pubspec.yaml` 의 `environment.sdk` 참고 (현재 `^3.9.2`) |
| Firebase CLI | Android 업로드 | `npm i -g firebase-tools` 또는 [공식 binary](https://firebase.google.com/docs/cli) |
| JDK 17+ | Android Gradle | `flutter doctor` 로 확인 |
| Xcode 15+ | iOS | macOS 전용 — Linux/Windows 에서는 iOS 빌드 불가 |
| Apple Developer 계정 | iOS 서명 | TestFlight 업로드용 |

### 1.2 시크릿 파일

저장소에 커밋되지 않는 파일들. 처음 셋업할 때 안전한 곳에서 복원해야 한다.

| 파일 | 용도 | 위치 |
| --- | --- | --- |
| `android/key.properties` | Android 릴리즈 키스토어 메타 (`storePassword`, `keyPassword`, `keyAlias`, `storeFile`) | `android/.gitignore` 에 포함 |
| `android/upload-keystore.jks` | Android 업로드 키 | `android/key.properties` 의 `storeFile` 가 가리키는 경로 |
| `android/secrets.properties` | Maps API 등 빌드 시 주입되는 시크릿 (`MAPS_API_KEY`) | `secrets.properties` 또는 환경변수 `MAPS_API_KEY` |
| `android/app/google-services.json` | Firebase Android 설정 | gitignored |
| `ios/Runner/GoogleService-Info.plist` | Firebase iOS 설정 | gitignored |

> ⚠️ 위 파일이 누락된 채로 `flutter build` 를 실행하면 키 검증 실패 또는 Firebase 미초기화로 떨어진다.

### 1.3 버전 관리

`pubspec.yaml` 의 `version` 한 곳에서 관리한다.

```yaml
version: 1.0.0+11
#         ^      ^
#         |      └── build number (TestFlight/Play 에 고유해야 함)
#         └────── marketing version (UI 노출용)
```

- **build number** 는 **반드시 매 업로드마다 증가**시킨다. 같은 번호로 두 번 올리면 거절된다.
- marketing version (`1.0.0`) 은 사용자에게 보이는 버전. 큰 변화 없을 땐 그대로 두고 build 번호만 올려도 된다.
- Flutter 가 두 값을 각각 Android `versionCode` / `versionName` 과 iOS `CURRENT_PROJECT_VERSION` / `MARKETING_VERSION` 에 자동 전달한다.

---

## 2. Android — Firebase App Distribution

### 2.1 최초 1회: Firebase CLI 로그인

```bash
firebase login
# 브라우저로 OAuth 인증
firebase projects:list   # mwn-fb 가 보이면 OK
```

### 2.2 빌드

```bash
# 저장소 루트에서
flutter clean
flutter pub get

# AAB(권장) — Play Store 와 호환되는 포맷
flutter build appbundle --release \
  --dart-define=API_BASE_URL=http://203.250.33.77

# 또는 APK (간단 배포용)
flutter build apk --release \
  --dart-define=API_BASE_URL=http://203.250.33.77
```

산출물:
- AAB: `build/app/outputs/bundle/release/app-release.aab`
- APK: `build/app/outputs/flutter-apk/app-release.apk`

> `--dart-define=API_BASE_URL=...` 을 명시하지 않으면 `lib/services/api_service.dart` 의 기본값(운영 IP) 이 사용된다. 스테이징 백엔드로 보낼 땐 반드시 명시한다.

### 2.3 Firebase App Distribution 업로드

```bash
firebase appdistribution:distribute \
  build/app/outputs/bundle/release/app-release.aab \
  --app 1:758520453995:android:9be1c6b286f449acb78a2e \
  --groups "internal-testers" \
  --release-notes-file release-notes.txt
```

옵션:
- `--groups` : Firebase 콘솔에서 만든 테스터 그룹 이름
- `--testers "a@x.com,b@y.com"` : 그룹 대신 개별 이메일
- `--release-notes "한 줄 메모"` : 인라인 릴리즈 노트
- `--release-notes-file path.txt` : 파일에서 읽기

업로드 성공 시 콘솔이 배포 URL 을 출력한다. 그룹의 테스터 모두에게 자동으로 이메일이 발송된다.

### 2.4 헬퍼 스크립트

위 절차를 한 번에 수행하는 스크립트 제공:

```bash
./scripts/build_android.sh
# 또는 인자로 그룹 / 노트 지정
./scripts/build_android.sh "internal-testers" "v1.0.0+12 - 지도 개편"
```

---

## 3. iOS — TestFlight

> ⚠️ **iOS 빌드는 macOS + Xcode 가 필수**다. Linux/Windows 환경에선 불가능. macOS 머신에서 아래 절차를 수행한다.

### 3.1 최초 1회 셋업

1. Apple Developer Program 가입 (연 $99 또는 $299).
2. App Store Connect 에 앱 등록 — Bundle ID `snslab.cu.ac.kr.mwn`.
3. 인증서 / 프로비저닝 프로파일:
   - Xcode → Settings → Accounts 에서 Apple ID 로그인.
   - Runner.xcodeproj → Signing & Capabilities → "Automatically manage signing" 활성.
   - Team 선택 후 자동으로 Development / Distribution 프로파일 생성.
4. `ios/Runner/GoogleService-Info.plist` 가 존재하는지 확인 (gitignored).

### 3.2 빌드 & 아카이브 (Xcode GUI)

```bash
# 저장소 루트에서
flutter clean
flutter pub get
cd ios && pod install && cd ..

# Flutter 빌드 (release iOS framework 생성)
flutter build ios --release \
  --dart-define=API_BASE_URL=http://203.250.33.77
```

이어서 **Xcode** 로 진행:

1. `open ios/Runner.xcworkspace` (꼭 `.xcodeproj` 가 아니라 `.xcworkspace`).
2. 상단 타깃 셀렉터에서 디바이스를 **"Any iOS Device (arm64)"** 로 변경.
3. 메뉴 → Product → **Archive**. 빌드가 끝나면 Organizer 가 열린다.
4. Organizer 에서 이 빌드를 선택 → **Distribute App** → **App Store Connect** → **Upload** → 옵션은 기본값 유지 → Next → Upload.
5. 업로드 성공 시 App Store Connect 의 TestFlight 탭에 빌드가 처리 대기(보통 10~30 분).

### 3.3 빌드 & 아카이브 (CLI — fastlane / xcodebuild)

GUI 없이 자동화하려면:

```bash
# Archive
xcodebuild -workspace ios/Runner.xcworkspace \
  -scheme Runner \
  -configuration Release \
  -archivePath build/ios/Runner.xcarchive \
  archive

# Export IPA (ExportOptions.plist 필요)
xcodebuild -exportArchive \
  -archivePath build/ios/Runner.xcarchive \
  -exportPath build/ios/ipa \
  -exportOptionsPlist ios/ExportOptions.plist

# Upload to App Store Connect
xcrun altool --upload-app \
  --type ios \
  --file build/ios/ipa/Runner.ipa \
  --username "<APPLE_ID_EMAIL>" \
  --password "@keychain:AC_PASSWORD"
# AC_PASSWORD 는 사전에 keychain 에 등록한 app-specific password
```

`ios/ExportOptions.plist` 예시는 `scripts/build_ios.sh` 안의 주석 참조.

### 3.4 TestFlight 에서 테스터에게 노출

1. App Store Connect → My Apps → MWN → **TestFlight** 탭.
2. 빌드가 "Ready to Submit" 또는 "Ready to Test" 상태인지 확인. 처음 업로드 시에는 **수출 규정 (Export Compliance)** 한 번 답해야 한다.
3. 내부 테스터 (Internal Testing): 팀 멤버 최대 100 명. 즉시 사용 가능.
4. 외부 테스터 (External Testing): Apple 베타 리뷰 통과 필요 (보통 1~2 일). 최대 10,000 명.

### 3.5 헬퍼 스크립트

`scripts/build_ios.sh` — macOS 에서만 동작. Linux 에서는 안내 메시지 출력 후 종료.

---

## 4. 테스터 추가 / 온보딩

`docs/RELEASE_CHECKLIST.md` 의 "Tester onboarding" 섹션 참고. 짧게:

**Android (Firebase App Distribution)**
1. Firebase 콘솔 → App Distribution → Testers & Groups → 그룹에 이메일 추가
2. 테스터가 받은 이메일에서 "Get Started" → Firebase App Tester 앱 설치 → 같은 계정으로 로그인
3. 새 빌드가 올라올 때마다 자동 알림 → 앱 안에서 설치

**iOS (TestFlight)**
1. App Store Connect → 사용자 및 액세스 → 테스터 추가 (이메일)
2. 테스터에게 자동 이메일이 가고, TestFlight 앱 설치 후 코드/링크 입력
3. 새 빌드가 올라오면 TestFlight 앱이 알림

---

## 5. 자주 발생하는 문제

### 5.1 Android

| 증상 | 원인 | 해결 |
| --- | --- | --- |
| `Keystore file does not exist` | `key.properties` 의 `storeFile` 경로가 잘못됨 | `android/upload-keystore.jks` 가 실제 존재하고 `storeFile=upload-keystore.jks` 로 적혔는지 확인 |
| `versionCode 11 has already been used` | 이전과 같은 build number | `pubspec.yaml` 의 `+N` 을 증가 |
| Firebase 앱 ID 에러 | App Distribution 에 등록되지 않은 앱 | Firebase 콘솔 → App Distribution → 앱 등록 |
| `MAPS_API_KEY` 미설정 → 지도 빈화면 | `secrets.properties` 누락 | 파일 복원 또는 `MAPS_API_KEY=...` 환경변수 |

### 5.2 iOS

| 증상 | 원인 | 해결 |
| --- | --- | --- |
| `No signing certificate "iOS Distribution" found` | Apple Developer 멤버십 미가입 또는 Xcode 미인증 | Settings → Accounts 에 Apple ID 추가 + Team 선택 |
| `CFBundleVersion ... already exists` | 같은 build number 재업로드 | `+N` 증가 후 재빌드 |
| `ITMS-90809: Deprecated API Usage` | 사용 중인 패키지가 만료된 API 호출 | 경고로만 처리되며 업로드는 통과 (이슈로만 기록) |
| Pod 충돌 | `Podfile.lock` 손상 | `cd ios && pod deintegrate && pod install` |

---

## 6. 다음 단계

운영을 진행할수록 수동 작업 빈도가 높아진다. 다음 단계로 자동화를 권장:

- `scripts/build_android.sh` / `scripts/build_ios.sh` 헬퍼 스크립트로 매 빌드의 명령어를 단순화 (이미 제공).
- GitHub Actions (`.github/workflows/android-distribute.yml`, `.github/workflows/ios-testflight.yml`) 초안을 참고해 CI 자동 배포 구축.
- 시크릿은 GitHub Secrets 에 저장하고 워크플로에서 주입.
