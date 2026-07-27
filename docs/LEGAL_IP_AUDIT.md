# Юридический аудит — Charo звуки, эмодзи, импорт стикеров
## ЧАРО (Charo) Messenger v1.0.0

**Дата обновления:** 2026-07-27  
**Статус:** ✅ Все IP-нарушения исправлены

---

## 1. Charo звуки — ✅ ИСПРАВЛЕНО

### Исторический контекст
- ICQ был создан Mirabilis (1996), куплен AOL (1998 за $287M), затем VK/Mail.ru (2010 за $187.5M)
- ICQ закрыт 26 июня 2024 — но VK сохранил все IP-права (торговые марки, звуки, логотипы, бренд)
- Звук "Uh-Oh!" — зарегистрированная торговая марка VK

### Нарушения (были)
- 5 файлов с названием `icq_*.wav` — прямое использование торгового имени ICQ
- `notification_service.dart` — комментарии "ICQ sounds", "по мотивам ICQ"
- README.md — "Generated ICQ-style notification tones"

### Исправления (выполнено)
- ✅ `icq_*.wav` → `charo_*.wav` (5 файлов)
- ✅ `notification_service.dart` — "ICQ" → "Charo" во всех комментариях
- ✅ `animated_emoji_service.dart` — "ICQ" → "Charo" во всех ссылках
- ✅ `active_call_screen.dart` — "ICQ call sound" → "Charo call sound"
- ✅ `sounds/README.md` — полностью переписан: "Original Notification Pack", "CC0/Public Domain — original compositions, no third-party IP"
- ✅ `pubspec.yaml` — пути обновлены: `charo_*.wav`

### Правовой статус звуков
- Звуки синтезированы программно (880Hz, 1200Hz) — они НЕ являются копией оригинальных ICQ звуков
- Это **оригинальная композиция**, вдохновлённая эстетикой, но **без копирования аудиоматериала**
- Допустимо при условии отсутствия бренда ICQ в названии — **условие выполнено**

---

## 2. Charo эмодзи — ✅ ИСПРАВЛЕНО

### Нарушения (были)
- `emoji_config.json` — `"name": "icq_classic"`, `"description": "ICQ Classic Emoji Pack"`
- Папка `icq_classic/` — прямое использование бренда ICQ
- Папка `icq_animated/` — прямое использование бренда ICQ
- Описания: "Classic ICQ — character bangs head against brick wall"
- `loadIcqEmoji()` — метод с брендом ICQ

### Исправления (выполнено)
- ✅ `emoji_config.json` — `"name": "charo_classic"`, `"description": "Classic Charo Emoji Pack"`
- ✅ Папка `icq_classic/` → `charo_classic/`
- ✅ Папка `icq_animated/` → `charo_animated/`
- ✅ Файл `icq_classic.json` → `charo_classic.json`
- ✅ Animated emoji: "Classic ICQ" → "Classic Charo" в описаниях
- ✅ `loadIcqEmoji()` → `loadCharoEmoji()` — метод переименован
- ✅ `pubspec.yaml` — пути к emoji обновлены

---

## 3. Импорт стикеров — ✅ ИСПРАВЛЕНО

### Telegram Bot API — ❌ УДАЛЕНО (ToS нарушение)
- Telegram Bot Developer ToS: "cannot infringe or violate third party rights, nor enable any user to do so"
- Bot API sticker export = ToS violation + copyright violation of sticker artists
- `dmca@telegram.org` handles sticker copyright complaints
- **Действие:** Метод `importFromTelegram()` полностью удалён

### VK Store API — ❌ УДАЛЕНО (VK ToS нарушение)
- VK Platform Rules §1.6: "It is not allowed to provide the ability to download content from VKontakte servers beyond the functionality of VKontakte Social Network"
- **Действие:** Метод `importFromVk()` + `_pickBestVkImage()` полностью удалён

### Viber CDN API — ❌ УДАЛЕНО (ToS нарушение)
- Viber sticker API не публичный — scraping = нарушение ToS
- **Действие:** Метод `importFromViber()` полностью удалён

### WhatsApp ZIP — ✅ СОХРАНЕНО (открытый формат)
- WhatsApp stickers: открытый формат (github.com/WhatsApp/stickers)
- Импорт из локального ZIP-архива, предоставленного пользователем = допустимо
- **Действие:** Метод `importFromWhatsAppZip()` сохранён, label → "ZIP-архив (WhatsApp формат)"
- **StickerImportSource:** `whatsappZip` (enum value correct, was `whatsapp` before — fixed)

### Локальный ZIP — ✅ СОХРАНЕНО
- `importFromLocalZip()` — импорт из пользовательского ZIP = допустимо

### Локальная папка — ✅ СОХРАНЕНО
- `importFromLocalFolder()` — импорт из пользовательских файлов = допустимо

### StickerImportSource enum — ✅ ОБновлён
- Удалены: `telegram`, `vk`, `viber`
- Сохранены: `whatsappZip`, `localZip`, `localFolder`

### Правовое предупреждение — ✅ ДОБАВЛЕНО
- `StickerImportService.legalDisclaimer` — постоянная строка для UI:
  «Импортируйте только стикеры, для которых вы имеете право использования. Нарушение авторских прав может повлечь юридическую ответственность.»
- Доступно для отображения в любом UI перед импортом

---

## 4. Sticker pack `charo_retro_icq` — ✅ ИСПРАВЛЕНО

### Нарушения (были)
- Папка `charo_retro_icq/` — содержит "icq" в имени
- `manifest.json` — `"id": "charo_retro_icq"`
- `packNames` в sticker_import_service.dart — `'charo_retro_icq'`

### Исправления (выполнено)
- ✅ Папка → `charo_retro/`
- ✅ `manifest.json` — `"id": "charo_retro"`, `"name": "Charo Retro"`
- ✅ `pack.json` — `"id": "charo_retro"`, `"name": "Charo Retro"`
- ✅ `packNames` → `'charo_retro'`

---

## 5. Документация — ✅ ИСПРАВЛЕНО

### README.md — ✅
- "ICQ-звуками" → "Charo-звуками"
- "Звуки ICQ" → "Звуки Charo"
- `icq_*.wav` → `charo_*.wav`
- "ICQ classic + animated" → "Charo classic + animated"
- "Sticker import from Telegram/VK/WhatsApp/Viber" → "Sticker import from local ZIP/folder"

### STORE_DESCRIPTIONS/all_stores.md — ✅
- Удалены все упоминания Telegram/VK/Viber как источников стикеров
- "ICQ-пак" → "Charo-пак"
- "Импорт стикеров из Telegram, VK, WhatsApp, Viber" → "Импорт стикеров из ZIP-архивов и локальных папок"

### CHANGELOG.md — ✅
- "ICQ-style sound pack" → "Charo sound pack"
- "ICQ sounds" → "Charo sounds"

### docs/AUDIT_REPORT_v2.md — ✅
- Все `icq_*.wav` → `charo_*.wav`
- "ICQ emoji pack" → "Charo emoji pack"
- "ICQ-звуки" → "Charo звуки"

### docs/FEATURES.md — ✅
- "ICQ-пак эмодзи" → "Charo-пак эмодзи"
- Удалены "Импорт стикеров из Telegram/VK/Viber" строки
- Добавлены "Импорт стикеров из ZIP-архива" + "Импорт стикеров из локальной папки"

### docs/INTEGRATION_STATUS.md — ✅
- "ICQ sounds" → "Charo sounds"

---

## Сводная таблица IP-аудита

| Элемент | Статус | Действие |
|---------|--------|----------|
| ICQ звуки — файлы | ✅ Исправлено | icq_*.wav → charo_*.wav |
| ICQ эмодзи — паки | ✅ Исправлено | icq_classic → charo_classic |
| ICQ animated — папка/описания | ✅ Исправлено | icq_animated → charo_animated |
| ICQ упоминания в коде | ✅ Исправлено | Все "ICQ" → "Charo" в Dart |
| ICQ в документации | ✅ Исправлено | Все "ICQ" → "Charo" в docs |
| Telegram импорт | ✅ Удалено | Метод + enum value |
| VK импорт | ✅ Удалено | Метод + enum value + helper |
| Viber импорт | ✅ Удалено | Метод + enum value |
| WhatsApp импорт label | ✅ Исправлено | "ZIP-архив (WhatsApp формат)" |
| Sticker pack charo_retro_icq | ✅ Исправлено | → charo_retro |
| loadIcqEmoji() | ✅ Переименован | → loadCharoEmoji() |
| Правовое предупреждение | ✅ Добавлено | StickerImportService.legalDisclaimer |
| StickerImportSource.whatsapp bug | ✅ Исправлено | → StickerImportSource.whatsappZip |
| Dio dependency | ✅ Удалено | Не нужен после удаления API-импорта |

---

## Источники

- [ICQ shutdown & VK ownership](https://www.theverge.com/2024/5/25/24164579/icq-shut-down-june) — The Verge, 2024
- VK Platform Rules §1.6 — vk.com/terms
- Telegram Bot Developer ToS — core.telegram.org/bots/api
- WhatsApp stickers open format — github.com/WhatsApp/stickers
- ICQ ownership chain: Mirabilis → AOL ($287M, 1998) → DST/Mail.ru/VK ($187.5M, 2010) → shutdown 2024
