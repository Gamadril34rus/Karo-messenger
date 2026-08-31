<div align="center">

# ЧАРО

### Мессенджер нового поколения. Быстрый. Приватный. Мощный.

[![CI/CD](https://github.com/Gamadril34rus/Karo-messenger/actions/workflows/main.yml/badge.svg)](https://github.com/Gamadril34rus/Karo-messenger/actions)
[![License: Proprietary](https://img.shields.io/badge/License-Proprietary-red.svg)](./LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Web%20%7C%20Windows%20%7C%20Linux%20%7C%20macOS-blue.svg)]()
[![Server](https://img.shields.io/badge/Server-Fastify-black.svg)](https://fastify.dev)
[![Architecture](https://img.shields.io/badge/Architecture-Clean%20%2B%20BLoC-purple.svg)]()

</div>

---

## ⬇️ Скачать

| Платформа | Ссылка | Версия |
|-----------|--------|--------|
| 🤖 Android APK | [Скачать .apk](https://github.com/Gamadril34rus/Karo-messenger/releases/latest) | 1.1.0 |
| 🪟 Windows | [Скачать .zip](https://github.com/Gamadril34rus/Karo-messenger/releases/latest) | 1.1.0 |
| 🐧 Linux | [Скачать .tar.gz](https://github.com/Gamadril34rus/Karo-messenger/releases/latest) | 1.1.0 |
| 🌐 Web | [Открыть в браузере](https://gamadril34rus.github.io/Karo-messenger/) | 1.1.0 |
| 🍎 iOS | Сборка из исходников (Xcode) | 1.1.0 |
| 🍏 macOS | [Артефакты CI](https://github.com/Gamadril34rus/Karo-messenger/actions/workflows/main.yml) | 1.1.0 |

> 📦 Промежуточные сборки всех 6 платформ доступны в артефактах [GitHub Actions](https://github.com/Gamadril34rus/Karo-messenger/actions/workflows/main.yml), сервер — в виде Docker-образа `ghcr.io/gamadril34rus/karo-messenger-server` [на GHCR](https://github.com/Gamadril34rus/Karo-messenger/pkgs/container/karo-messenger-server).

---

## ✨ Возможности

- 🔒 **End-to-End шифрование** — Signal Protocol (Double Ratchet, Sealed Sender)
- 📞 **Голосовые и видеозвонки** — WebRTC с E2EE
- 🤖 **AI-ассистент** — Gemini 2.0 Flash: саммаризация чатов, генерация стикеров, перевод
- 📍 **Рядом** — поиск людей поблизости (opt-in)
- 📖 **Истории** — текст, фото, видео с настройкой видимости
- 🎨 **Стикеры** — встроенные паки + импорт + AI-генерация
- 🧊 **Исчезающие сообщения** — таймер от 5 сек до 7 дней
- 👥 **Группы E2EE** — MLS (Messaging Layer Security)
- 🔐 **Биометрия** — вход по отпечатку/лицу
- 🌍 **8 языков** — RU, EN, DE, FR, ES, PT, ZH, JA
- 📱 **6 платформ** — Android, iOS, Web, Windows, Linux, macOS
- 🔄 **Оффлайн-first** — Drift SQLite + синхронизация при подключении
- 🛡️ **ФЗ-152 / GDPR / CCPA** — полное правовое соответствие

---

## 🏗️ Архитектура

```
┌─────────────────────────────────────────────┐
│                  Flutter Client              │
│  ┌─────────┐  ┌──────────┐  ┌────────────┐ │
│  │  BLoC   │──│  Charo   │──│  CharoApi  │ │
│  │ Layer   │  │Repository│  │ Repository │ │
│  └─────────┘  └──────────┘  └────────────┘ │
│       │                          │          │
│  ┌─────────┐              ┌────────────┐   │
│  │  Drift <──│  Local DB  │  WebSocket │   │
│  │  SQLite │              │  Channel   │   │
│  └─────────┘              └────────────┘   │
└─────────────────────────────────────────────┘
                         │
                    HTTPS / WSS
                         │
┌─────────────────────────────────────────────┐
│               Fastify Server                │
│  ┌────────┐  ┌────────┐  ┌──────────────┐ │
│  │ Prisma │──│PostgreSQL│  │    Redis    │ │
│  │  ORM   │  │   16    │  │  7 (ioredis)│ │
│  └────────┘  └────────┘  └──────────────┘ │
│  ┌────────┐  ┌────────┐  ┌──────────────┐ │
│  │ MinIO  │  │ Gemini │  │  WebSocket   │ │
│  │  S3    │  │  AI    │  │  Handler     │ │
│  └────────┘  └────────┘  └──────────────┘ │
└─────────────────────────────────────────────┘
```

**Принципы:** Clean Architecture, BLoC, Domain-Driven Design, Offline-First, Security-by-Design.

---

## 🚀 Быстрый старт

### Требования
- Flutter 3.44.8+ (SDK ≥3.12.0 <4.0.0)
- Node.js 20+
- PostgreSQL 16+
- Redis 7+

### Клиент
```bash
cd client/flutter
flutter pub get
# один раз: сгенерировать нативные проекты (android/ios/macos/windows/linux)
./scripts/regen_native.sh
flutter run
```

### Сервер
```bash
cd server
npm ci
npx prisma generate
npx prisma migrate dev
npm run dev
```

### Деплой на Render
См. → [DEPLOY_GUIDE.md](./DEPLOY_GUIDE.md) — пошаговая инструкция.

---

## 📁 Структура проекта

```
Karo-messenger/
├── client/flutter/          # Flutter-клиент (108 Dart-файлов)
│   ├── lib/
│   │   ├── core/            # Ядро: domain, network, storage, E2EE, theme
│   │   ├── features/        # Фичи: auth, chat, calls, stories, contacts, ...
│   │   ├── i18n/            # Локализация (8 языков)
│   │   └── main.dart        # Точка входа
│   └── test/                # Unit + Widget тесты
├── server/                  # Fastify-сервер (20+ модулей)
│   ├── src/
│   │   ├── modules/         # Маршруты: auth, chats, messages, ai, ...
│   │   ├── middleware/       # Auth, error handler
│   │   ├── ws/              # WebSocket handler
│   │   └── index.ts         # buildServer() + main()
│   └── prisma/              # 30 моделей, миграции
├── .github/workflows/       # CI/CD: test, build×6, deploy, lint
├── LICENSE                  # Проприетарная (запрет модификации)
├── PRIVACY_POLICY.md        # ФЗ-152 / GDPR / CCPA
├── TERMS_OF_SERVICE.md      # Пользовательское соглашение
└── DEPLOY_GUIDE.md          # Инструкция деплоя
```

---

## 📊 CI/CD

[![CI/CD Pipeline](https://github.com/Gamadril34rus/Karo-messenger/actions/workflows/main.yml/badge.svg)](https://github.com/Gamadril34rus/Karo-messenger/actions/workflows/main.yml)

| Job | Платформа | Статус |
|-----|-----------|--------|
| Tests & Coverage | Ubuntu + PG16 + Redis7 | ✅ server tests |
| Build Android | Ubuntu + JDK17 | ✅ APK + AAB |
| Build iOS | macOS | ✅ Runner.app |
| Build Windows | Windows | ✅ EXE |
| Build Linux | Ubuntu + GTK3 | ✅ Bundle |
| Build macOS | macOS | ✅ .app |
| Build & Deploy Web | Ubuntu → GitHub Pages | ✅ |
| Build Docker | Ubuntu → GHCR | ✅ |
| Legacy Check | Ubuntu | ✅ Zero remnants |

> Нативные проекты платформ генерируются скриптом `client/flutter/scripts/regen_native.sh` (те же шаги выполняет CI). Релизы со сборками создаются автоматически по тегу `v*` — см. [release.yml](./.github/workflows/release.yml).

---

## 🛡️ Правовое соответствие

| Закон | Соответствие | Документ |
|-------|-------------|----------|
| ФЗ-152 | Данные РФ-граждан на серверах в РФ | [PRIVACY_POLICY.md](./PRIVACY_POLICY.md) |
| GDPR | Right to erasure, portability, consent | [PRIVACY_POLICY.md](./PRIVACY_POLICY.md) |
| CCPA | Opt-out, no data sale, deletion | [PRIVACY_POLICY.md](./PRIVACY_POLICY.md) |
| COPPA | 13+ age gate | [PRIVACY_POLICY.md](./PRIVACY_POLICY.md) |
| — | Пользовательское соглашение | [TERMS_OF_SERVICE.md](./TERMS_OF_SERVICE.md) |
| — | Политика безопасности | [SECURITY.md](./SECURITY.md) |
| — | Авторские права | [NOTICE.md](./NOTICE.md) |
| — | Лицензия (запрет модификации) | [LICENSE](./LICENSE) |

---

## 📜 Лицензия

```
Copyright © 2024-2026 Бутаев Алексей Юрьевич (Charo Team). All rights reserved.

ЗАПРЕЩАЕТСЯ: модификация, распространение, декомпилирование,
коммерческое использование без письменного разрешения.

См. LICENSE для полного текста.
```

---

## 📞 Контакты

| Роль | Email |
|------|-------|
| Команда | pizdec666@yandex.ru |
| Поддержка | pizdec666@yandex.ru |
| Безопасность | pizdec666@yandex.ru |
| Конфиденциальность | pizdec666@yandex.ru |
| Юридические вопросы | pizdec666@yandex.ru |

---

<div align="center">

**ЧАРО** — мессенджер, которому можно доверять.

</div>
