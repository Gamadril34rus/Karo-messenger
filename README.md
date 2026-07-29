# ЧАРО (Charo) — Мессенджер нового поколения

> Быстрый. Приватный. Мощный. Красивый.

## О проекте

ЧАРО — это production-ready мессенджер с end-to-end шифрованием (Signal Protocol), группами, каналами, голосовыми сообщениями, видеозвонками (WebRTC), стикерами и AI-ассистентом.

## Архитектура

| Компонент | Технология |
|-----------|-----------|
| Клиент | Flutter + BLoC + GetIt |
| Сервер | Fastify + TypeScript |
| База данных | PostgreSQL + Prisma v6 |
| Кэш | Redis |
| Медиа | MinIO (S3-compatible) |
| Шифрование | Signal Protocol (E2EE) |
| Звонки | WebRTC (STUN/TURN) |
| Push | FCM (Android) + APNS (iOS) |

## Быстрый старт

### Предварительные требования

- Node.js 20+
- Flutter 3.22+
- Docker & Docker Compose
- PostgreSQL 16+ (или через Docker)

### 1. Клонирование

```bash
git clone https://github.com/charo-messenger/charo.git
cd charo
```

### 2. Запуск инфраструктуры

```bash
docker compose up -d db redis minio
```

### 3. Настройка сервера

```bash
cd server
cp .env.example .env
# Отредактируйте .env — укажите свои секреты

npm install
npx prisma migrate dev
npx prisma generate
npm run build
npm start
```

### 4. Запуск клиента

```bash
cd client/flutter
flutter pub get
flutter run
```

### 5. Docker Compose (всё вместе)

```bash
docker compose up -d
```

## Структура проекта

```
charo-messenger/
├── server/                  # Fastify API сервер
│   ├── src/
│   │   ├── modules/        # 13 модулей (auth, chats, messages, media, ...)
│   │   ├── ws/             # WebSocket connection manager
│   │   ├── middleware/     # Auth, error handling
│   │   └── index.ts        # Entry point
│   ├── prisma/             # 30 моделей (User, Chat, Message, ...)
│   └── Dockerfile
├── client/flutter/
│   ├── lib/
│   │   ├── core/           # Services, network, storage, theme
│   │   ├── features/       # 9 фич (auth, chat, calls, stories, ...)
│   │   └── main.dart       # GetIt DI + BLoC providers
│   └── test/               # Unit + widget тесты
├── docker-compose.yml
└── README.md
```

## Функциональность

- ✅ E2EE шифрование (Signal Protocol)
- ✅ MLS групповое шифрование
- ✅ Голосовые и видеозвонки (WebRTC)
- ✅ Голосовые сообщения с waveform
- ✅ Медиа-просмотрщик (pinch-to-zoom, swipe)
- ✅ Реакции на сообщения (6 quick + 24 extended)
- ✅ Исчезающие сообщения (client + server enforcement)
- ✅ Чёрный список
- ✅ Группы и каналы (с ролями)
- ✅ Offline-first (queue + gap-filling sync)
- ✅ Push-уведомления (FCM/APNS)
- ✅ 2FA (TOTP)
- ✅ Экспорт данных (GDPR/ФЗ-152)
- ✅ Стикеры (177 штук, 15 паков, CC0)
- ✅ AI-ассистент
- ✅ Адаптивный layout (desktop NavigationRail)
- ✅ Глобальный поиск

## Правовая Compliance

- ✅ ФЗ-152 (Российский закон о персональных данных)
- ✅ GDPR (EU General Data Protection Regulation)
- ✅ CCPA (California Consumer Privacy Act)
- ✅ IP-clean — нет нарушений чужих товарных знаков

## Лицензия

Proprietary — © 2024-2026 ЧАРО
