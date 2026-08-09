# ЧАРО Server — Локальный запуск

## 1. Установи Node.js 20+ и PostgreSQL

Если нет PostgreSQL — можно без него (сервер запустится в degraded режиме).

Скачай Node.js: https://nodejs.org (LTS версию)

## 2. Клонируй проект

```bash
git clone -b main https://github.com/Gamadril34rus/Karo-messenger.git charo
cd charo/server
```

## 3. Установи зависимости

```bash
npm ci
```

## 4. Создай .env файл

Создай файл `server/.env`:

```env
NODE_ENV=development
HOST=0.0.0.0
PORT=3000

# БД Neon (уже работает, миграции применены)
DATABASE_URL=postgresql://neondb_owner:npg_TJ2khECyOKb4@ep-long-glade-ayth04ig-pooler.c-5.us-east-2.aws.neon.tech/neondb?sslmode=require

# Redis — пока без него (сервер запустится в degraded)
# REDIS_URL=rediss://default:PASSWORD@HOST:PORT

# JWT
JWT_ACCESS_SECRET=1e1d9d626681ffaaf9f5e08223612db11e22c969e66cdc516e9d922531a4de81
JWT_REFRESH_SECRET=9dc386c8b6db05de0ae6ec86135c74c4c5ad32b1e775644dd8eb2574eb252b60
JWT_ACCESS_EXPIRY=15m
JWT_REFRESH_EXPIRY=30d

# CORS
CORS_ORIGINS=*

# Logging
LOG_LEVEL=info
```

## 5. Запусти сервер

```bash
npm run dev
```

Это запустит `tsx watch src/index.ts` — с автоперезагрузкой при изменениях.

## 6. Проверь

Открой в браузере:
- http://localhost:3000/health — статус сервера
- http://localhost:3000/docs — Swagger UI

## Ожидаемый результат

`/health` вернёт:
```json
{
  "status": "degraded",
  "version": "1.0.0",
  "checks": {
    "database": "ok",
    "redis": "error"
  }
}
```

`database: "ok"` потому что Neon подключена.
`redis: "error"` — нормально, Redis нет.

## Если хочешь полную БД локально (PostgreSQL + Redis)

### Вариант A: Docker

```bash
# Из корня проекта
docker compose -f infra/docker/docker-compose.yml up -d
```

Тогда в .env поставь:
```
DATABASE_URL=postgresql://charo:charo123@localhost:5432/charo?schema=public
REDIS_HOST=localhost
REDIS_PORT=6379
```

И примени миграции:
```bash
npx prisma migrate deploy
```

### Вариант B: Только PostgreSQL локально

Установи PostgreSQL, создай БД `charo`, и обнови `DATABASE_URL`.

## Тестирование API

### Регистрация
```bash
curl -X POST http://localhost:3000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@charo.chat",
    "password": "Test1234!",
    "phone": "+79696514370",
    "username": "testuser",
    "displayName": "Тест"
  }'
```

### Логин
```bash
curl -X POST http://localhost:3000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@charo.chat",
    "password": "Test1234!"
  }'
```

### Swagger UI
Открой http://localhost:3000/docs — там все эндпоинты с возможностью тестировать.
