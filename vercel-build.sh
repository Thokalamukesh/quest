#!/bin/bash
set -e

if [[ -z "${API_BASE_URL:-}" ]]; then
	API_BASE_URL="https://quest-backend.vercel.app"
	echo "API_BASE_URL not set; defaulting to $API_BASE_URL"
fi

API_BASE_URL="${API_BASE_URL%/}"
if [[ "${API_BASE_URL,,}" != https://* ]]; then
	echo "API_BASE_URL must be the public HTTPS origin of the deployed backend." >&2
	exit 1
fi
if [[ "${API_BASE_URL,,}" =~ ^https://(localhost|127\.0\.0\.1|\[::1\])(:[0-9]+)?(/|$) ]]; then
	echo "API_BASE_URL cannot point to localhost in a Vercel production build." >&2
	exit 1
fi
api_host="${API_BASE_URL#https://}"
if [[ "$api_host" == */* || "$api_host" == *\?* || "$api_host" == *\#* ]]; then
	echo "API_BASE_URL must be the backend origin only, without an API path, query, or fragment." >&2
	exit 1
fi

echo "Installing Flutter SDK..."

git clone https://github.com/flutter/flutter.git -b stable --depth 1 /tmp/flutter

export PATH="/tmp/flutter/bin:$PATH"

flutter --version

echo "Getting Flutter dependencies..."
flutter pub get

echo "Building Flutter web..."
flutter build web --release --dart-define=API_BASE_URL="$API_BASE_URL"

echo "Flutter web build completed!"
