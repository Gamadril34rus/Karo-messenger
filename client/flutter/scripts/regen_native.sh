#!/usr/bin/env bash
# © 2024-2026 Бутаев Алексей Юрьевич. All rights reserved. PROPRIETARY AND CONFIDENTIAL.
#
# Регенерирует нативные проекты платформ (android/ios/macos/windows/linux)
# и применяет патчи ЧАРО, необходимые для сборки:
#   • Android: core library desugaring (flutter_local_notifications),
#     applicationId, разрешение INTERNET в release-манифесте
#   • iOS: строки разрешений камеры/микрофона/фото/геолокации,
#     отключение кодоподписи (CI-сборки без Apple Developer Team)
#   • pub-cache: compileSdk >= 36 во всех плагинах (file_picker 8.x и др.
#     собираются против android-34, а AAR-metadata flutter_plugin_android_lifecycle
#     требует 36 — именно на этом падала сборка)
#   • Dart: регенерация drift-кода (local_db.g.dart) под актуальную версию drift
#   • Linux: системные зависимости (GTK, gstreamer для audioplayers_linux)
#
# Использование:  ./scripts/regen_native.sh   (из каталога client/flutter)

set -euo pipefail

cd "$(dirname "$0")/.."

PY="$(command -v python3 || command -v python)"

# Linux: системные зависимости нативной сборки
#  - gstreamer нужен audioplayers_linux
#  - libsecret-1 нужен flutter_secure_storage_linux
if [[ "$(uname -s)" == "Linux" && -x /usr/bin/apt-get ]]; then
  echo "==> Installing Linux build dependencies"
  sudo apt-get update -qq || true
  sudo apt-get install -y -qq clang cmake ninja-build pkg-config \
    libgtk-3-dev liblzma-dev libstdc++-12-dev \
    libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev libunwind-dev \
    libgcrypt20-dev libsecret-1-dev \
    libayatana-appindicator3-dev libpulse-dev \
    >/dev/null || echo "!! apt install failed (continuing)"
fi

if [[ -n "${GITHUB_ENV:-}" ]]; then
  # CMake 4: старые cmake_minimum_required в firebase_cpp_sdk (Windows)
  echo "CMAKE_POLICY_VERSION_MINIMUM=3.5" >> "$GITHUB_ENV"
  # MSVC: плагины local_auth_windows/permission_handler_windows используют
  # устаревший <experimental/coroutine> — подавляем STL1011 через переменную CL
  if [[ "$(uname -s)" == MINGW* || "$(uname -s)" == MSYS* ]]; then
    echo 'CL=/D_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS' >> "$GITHUB_ENV"
  fi
fi

# SPM (Swift Package Manager) в связке с --no-codesign ломает iOS-сборку на CI
# (flutter/flutter#164317) — используем классический CocoaPods-флоу
flutter config --no-enable-swift-package-manager || true

echo "==> Generating native platform projects"
rm -rf android ios macos windows linux
flutter create . --platforms=android,ios,macos,windows,linux \
  --org com.charo --project-name charo_messenger
flutter pub get

echo "==> Regenerating drift code (local_db.g.dart) for the resolved drift version"
dart run build_runner build --delete-conflicting-outputs

echo "==> Applying Charo patches"
"$PY" <<'EOF'
import os
import pathlib
import re

UTF8 = {'encoding': 'utf-8'}
flutter_dir = pathlib.Path('.').resolve()

# ── 1. Android: app/build.gradle.kts ──────────────────────────────────────
app_gradle = flutter_dir / 'android' / 'app' / 'build.gradle.kts'
c = app_gradle.read_text(**UTF8)
if 'isCoreLibraryDesugaringEnabled' not in c:
    c = c.replace(
        'compileOptions {',
        'compileOptions {\n        isCoreLibraryDesugaringEnabled = true',
    )
if 'coreLibraryDesugaring' not in c:
    if re.search(r'dependencies\s*\{', c):
        c = re.sub(
            r'(dependencies\s*\{)',
            r'\1\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")',
            c,
            count=1,
        )
    else:
        c = c.rstrip() + '\n\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n'
c = re.sub(
    r'applicationId\s*=\s*"[^"]+"',
    'applicationId = "com.charo.messenger"',
    c,
)
app_gradle.write_text(c, **UTF8)
print('patched android/app/build.gradle.kts')

# ── 2. Android: INTERNET в release-манифесте ──────────────────────────────
manifest = flutter_dir / 'android' / 'app' / 'src' / 'main' / 'AndroidManifest.xml'
m = manifest.read_text(**UTF8)
if 'android.permission.INTERNET' not in m:
    m = m.replace(
        '<application',
        '<uses-permission android:name="android.permission.INTERNET" />\n    <application',
        1,
    )
    manifest.write_text(m, **UTF8)
    print('patched AndroidManifest.xml (INTERNET)')

# ── 3. iOS: usage descriptions + отключение подписи для CI ────────────────
plist = flutter_dir / 'ios' / 'Runner' / 'Info.plist'
if plist.exists():
    p = plist.read_text(**UTF8)
    keys = {
        'NSCameraUsageDescription': 'ЧАРО использует камеру для фото и видеозвонков.',
        'NSPhotoLibraryUsageDescription': 'ЧАРО использует фото для аватаров, стикеров и историй.',
        'NSPhotoLibraryAddUsageDescription': 'ЧАРО сохраняет изображения в вашу фототеку.',
        'NSMicrophoneUsageDescription': 'ЧАРО использует микрофон для голосовых сообщений и звонков.',
        'NSLocationWhenInUseUsageDescription': 'ЧАРО использует геолокацию для функции «Рядом».',
    }
    inject = ''.join(
        f'\t<key>{k}</key>\n\t<string>{v}</string>\n'
        for k, v in keys.items()
        if f'<key>{k}</key>' not in p
    )
    if inject:
        p = p.replace('<dict>', '<dict>\n' + inject.rstrip('\n'), 1)
        plist.write_text(p, **UTF8)
        print('patched ios/Runner/Info.plist')

for cfg in ['Release.xcconfig', 'Debug.xcconfig']:
    xc = flutter_dir / 'ios' / 'Flutter' / cfg
    if xc.exists():
        t = xc.read_text(**UTF8)
        if 'CODE_SIGNING_ALLOWED' not in t:
            t += '\n// Charo CI: unsigned builds (no Apple Developer Team)\nCODE_SIGNING_ALLOWED=NO\nCODE_SIGNING_REQUIRED=NO\n'
            xc.write_text(t, **UTF8)
            print(f'patched ios/Flutter/{cfg}')

# ── 4. pub-cache: compileSdk >= 36 во всех плагинах ───────────────────────
pub_cache = pathlib.Path(os.environ.get('PUB_CACHE', os.path.expanduser('~/.pub-cache')))


def bump(mo):
    return f'{mo.group(1)}36' if int(mo.group(2)) < 36 else mo.group(0)


patched = 0
for root, _dirs, files in os.walk(pub_cache / 'hosted'):
    for name in files:
        if name not in ('build.gradle', 'build.gradle.kts'):
            continue
        path = pathlib.Path(root) / name
        try:
            g = path.read_text(**UTF8)
        except Exception:
            continue
        ng = re.sub(r'(compileSdk\s*[= ]\s*)(\d+)', bump, g)
        ng = re.sub(r'(compileSdkVersion\s+)(\d+)', bump, ng)
        if ng != g:
            path.write_text(ng, **UTF8)
            patched += 1
print(f'pub-cache gradle files patched: {patched}')
EOF

echo "==> Native projects are ready"
