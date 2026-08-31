#!/usr/bin/env bash
# © 2024-2026 Бутаев Алексей Юрьевич. All rights reserved. PROPRIETARY AND CONFIDENTIAL.
#
# Регенерирует нативные проекты платформ (android/ios/macos/windows/linux)
# и применяет патчи ЧАРО, необходимые для сборки:
#   • Android: core library desugaring (flutter_local_notifications),
#     applicationId, разрешение INTERNET в release-манифесте
#   • iOS: строки разрешений камеры/микрофона/фото/геолокации
#   • pub-cache: compileSdk >= 36 во всех плагинах (file_picker 8.x и др.
#     собираются против android-34, а AAR-metadata flutter_plugin_android_lifecycle
#     требует 36 — именно на этом падала сборка)
#
# Использование:  ./scripts/regen_native.sh   (из каталога client/flutter)

set -euo pipefail

cd "$(dirname "$0")/.."

PY="$(command -v python3 || command -v python)"

echo "==> Generating native platform projects"
rm -rf android ios macos windows linux
flutter create . --platforms=android,ios,macos,windows,linux \
  --org com.charo --project-name charo_messenger
flutter pub get

echo "==> Applying Charo patches"
"$PY" <<'EOF'
import os
import pathlib
import re

flutter_dir = pathlib.Path('.').resolve()

# ── 1. Android: app/build.gradle.kts ──────────────────────────────────────
app_gradle = flutter_dir / 'android' / 'app' / 'build.gradle.kts'
c = app_gradle.read_text()
if 'isCoreLibraryDesugaringEnabled' not in c:
    c = c.replace(
        'compileOptions {',
        'compileOptions {\n        isCoreLibraryDesugaringEnabled = true',
    )
if 'coreLibraryDesugaring' not in c:
    c = re.sub(
        r'(dependencies\s*\{)',
        r'\1\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")',
        c,
        count=1,
    )
c = re.sub(
    r'applicationId\s*=\s*"[^"]+"',
    'applicationId = "com.charo.messenger"',
    c,
)
app_gradle.write_text(c)
print('patched android/app/build.gradle.kts')

# ── 2. Android: INTERNET в release-манифесте ──────────────────────────────
manifest = flutter_dir / 'android' / 'app' / 'src' / 'main' / 'AndroidManifest.xml'
m = manifest.read_text()
if 'android.permission.INTERNET' not in m:
    m = m.replace(
        '<application',
        '<uses-permission android:name="android.permission.INTERNET" />\n    <application',
        1,
    )
    manifest.write_text(m)
    print('patched AndroidManifest.xml (INTERNET)')

# ── 3. iOS: usage descriptions ────────────────────────────────────────────
plist = flutter_dir / 'ios' / 'Runner' / 'Info.plist'
if plist.exists():
    p = plist.read_text()
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
        plist.write_text(p)
        print('patched ios/Runner/Info.plist')

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
            g = path.read_text()
        except Exception:
            continue
        ng = re.sub(r'(compileSdk\s*[= ]\s*)(\d+)', bump, g)
        ng = re.sub(r'(compileSdkVersion\s+)(\d+)', bump, ng)
        if ng != g:
            path.write_text(ng)
            patched += 1
print(f'pub-cache gradle files patched: {patched}')
EOF

echo "==> Native projects are ready"
