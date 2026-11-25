FROM debian:bookworm-slim AS flutter-build
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl git unzip xz-utils zip \
    && rm -rf /var/lib/apt/lists/*
RUN git clone --depth 1 --branch 3.47.9 https://github.com/flutter/flutter.git /opt/flutter
ENV PATH="/opt/flutter/bin:${PATH}"
WORKDIR /app
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get
COPY lib ./lib
COPY assets ./assets
COPY web ./web
ARG API_BASE_URL
RUN test -n "$API_BASE_URL" || (echo "Set API_BASE_URL to the Railway backend HTTPS origin." >&2; exit 1)
RUN flutter build web --release --no-pub --dart-define="API_BASE_URL=$API_BASE_URL"

FROM nginx:stable-alpine
ENV PORT=8080
ENV NGINX_ENVSUBST_FILTER="^PORT$"
COPY nginx/default.conf.template /etc/nginx/templates/default.conf.template
COPY --from=flutter-build /app/build/web/ /usr/share/nginx/html/
