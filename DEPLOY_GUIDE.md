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
