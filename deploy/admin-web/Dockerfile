# MWN 웹 관리자 — Flutter Web 빌드 후 nginx 로 정적 서빙하는 멀티 스테이지 이미지.
#
# 빌드 컨텍스트는 저장소 루트여야 한다:
#   docker build -t harbor.cu.ac.kr/mwn/admin-web:latest -f deploy/admin-web/Dockerfile .

FROM ghcr.io/cirruslabs/flutter:3.41.4 AS build
WORKDIR /app
COPY . .
RUN flutter pub get
RUN flutter build web -t lib/main_web.dart --base-href /admin/ --release

FROM nginx:alpine
COPY --from=build /app/build/web /usr/share/nginx/html
COPY deploy/admin-web/nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
