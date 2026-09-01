# 🚀 ЧАРО — Бесплатный деплой на Bonto.dev (0₽, без карты)

**Glitch закрылся в июле 2025. Bonto.dev — его замена. Бесплатно, без карты.**

---

## Шаг 1. Регистрация на Bonto.dev (1 мин)

1. Открой **https://bonto.dev/register**
2. Заполни: email, username, password
3. **Карта НЕ нужна**

---

## Шаг 2. Создать проект из GitHub (1 мин)

1. После входа → **New Project**
2. Выбери **Import from Git**
3. Вставь URL: `https://github.com/Gamadril34rus/Karo-messenger`
4. Root Directory: `server`
5. Нажми **Create**

---

## Шаг 3. Настроить переменные (1 мин)

В проекте открой файл `.env` и вставь:

```
NODE_ENV=production
HOST=0.0.0.0
PORT=3000
JWT_ACCESS_SECRET=1e1d9d626681ffaaf9f5e08223612db11e22c969e66cdc516e9d922531a4de81
JWT_REFRESH_SECRET=9dc386c8b6db05de0ae6ec86135c74c4c5ad32b1e775644dd8eb2574eb252b60
CORS_ORIGINS=*
LOG_LEVEL=info
```

---

## Шаг 4. Готово!

Сервер запустится автоматически.
URL: **https://твоё-имя.bonto.run**

Проверь: открой `https://твоё-имя.bonto.run/health`

---

## 💰 0₽ навсегда

| План | Цена | Что входит |
|------|------|------------|
| Free | 0₽ | 50 часов/мес, 512 MB RAM, auto-sleep/wake |
| Pro | $5/мес | Always-on, больше RAM |

**Free план:** сервер спит через 5 мин без запросов, просыпается за ~5 сек.
Для теста и проверки — хватает.

---

## ⚠️ Если Bonto не зайдёт из РФ

Используй VPN при регистрации, потом сайт работает без VPN.

---

## Альтернативы (тоже бесплатно)

| Сервис | URL | Карта | Заметка |
|--------|-----|-------|---------|
| **Bonto.dev** | https://bonto.dev | ❌ | Лучший вариант |
| **Vercel** | https://vercel.com | ❌ | Только serverless, не подходит для WebSocket |
| **Fly.io** | https://fly.io | ❌ | Нужен CLI, сложнее |
| **Oracle Cloud** | https://cloud.oracle.com | ❌ | Free VPS forever, но сложная регистрация |

---

## 🌐 Веб-версия (GitHub Pages)

Сайт: **https://gamadril34rus.github.io/Karo-messenger/**
Собирается джобой `deploy-web` в `.github/workflows/main.yml` и публикуется
в ветку `gh-pages`.

Что обязательно для работающей веб-сборки:

1. **База данных.** drift в браузере не умеет грузить sqlite3 сам, поэтому
   `driftDatabase()` вызывается с параметром `web:`
   (`client/flutter/lib/core/storage/local_db.dart`). Без него drift_flutter
   бросает `ArgumentError` прямо в конструкторе `AppDatabase()` — ещё до
   `runApp()`, и страница навсегда зависает на заставке загрузки.

2. **Ассеты drift.** `web/sqlite3.wasm` и `web/drift_worker.js` должны быть
   из одного релиза drift, совпадающего с версией пакета в `pubspec.lock`.
   Файлы в репозитории — запасной вариант; при каждой сборке их заново
   скачивает `client/flutter/scripts/fetch_drift_web_assets.sh`, который
   вызывается из `scripts/regen_native.sh` (шаг «Regenerate code & native
   projects» в CI).

   Локально, если есть интернет:

   ```bash
   cd client/flutter && flutter pub get && ./scripts/fetch_drift_web_assets.sh
   ```

3. **Базовый href.** Сайт живёт в подкаталоге, поэтому сборка идёт с
   `--base-href /Karo-messenger/`; все пути в `web/` — относительные.

4. **Иконки.** `web/favicon.ico`, `web/favicon.png`, `web/icons/*` — иначе
   браузер сыпет 404 в консоль.

`scripts/regen_native.sh` проверяет наличие всех этих файлов в `web/` и
останавливает сборку, если чего-то не хватает.
