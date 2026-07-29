<div align="center">

# ⚡ ЧАРО

### Мессенджер нового поколения

**Быстрый. Приватный. Мощный.**

[![CI/CD](https://github.com/charo-messenger/charo/actions/workflows/main.yml/badge.svg)](https://github.com/charo-messenger/charo/actions/workflows/main.yml)
[![License](https://img.shields.io/badge/license-AGPL--3.0-blue.svg)](LICENSE)
[![TypeScript](https://img.shields.io/badge/server-TypeScript%205-3178C6.svg)](https://www.typescriptlang.org/)
[![Flutter](https://img.shields.io/badge/client-Flutter%203-02569B.svg)](https://flutter.dev)
[![Prisma](https://img.shields.io/badge/ORM-Prisma%20v6-2D3748.svg)](https://www.prisma.io/)

[Features](#-features) • [Architecture](#-architecture) • [Quick Start](#-quick-start) • [Deployment](#-deployment) • [Contributing](CONTRIBUTING.md) • [Security](SECURITY.md)

</div>

---

## ✨ Features

| Category | Features |
|----------|----------|
| **💬 Messaging** | E2EE (Signal Protocol), reactions, replies, forwarding, editing, disappearing messages |
| **📞 Calls** | Voice & video calls (WebRTC), up to 32 video participants |
| **📺 Stories** | Image, video, text stories with auto-advance, 24h expiry |
| **👥 Groups** | Groups & channels with roles (Owner/Admin/Member), up to 200K members |
| **🔒 Privacy** | ФЗ-152, GDPR, CCPA compliant. 2FA (TOTP). Block list. Data export. Account recovery (30 days) |
| **🤖 AI** | Built-in AI assistant (Gemini), voice transcription (Whisper), sticker generation |
| **📱 Adaptive** | Mobile, tablet, desktop (NavigationRail + Master-Detail layout) |
| **🌐 Offline** | Offline-first (Drift local DB), gap-filling sync, queue-based sending |
| **🎨 Themes** | Light, Dark, AMOLED. 56+ languages. Custom wallpapers |
| **🎯 Stickers** | 177 stickers in 15 packs (CC0), import from external sources |

---

## 🏗 Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    ЧАРО Architecture                      │
├─────────────────────┬───────────────────────────────────┤
│     Client (Flutter)    │        Server (Fastify)          │
│  ┌─────────────────┐    │  ┌─────────────────────────────┐ │
│  │  Screens (38+)   │    │  │  REST API (80+ routes)      │ │
│  ├─────────────────┤    │  ├─────────────────────────────┤ │
│  │  BLoCs (10+)     │    │  │  WebSocket (12 event types) │ │
│  ├─────────────────┤    │  ├─────────────────────────────┤ │
│  │  Services (15+)  │    │  │  Prisma ORM (30 models)     │ │
│  ├─────────────────┤    │  ├─────────────────────────────┤ │
│  │  Local DB (Drift)│    │  │  MinIO (S3 media storage)   │ │
│  ├─────────────────┤    │  ├─────────────────────────────┤ │
│  │  ApiClient (Dio) │    │  │  Redis (cache + sessions)   │ │
│  └─────────────────┘    │  └─────────────────────────────┘ │
└─────────────────────┴───────────────────────────────────┘
```

| Component | Technology |
|-----------|-----------|
| **Client** | Flutter 3.24 + BLoC 9 + GetIt + GoRouter |
| **Server** | Fastify 5 + TypeScript 5 + Zod validation |
| **Database** | PostgreSQL 16 + Prisma v6 (30 models) |
| **Cache** | Redis 7 (sessions, rate limiting, nearby) |
| **Media** | MinIO (S3-compatible) + CDN |
| **Encryption** | Signal Protocol (E2EE) + MLS (groups) |
| **Calls** | WebRTC via flutter_webrtc |
| **Push** | Firebase Cloud Messaging (FCM/APNS) |
| **AI** | Google Gemini 2.0 Flash + OpenAI Whisper |
| **Crash Reporting** | Sentry |

---

## 🚀 Quick Start

### Prerequisites

- **Node.js** 20+
- **Flutter** 3.24+
- **Docker** & Docker Compose
- **PostgreSQL** 16+ (or use Docker)

### 1. Clone

```bash
git clone https://github.com/charo-messenger/charo.git
cd charo
```

### 2. Start Infrastructure

```bash
docker compose up -d db redis minio
```

### 3. Configure Server

```bash
cd server
cp .env.example .env
# Edit .env — set your secrets (JWT_ACCESS_SECRET, JWT_REFRESH_SECRET, etc.)
npm install
npx prisma migrate dev
npx prisma generate
npm run build
npm start
```

### 4. Run Client

```bash
cd client/flutter
flutter pub get
flutter run
```

### 5. Full Stack (Docker)

```bash
docker compose up -d
```

### 6. Verify

```bash
curl http://localhost:3000/health
# Expected: {"status":"ok","checks":{"database":"ok","redis":"ok"}}
```

---

## 📁 Project Structure

```
charo/
├── server/                          # Fastify API server
│   ├── src/
│   │   ├── modules/                 # 13 route modules
│   │   │   ├── auth/                # 20 routes (login, register, 2FA, OAuth, devices)
│   │   │   ├── chats/               # 15 routes (CRUD, messages, members, pin/mute/archive)
│   │   │   ├── messages/            # 4 routes (get, edit, delete, react)
│   │   │   ├── contacts/            # 7 routes (CRUD, sync, block/unblock)
│   │   │   ├── media/               # 6 routes (upload, get, delete, thumbnail)
│   │   │   ├── users/               # 10 routes (me, profile, search, avatar, keys)
│   │   │   ├── calls/               # 2 routes (create, history)
│   │   │   ├── stories/             # 4 routes (create, feed, delete, views)
│   │   │   ├── settings/            # 6 routes (privacy, notifications, appearance)
│   │   │   ├── ai/                  # 5 routes (chat, transcribe, summarize, generate)
│   │   │   ├── stickers/            # 3 routes (packs, import)
│   │   │   ├── nearby/              # 1 route (location-based)
│   │   │   ├── search/              # 1 route (global search)
│   │   │   └── mls/                 # MLS group encryption
│   │   ├── ws/                      # WebSocket connection manager
│   │   ├── middleware/              # Auth, error handling
│   │   └── index.ts                 # Entry point + buildServer()
│   ├── prisma/                      # 30 Prisma models
│   ├── Dockerfile
│   └── .env.example
├── client/flutter/
│   ├── lib/
│   │   ├── core/                    # Services, network, storage, theme
│   │   │   ├── services/            # 15 service files
│   │   │   ├── network/             # ApiClient (Dio), WsClient, interceptors
│   │   │   ├── storage/             # SecureStorage, LocalDB (Drift)
│   │   │   ├── theme/               # AppTheme (Light/Dark/AMOLED)
│   │   │   ├── routing/             # GoRouter (38+ routes)
│   │   │   ├── e2ee/                # Signal Protocol (E2EE)
│   │   │   ├── accessibility/       # Semantic labels
│   │   │   └── constants/           # AppConstants
│   │   ├── features/                # 9 feature modules
│   │   │   ├── auth/                # Login, Register, OTP, 2FA, Recovery
│   │   │   ├── chat/                # ChatList, ChatDetail, Create, Forward
│   │   │   ├── calls/               # ActiveCall, IncomingCall
│   │   │   ├── stories/             # StoryViewer, StoryCreate
│   │   │   ├── contacts/            # Contacts, ContactPicker
│   │   │   ├── settings/            # 10+ settings screens
│   │   │   ├── profile/             # Profile, ProfileEdit
│   │   │   ├── search/              # GlobalSearch
│   │   │   └── ai_assistant/        # AI chat
│   │   ├── shared/                  # Reusable widgets
│   │   │   ├── charo_widgets.dart   # CharoCard, CharoTile, CharoAvatar, etc.
│   │   │   ├── message_bubble.dart  # MessageBubble with all types
│   │   │   └── error_boundary.dart
│   │   ├── i18n/                    # 56+ language JSON files
│   │   └── main.dart                # GetIt DI + BLoC providers
│   └── test/                        # 18 test files
├── .github/workflows/               # CI/CD (test, build, deploy)
├── docker-compose.yml               # PostgreSQL + Redis + MinIO + Server
├── LICENSE                          # AGPL-3.0
├── CONTRIBUTING.md
├── SECURITY.md
├── CODE_OF_CONDUCT.md
└── README.md
```

---

## 🚢 Deployment

### Production Server (VPS)

**Minimum**: 2 vCPU, 4 GB RAM, 40 GB SSD

```bash
# 1. Install Docker
curl -fsSL https://get.docker.com | sh

# 2. Clone & configure
git clone https://github.com/charo-messenger/charo.git
cd charo
cp .env.example .env
# Edit .env with production secrets!

# 3. Generate strong secrets
JWT_ACCESS_SECRET=$(openssl rand -base64 48)
JWT_REFRESH_SECRET=$(openssl rand -base64 48)
DB_PASSWORD=$(openssl rand -base64 24)

# 4. Deploy
docker compose up -d

# 5. Run migrations
docker compose exec server npx prisma migrate deploy

# 6. Create MinIO bucket
docker compose exec minio mc alias set local http://localhost:9000 minioadmin YOUR_SECRET
docker compose exec minio mc mb local/charo-media

# 7. Setup SSL (Certbot)
sudo apt install certbot
sudo certbot certonly --standalone -d api.charo.chat
```

### Environment Variables

See [.env.example](server/.env.example) for the complete list. Critical variables:

| Variable | Description | Required |
|----------|-------------|----------|
| `DATABASE_URL` | PostgreSQL connection string | ✅ |
| `JWT_ACCESS_SECRET` | Access token signing key | ✅ |
| `JWT_REFRESH_SECRET` | Refresh token signing key | ✅ |
| `DB_PASSWORD` | PostgreSQL password | ✅ |
| `MINIO_SECRET_KEY` | MinIO secret key | ✅ |
| `GEMINI_API_KEY` | Google Gemini API key | Optional |
| `FIREBASE_PROJECT_ID` | Firebase push notifications | Optional |
| `SENTRY_DSN` | Sentry crash reporting | Optional |

---

## 🔄 Swapping the Backend

ЧАРО is designed for easy server replacement. The architecture uses a **Repository Pattern**:

1. **Create** a new `CharoRepository` implementation (e.g., `CharoSupabaseRepository`)
2. **Register** it in `main.dart` DI container
3. **Done** — all BLoCs, screens, and widgets remain unchanged

See [AUDIT_VISUAL_ARCH_GITHUB.md](AUDIT_VISUAL_ARCH_GITHUB.md#2-архитектура-с-быстрой-заменой-сервера) for the full migration guide.

---

## 🧪 Testing

```bash
# Server tests
cd server
npm test

# Client tests
cd client/flutter
flutter test

# Server type checking
cd server
npx tsc --noEmit
```

---

## 📊 Project Stats

| Metric | Count |
|--------|-------|
| Server TS files | 31 |
| Server test files | 11 |
| Client Dart files | 105 |
| Client test files | 18 |
| i18n languages | 56+ |
| Prisma models | 30 |
| API routes | 80+ |
| WebSocket events | 12 |
| BLoCs | 10+ |
| Screens | 38+ |
| Services | 15+ |

---

## 🛡 Legal Compliance

- ✅ **ФЗ-152** — Russian Federal Law on Personal Data
- ✅ **GDPR** — EU General Data Protection Regulation
- ✅ **CCPA** — California Consumer Privacy Act
- ✅ **IP-clean** — No trademark violations

---

## 📄 License

This project is licensed under the GNU Affero General Public License v3.0 — see [LICENSE](LICENSE).

This means:
- ✅ You can freely use, study, and modify the application
- ✅ Any modifications must be distributed under the same license
- ✅ If you run a modified version as a network service, you must provide source code to users

---

## 🤝 Contributing

We welcome contributions! Please read [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

---

<div align="center">

**ЧАРО** © 2024–2026 — [charo.chat](https://charo.chat)

</div>
