# Security Policy — ЧАРО Messenger

## Supported Versions

| Version | Supported |
| ------- | --------- |
| 1.1.x   | ✅ Active |
| < 1.0   | ❌ EOL    |

## Reporting a Vulnerability

**Не публикуйте уязвимости в GitHub Issues!**

Отправляйте отчёт на: **security@charo.chat**

### Что включить в отчёт:
- Описание уязвимости
- Шаги воспроизведения
- Версия сервера/клиента
- Скриншоты/логи (без персональных данных)
- Возможное решение (опционально)

### Процесс:
1. Подтверждение — в течение 48 часов
2. Оценка критичности — в течение 5 рабочих дней
3. Патч — критические: 7 дней, средние: 30 дней, низкие: 90 дней
4. Уведомление — после выпуска патча

## Security Measures

- **E2EE** — Signal Protocol (Double Ratchet, Sealed Sender)
- **JWT** — RSA-256, rotate every 15m access / 30d refresh
- **ФЗ-152** — персональные данные хранятся в РФ
- **GDPR** — право на удаление, экспорт данных
- **CCPA** — opt-out, не продаём данные
- **COPPA** — возрастное ограничение 13+
- **Rate Limiting** — 100 req/min per IP
- **Helmet** — CSP, HSTS, X-Frame-Options
- **Input Validation** — Zod schemas на всех endpoints
- **SQL Injection** — Prisma parameterized queries
- **XSS** — content sanitization
