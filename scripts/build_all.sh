#!/bin/bash
# ─── ЧАРО — Build All Platforms ────────────────────────
# Скрипт сборки всех платформ из одного места

set -euo pipefail

VERSION="1.0.0"
BUILD_DIR="build"
FLUTTER_DIR="client/flutter"
SERVER_DIR="server"

echo "⚡ ЧАРО v${VERSION} — Build Script"
echo "=============================================="

# ─── Очистка ─────────────────────────────────────────────────────
clean() {
  echo "🧹 Cleaning build artifacts..."
  rm -rf ${BUILD_DIR}
  mkdir -p ${BUILD_DIR}
}

# ─── Сервер ──────────────────────────────────────────────────────
build_server() {
  echo "🔨 Building server..."
  cd ${SERVER_DIR}
  npm ci
  npx prisma generate
  npm run build
  cd ../..
  echo "✅ Server build complete"
}

# ─── Docker образ ────────────────────────────────────────────────
build_docker() {
  echo "🐳 Building Docker image..."
  docker build -t charo-messenger:${VERSION} ${SERVER_DIR}
  echo "✅ Docker image built: charo-messenger:${VERSION}"
}

# ─── Android APK ─────────────────────────────────────────────────
build_android() {
  echo "📱 Building Android APK..."
  cd ${FLUTTER_DIR}
  flutter pub get
  flutter build apk --release --build-number=${VERSION##*.}
  cp build/app/outputs/flutter-apk/app-release.apk \
    ../../${BUILD_DIR}/charo-messenger-${VERSION}-android.apk
  echo "✅ Android APK: ${BUILD_DIR}/charo-messenger-${VERSION}-android.apk"
  cd ../..
}

# ─── Android App Bundle (Play Store) ─────────────────────────────
build_android_aab() {
  echo "📱 Building Android App Bundle..."
  cd ${FLUTTER_DIR}
  flutter build appbundle --release --build-number=${VERSION##*.}
  cp build/app/outputs/bundle/release/app-release.aab \
    ../../${BUILD_DIR}/charo-messenger-${VERSION}-android.aab
  echo "✅ Android AAB: ${BUILD_DIR}/charo-messenger-${VERSION}-android.aab"
  cd ../..
}

# ─── iOS ─────────────────────────────────────────────────────────
build_ios() {
  echo "🍎 Building iOS..."
  cd ${FLUTTER_DIR}
  flutter pub get
  flutter build ios --release --no-codesign
  echo "✅ iOS build complete (requires Xcode for signing)"
  cd ../..
}

# ─── Windows ─────────────────────────────────────────────────────
build_windows() {
  echo "🪟 Building Windows..."
  cd ${FLUTTER_DIR}
  flutter pub get
  flutter build windows --release
  cp -r build/windows/x64/runner/Release \
    ../../${BUILD_DIR}/charo-messenger-${VERSION}-windows
  cd ../..
  # Создаём ZIP
  cd ${BUILD_DIR}
  zip -r charo-messenger-${VERSION}-windows.zip charo-messenger-${VERSION}-windows
  cd ..
  echo "✅ Windows: ${BUILD_DIR}/charo-messenger-${VERSION}-windows.zip"
}

# ─── macOS ───────────────────────────────────────────────────────
build_macos() {
  echo "🍎 Building macOS..."
  cd ${FLUTTER_DIR}
  flutter pub get
  flutter build macos --release
  cp -r build/macos/Build/Products/Release/charo_messenger.app \
    ../../${BUILD_DIR}/charo-messenger-${VERSION}-macos.app
  cd ../..
  echo "✅ macOS: ${BUILD_DIR}/charo-messenger-${VERSION}-macos.app"
}

# ─── Linux ───────────────────────────────────────────────────────
build_linux() {
  echo "🐧 Building Linux..."
  cd ${FLUTTER_DIR}
  flutter pub get
  flutter build linux --release
  cp -r build/linux/x64/release/bundle \
    ../../${BUILD_DIR}/charo-messenger-${VERSION}-linux
  cd ../..
  # AppImage
  cd ${BUILD_DIR}
  tar -czf charo-messenger-${VERSION}-linux.tar.gz charo-messenger-${VERSION}-linux
  cd ..
  echo "✅ Linux: ${BUILD_DIR}/charo-messenger-${VERSION}-linux.tar.gz"
}

# ─── Web ─────────────────────────────────────────────────────────
build_web() {
  echo "🌐 Building Web..."
  cd ${FLUTTER_DIR}
  flutter pub get
  flutter build web --release --web-renderer canvaskit
  cp -r build/web ../../${BUILD_DIR}/charo-web
  cd ../..
  echo "✅ Web: ${BUILD_DIR}/charo-web/"
}

# ─── Все платформы ───────────────────────────────────────────────
build_all() {
  clean
  build_server
  build_android
  build_windows
  build_web
  echo ""
  echo "🎉 All builds complete!"
  echo "Files in ${BUILD_DIR}/:"
  ls -la ${BUILD_DIR}/
}

# ─── CLI ─────────────────────────────────────────────────────────
case "${1:-all}" in
  clean)     clean ;;
  server)    build_server ;;
  docker)    build_docker ;;
  android)   build_android ;;
  aab)       build_android_aab ;;
  ios)       build_ios ;;
  windows)   build_windows ;;
  macos)     build_macos ;;
  linux)     build_linux ;;
  web)       build_web ;;
  all)       build_all ;;
  *)
    echo "Usage: $0 {clean|server|docker|android|aab|ios|windows|macos|linux|web|all}"
    exit 1
    ;;
esac
