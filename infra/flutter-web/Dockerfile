# Flutter web build of one app, served by nginx with /api proxied to the API.
# Build context: repository root.   docker build --build-arg APP=student_app -f infra/flutter-web/Dockerfile .
FROM debian:bookworm-slim AS sdk
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl git unzip xz-utils && rm -rf /var/lib/apt/lists/*
ARG FLUTTER_VERSION=3.47.6
# From git rather than the release tarball: the tarball is x86-only, git works on ARM hosts too
# (Oracle Ampere); `flutter precache` then fetches the Dart SDK for the build machine's architecture.
RUN git clone --depth 1 --branch "${FLUTTER_VERSION}" https://github.com/flutter/flutter.git /opt/flutter \
  && git config --global --add safe.directory /opt/flutter
ENV PATH=/opt/flutter/bin:$PATH
RUN flutter config --no-analytics --no-cli-animations && flutter precache --web

FROM sdk AS build
ARG APP
WORKDIR /repo
# The Dart workspace needs every member's pubspec to resolve.
COPY pubspec.yaml ./
COPY packages/naql_ui packages/naql_ui
COPY packages/naql_core packages/naql_core
COPY packages/naql_app packages/naql_app
COPY apps/student_app apps/student_app
COPY apps/driver_app apps/driver_app
RUN flutter pub get
WORKDIR /repo/apps/${APP}
# Map tiles for the student app (docs/OPERATIONS.md §8); empty = OpenStreetMap.
ARG MAP_TILES=
ARG MAP_ATTRIBUTION=
RUN flutter build web --release --no-web-resources-cdn --pwa-strategy=none \
      ${MAP_TILES:+--dart-define=MAP_TILES=$MAP_TILES} ${MAP_ATTRIBUTION:+"--dart-define=MAP_ATTRIBUTION=$MAP_ATTRIBUTION"}

FROM nginx:1.27-alpine
ARG APP
COPY infra/flutter-web/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /repo/apps/${APP}/build/web /usr/share/nginx/html
EXPOSE 80
