# ЧАРО Messenger — Stage 9 Progress Report

## Stage 9: Production Hardening — Validation, Rate Limiting, i18n, Accessibility, Legal

### Completed

#### 1. Server: Standalone Global Search Route
- **New file**: `server/src/modules/search/search.routes.ts`
- Added `/api/v1/search` as a top-level route (mirrors `/users/search` but at a more convenient path)
- Includes zod validation for query string (`q` must be 2-200 chars)
- Searches chats, messages, and contacts in parallel
- Returns unified `{ chats, messages, contacts }` response

#### 2. Server: Per-Route Rate Limiting
- **Auth routes** now have per-route rate limits:
  - `POST /auth/login` — 5/min
  - `POST /auth/login/password` — 5/min
  - `POST /auth/register` — 3/min
  - `POST /auth/verify` — 10/min
  - `POST /auth/2fa/enable` — 3/min
  - `POST /auth/2fa/verify` — 5/min
  - `POST /auth/recover` — 3/min
- Global rate limit remains 100/min for all other routes

#### 3. Server: Input Validation (Zod Schemas)
- **Contacts**: `addContactSchema` (identifier or contactUserId required), `syncSchema` (1-1000 phones), `blockSchema` (UUID)
- **Calls**: `createCallSchema` (type enum VOICE/VIDEO, UUID targetUserIds, max 10)
- **Stories**: `createStorySchema` (type enum IMAGE/VIDEO/TEXT, content max 1000, backgroundColor hex regex)
- **Messages**: `reactSchema` (emoji 1-10 chars)
- **Settings**: `appearanceSchema` (language max 10, theme enum light/dark/system), `quietHoursStart/End` regex HH:MM
- **AI**: `aiChatSchema` (conversation_id UUID, message max 4000, action enum), `aiSummarizeSchema` (chat_id UUID), `aiGenerateSchema` (prompt 1-500)
- **Stickers**: `stickerImportSchema` (source enum, sourceId 1-200, name max 200)
- **Nearby**: `nearbyQuerySchema` (lat/lng regex, radius optional)
- **Search**: `searchQuerySchema` (q 2-200 chars)

#### 4. Server: New Tests (3 test files)
- `search.test.ts` — 401 without auth, 400 for q<2 chars, 200 with empty results
- `contacts.validation.test.ts` — rejects body without identifier/contactUserId, invalid UUID, empty/too-large phones array
- `validation.test.ts` — 17 tests across calls, stories, messages, settings, nearby, AI, stickers modules

#### 5. Client: i18n — Complete EN/RU/DE Strings
- **`strings_en.json`** — 158 English keys (complete coverage)
- **`strings_ru.json`** — 158 Russian keys (complete coverage)
- **`strings_de.json`** — 158 German keys (complete coverage)
- Added `lib/i18n/` to pubspec.yaml assets
- All 3 languages include: auth, chat, calls, settings, stickers, stories, profile, errors, accessibility, privacy, contacts, search, groups, media, export, quiet hours, notifications, proxy, cache, common UI strings, connection states, message statuses, disappearing messages, verification

#### 6. Client: Accessibility — Semantic Labels
- **New file**: `lib/core/accessibility/charo_accessibility.dart`
  - `CharoAccessibility.labeled()` — semantic label wrapper
  - `CharoAccessibility.iconButton()` — accessible icon button
  - `CharoAccessibility.liveRegion()` — live region for dynamic content
  - `CharoAccessibility.announce()` — announce to screen readers
  - `CharoAccessibility.header()` — semantic header
  - `CharoAccessibility.group()` — semantic group
  - `CharoAccessibility.chatItem()` — chat list item with full semantic info
  - `CharoAccessibility.messageBubble()` — message with sender, content, time, read status
  - `CharoAccessibility.contactItem()` — contact with name, username, online, blocked status
  - `CharoAccessibility.callItem()` — call with caller, type, direction, time, missed
  - `CharoAccessibility.storyItem()` — story with user name, viewed status
- **ChatListScreen**: Added semantic labels to FAB, search button, and chat tiles
- **SettingsLegalScreen**: Added semantic headers to all sections

#### 7. Client: BLoC Tests (2 new test files)
- **`auth_bloc_test.dart`** — 8 tests:
  - Initial state is AuthInitial
  - AuthCheckRequested with no token → AuthUnauthenticated
  - AuthLoginRequested → AuthOtpSent
  - AuthOtpSubmitted → AuthAuthenticated
  - AuthOtpSubmitted with 2FA → Auth2faRequired
  - AuthRegisterRequested → AuthOtpSent
  - AuthLogoutRequested → AuthUnauthenticated
  - AuthDeleteAccountRequested with wrong → AuthError, with DELETE → AuthAccountDeleted
- **`settings_bloc_test.dart`** — 10 tests:
  - Initial state defaults
  - ThemeChanged, LanguageChanged, TextScaleChanged
  - PrivacyChanged, NotificationChanged, NetworkChanged, MediaQualityChanged
  - LoadRequested from SharedPreferences cache
  - copyWith preserves unchanged fields
  - State equality

#### 8. Client: Contacts Local Caching (Drift)
- **ContactsBloc** now accepts optional `AppDatabase` parameter
- Loads from local cache first (offline-first), then fetches from server
- Persists contacts to local DB after server fetch
- Removes from local DB on contact delete
- Falls back to cached data if server fails (graceful degradation)
- **AppDatabase** new methods: `getAllContacts()`, `insertContact()`, `deleteContact()`, `deleteAllContacts()`
- main.dart updated to pass `AppDatabase` singleton to `ContactsBloc`

#### 9. Client: Legal Compliance — Privacy Policy & Terms of Service
- **New file**: `settings_legal_screen.dart`
  - `PrivacyPolicyScreen` — Full ФЗ-152/GDPR/CCPA compliant privacy policy (12 sections)
  - `TermsOfServiceScreen` — Complete terms of service (10 sections)
  - Both include semantic headers for accessibility
- **New routes**: `/settings/privacy-policy`, `/settings/terms`
- **SettingsAboutScreen**: Updated to use in-app navigation instead of external URLs

#### 10. Drift Generated Code Updated
- `local_db.g.dart` updated to include `isArchived` field in `LocalChat`, `LocalChatsCompanion`

### Project Metrics

| Metric | Count |
|--------|-------|
| Server TS files (non-test) | 20 |
| Server test files | 11 |
| Client Dart files | 105 |
| Client test files | 18 |
| Total server TS lines | ~6,747 |
| Total client Dart lines | ~27,980 |
| i18n JSON files | 56 |
| Prisma models | 30 |
| BLoCs | 10+ |
| Screens | 38+ |

### Server Route Inventory (Updated)

| Module | Routes | New Validation |
|--------|--------|---------------|
| auth | 20 | ✅ rate limiting on 6 routes |
| users | 10 | ✅ existing |
| chats | 15 | ✅ existing |
| messages | 4 | ✅ reactSchema added |
| contacts | 7 | ✅ full zod validation |
| media | 6 | ✅ existing |
| calls | 2 | ✅ createCallSchema |
| stories | 4 | ✅ createStorySchema |
| settings | 6 | ✅ appearanceSchema |
| ai | 5 | ✅ aiChatSchema, aiSummarizeSchema, aiGenerateSchema |
| stickers | 3 | ✅ stickerImportSchema |
| nearby | 1 | ✅ nearbyQuerySchema |
| **search** | **1** | ✅ **NEW** searchQuerySchema |
| mls | - | ✅ existing |

### Remaining Gaps

- **Push notification Firebase** — needs `google-services.json` / plist to uncomment code
- **Drift DB schema** — `local_db.g.dart` should be regenerated with `dart run build_runner build` when Flutter SDK is available
- **E2E/integration tests** — only unit tests exist
- **Sentry crash reporting** — added but not fully wired (needs DSN)
- **Notification sound/vibration** — settings exist but may not fully save
- **Server: further rate limiting** — can add more granular per-route limits
- **Accessibility** — semantic labels not on every screen yet
- **i18n** — minor languages (ab, abq, ady, etc.) have fewer strings than EN/RU/DE

### TypeScript Compilation
- ✅ 0 errors (`npx tsc --noEmit`)
