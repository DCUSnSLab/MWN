#!/usr/bin/env bash
#
# Android 릴리즈 빌드 + Firebase App Distribution 업로드 헬퍼.
#
# Usage:
#   ./scripts/build_android.sh                                  # 기본 그룹 / 빈 노트
#   ./scripts/build_android.sh internal-testers "v1.0.0+12 - 지도 개편"
#   API_BASE_URL=http://stg.example.com ./scripts/build_android.sh
#
# 환경변수:
#   API_BASE_URL  — 백엔드 base URL. 기본은 lib/services/api_service.dart 의 default.
#   SKIP_UPLOAD   — "1" 이면 빌드만 하고 업로드는 건너뜀.
#   BUILD_KIND    — "aab" (기본) 또는 "apk".
#
# 사전 조건:
#   - flutter, firebase CLI 가 PATH 에 있고
#   - android/key.properties, android/upload-keystore.jks, android/secrets.properties,
#     android/app/google-services.json 이 모두 제자리에 있어야 한다.

set -euo pipefail

# ── 인자 / 환경 정리 ─────────────────────────────────────────────────────────
GROUP="${1:-internal-testers}"
NOTES="${2:-}"
BUILD_KIND="${BUILD_KIND:-aab}"
SKIP_UPLOAD="${SKIP_UPLOAD:-0}"

FIREBASE_APP_ID="1:758520453995:android:9be1c6b286f449acb78a2e"

# ── 위치 확인 ─────────────────────────────────────────────────────────────
cd "$(dirname "$0")/.."
ROOT="$(pwd)"

if [[ ! -f pubspec.yaml ]]; then
  echo "❌ pubspec.yaml 을 찾을 수 없다. 저장소 루트에서 실행하라." >&2
  exit 1
fi

# ── 사전 점검 ─────────────────────────────────────────────────────────────
require_file() {
  if [[ ! -f "$1" ]]; then
    echo "❌ 필수 시크릿 파일 누락: $1" >&2
    echo "   docs/DEPLOYMENT.md 의 1.2 시크릿 파일 표를 참고하라." >&2
    exit 1
  fi
}
require_file android/key.properties
require_file android/upload-keystore.jks
require_file android/app/google-services.json
# secrets.properties 는 환경변수로 대체 가능 → 둘 다 없으면 경고만
if [[ ! -f android/secrets.properties && -z "${MAPS_API_KEY:-}" ]]; then
  echo "⚠️  android/secrets.properties 도 없고 MAPS_API_KEY 환경변수도 없다."
  echo "    지도가 빈화면으로 나올 수 있다. 계속 진행한다."
fi

# 현재 버전 출력
VERSION=$(grep "^version:" pubspec.yaml | awk '{print $2}')
echo "📦 빌드 버전: $VERSION"

# ── Flutter 빌드 ──────────────────────────────────────────────────────────
DART_DEFINES=()
if [[ -n "${API_BASE_URL:-}" ]]; then
  DART_DEFINES+=(--dart-define "API_BASE_URL=${API_BASE_URL}")
  echo "🌐 API_BASE_URL=${API_BASE_URL}"
else
  echo "🌐 API_BASE_URL=(default, lib/services/api_service.dart 의 값)"
fi

echo "🧹 flutter clean"
flutter clean >/dev/null

echo "📥 flutter pub get"
flutter pub get >/dev/null

case "$BUILD_KIND" in
  aab)
    echo "🛠  flutter build appbundle --release"
    flutter build appbundle --release "${DART_DEFINES[@]}"
    ARTIFACT="build/app/outputs/bundle/release/app-release.aab"
    ;;
  apk)
    echo "🛠  flutter build apk --release"
    flutter build apk --release "${DART_DEFINES[@]}"
    ARTIFACT="build/app/outputs/flutter-apk/app-release.apk"
    ;;
  *)
    echo "❌ BUILD_KIND 는 aab 또는 apk 만 지원한다 (받은 값: $BUILD_KIND)" >&2
    exit 1
    ;;
esac

if [[ ! -f "$ARTIFACT" ]]; then
  echo "❌ 산출물이 생성되지 않았다: $ARTIFACT" >&2
  exit 1
fi

SIZE=$(du -h "$ARTIFACT" | awk '{print $1}')
echo "✅ 빌드 완료: $ARTIFACT ($SIZE)"

# ── 업로드 ────────────────────────────────────────────────────────────────
if [[ "$SKIP_UPLOAD" == "1" ]]; then
  echo "ℹ️  SKIP_UPLOAD=1 이라 업로드는 건너뛴다. 산출물: $ARTIFACT"
  exit 0
fi

if ! command -v firebase >/dev/null; then
  echo "❌ firebase CLI 가 PATH 에 없다. npm i -g firebase-tools 후 다시 시도." >&2
  exit 1
fi

UPLOAD_CMD=(
  firebase appdistribution:distribute "$ARTIFACT"
  --app "$FIREBASE_APP_ID"
  --groups "$GROUP"
)
if [[ -n "$NOTES" ]]; then
  UPLOAD_CMD+=(--release-notes "$NOTES")
fi

echo "🚀 Firebase App Distribution 업로드"
echo "   group=$GROUP"
[[ -n "$NOTES" ]] && echo "   notes=$NOTES"
"${UPLOAD_CMD[@]}"

echo "✅ 업로드 완료. Firebase 콘솔에서 배포 상태를 확인하라."
