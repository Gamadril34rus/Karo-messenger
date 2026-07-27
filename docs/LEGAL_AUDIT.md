# ⚖️ Правовой аудит ЧАРО — Авторизация, восстановление, соответствие законам

**Дата: 27 июля 2026 г.**

---

## Статус: ✅ СООТВЕТСТВУЕТ (с исправлениями)

---

## 1. Регистрация и согласие на обработку данных

### ✅ ФЗ-152 (РФ) — Статья 9
- **Было**: Регистрация не требовала согласия — нарушение ФЗ-152
- **Стало**: Три обязательных чекбокса:
  1. Согласие на обработку персональных данных
  2. Подтверждение возраста 13+
  3. Принятие Условий использования
- Запись в `consent_records` с IP, userAgent, version — юридически значимое доказательство

### ✅ GDPR (ЕС) — Статья 6/7
- Согласие — explicit (не implicit), записано с timestamp и IP
- ConsentRecord хранит версию Policy и Terms — при обновлении политики можно потребовать новое согласие
- Отказ от согласия = отказ от регистрации (не допускается регистрация без consent)

### ✅ CCPA (Калифорния)
- Right to Know: данные экспортируются через `/auth/export-data`
- Right to Delete: `/auth/account` с confirmation + 30-day recovery
- No Sale: в Privacy Policy прямо указано «мы НЕ продаём данные»

---

## 2. Возрастные ограничения

### ✅ COPPA (US) / ФЗ-152
- **Было**: Privacy Policy обещал «13+», но регистрации не было проверки
- **Стало**: `age_confirmed: true` обязателен при регистрации
- В Terms of Service: пункт 2 — «13+», блокировка при обнаружении <13
- OAuth: при OAuth-регистрации `age_confirmed: true` записывается автоматически (OAuth providers проверяют возраст)

---

## 3. Восстановление профиля / аккаунта

### ✅ 30-дневный recovery window
- **Было**: Удаление — сразу soft delete, но нет механизма восстановления
- **Стало**:
  - DELETE `/auth/account` — soft delete + 8-char recovery code + Redis с TTL 30d
  - POST `/auth/recover` — восстановление по account_id + verification_code
  - UI: AccountRecoveryScreen (код, предупреждения)

### ✅ Forgot access / Recovery
- **Было**: Нет механизма — если потерял телефон/email, нет выхода
- **Стало**: POST `/auth/forgot` — recovery через backup identifier
  - Если пользователь указал email при phone-регистрации (или наоборот) — OTP на запасной контакт
  - Anti-enumeration: одинаковый ответ независимо от существования username

### ✅ 2FA Recovery
- При включении 2FA генерируются 8 recovery codes
- Recovery code можно использовать вместо OTP-кода при входе
- Recovery codes хранятся в Redis с TTL 1 год

---

## 4. OTP и brute-force защита

### ✅ Crypto-safe OTP
- **Было**: `Math.floor(Math.random() * 900000)` — NOT cryptographically secure
- **Стало**: `crypto.randomInt(100000, 999999)` — Node.js crypto module

### ✅ Anti brute-force
- OTP verify: 5 attempts за 15 минут, потом lockout
- Password login: 5 attempts за 15 минут, потом lockout
- Rate limit: 1 OTP отправка в минуту (60 сек между resend)

### ✅ Anti-enumeration (user enumeration)
- Login: «Если этот номер/email зарегистрирован, код отправлен» — одинаковый ответ
- Forgot: одинаковый ответ — не раскрывает существование username
- Register: 409 только для username/phone/email (это допустимо — пользователь вводит свои данные)

---

## 5. Экспорт данных (GDPR Art.20, ФЗ-152)

### ✅ GET /auth/export-data
- Профиль: id, username, displayName, bio, phone, email, language, createdAt
- Контакты: userId, displayName, addedAt
- Чаты: id, type, title, role
- Own messages: id, chatId, type, createdAt, isEdited (limit 10000)
- Privacy settings: все поля
- Consent records: type, consentGiven, createdAt
- **Примечание**: E2EE-шифрованное содержимое сообщений не экспортируется из сервера — в export_data прямо указано: «Use local chat export for full message content»

---

## 6. Условия использования (Terms of Service)

### ✅ Создан TERMS_OF_SERVICE.md
17 разделов:
1. Общие положения
2. Возрастные ограничения (13+)
3. Регистрация и авторизация
4. **Восстановление доступа** — 3 способа (backup contact, support, recovery code)
5. Шифрование и безопасность
6. Контент и поведение (zero tolerance CSAM)
7. Авторские права (AGPL-3.0)
8. Удаление аккаунта (30-day recovery)
9. **Право на экспорт данных**
10. Функция «Кто рядом»
11. AI-ассистент
12. Анти-блокировочные механизмы
13. Изменения Условий
14. Ограничение ответственности
15. Разрешение споров
16. **Соответствие законодательству** (ФЗ-152, GDPR, CCPA, ФЗ-149)
17. Контакты

---

## 7. Privacy Policy — обновления

### ✅ Дополнено
- Пункт 4.3: «30-дневный период восстановления после удаления»
- Пункт 8: Recovery window описан
- Пункт 9: Data export endpoint описан

---

## 8. Правоохранительные запросы

### ✅ Указано в Privacy Policy
- Только при наличии юридически значимого документа
- Уведомление пользователя (если не запрещено законом)
- **Для E2EE-шифрованных чатов — сервер НЕ МОЖЕТ предоставить содержание**
- Это прямо защищает ЧАРО от требования «предоставить ключи шифрования» — ключи на устройствах, не на сервере

### ⚠️ Риск: ФЗ-149 (РСН)
- Роскомнадзор может требовать удаления «запрещённой информации»
- ЧАРО обязан удалить конкретный контент по требованию — но НЕ может расшифровать E2EE сообщения
- В Terms of Service пункт 16.4 прямо указывает: удаление по требованию Роскомнадзора

---

## 9. SMS/email — законность отправки

### ✅ SMSAero (РФ)
- SMSAero — российский SMS-провайдер, работает по ФЗ-152
- SMS содержит «Не сообщайте код третьим лицам» — требование ФЗ-152

### ✅ Twilio (International)
- Twilio — международный, GDPR compliant
- SMS одинакового формата

### ✅ Resend/SendGrid (Email)
- Email содержит: OTP, срок действия, предупреждение «не сообщайте»
- Email содержит «Если вы не запрашивали код — проигнорируйте» — anti-phishing

---

## 10. AGPL-3.0 Лицензия

### ✅ Сетевой сервис
- ЧАРО под AGPL-3.0 — любой, кто модифицирует и запускает как сетевой сервис, обязан предоставить исходный код
- В LICENSE прямо указано: «ЧАРО останется открытым»

---

## 11. Данные на территории РФ (ФЗ-152)

### ✅ Указано в Privacy Policy
- «Данные российских пользователей хранятся на территории РФ»
- В .env.example нет указания серверов РФ — нужно добавить Russian server config

### ⚠️ TODO: Добавить русский регион в docker-compose
- Текущий docker-compose.yml не указывает российский сервер
- Для реальной проды: нужен отдельный instance для РФ или federation

---

## 12. AI-ассистент — правовые аспекты

### ✅ GDPR compliance
- Запросы к AI — «без привязки к личности» (anonymised)
- Диалоги AI — «не используются для обучения моделей»
- AI можно полностью отключить
- AI disclaimer: «не заменяет профессиональные консультации»

### ✅ ФЗ-149
- AI может генерировать контент — ответственность за контент лежит на пользователе
- В Terms 6.1: «Вы несёте ответственность за содержание своих сообщений»

---

## Сводная таблица соответствия

| Закон | Статья/Пункт | Статус | Реализация |
|-------|-------------|--------|------------|
| ФЗ-152 | Art.6 (Consent) | ✅ | consent_records table, 3 checkboxes |
| ФЗ-152 | Art.9 (Written consent) | ✅ | IP+UA+version logged |
| ФЗ-152 | Art.9 (Withdraw) | ✅ | DELETE account |
| ФЗ-152 | Art.14 (Data on RF territory) | ⚠️ | Policy says yes, infra needs Russian server |
| ФЗ-152 | Art.21 (Right to delete) | ✅ | DELETE /auth/account + 30-day recovery |
| ФЗ-149 | Blocked content | ✅ | Terms 16.4 |
| GDPR | Art.6 (Lawful basis) | ✅ | Explicit consent |
| GDPR | Art.7 (Consent conditions) | ✅ | ConsentRecord, withdrawable |
| GDPR | Art.17 (Right to erasure) | ✅ | Delete + 30-day then hard delete |
| GDPR | Art.20 (Data portability) | ✅ | GET /auth/export-data (JSON) |
| GDPR | Art.13 (Information) | ✅ | Privacy Policy + Terms |
| CCPA | Right to Know | ✅ | Data export |
| CCPA | Right to Delete | ✅ | Account deletion |
| CCPA | Right to Opt-Out of Sale | ✅ | We don't sell data |
| COPPA | Under 13 | ✅ | Age checkbox + auto-block |

---

## Остаточные риски

1. **ФЗ-152 Data Localization**: Политика говорит «данные на территории РФ», но infra пока не содержит российского сервера. **Fix**: Добавить docker-compose регион РФ или federation.
2. **E2EE vs Law Enforcement**: Сервер не может предоставить E2EE контент. Это правовая защита, но может вызвать pressure от властей.
3. **CSAM Detection**: В Terms указан zero tolerance, но **нет автоматического сканирования**. Для production нужен PhotoDNA/ML detection pipeline.
4. **Privacy Policy PGP key**: Сказано «ссылка на публичный ключ» — ещё не создан. **Fix**: Генерировать PGP ключ и опубликовать.
5. **DPO**: Privacy Policy говорит «DPO назначен» — для production нужен реальный DPO.
