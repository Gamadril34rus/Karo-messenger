# Этап 7 — Story Creation, Contact Picker, Chat Wallpaper, Tests

## Дата: 2026-07-29
## Коммит: 4ae3650

---

## Что было сделано

### 1. 📸 Story Creation Screen
- Новый экран `StoryCreateScreen` — полноценное создание историй
- **Типы**: Фото, Видео, Текст — выбор через чипы
- **Фото/Видео**: выбор из галереи через FilePicker, загрузка на сервер через FileUploadService
- **Текст**: ввод текста до 500 символов + выбор цвета фона (10 градиентов)
- **Предпросмотр**: миниатюра с mock-сообщениями для визуальной оценки
- Маршрут `/story-create` в GoRouter
- StoriesBloc обновлён: `StoryPublishRequested` теперь принимает `mediaUrl`, `textContent`, `backgroundColor`

### 2. 👥 Contact Picker Screen
- Новый экран `ContactPickerScreen` — выбор контактов для добавления в группу
- **Multi-select**: множественный выбор с анимированными чекбоксами
- **Поиск**: фильтрация контактов по имени/username
- **Добавление**: отправка POST /chats/:id/members для каждого выбранного
- Маршрут `/contact-picker/:id` в GoRouter
- ChatMembersScreen: кнопка «Добавить участника» открывает ContactPicker

### 3. 🎨 Chat Wallpaper Screen
- Новый экран `ChatWallpaperScreen` — кастомные фоны чатов
- **12 предустановленных обоев**: Океан, Закат, Лес, Лаванда, Ночь, Персик, Мята, Уголь, Небо, Роза, По умолчанию, Без фона
- **Предпросмотр**: миниатюра чата с mock-сообщениями на выбранном фоне
- **Сохранение**: через SharedPreferences (wallpaper_:chatId)
- ChatDetailScreen: пункт меню «Фон чата» теперь открывает экран выбора
- Маршрут `/chat-wallpaper/:id` в GoRouter

### 4. 🔍 Server: Message Search Fix
- Поиск по сообщениям теперь использует `OR` условие:
  - `content.path(['text'], string_contains: q)` — поиск по JSON полю text
  - `content.string_contains: q` — fallback поиск по raw строке
- Это исправляет поиск, когда content может быть как JSON `{"text": "..."}`, так и plain text

### 5. 🧪 Client BLoC Tests
- **ChatListBloc** (7 тестов): initial state, event props, ChatItem copyWith, isArchived
- **ProfileBloc** (7 тестов): initial state, event props, ProfileLoaded fields
- **StoriesBloc** (5 тестов): initial state, StoryPublishRequested props, StoryItem copyWith
- Всего 16 клиентских тестов (+3 новых)

### 6. 🧪 Server Tests
- **Story Routes** (4 теста): GET /stories, POST /stories, DELETE /stories/:id, GET /stories/:id/views
- **Chat Search** (1 тест): GET /chats/:id/search
- **Contact Routes** (5 тестов): GET /contacts, POST /contacts, POST /contacts/sync, POST /contacts/block, DELETE /contacts/:id

---

## Метрики

| Метрика | До | После |
|---------|-----|-------|
| Dart файлов (lib) | 100 | 103 |
| Dart строк (lib) | 26,289 | 27,326 |
| TS файлов | 27 | 28 |
| Server test файлов | 8 | 9 |
| Client test файлов | 13 | 16 |
| TS ошибок | 0 | 0 |
| Маршрутов GoRouter | 33 | 36 (+3) |
| Новых экранов | 0 | 3 |

---

## Оставшиеся известные ограничения

1. **Push notification Firebase** — нужен google-services.json / plist
2. **Drift local_db.g.dart** — требует `dart run build_runner build`
3. **Sentry DSN** — нужен env variable для активации
4. **E2E/integration tests** — только unit-тесты
5. **Camera capture** — для сторис и аватара используется FilePicker (gallery), нет прямой интеграции с камерой
6. **Chat wallpaper** — хранится в SharedPreferences, не синхронизируется между устройствами
7. **Localization** — частичная, EN/RU/DE не полностью покрыты
8. **Accessibility** — Semantic labels добавлены частично

---

## Архитектурные решения

### StoryCreateScreen
- Загрузка медиа через `FileUploadService.instance.uploadFile()` — единый путь загрузки
- StoriesBloc получает `mediaUrl` после загрузки, отправляет в API с типом и URL
- Для текстовых историй — `backgroundColor` hex-код сохраняется на сервере

### ContactPickerScreen
- Multi-select через `Set<String> _selectedIds` — нет лимита на количество
- Добавление участников — последовательные POST запросы (надёжно, но не батч)
- Поиск — локальный фильтр по загруженным контактам

### ChatWallpaperScreen
- SharedPreferences для хранения — быстро, не требует сервера
- Формат ключа: `wallpaper_<chatId>` — уникальный для каждого чата
- `wallpaper_default` — глобальный фон по умолчанию
- 12 предустановленных градиентов — не требует загрузки изображений
