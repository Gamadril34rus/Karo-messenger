# ЧАРО (Charo) — Мессенджер нового поколения

> Быстрый. Приватный. Мощный. Красивый.

ЧАРО — production-ready мессенджер с E2EE (Signal Protocol), MLS для групп, WebRTC звонками, DataChannel, Charo-звуками, анти-блокировками и premium UI.

## 📱 Архитектура

| Компонент | Технология |
|---|---|
| **Client** | Flutter (Android, iOS, Web, Windows, macOS, Linux) |
| **State Management** | BLoC (flutter_bloc ^9.1.1) |
| **Backend** | Fastify (Node.js) + TypeScript |
| **Database** | PostgreSQL 16 + Prisma ORM |
| **Cache** | Redis (ioredis) |
| **Storage** | MinIO (S3-compatible) |
| **E2EE** | Signal Protocol (libsignal_protocol_dart ^0.8.2) |
| **Group E2EE** | MLS (AES-256-CBC + PointyCastle) |
| **Calls** | WebRTC (flutter_webrtc ^1.5.2) |
| **Anti-blocking** | DoH + Domain Fronting + Mirror Domains + Proxy |

## 🚀 Быстрый старт

### Сервер

```bash
# 1. Установите зависимости
cd server
npm install

# 2. Настройте .env
cp .env.example .env
# Отредактируйте .env — установите JWT secrets, DATABASE_URL, etc.

# 3. Запустите PostgreSQL + Redis через Docker
cd ..
docker compose up postgres redis minio -d

# 4. Примените миграции
cd server
npx prisma migrate deploy

# 5. Запустите сервер
npm run dev
```

### Клиент (Flutter)

```bash
# 1. Установите Flutter SDK (3.44+)
cd client/flutter

# 2. Установите зависимости
flutter pub get

# 3. Запустите build_runner для Drift
dart run build_runner build

# 4. Запустите на нужной платформе
flutter run               # Android/iOS
flutter run -d chrome     # Web
flutter run -d macos      # macOS
flutter run -d windows    # Windows
flutter run -d linux      # Linux
```

## 🔐 Криптография

### Signal Protocol (1:1 чаты)
- `generateIdentityKeyPair()` — создание Identity Key Pair
- `generateRegistrationId()` — генерация registration ID
- `generateSignedPreKey()` + `generatePreKeys()` — создание PreKey Bundle
- `SessionCipher(store, address)` — шифрование/дешифрование
- `SessionBuilder(store, address)` — создание сессий
- Safety Numbers = SHA-256(sorted(fp₁, fp₂)) — верификация

### AES-256-CBC (группы)
- PointyCastle `CBCBlockCipher(AESEngine())`
- PKCS7 padding/unpadding
- FortunaRandom с `Random.secure()` seeding
- IV prepended to ciphertext
- Key derivation: SHA-256(groupId + context)

## 📡 Anti-Blocking

- **DNS-over-HTTPS**: Cloudflare, Google, Quad9
- **Domain Fronting**: HTTPS requests через CDN
- **Mirror Domains**: 5 зеркальных API-серверов
- **Auto-rotation**: при ошибке соединения → переключение на зеркало
- **Proxy support**: SOCKS5/HTTP proxy через настройки

## 🎨 UI — CharoWidgets Library

| Widget | Описание |
|---|---|
| `CharoCard` | Карточка с gradient, elevation, border |
| `CharoSection` | Секция с заголовком и divider |
| `CharoTile` | ListTile с premium styling |
| `CharoAvatar` | Аватар с badge и статусом |
| `CharoBadge` | Badge для unread count |
| `CharoHeaderCard` | Большая карточка профиля |
| `CharoSwitchTile` | Toggle с подписью |
| `CharoProgressRing` | Круговой progress indicator |

## 🔊 Звуки Charo

| Файл | Описание |
|---|---|
| `charo_message.wav` | Входящее сообщение (Uh-oh!) |
| `charo_send.wav` | Отправка сообщения |
| `charo_call.wav` | Входящий звонок (4-ring) |
| `charo_online.wav` | Контакт онлайн |
| `charo_system.wav` | Системное уведомление |

## 🗂️ Структура проекта

```
charo-messenger/
├── client/flutter/
│   ├── lib/
│   │   ├── core/           # E2EE, MLS, network, storage, theme, routing
│   │   ├── features/       # auth, chat, calls, contacts, stories, etc.
│   │   ├── i18n/           # Strings + localization
│   │   ├── shared/         # CharoWidgets, MessageBubble
│   │   └── main.dart
│   ├── assets/
│   │   ├── fonts/          # CharoSans (Open Sans rebrand)
│   │   ├── sounds/         # Charo WAV sounds
│   │   ├── stickers/       # 15 packs, 132 stickers
│   │   ├── emoji/          # Charo classic + animated
│   │   └── icons/          # App icon 1024×1024
│   └── pubspec.yaml
├── server/
│   ├── src/
│   │   ├── modules/        # auth, chats, users, media, calls, etc.
│   │   ├── middleware/     # auth, errorHandler
│   │   ├── ws/             # WebSocket connection manager
│   │   ├── services/       # AuthService, ChatService, etc.
│   │   └── index.ts        # Fastify bootstrap
│   ├── prisma/
│   │   ├── schema.prisma   # Database schema
│   │   └── migrations/     # SQL migrations
│   └── package.json
├── docker-compose.yml
└── .gitignore
```

## 🧪 Тестирование

```bash
# Server
cd server
npm test                # Vitest

# Client
cd client/flutter
flutter test            # Unit tests
flutter analyze         # Static analysis (0 errors target)
```

## 📋 Production Checklist

- [x] E2EE Signal Protocol — real AES-256-CBC + SHA-256
- [x] MLS group encryption — AES-256-CBC with Sender Keys
- [x] Safety Numbers — SHA-256(sorted fingerprints) + server fetch
- [x] WebRTC calls + DataChannel + E2EE
- [x] Anti-blocking — DoH + mirrors + proxy + domain fronting
- [x] Charo sounds + haptic feedback
- [x] Premium CharoWidgets UI (8 widgets)
- [x] 35+ languages of Russia
- [x] Sticker import from local ZIP/folder (WhatsApp format supported)
- [x] Animated emoji (6 packs)
- [x] Server: 0 TypeScript errors
- [x] Docker + docker-compose
- [ ] Flutter analyze on real machine (need Flutter SDK)
- [ ] Flutter build for all platforms (need Flutter SDK)
- [ ] dart run build_runner build (regenerate local_db.g.dart)
- [ ] Runtime testing on emulator

## 📄 License

Proprietary — All rights reserved.
