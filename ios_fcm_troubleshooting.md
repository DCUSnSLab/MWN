# iOS FCM 알림 문제 해결 가이드

## 🚨 현재 상황
iOS에서 FCM 알림이 작동하지 않는 문제를 해결하기 위한 체계적인 접근 방법입니다.

## 📋 1단계: 기본 진단 (앱 내에서 실행)

### 관리자 대시보드에서 확인
1. 앱에서 관리자 계정으로 로그인
2. "iOS FCM 디버깅" 메뉴 클릭
3. 다음 항목들을 확인:

```
✅ 정상 상태일 때:
- 기기 타입: ✅ 실기기
- 권한 상태: ✅ 허용됨
- APNS 토큰: ✅ 있음
- FCM 토큰: ✅ 있음
- Firebase 연결: connected

❌ 문제가 있을 때:
- 기기 타입: ❌ 시뮬레이터
- 권한 상태: ❌ 거부됨 또는 ⚠️ 미결정
- APNS 토큰: ❌ 없음
- FCM 토큰: ❌ 없음
```

## 🔧 2단계: Firebase Console 설정 확인

### A. APNs 인증 설정
1. [Firebase Console](https://console.firebase.google.com/) 접속
2. 프로젝트 선택 > 프로젝트 설정 (⚙️)
3. Cloud Messaging 탭
4. iOS 앱 섹션에서 다음 확인:

#### 방법 1: APNs 인증 키 (권장)
```
- APNs 인증 키 파일 (.p8) 업로드 여부
- 키 ID 입력 여부
- 팀 ID 입력 여부
```

#### 방법 2: APNs 인증서 (기존 방식)
```
- Development/Production 인증서 (.p12) 업로드 여부
- 인증서 만료일 확인
- 비밀번호 설정 여부
```

### B. Bundle ID 확인
```
Firebase Console Bundle ID: com.example.mwn
iOS 프로젝트 Bundle ID: (Xcode에서 확인)
→ 정확히 일치해야 함
```

## 🍎 3단계: Apple Developer 설정

### A. App ID 설정
1. [Apple Developer Console](https://developer.apple.com/account/) 접속
2. Certificates, Identifiers & Profiles
3. Identifiers > App IDs
4. 해당 Bundle ID 선택
5. Capabilities에서 "Push Notifications" 체크 확인

### B. 프로비저닝 프로파일
1. 개발용/배포용 프로비저닝 프로파일 재생성
2. Push Notifications 기능 포함 확인
3. Xcode에서 새 프로파일로 업데이트

## 📱 4단계: iOS 기기 설정

### A. 기기 알림 설정
```
설정 > 알림 > MWN
├── 알림 허용: ON
├── 잠금 화면: ON
├── 알림 센터: ON
├── 배너: ON (또는 알림)
├── 사운드: ON
└── 배지: ON
```

### B. 백그라운드 앱 새로고침
```
설정 > 일반 > 백그라운드 앱 새로고침
├── 백그라운드 앱 새로고침: ON
└── MWN: ON
```

## 🛠️ 5단계: Xcode 프로젝트 설정

### A. Capabilities 확인
```
Xcode > Runner > Signing & Capabilities
└── + Capability > Push Notifications 추가
```

### B. Entitlements 파일
`ios/Runner/Runner.entitlements` 확인:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>aps-environment</key>
    <string>development</string> <!-- 또는 production -->
</dict>
</plist>
```

### C. Info.plist 확인
```xml
<key>UIBackgroundModes</key>
<array>
    <string>remote-notification</string>
</array>
```

## 🧪 6단계: 테스트 방법

### A. 시뮬레이터 vs 실기기
```
❌ iOS 시뮬레이터: APNS 지원 안 함
✅ 실제 iOS 기기: APNS 지원
```

### B. Firebase Console 테스트
1. Firebase Console > Cloud Messaging
2. "첫 번째 캠페인 보내기"
3. FCM 토큰 직접 입력하여 테스트

### C. 백엔드 테스트
관리자 대시보드 > FCM 브로드캐스트로 테스트 전송

## 🔍 7단계: 로그 분석

### 중요한 로그 메시지들:
```
🔥 FCM 초기화 시작 (iOS)
✅ FCM 권한 허용됨
🍎 iOS APNS 토큰 등록 대기 중...
✅ APNS 토큰 획득 성공
🎯 FCM 토큰 획득 성공
📨 포그라운드 FCM 메시지 수신
```

### 문제 발생 시 로그:
```
❌ FCM 권한 거부됨
⚠️ APNS 토큰 획득 실패
💥 FCM 토큰 획득 오류
```

## 🚨 8단계: 일반적인 문제들

### 문제 1: "No APNS token specified"
**원인**: APNS 토큰이 없음
**해결**: 실기기에서 테스트, Apple Developer 설정 확인

### 문제 2: FCM 토큰은 있지만 알림 안 옴
**원인**: Firebase Console APNs 설정 문제
**해결**: APNs 인증서/키 재업로드

### 문제 3: 권한은 허용했지만 토큰 없음
**원인**: Bundle ID 불일치 또는 프로비저닝 문제
**해결**: Bundle ID 확인, 프로비저닝 프로파일 재생성

### 문제 4: 개발 환경에서만 작동 안 함
**원인**: Development/Production 환경 불일치
**해결**: Firebase Console에서 올바른 환경의 인증서 업로드

## 📞 9단계: 추가 도움

### 확인해야 할 추가 사항들:
1. **네트워크 연결**: Firebase와 연결 상태 확인
2. **iOS 버전**: 최신 iOS에서 테스트
3. **Firebase SDK 버전**: 최신 버전 사용 권장
4. **Apple Developer 계정**: 유효한 개발자 계정 확인
5. **인증서 만료**: Apple 인증서 만료일 확인

### 도구들:
- iOS FCM 디버깅 다이얼로그 (앱 내)
- Firebase Console 테스트 메시지
- Xcode Console 로그
- Apple Developer Console

이 가이드를 단계별로 따라하면 대부분의 iOS FCM 문제를 해결할 수 있습니다.