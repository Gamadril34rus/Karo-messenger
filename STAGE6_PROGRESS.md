# Этап 6 — Offline-First, Chat Actions, Video Player, Crash Reporting

## Дата: 2026-07-29
## Коммит: 83e7042

---

## Что было сделано

### 1. 🗄️ Drift Local Caching — Offline-First
- **ChatDetailBloc** теперь сохраняет все сообщения в локальную БД (Drift/SQLite)
- При загрузке чата сначала показывает кэш, затем обновляет с сервера
- При отсутствии сети — показывает кэшированные сообщения
- Добавлены методы: `getMessages()`, `insertMessages()`, `deleteMessage()`, `deleteMessagesForChat()`, `getLastMessage()`
- Маппинг `LocalMessage → MessageItem` для отображения кэша

### 2. 📌 Chat List Actions — Pin/Mute/Archive/Delete
- **Новые события BLoC**: `ChatListPinToggled`, `ChatListMuteToggled`, `ChatListArchiveToggled`
- **Серверные API**: `PATCH /chats/:id/pin`, `PATCH /chats/:id/mute`, `PATCH /chats/:id/archive`
- **ChatItem** расширен: `isArchived`, `copyWith()`
- **ChatListScreen**: действия привязаны к API (раньше были пустые onTap)
- **Удаление чата**: подтверждение через диалог
- **Архивация**: чат исчезает из списка, `include_archived` параметр

### 3. 👥 Chat Members Screen
- Новый экран `ChatMembersScreen` — список участников группы по ролям
- Владелец, Администраторы, Участники — сгруппированные секции
- Кнопка «Добавить участника» в AppBar
- Онлайновый индикатор для каждого участника
- Модель `ChatMemberInfo` с парсингом JSON
- Маршрут `/chat-members/:id` в GoRouter
- Кнопка «Участники» в AppBar ChatDetailScreen

### 4. 🎬 Video Player in Stories
- **Реальный видеоплеер** на основе `video_player` — заменён placeholder
- `_StoryVideoPlayer` — stateful виджет с `VideoPlayerController`
- Инициализация, воспроизведение, пауза при long-press
- Автоматический переход к следующей истории при окончании видео
- Обработка ошибок — fallback на placeholder при недоступности

### 5. 📊 Sentry Crash Reporting
- Новый сервис `CrashReportingService` — Sentry integration
- `sentry_flutter: ^8.14.0` добавлен в pubspec.yaml
- GDPR-compliant: `sendDefaultPii: false`
- Breadcrumbs, user tagging, error reporting
- Инициализация в main.dart через GetIt
- Environment区分: development/production
- Traces & profiles sample rate: 0 в debug, 1.0 в production

### 6. 📥 Data Export File Download
- Реальное скачивание файла через `path_provider`
- Сохранение JSON в `charo_data_export_YYYY-MM-DD.json`
- Кнопка «Сохранить файл» + «Поделиться»
- SnackBar с путём к файлу и кнопкой «Поделиться»

### 7. 🔕 Notification Settings — Quiet Hours
- Тихие часы сохраняются на сервер: `quietHoursEnabled`, `quietHoursStart`, `quietHoursEnd`
- Серверная schema `notificationSchema` расширена
- Клиент отправляет все настройки одним запросом

### 8. 🗄️ Server Schema Updates
- **ChatMember**: добавлены `isPinned` (Boolean), `isArchived` (Boolean)
- **Prisma client** перегенерирован (v6.19.3)
- **GET /chats**: поддержка `include_archived` параметра, `q` для поиска
- **PATCH /chats/:id**: поддержка `is_muted`, `is_pinned`, `is_archived`
- Сортировка: pinned чаты сверху, затем по updatedAt

### 9. 🐛 Bug Fixes
- Исправлен дублирующийся маршрут `GET /users/search` (был объявлен дважды)
- Удалён первый (простой) маршрут, оставлен полный (глобальный поиск)

### 10. 🧪 Tests
- 12 новых серверных тестов: chat actions, members, quiet hours
- 0 TS ошибок, 0 IP нарушений, все Dart файлы сбалансированы

---

## Метрики

| Метрика | До | После |
|---------|-----|-------|
| Dart файлов | 112 | 114 |
| Dart строк | ~25,310 | 26,289 |
| TS файлов (non-test) | 25 | 25 |
| Server test файлов | 7 | 8 |
| TS ошибок | 0 | 0 |
| Prisma моделей | 30 | 30 (+2 поля) |
| Маршрутов чатов | 12 | 15 (+3) |
| BLoCs | 10 | 10 |
| Сервисов | 14 | 15 (+1) |

---

## Оставшиеся известные ограничения

1. **Push notification Firebase** — нужен `google-services.json` / GoogleService-Info.plist для активации
2. **Drift local_db.g.dart** — требует `dart run build_runner build` после изменения схемы
3. **Sentry DSN** — нужно установить `SENTRY_DSN` env variable для активации
4. **E2E/integration tests** — пока только unit-тесты
5. **Chat member add** — экран выбора контактов для добавления в группу не реализован (показан SnackBar)
6. **Video player** — не работает на веб-платформе (только нативные)

---

## Следующие этапы (потенциальные)

1. **E2E/integration tests** — Flutter integration tests с реальным сервером
2. **Chat member add** — контакт-пикер для добавления участников
3. **Story creation** — создание историй (камера/галерея)
4. **Message search** — глобальный поиск по сообщениям
5. **Chat wallpaper** — кастомные фоны чатов
6. **Call quality** — WebRTC improvements (ICE, bandwidth)
7. **Localization** — полная i18n для EN/DE/RU
8. **Accessibility** — Semantics, Screen Reader support
