# 🚀 ЧАРО — Пошаговая инструкция деплоя на Render

## Шаг 1. Регистрация и ключи

### 1.1 Render
1. Зайди на https://render.com → Sign Up (через GitHub)
2. Подтверди email
3. Free tier даёт: 1 Web Service, 1 PostgreSQL, 1 Redis — хватает для теста

### 1.2 GitHub (уже есть)
- Репо: `Gamadril34rus/Karo-messenger` (private)
- PAT: уже создан

### 1.3 Сгенерировать секреты
Выполни локально (Linux/Mac):
```bash
# JWT секреты — случайные 64-символьные ключи
JWT_ACCESS_SECRET=$(openssl rand -hex 32)
JWT_REFRESH_SECRET=$(openssl rand -hex 32)

# MinIO (Render Object Storage или внешний)
MINIO_ACCESS_KEY=$(openssl rand -hex 16)
MINIO_SECRET_KEY=$(openssl rand -hex 32)

# Gemini AI (опционально для теста)
# Получить на https://aistudio.google.com/apikey
GEMINI_API_KEY=your-key-here

echo "JWT_ACCESS_SECRET=$JWT_ACCESS_SECRET"
echo "JWT_REFRESH_SECRET=$JWT_REFRESH_SECRET"
echo "MINIO_ACCESS_KEY=$MINIO_ACCESS_KEY"
echo "MINIO_SECRET_KEY=$MINIO_SECRET_KEY"
```

**Запиши все значения!** Они понадобятся на следующих шагах.

---

## Шаг 2. Render — PostgreSQL база

1. Render Dashboard → **New** → **PostgreSQL**
2. Заполни:
   - Name: `charo-db`
   - Region: `Frankfurt` (ближе к RU) или `Oregon`
   - PostgreSQL Version: `16`
   - Plan: **Free** (1 GB, истекает через 90 дней — для теста ок)
3. Нажми **Create**
4. Жди статус **Available** (~2 мин)
5. Скопируй **Internal Database URL** — это `DATABASE_URL` для сервера
   - Формат: `postgresql://charo_db_xxx:password@render-host/render_db_xxx`

---

## Шаг 3. Render — Redis

1. Render Dashboard → **New** → **Redis**
2. Заполни:
   - Name: `charo-redis`
   - Region: тот же что у PostgreSQL
   - Plan: **Free** (25 MB, истекает через 90 дней)
3. Нажми **Create**
4. Жди **Available**
5. Скопируй **Internal Redis URL** — это `REDIS_URL`
   - Формат: `redis://red-xxx:6379`

---

## Шаг 4. Render — Object Storage (MinIO替代)

MinIO на Render нет, но есть **Object Storage** (S3-совместимый):

1. Render Dashboard → **New** → **Object Storage**
2. Заполни:
   - Name: `charo-media`
   - Region: тот же
   - Plan: **Starter** ($5/мес) или пропусти если не нужен для теста
3. Создай bucket: `charo-media`
4. Скопируй:
   - Endpoint → `MINIO_ENDPOINT`
   - Access Key → `MINIO_ACCESS_KEY`
   - Secret Key → `MINIO_SECRET_KEY`

**Если не хочешь платить за Object Storage** — сервер уже работает без MinIO (возвращает 503 для медиа, остальное работает). Для теста можно пропустить.

---

## Шаг 5. Render — Web Service (Backend)

1. Render Dashboard → **New** → **Web Service**
2. **Connect repo:**
   - Выбери `Gamadril34rus/Karo-messenger`
   - Branch: `main`
   - Root Directory: `server`
3. **Build & Deploy:**
   - Runtime: **Node**
   - Build Command: `npm ci && npx prisma generate && npx prisma migrate deploy`
   - Start Command: `node dist/index.js`
   - **ИЛИ** если tsx: `npx tsx src/index.ts`
4. **Environment:**
   - Plan: **Free** (750 часов/мес)
5. **Environment Variables** (раздел Advanced):

| Ключ | Значение | Откуда |
|------|----------|--------|
| `NODE_ENV` | `production` | — |
| `PORT` | `10000` | Render даёт свой порт |
| `DATABASE_URL` | `postgresql://...` | Шаг 2 (Internal URL) |
| `REDIS_HOST` | `red-xxx.render.com` | Шаг 3 (хост без порта) |
| `REDIS_PORT` | `6379` | Шаг 3 |
| `REDIS_URL` | `redis://red-xxx:6379` | Шаг 3 (Internal URL) |
| `JWT_ACCESS_SECRET` | `сгенерированный` | Шаг 1.3 |
| `JWT_REFRESH_SECRET` | `сгенерированный` | Шаг 1.3 |
| `JWT_ACCESS_EXPIRY` | `15m` | — |
| `JWT_REFRESH_EXPIRY` | `30d` | — |
| `CORS_ORIGINS` | `https://charo.onrender.com,http://localhost:3000` | — |
| `MINIO_ENDPOINT` | `хост` | Шаг 4 или пусто |
| `MINIO_PORT` | `9000` | Шаг 4 или пусто |
| `MINIO_ACCESS_KEY` | `ключ` | Шаг 4 или пусто |
| `MINIO_SECRET_KEY` | `секрет` | Шаг 4 или пусто |
| `MINIO_BUCKET` | `charo-media` | Шаг 4 |
| `CDN_BASE_URL` | `https://charo-media.onrender.com` | Шаг 4 |
| `GEMINI_API_KEY` | `ключ` | Шаг 1.3 или пусто |
| `LOG_LEVEL` | `info` | — |
| `HOST` | `0.0.0.0` | Обязательно! |

6. Нажми **Create Web Service**
7. Жди первый деплой (~3-5 мин)
8. Проверь логи: должен быть `🚀 charo Server running on 0.0.0.0:10000`

---

## Шаг 6. Render — Static Site (Frontend Web)

1. Render Dashboard → **New** → **Static Site**
2. **Connect repo:**
   - `Gamadril34rus/Karo-messenger`
   - Branch: `main`
   - Root Directory: `client/flutter`
3. **Build:**
   - Build Command: `flutter build web --release --web-renderer canvaskit`
   - **ИЛИ** если Flutter не установлен на Render:
     - Build Command: `cd ../../ && bash -c "curl -fsSL https://get.flutter.dev | bash -s -- --version stable && export PATH=$HOME/flutter/bin:$PATH && cd client/flutter && flutter pub get && flutter build web --release --web-renderer canvaskit"`
   - Publish Directory: `build/web`
4. **Environment Variables:**

| Ключ | Значение |
|------|----------|
| `API_URL` | `https://charo-server.onrender.com` (URL из Шага 5) |

5. Нажми **Create Static Site**

**Альтернатива** — GitHub Pages (уже настроен в CI):
- Settings → Pages → Source: `gh-pages` branch
- URL: `https://gamadril34rus.github.io/Karo-messenger/`

---

## Шаг 7. Prisma миграции на продакшн-БД

После первого деплоя сервера, миграции должны пройти автоматически (build command включает `npx prisma migrate deploy`).

Если нет — выполни вручную:
```bash
# Локально, с продакшн DATABASE_URL
export DATABASE_URL="postgresql://charo_db_xxx:password@render-host/render_db_xxx"
cd server
npx prisma migrate deploy
```

---

## Шаг 8. Проверка

1. **Backend health:** открой `https://charo-server.onrender.com/health`
   - Должен вернуть: `{"status":"ok","version":"1.0.0","checks":{"database":"ok","redis":"ok"}}`
2. **API docs:** `https://charo-server.onrender.com/docs` (Swagger UI)
3. **Frontend:** открой URL Static Site из Шага 6

---

## Шаг 9. Домен (опционально)

В Render можно привязать свой домен:
1. Web Service → Settings → Custom Domains
2. Добавь: `api.charo.chat` (нужен A/CNAME запись у регистратора)
3. Static Site → Settings → Custom Domains
4. Добавь: `charo.chat`

---

## ⚖️ Шаг 10. Лицензия — Запрет модификации

ЧАРО — проприетарный продукт. Лицензия запрещает модификацию, распространение и коммерческое использование без разрешения правообладателя.

### 10.1 Создать файл LICENSE
Уже создан ниже — см. `LICENSE` файл в корне проекта.

### 10.2 Добавить copyright во все исходники
В каждый `.dart` и `.ts` файл вверху:
```
// © 2024-2026 Charo Team. All rights reserved.
// PROPRIETARY AND CONFIDENTIAL. Do not modify or distribute.
```

### 10.3 Добавить в pubspec.yaml и package.json
- `pubspec.yaml`: уже есть `publish_to: 'none'` (запрет публикации в pub.dev)
- `package.json`: добавить `"license": "UNLICENSED"`

### 10.4 GitHub — Legal
1. Репо Settings → **Danger Zone** → Visibility: **Private** ✅ (уже)
2. Добавить **SECURITY.md** (политика безопасности)
3. Добавить **NOTICE.md** (уведомление о авторских правах)

---

## 📋 Чек-лист — всё что нужно создать/заполнить

### На Render (веб-форма)
- [ ] PostgreSQL база `charo-db`
- [ ] Redis `charo-redis`
- [ ] Object Storage `charo-media` (опционально)
- [ ] Web Service `charo-server` (backend)
- [ ] Static Site `charo-web` (frontend)

### Сгенерировать (локально)
- [ ] `JWT_ACCESS_SECRET` — 64 hex символа
- [ ] `JWT_REFRESH_SECRET` — 64 hex символа
- [ ] `MINIO_ACCESS_KEY` — 32 hex символа
- [ ] `MINIO_SECRET_KEY` — 64 hex символа
- [ ] `GEMINI_API_KEY` — с Google AI Studio

### Внести в Render Environment Variables (backend)
- [ ] Все 17 переменных из таблицы Шага 5

### В репозитории (файлы)
- [ ] `LICENSE` — проприетарная лицензия ✅ (создана)
- [ ] `SECURITY.md` — политика безопасности
- [ ] `NOTICE.md` — авторские права
- [ ] `PRIVACY_POLICY.md` — ФЗ-152/GDPR/CCPA
- [ ] `TERMS_OF_SERVICE.md` — пользовательское соглашение
- [ ] Copyright заголовки в исходниках

### Согласия (для приложения)
- [ ] Согласие на обработку персональных данных (ФЗ-152)
- [ ] Пользовательское соглашение (Terms of Service)
- [ ] Политика конфиденциальности (Privacy Policy)
- [ ] Cookie consent (GDPR)
- [ ] Возрастное ограничение (13+ по COPPA)

---

## 💰 Стоимость на Render (тест)

| Сервис | Plan | Цена |
|--------|------|------|
| PostgreSQL | Free | $0 (90 дней, потом $7/мес) |
| Redis | Free | $0 (90 дней, потом $7/мес) |
| Web Service | Free | $0 (750 ч/мес, спит через 15 мин) |
| Static Site | Free | $0 |
| **Итого** | | **$0/мес** на время теста |

**Важно:** Free Web Service "засыпает" через 15 мин без запросов. Первый запрос разбудит за ~30 сек. Для продакшн нужен Starter ($7/мес) — не засыпает.
