# 🏗 Архитектура ЧАРО

## Обзор системы

ЧАРО построен по принципам **Clean Architecture** на клиенте и **микросервисной архитектуры** на сервере. Каждый слой изолирован, тестируем и масштабируем независимо.

---

## Высокоуровневая архитектура

```
                          ┌─────────────────────┐
                          │   CDN / Cloudflare   │
                          │   (Anti-DDoS, SSL)   │
                          └──────────┬──────────┘
                                     │
                          ┌──────────▼──────────┐
                          │   API Gateway        │
                          │   (Nginx + Rate Limit)│
                          └──────────┬──────────┘
                                     │
              ┌──────────────────────┼──────────────────────┐
              │                      │                      │
   ┌──────────▼─────────┐ ┌─────────▼──────────┐ ┌────────▼─────────┐
   │  Auth Service       │ │  Message Service    │ │  Media Service    │
   │  (JWT, OAuth, 2FA) │ │  (CRUD, Search)    │ │  (Upload, CDN)   │
   └──────────┬─────────┘ └─────────┬──────────┘ └────────┬─────────┘
              │                      │                      │
   ┌──────────▼─────────┐ ┌─────────▼──────────┐ ┌────────▼─────────┐
   │  Call Service       │ │  AI Service         │ │  Push Service     │
   │  (WebRTC SFU)      │ │  (LLM, TTS, STT)   │ │  (FCM, APNs)     │
   └──────────┬─────────┘ └─────────┬──────────┘ └────────┬─────────┘
              │                      │                      │
              └──────────────────────┼──────────────────────┘
                                     │
                          ┌──────────▼──────────┐
                          │     Data Layer       │
                          │  PG · Redis · MinIO  │
                          │  ClickHouse · Meili  │
                          └─────────────────────┘
```

---

## Клиентская архитектура (Flutter)

### Структура проекта

```
lib/
├── main.dart                     # Точка входа
├── core/                         # Ядро приложения
│   ├── theme/                    # Темы, цвета, типографика
│   │   ├── app_theme.dart
│   │   ├── app_colors.dart
│   │   └── app_typography.dart
│   ├── constants/                # Константы
│   │   ├── app_constants.dart
│   │   └── api_constants.dart
│   ├── routing/                  # Навигация (GoRouter)
│   │   ├── app_router.dart
│   │   └── route_guards.dart
│   ├── network/                  # Сетевой слой
│   │   ├── api_client.dart       # Dio-клиент с интерцепторами
│   │   ├── ws_client.dart        # WebSocket менеджер
│   │   ├── interceptors/         # JWT, логирование, ошибки
│   │   └── connectivity.dart     # Мониторинг сети
│   ├── storage/                  # Локальное хранилище
│   │   ├── secure_storage.dart   # Flutter Secure Storage
│   │   ├── local_db.dart         # Drift (SQLite)
│   │   └── hive_boxes.dart       # Hive (кэш, настройки)
│   ├── utils/                    # Утилиты
│   │   ├── logger.dart
│   │   ├── crypto.dart           # E2E шифрование
│   │   ├── anti_block.dart       # Анти-блокировки
│   │   └── date_formatter.dart
│   └── extensions/               # Расширения Dart
├── features/                     # Фичи (Clean Architecture)
│   ├── auth/                     # Авторизация
│   │   ├── data/                 # Repository impl, DTO, API
│   │   ├── domain/               # Entities, UseCases, Repository interfaces
│   │   └── presentation/         # BLoC, Screens, Widgets
│   ├── chat/                     # Чаты и сообщения
│   ├── contacts/                 # Контакты
│   ├── calls/                    # Звонки
│   ├── stories/                  # Истории
│   ├── profile/                  # Профиль
│   ├── settings/                 # Настройки
│   ├── ai_assistant/             # AI-ассистент
│   ├── nearby/                   # Кто рядом
│   └── media/                    # Медиа-просмотр
└── shared/                       # Общие виджеты
    └── widgets/
        ├── message_bubble.dart
        ├── avatar.dart
        ├── check_marks.dart
        └── loading_indicator.dart
```

### Слои Clean Architecture

```
┌─────────────────────────────────────┐
│          PRESENTATION               │
│  Screens · BLoC · Widgets           │
│  (Зависит от Domain)                │
├─────────────────────────────────────┤
│             DOMAIN                  │
│  Entities · UseCases · Repositories │
│  (Не имеет внешних зависимостей)    │
├─────────────────────────────────────┤
│              DATA                   │
│  Repository Impl · DTO · API        │
│  (Зависит от Domain)                │
└─────────────────────────────────────┘
```

---

## Серверная архитектура (Node.js)

### Микросервисы

| Сервис | Порт | Ответственность |
|--------|------|----------------|
| **API Gateway** | 80/443 | Маршрутизация, rate limiting, аутентификация |
| **Auth Service** | 3001 | Регистрация, логин, JWT, OAuth, 2FA |
| **Message Service** | 3002 | CRUD сообщений, чатов, групп, поиск |
| **Media Service** | 3003 | Загрузка/скачивание файлов, конвертация, CDN |
| **Call Service** | 3004 | WebRTC сигналинг, SFU, запись звонков |
| **AI Service** | 3005 | LLM, генерация стикеров, TTS, STT |
| **Push Service** | 3006 | FCM, APNs, локальные уведомления |
| **Presence Service** | 3007 | Статус «в сети», набор текста |
| **Story Service** | 3008 | Публикация/просмотр историй |
| **Notification Service** | 3009 | In-app уведомления, счётчики |

### Структура сервера

```
server/
├── src/
│   ├── index.ts                  # Точка входа
│   ├── config/                   # Конфигурация
│   │   ├── database.ts
│   │   ├── redis.ts
│   │   ├── jwt.ts
│   │   └── storage.ts
│   ├── middleware/                # Промежуточные обработчики
│   │   ├── auth.ts               # JWT верификация
│   │   ├── rateLimit.ts          # Rate limiting
│   │   ├── validator.ts          # Валидация запросов
│   │   └── errorHandler.ts       # Централизованная обработка ошибок
│   ├── modules/                  # Бизнес-модули
│   │   ├── auth/
│   │   ├── messages/
│   │   ├── chats/
│   │   ├── calls/
│   │   ├── media/
│   │   ├── ai/
│   │   ├── stories/
│   │   ├── presence/
│   │   ├── push/
│   │   ├── contacts/
│   │   └── settings/
│   ├── ws/                       # WebSocket обработчики
│   │   ├── connection.ts
│   │   ├── rooms.ts
│   │   └── handlers/
│   └── utils/                    # Утилиты
│       ├── crypto.ts
│       ├── logger.ts
│       └── helpers.ts
├── prisma/
│   └── schema.prisma             # Схема базы данных
├── Dockerfile
├── tsconfig.json
└── package.json
```

---

## Схема базы данных

### PostgreSQL — Основные таблицы

```sql
-- Пользователи
users (
  id              UUID PRIMARY KEY,
  phone           VARCHAR(20) UNIQUE,
  email           VARCHAR(255) UNIQUE,
  username        VARCHAR(64) UNIQUE,
  display_name    VARCHAR(128),
  bio             TEXT,
  avatar_url      VARCHAR(512),
  is_online       BOOLEAN DEFAULT FALSE,
  last_seen       TIMESTAMP,
  language        VARCHAR(10) DEFAULT 'ru',
  theme           VARCHAR(20) DEFAULT 'system',
  created_at      TIMESTAMP DEFAULT NOW(),
  updated_at      TIMESTAMP,
  deleted_at      TIMESTAMP           -- мягкое удаление
)

-- Чаты
chats (
  id              UUID PRIMARY KEY,
  type            ENUM('private','group','channel','secret'),
  title           VARCHAR(255),
  avatar_url      VARCHAR(512),
  description     TEXT,
  created_by      UUID REFERENCES users(id),
  is_disappearing BOOLEAN DEFAULT FALSE,
  disappear_timer INTEGER DEFAULT 0,  -- секунды
  created_at      TIMESTAMP DEFAULT NOW(),
  updated_at      TIMESTAMP
)

-- Участники чатов
chat_members (
  id              UUID PRIMARY KEY,
  chat_id         UUID REFERENCES chats(id),
  user_id         UUID REFERENCES users(id),
  role            ENUM('owner','admin','member'),
  joined_at       TIMESTAMP DEFAULT NOW(),
  last_read_at    TIMESTAMP,
  is_muted        BOOLEAN DEFAULT FALSE,
  UNIQUE(chat_id, user_id)
)

-- Сообщения
messages (
  id              UUID PRIMARY KEY,
  chat_id         UUID REFERENCES chats(id),
  sender_id       UUID REFERENCES users(id),
  type            ENUM('text','image','video','voice','video_note',
                        'file','sticker','gif','location','contact',
                        'poll','story_reply','ai_reply','system'),
  content         JSONB,              -- гибкая структура для разных типов
  reply_to_id     UUID REFERENCES messages(id),
  forwarded_from  UUID REFERENCES messages(id),
  is_edited       BOOLEAN DEFAULT FALSE,
  is_pinned       BOOLEAN DEFAULT FALSE,
  is_deleted      BOOLEAN DEFAULT FALSE,
  disappear_at    TIMESTAMP,          -- для исчезающих сообщений
  created_at      TIMESTAMP DEFAULT NOW(),
  updated_at      TIMESTAMP
)

-- Статусы доставки
message_status (
  id              UUID PRIMARY KEY,
  message_id      UUID REFERENCES messages(id),
  user_id         UUID REFERENCES users(id),
  status          ENUM('sent','delivered','read'),
  timestamp       TIMESTAMP DEFAULT NOW(),
  UNIQUE(message_id, user_id)
)

-- Реакции
reactions (
  id              UUID PRIMARY KEY,
  message_id      UUID REFERENCES messages(id),
  user_id         UUID REFERENCES users(id),
  emoji           VARCHAR(32),
  created_at      TIMESTAMP DEFAULT NOW(),
  UNIQUE(message_id, user_id, emoji)
)

-- Медиа-файлы
media (
  id              UUID PRIMARY KEY,
  message_id      UUID REFERENCES messages(id),
  type            ENUM('image','video','audio','file','sticker','gif'),
  url             VARCHAR(512),
  thumbnail_url   VARCHAR(512),
  mime_type       VARCHAR(128),
  size_bytes      BIGINT,
  width           INTEGER,
  height          INTEGER,
  duration_ms     INTEGER,            -- для аудио/видео
  uploaded_at     TIMESTAMP DEFAULT NOW()
)

-- Контакты
contacts (
  id              UUID PRIMARY KEY,
  user_id         UUID REFERENCES users(id),
  contact_user_id UUID REFERENCES users(id),
  display_name    VARCHAR(128),       -- локальное имя
  is_blocked      BOOLEAN DEFAULT FALSE,
  added_at        TIMESTAMP DEFAULT NOW(),
  UNIQUE(user_id, contact_user_id)
)

-- Настройки приватности
privacy_settings (
  user_id                 UUID PRIMARY KEY REFERENCES users(id),
  profile_visibility      ENUM('everyone','contacts','nobody') DEFAULT 'everyone',
  last_seen_visibility    ENUM('everyone','contacts','nobody') DEFAULT 'everyone',
  avatar_visibility       ENUM('everyone','contacts','nobody') DEFAULT 'everyone',
  phone_visibility        ENUM('everyone','contacts','nobody') DEFAULT 'contacts',
  who_can_message         ENUM('everyone','contacts','nobody') DEFAULT 'everyone',
  who_can_add_to_groups   ENUM('everyone','contacts','nobody') DEFAULT 'contacts',
  who_can_call            ENUM('everyone','contacts','nobody') DEFAULT 'everyone',
  read_receipts           BOOLEAN DEFAULT TRUE,
  typing_indicator        BOOLEAN DEFAULT TRUE
)

-- Истории
stories (
  id              UUID PRIMARY KEY,
  user_id         UUID REFERENCES users(id),
  type            ENUM('image','video','text'),
  media_url       VARCHAR(512),
  content         TEXT,
  background_color VARCHAR(20),
  expires_at      TIMESTAMP,          -- 24 часа
  created_at      TIMESTAMP DEFAULT NOW()
)

-- Звонки
calls (
  id              UUID PRIMARY KEY,
  chat_id         UUID REFERENCES chats(id),
  caller_id       UUID REFERENCES users(id),
  type            ENUM('voice','video'),
  status          ENUM('ringing','active','ended','missed','declined'),
  started_at      TIMESTAMP,
  ended_at        TIMESTAMP,
  duration_sec    INTEGER
)

-- Устройства / Сессии
devices (
  id              UUID PRIMARY KEY,
  user_id         UUID REFERENCES users(id),
  device_type     VARCHAR(32),
  device_name     VARCHAR(128),
  push_token      VARCHAR(512),
  last_active     TIMESTAMP,
  created_at      TIMESTAMP DEFAULT NOW()
)

-- Стикер-паки
sticker_packs (
  id              UUID PRIMARY KEY,
  name            VARCHAR(128),
  source          ENUM('charo','telegram','whatsapp','viber','vk','custom'),
  source_id       VARCHAR(128),       -- ID в исходном мессенджере
  thumbnail_url   VARCHAR(512),
  is_featured     BOOLEAN DEFAULT FALSE,
  created_at      TIMESTAMP DEFAULT NOW()
)

stickers (
  id              UUID PRIMARY KEY,
  pack_id         UUID REFERENCES sticker_packs(id),
  image_url       VARCHAR(512),
  emoji           VARCHAR(64),
  sort_order      INTEGER,
  width           INTEGER,
  height          INTEGER
)

-- AI-ассистент
ai_conversations (
  id              UUID PRIMARY KEY,
  user_id         UUID REFERENCES users(id),
  title           VARCHAR(255),
  created_at      TIMESTAMP DEFAULT NOW()
)

ai_messages (
  id              UUID PRIMARY KEY,
  conversation_id UUID REFERENCES ai_conversations(id),
  role            ENUM('user','assistant'),
  content         TEXT,
  created_at      TIMESTAMP DEFAULT NOW()
)
```

### Redis — Кэш и сессии

```
- session:{user_id}:{device_id}   → JWT payload, TTL: 7d
- presence:{user_id}              → "online" | "away" | timestamp, TTL: 5m
- typing:{chat_id}:{user_id}      → 1, TTL: 5s
- unread:{user_id}:{chat_id}      → count, TTL: none
- rate_limit:{ip}:{endpoint}      → counter, TTL: 1m
- ws_sessions:{user_id}           → Set of device_ids
- call_signaling:{call_id}        → WebRTC offer/answer/candidates
```

### ClickHouse — Аналитика

```sql
-- События для аналитики
events (
  timestamp   DateTime,
  user_id     UUID,
  event_type  String,    -- message_sent, call_started, story_viewed, etc.
  properties  String,    -- JSON
  platform    String,
  app_version String
)
```

---

## Протоколы взаимодействия

### WebSocket Events

```typescript
// Клиент → Сервер
"auth"           → { token: string }
"message.send"   → { chatId, type, content, replyTo, tempId }
"message.edit"   → { messageId, content }
"message.delete" → { messageId }
"typing.start"   → { chatId }
"typing.stop"    → { chatId }
"call.offer"     → { callId, sdp }
"call.answer"    → { callId, sdp }
"call.ice"       → { callId, candidate }
"presence"       → { status: "online" | "away" }
"read"           → { chatId, lastMessageId }

// Сервер → Клиент
"message.new"       → { message }
"message.updated"   → { messageId, content, isEdited }
"message.deleted"   → { messageId }
"message.status"    → { messageId, userId, status, timestamp }
"chat.created"      → { chat }
"chat.updated"      → { chatId, ...changes }
"typing"            → { chatId, userId }
"presence.update"   → { userId, status, lastSeen }
"call.incoming"     → { callId, callerId, type }
"call.offer"        → { callId, sdp }
"call.answer"       → { callId, sdp }
"call.ice"          → { callId, candidate }
"call.ended"        → { callId }
"story.new"         → { story }
"push"              → { title, body, data }
```

### REST API (ключевые эндпоинты)

```
# Auth
POST   /api/v1/auth/register         # Регистрация (телефон/email)
POST   /api/v1/auth/login            # Вход
POST   /api/v1/auth/verify           # Верификация OTP
POST   /api/v1/auth/refresh          # Обновление JWT
POST   /api/v1/auth/logout           # Выход
DELETE /api/v1/auth/account           # Удаление аккаунта
POST   /api/v1/auth/password/reset   # Сброс пароля
POST   /api/v1/auth/2fa/enable       # Включить 2FA
POST   /api/v1/auth/2fa/verify       # Проверить 2FA

# OAuth
GET    /api/v1/auth/oauth/:provider   # OAuth2 (Google, Apple, VK)

# Users
GET    /api/v1/users/me               # Свой профиль
PATCH  /api/v1/users/me               # Обновить профиль
DELETE /api/v1/users/me               # Удалить профиль
GET    /api/v1/users/:id              # Профиль пользователя
PATCH  /api/v1/users/me/avatar        # Загрузить аватар
GET    /api/v1/users/search?q=        # Поиск пользователей

# Chats
POST   /api/v1/chats                  # Создать чат
GET    /api/v1/chats                  # Список чатов
GET    /api/v1/chats/:id              # Информация о чате
PATCH  /api/v1/chats/:id              # Обновить чат
DELETE /api/v1/chats/:id              # Удалить чат
POST   /api/v1/chats/:id/members      # Добавить участника
DELETE /api/v1/chats/:id/members/:uid # Удалить участника
PATCH  /api/v1/chats/:id/members/:uid # Обновить роль

# Messages
GET    /api/v1/chats/:id/messages     # Сообщения чата (пагинация)
GET    /api/v1/messages/:id           # Одно сообщение
POST   /api/v1/chats/:id/messages     # Отправить сообщение
PATCH  /api/v1/messages/:id           # Редактировать
DELETE /api/v1/messages/:id           # Удалить
POST   /api/v1/messages/:id/react     # Реакция
GET    /api/v1/chats/:id/search       # Поиск в чате

# Media
POST   /api/v1/media/upload           # Загрузить файл
GET    /api/v1/media/:id              # Скачать файл
DELETE /api/v1/media/:id              # Удалить файл

# Calls
POST   /api/v1/calls                  # Инициировать звонок
GET    /api/v1/calls/history          # История звонков

# Stories
POST   /api/v1/stories                # Опубликовать историю
GET    /api/v1/stories                # Лента историй
DELETE /api/v1/stories/:id            # Удалить
GET    /api/v1/stories/:id/views      # Просмотры

# Contacts
GET    /api/v1/contacts               # Список контактов
POST   /api/v1/contacts               # Добавить контакт
DELETE /api/v1/contacts/:id           # Удалить
POST   /api/v1/contacts/sync          # Синхронизация телефонной книги

# Settings
GET    /api/v1/settings               # Все настройки
PATCH  /api/v1/settings/privacy       # Настройки приватности
PATCH  /api/v1/settings/notifications # Настройки уведомлений
PATCH  /api/v1/settings/appearance    # Настройки внешнего вида
PATCH  /api/v1/settings/network       # Настройки сети
PATCH  /api/v1/settings/storage       # Настройки хранилища

# Nearby
GET    /api/v1/nearby                 # Пользователи рядом

# AI
POST   /api/v1/ai/chat                # Чат с AI
POST   /api/v1/ai/generate-sticker    # Генерация стикера
POST   /api/v1/ai/transcribe          # Транскрипция голоса
POST   /api/v1/ai/summarize           # Саммаризация чата

# Stickers
GET    /api/v1/stickers/packs         # Каталог стикер-паков
GET    /api/v1/stickers/packs/:id     # Один пак
POST   /api/v1/stickers/import        # Импорт из другого мессенджера
```

---

## Шифрование

### Транспортное шифрование
- **TLS 1.3** для всех HTTP/WebSocket соединений
- Certificate pinning в мобильных приложениях

### E2E-шифрование (секретные чаты)
- Протокол **Signal Protocol** (Double Ratchet)
- X3DH (Extended Triple Diffie-Hellman) для обмена ключами
- Ключи хранятся только на устройствах пользователей
- Предыдущие сообщения невозможно расшифровать при компрометации ключа

### Шифрование локального хранилища
- SQLCipher для локальной базы данных
- Flutter Secure Storage для токенов и ключей
- Биометрическая разблокировка приложения

---

## Анти-блокировки

```
┌───────────┐     ┌──────────────┐     ┌──────────────┐
│  Client    │────▶│  DoH/DoT     │────▶│  DNS Resolve │
│            │     │  (Cloudflare) │     │  (Real IP)   │
│            │     └──────────────┘     └──────┬───────┘
│            │                                  │
│            │◀───── Domain Fronting ───────────┤
│            │       (via CDN host)             │
│            │                                  │
│            │────▶ Built-in Proxy ────────────▶│
│            │      (SOCKS5/MTProto)            │
│            │                                  │
│            │────▶ Mirror Domains ────────────▶│
│            │      (auto-fallback)             │
└───────────┘     └────────────────────────────┘
```

### Механизмы
1. **DNS-over-HTTPS** (Cloudflare, Google) — обход DNS-блокировок
2. **Domain Fronting** — маскировка под легитимный CDN-трафик
3. **Встроенный прокси** — одно нажатие для включения
4. **Зеркальные домены** — автоматическое переключение при недоступности
5. **Fetched Config** — сервер присылает актуальные адреса подключения
6. **Obfuscation** — маскировка WS-трафика под обычный HTTPS

---

## Масштабирование

### Горизонтальное
- Stateless-сервисы → автоскейлинг через Kubernetes HPA
- WebSocket → sticky sessions через Redis adapter
- База данных → read replicas, connection pooling (PgBouncer)

### Вертикальное
- PostgreSQL → партиционирование messages по chat_id
- Redis Cluster → шардирование сессий
- MinIO → распределённое хранение файлов

### Нагрузочные цели
- **1 000 000** одновременных WebSocket-соединений
- **100 000** сообщений/секунду
- **< 100 мс** задержка доставки сообщения (P99)
- **99.99%** аптайм
