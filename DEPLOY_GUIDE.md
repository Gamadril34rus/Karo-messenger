# 🚀 ЧАРО — Деплой бесплатно из России (без банковской карты)

Все сервисы ниже **бесплатны** и **не требуют банковскую карту**.

---

## Шаг 1. Neon — PostgreSQL (бесплатно, без карты)

1. Зайди на **https://neon.tech** → Sign Up (через GitHub)
2. **Create Project:**
   - Name: `charo-db`
   - Region: `AWS Asia Pacific (Singapore)` или `EU (Frankfurt)` 
   - PostgreSQL Version: `16`
   - Plan: **Free** (0.5 GB, always available, 100 compute hours/мес)
3. Нажми **Create Project**
4. Скопируй **Connection string** (с пометкой `?sslmode=require`)
   - Формат: `postgresql://charo:pass@ep-cool-name-123456.eu-central-2.aws.neon.tech/neondb?sslmode=require`
5. Это твой `DATABASE_URL` ✅

---

## Шаг 2. Upstash — Redis (бесплатно, без карты)

1. Зайди на **https://upstash.com** → Sign Up (через GitHub)
2. **Create Redis Database:**
   - Name: `charo-redis`
   - Region: `eu-central-1` (Frankfurt) или ближайший
   - Plan: **Free** (10K commands/день, 256 MB)
   - Eviction: `allkeys-lru`
3. Нажми **Create**
4. Скопируй:
   - **Endpoint** → `REDIS_HOST` (без порта)
   - **Port** → `REDIS_PORT` (обычно 6379)
   - **Password** → `REDIS_PASSWORD`
   - **UPSTASH_REDIS_REST_URL** — для REST API (опционально)
5. `REDIS_URL` = `rediss://default:PASSWORD@ENDPOINT:6379` ✅

---

## Шаг 3. Glitch — Backend Server (бесплатно, без карты)

1. Зайди на **https://glitch.com** → Sign In (через GitHub)
2. **New Project** → **Import from GitHub**
   - Repo: `Gamadril34rus/Karo-messenger`
3. В Glitch проекте:
   - Открой **⚙️ Settings** → **Root Directory** → `server`
   - **Build Command**: `npm ci && npx prisma generate && npx prisma migrate deploy && npm run build`
   - **Start Command**: `node dist/index.js`
4. **Environment Variables** — открой файл `.env` в проекте и вставь:

```
NODE_ENV=production
HOST=0.0.0.0
PORT=3000

DATABASE_URL=postgresql://charo:pass@ep-xxx.neon.tech/neondb?sslmode=require
REDIS_URL=rediss://default:pass@xxx.upstash.io:6379
REDIS_HOST=xxx.upstash.io
REDIS_PORT=6379
REDIS_PASSWORD=твой-пароль-upstash

JWT_ACCESS_SECRET=1e1d9d626681ffaaf9f5e08223612db11e22c969e66cdc516e9d922531a4de81
JWT_REFRESH_SECRET=9dc386c8b6db05de0ae6ec86135c74c4c5ad32b1e775644dd8eb2574eb252b60
JWT_ACCESS_EXPIRY=15m
JWT_REFRESH_EXPIRY=30d

CORS_ORIGINS=*
LOG_LEVEL=info
```

5. Glitch автоматически запустит сервер
6. URL будет: `https://твоё-имя.glitch.me` ✅

---

## Шаг 4. GitHub Pages — Frontend Web (уже работает!)

CI уже автоматически деплоит frontend на GitHub Pages:
- URL: **https://gamadril34rus.github.io/Karo-messenger/**

---

## Шаг 5. Prisma миграции

На Glitch сервер запустится с `npx prisma migrate deploy` в build command.
Миграции применятся автоматически к Neon базе.

Если нужно вручную:
```bash
export DATABASE_URL="postgresql://charo:pass@ep-xxx.neon.tech/neondb?sslmode=require"
cd server
npx prisma migrate deploy
```

---

## Шаг 6. Проверка

1. **Backend health:** `https://твоё-имя.glitch.me/health`
   - Должен вернуть: `{"status":"ok","version":"1.0.0"}`
2. **API docs:** `https://твоё-имя.glitch.me/docs`
3. **Frontend:** `https://gamadril34rus.github.io/Karo-messenger/`

---

## 📋 Чек-лист

### Регистрация (всё через GitHub, без карты)
- [ ] **neon.tech** — PostgreSQL free → скопировать DATABASE_URL
- [ ] **upstash.com** — Redis free → скопировать REDIS_HOST/PASSWORD/URL
- [ ] **glitch.com** — Backend free → import repo → env vars

### Переменные (уже сгенерированы)
- `JWT_ACCESS_SECRET` = `1e1d9d626681ffaaf9f5e08223612db11e22c969e66cdc516e9d922531a4de81`
- `JWT_REFRESH_SECRET` = `9dc386c8b6db05de0ae6ec86135c74c4c5ad32b1e775644dd8eb2574eb252b60`

### На Glitch (.env)
- [ ] Все 13 переменных из Шага 3

---

## 💰 Стоимость — 0₽ / 0$

| Сервис | План | Цена | Карта |
|--------|------|------|-------|
| Neon PostgreSQL | Free | $0 | ❌ Не нужна |
| Upstash Redis | Free | $0 | ❌ Не нужна |
| Glitch Server | Free | $0 | ❌ Не нужна |
| GitHub Pages | Free | $0 | ❌ Не нужна |
| **Итого** | | **0₽/мес** | **Без карты** |

---

## ⚠️ Ограничения Free-плана

| Сервис | Лимит | Что значит |
|--------|-------|------------|
| Neon | 0.5 GB, 100 compute hrs/мес | Хватит для ~1K пользователей |
| Upstash | 10K команд/день, 256 MB | Хватит для сессий + кэш |
| Glitch | 1000 hrs/мес, спит через 5 мин | Первый запрос ~10 сек (пробуждение) |
| GitHub Pages | 1 GB, 100 GB трафик/мес | Хватит для SPA |

**Для продакшн** (когда будут пользователи): 
- Neon Pro — $19/мес (10 GB, always on)
- Upstash Pay-as-you-go — от $0.20/мес
- Glitch Boost — $8/мес (не спит)
- Или VPS на Hostinger/Yandex Cloud от 200₽/мес

---

## 🔄 Альтернатива: VPS в РФ (Yandex Cloud / Selectel / Timeweb)

Если нужна полная свобода и сервер в РФ:

1. **Yandex Cloud** — от 200₽/мес за e2-small (2 vCPU, 2 GB)
2. **Selectel** — от 199₽/мес
3. **Timeweb Cloud** — от 199₽/мес

На VPS:
```bash
# Установить
sudo apt install nodejs npm postgresql redis-server
git clone https://github.com/Gamadril34rus/Karo-messenger
cd Karo-messenger/server
npm ci && npx prisma generate && npx prisma migrate deploy && npm run build
NODE_ENV=production node dist/index.js
```

ФЗ-152: данные граждан РФ на серверах в РФ ✅
