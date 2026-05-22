# MWN 웹 관리자 — k8s 배포 가이드

`lib/main_web.dart`로 빌드한 Flutter Web 관리자 인터페이스를 `mwn` 네임스페이스에
배포하는 절차다. 웹 관리자는 기존 `mwn-nginx` LoadBalancer의 `/admin/` 경로로
서빙되어 `http://203.250.33.77/admin/` 로 접근한다.

## 구성 요소

| 파일 | 역할 |
|---|---|
| `Dockerfile` | Flutter Web 빌드 → nginx 정적 서빙 멀티 스테이지 이미지 |
| `nginx.conf` | 컨테이너 내부 nginx 설정 (SPA 폴백) |
| `k8s.yaml` | `mwn-admin-web` Deployment + ClusterIP Service |
| `mwn-nginx-configmap.patched.yaml` | 기존 `mwn-nginx-conf` 에 `/admin/` 라우팅을 추가한 ConfigMap |

## 선행 조건 (중요)

배포 전 반드시 충족되어야 한다:

1. **백엔드 CORS 배포 완료** — 웹 관리자는 브라우저에서 API를 호출하므로
   백엔드에 CORS가 적용·배포돼 있어야 한다. (백엔드 저장소 `WEB_ADMIN_CORS_HANDOFF.md` 참고)
2. **프론트엔드 PR #13 머지** — 웹 관리자 코드가 `main` 에 반영된 상태여야 한다.

> 위 조건 없이 배포하면 페이지는 떠도 로그인·API 호출이 CORS로 차단되어 동작하지 않는다.

## 배포 절차

빌드 컨텍스트는 **저장소 루트**다. 아래 명령은 루트에서 실행한다.

### 1. 이미지 빌드 & 푸시

```bash
docker build -t harbor.cu.ac.kr/mwn/admin-web:latest -f deploy/admin-web/Dockerfile .
docker push harbor.cu.ac.kr/mwn/admin-web:latest
```

> Harbor 레지스트리에 푸시하려면 사전에 `docker login harbor.cu.ac.kr` 가 필요하다.

### 2. Deployment + Service 생성

```bash
kubectl apply -f deploy/admin-web/k8s.yaml
kubectl rollout status deploy/mwn-admin-web -n mwn
```

### 3. mwn-nginx 라우팅 추가

ConfigMap 적용 전, 라이브 내용이 이 파일 기준과 동일한지 확인한다:

```bash
kubectl get cm mwn-nginx-conf -n mwn -o yaml
```

동일하면 적용 후 nginx 를 재시작한다 (ConfigMap 변경은 자동 반영되지 않음):

```bash
kubectl apply -f deploy/admin-web/mwn-nginx-configmap.patched.yaml
kubectl rollout restart deploy/mwn-nginx -n mwn
```

### 4. 검증

```bash
curl -I http://203.250.33.77/admin/
```

브라우저에서 `http://203.250.33.77/admin/` 접속 → 관리자 로그인 화면 확인.

## 롤백

```bash
# 라우팅 원복: /admin/ 블록을 제거한 ConfigMap 적용 후
kubectl rollout restart deploy/mwn-nginx -n mwn

# 워크로드 제거
kubectl delete -f deploy/admin-web/k8s.yaml
```

## 참고

- 웹 관리자는 백엔드(`http://`)와 동일하게 **HTTP로 서빙**된다. HTTPS로 서빙하면
  브라우저가 `http://` API 호출을 혼합 콘텐츠로 차단한다.
- 이미지 태그가 `:latest` + `imagePullPolicy: Always` 이므로, 재배포 시
  이미지를 다시 푸시하고 `kubectl rollout restart deploy/mwn-admin-web -n mwn` 한다.
