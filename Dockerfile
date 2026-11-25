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
RUN flutter build web --release --no-pub

FROM node:24-bookworm-slim
WORKDIR /app
COPY backend/package.json backend/package-lock.json ./
RUN npm ci
COPY backend/ ./
COPY --from=flutter-build /app/build/web/ ./public/
ENV SERVE_FLUTTER_WEB=1
RUN npm run build
ENV NODE_ENV=production
CMD ["npm", "start"]
