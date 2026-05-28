# 시크릿 / 키 관리

클라이언트 키와 Firebase 설정 파일은 **저장소에 커밋하지 않습니다.** 각자 로컬에 배치하거나
CI 가 빌드 시 주입합니다. 아래 파일들은 `.gitignore` 처리돼 있으며, `*.example` 템플릿만
저장소에 포함됩니다.

## 필요한 로컬 파일

| 파일 | 용도 | 획득 방법 |
|---|---|---|
| `android/secrets.properties` | Android Google Maps API 키 | `android/secrets.properties.example` 복사 후 값 채우기 |
| `ios/Flutter/Secrets.xcconfig` | iOS Google Maps API 키 | `ios/Flutter/Secrets.xcconfig.example` 복사 후 값 채우기 |
| `android/app/google-services.json` | Android Firebase 설정 | Firebase 콘솔 > 프로젝트 설정 > Android 앱에서 다운로드 |
| `ios/Runner/GoogleService-Info.plist` | iOS Firebase 설정 | Firebase 콘솔 > 프로젝트 설정 > iOS 앱에서 다운로드 |

## 동작 방식

- **Android Maps 키**: `secrets.properties`(또는 `MAPS_API_KEY` 환경변수) → `build.gradle.kts`가
  읽어 `manifestPlaceholders["MAPS_API_KEY"]` 로 주입 → `AndroidManifest.xml`의 `${MAPS_API_KEY}` 치환.
- **iOS Maps 키**: `Secrets.xcconfig`의 `MAPS_API_KEY` → `Info.plist`의 `GMSApiKey=$(MAPS_API_KEY)`
  → `AppDelegate.swift`가 런타임에 읽어 `GMSServices.provideAPIKey(...)` 호출.
- **Firebase 설정**: `google-services` Gradle 플러그인 / iOS 빌드가 각 설정 파일을 직접 읽습니다.

## CI 에서

빌드 전에 위 4개 파일을 시크릿 저장소에서 생성/주입하세요 (예: `secrets.properties` 작성,
`google-services.json` 배치). 파일이 없으면 빌드는 되지만 지도/Firebase 기능이 동작하지 않습니다.

## 참고: 기존 git 히스토리

이 키들은 과거 커밋에 평문으로 남아 있습니다. 키에 사용처 제한(Android 패키지+SHA-1,
iOS 번들 ID, API 범위)이 걸려 있어 즉각적 위험은 낮지만, 완전한 제거가 필요하면
**키 재발급(rotate)** 또는 히스토리 재작성(BFG/filter-repo)을 별도로 진행해야 합니다.
