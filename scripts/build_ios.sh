#!/usr/bin/env bash
#
# iOS 릴리즈 빌드 + TestFlight 업로드 헬퍼. **macOS 전용**.
#
# Usage:
#   ./scripts/build_ios.sh                    # 아카이브 + Xcode 자동 export 까지만
#   ./scripts/build_ios.sh --upload           # 위 + altool 로 TestFlight 업로드
#
# 사전 조건:
#   - macOS + Xcode 15+ + Apple Developer 계정
#   - Xcode → Settings → Accounts 에 Apple ID 추가, Team 선택, 자동 서명 ON
#   - ios/ExportOptions.plist 가 존재 (없으면 이 스크립트 첫 실행 시 안내)
#   - 업로드 사용 시: ASC_USERNAME, ASC_PASSWORD 환경변수 (또는 키체인의 @keychain:AC_PASSWORD)
#
# Linux/Windows 에서 실행 시: 안내 메시지만 출력 후 0 으로 종료.

set -euo pipefail

# ── 플랫폼 가드 ────────────────────────────────────────────────────────────
if [[ "$(uname)" != "Darwin" ]]; then
  cat <<'MSG'
ℹ️  이 스크립트는 macOS 전용이다.
    iOS 빌드/업로드는 Xcode 가 필요하므로 Linux/Windows 에서 수행할 수 없다.

    필요한 환경:
      - macOS 13+ (Sonoma 권장)
      - Xcode 15+
      - Apple Developer Program 계정
      - 동일 저장소 + ios/Runner/GoogleService-Info.plist (gitignored)

    macOS 머신에서 같은 스크립트를 실행하라.
    상세 절차는 docs/DEPLOYMENT.md 의 "3. iOS — TestFlight" 섹션 참고.
MSG
  exit 0
fi

# ── 인자 ──────────────────────────────────────────────────────────────────
UPLOAD=0
for arg in "$@"; do
  case "$arg" in
    --upload) UPLOAD=1 ;;
    -h|--help)
      head -n 14 "$0" | sed 's/^# //;s/^#//'
      exit 0
      ;;
  esac
done

# ── 위치 ──────────────────────────────────────────────────────────────────
cd "$(dirname "$0")/.."
ROOT="$(pwd)"

if [[ ! -f pubspec.yaml ]]; then
  echo "❌ pubspec.yaml 을 찾을 수 없다. 저장소 루트에서 실행하라." >&2
  exit 1
fi

# ── 사전 점검 ─────────────────────────────────────────────────────────────
if [[ ! -f ios/Runner/GoogleService-Info.plist ]]; then
  echo "❌ ios/Runner/GoogleService-Info.plist 누락 (gitignored, 별도 복원 필요)." >&2
  exit 1
fi

# 버전 출력
VERSION=$(grep "^version:" pubspec.yaml | awk '{print $2}')
echo "📦 빌드 버전: $VERSION"

# ── Flutter 빌드 ──────────────────────────────────────────────────────────
DART_DEFINES=()
if [[ -n "${API_BASE_URL:-}" ]]; then
  DART_DEFINES+=(--dart-define "API_BASE_URL=${API_BASE_URL}")
  echo "🌐 API_BASE_URL=${API_BASE_URL}"
fi

echo "🧹 flutter clean"
flutter clean >/dev/null

echo "📥 flutter pub get"
flutter pub get >/dev/null

echo "📦 pod install"
(cd ios && pod install)

echo "🛠  flutter build ios --release --no-codesign"
# --no-codesign 이면 xcodebuild archive 에서 서명을 적용한다.
flutter build ios --release --no-codesign "${DART_DEFINES[@]}"

# ── Archive ───────────────────────────────────────────────────────────────
ARCHIVE_PATH="build/ios/Runner.xcarchive"
echo "📦 xcodebuild archive → $ARCHIVE_PATH"
xcodebuild \
  -workspace ios/Runner.xcworkspace \
  -scheme Runner \
  -configuration Release \
  -archivePath "$ARCHIVE_PATH" \
  archive

# ── Export ────────────────────────────────────────────────────────────────
EXPORT_OPTS="ios/ExportOptions.plist"
if [[ ! -f "$EXPORT_OPTS" ]]; then
  cat <<MSG >&2
❌ $EXPORT_OPTS 가 없다. 아래 템플릿으로 생성한 뒤 다시 실행하라.

<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store</string>
    <key>teamID</key>
    <string>YOUR_TEAM_ID</string>
    <key>uploadSymbols</key>
    <true/>
    <key>uploadBitcode</key>
    <false/>
</dict>
</plist>
MSG
  exit 1
fi

EXPORT_PATH="build/ios/ipa"
mkdir -p "$EXPORT_PATH"
echo "📤 xcodebuild -exportArchive → $EXPORT_PATH"
xcodebuild \
  -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$EXPORT_OPTS"

IPA="$EXPORT_PATH/Runner.ipa"
if [[ ! -f "$IPA" ]]; then
  IPA=$(ls "$EXPORT_PATH"/*.ipa 2>/dev/null | head -1 || true)
fi
[[ -z "$IPA" ]] && { echo "❌ ipa 가 생성되지 않았다." >&2; exit 1; }
echo "✅ IPA: $IPA"

# ── Upload ────────────────────────────────────────────────────────────────
if [[ "$UPLOAD" != "1" ]]; then
  echo "ℹ️  --upload 옵션 없음. IPA 를 수동으로 Transporter 또는 Xcode Organizer 로 업로드하라."
  exit 0
fi

if [[ -z "${ASC_USERNAME:-}" ]]; then
  echo "❌ ASC_USERNAME (Apple ID 이메일) 환경변수 필요." >&2
  exit 1
fi
ASC_PASSWORD_REF="${ASC_PASSWORD:-@keychain:AC_PASSWORD}"

echo "🚀 xcrun altool --upload-app"
xcrun altool --upload-app \
  --type ios \
  --file "$IPA" \
  --username "$ASC_USERNAME" \
  --password "$ASC_PASSWORD_REF"

echo "✅ TestFlight 업로드 완료. App Store Connect → TestFlight 에서 처리 대기."
