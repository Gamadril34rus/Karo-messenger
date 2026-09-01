#!/usr/bin/env bash
# © 2024-2026 Бутаев Алексей Юрьевич. All rights reserved. PROPRIETARY AND CONFIDENTIAL.
#
# Скачивает веб-ассеты drift (sqlite3.wasm + drift_worker.js) строго той
# версии, которая реально зарезолвилась в pubspec.lock.
#
# Зачем: drift на вебе не умеет загружать sqlite3 сам — ему нужны
# скомпилированный модуль sqlite3.wasm и воркер drift_worker.js. Оба файла
# обязаны быть из ОДНОГО релиза drift, иначе воркер и клиент расходятся по
# внутреннему протоколу и база на вебе не открывается.
#
# Версия берётся из pubspec.lock (а не из pubspec.yaml), потому что там
# записана точная зарезолвленная версия пакета.
#
# Использование:  ./scripts/fetch_drift_web_assets.sh   (из каталога client/flutter)

set -euo pipefail

cd "$(dirname "$0")/.."

if [[ ! -f pubspec.lock ]]; then
  echo "!! pubspec.lock не найден — сначала выполните 'flutter pub get'" >&2
  exit 1
fi

# Точная версия drift из pubspec.lock (блок «  drift:\n ... version: "x.y.z"»)
DRIFT_VERSION="$(
  awk '
    /^  drift:$/        { in_drift = 1; next }
    in_drift && /^  [a-zA-Z0-9_]+:$/ { in_drift = 0 }
    in_drift && /^[[:space:]]*version:/ {
      gsub(/[",]/, "", $2); print $2; exit
    }
  ' pubspec.lock
)"

if [[ -z "$DRIFT_VERSION" ]]; then
  echo "!! Не удалось определить версию drift из pubspec.lock" >&2
  exit 1
fi

BASE_URL="https://github.com/simolus3/drift/releases/download/drift-${DRIFT_VERSION}"
echo "==> drift ${DRIFT_VERSION}: скачиваю веб-ассеты из ${BASE_URL}"

mkdir -p web

for asset in sqlite3.wasm drift_worker.js; do
  tmp="$(mktemp)"
  if curl --fail --location --silent --show-error --retry 3 --retry-delay 2 \
      -o "$tmp" "${BASE_URL}/${asset}"; then
    mv "$tmp" "web/${asset}"
    echo "    web/${asset} — $(wc -c < "web/${asset}") байт"
  else
    rm -f "$tmp"
    echo "!! Не удалось скачать ${asset} для drift ${DRIFT_VERSION}" >&2
    exit 1
  fi
done

echo "==> Веб-ассеты drift синхронизированы с версией ${DRIFT_VERSION}"
