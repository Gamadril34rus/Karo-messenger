# Changelog — ЧАРО (Charo) Messenger

All notable changes to this project will be documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.1.0] — 2026-07-25

### Added — Premium UI Overhaul
- **CharoWidgets library** (`shared/widgets/charo_widgets.dart`): 8 premium shared widgets
  - `CharoCard` — glassmorphism/gradient card with rounded corners (16px radius), optional gradient background
  - `CharoSection` — grouped settings section with title header and card body, auto-dividers between items
  - `CharoTile` — premium list tile with 40×40 icon container (rounded 12px), proper visual hierarchy
  - `CharoAvatar` — premium avatar with optional shimmer gradient ring, online indicator, edit badge overlay
  - `CharoBadge` — animated unread count badge with scale animation on count change
  - `CharoHeaderCard` — gradient header card for profile/about screens (rounded bottom corners)
  - `CharoSwitchTile` — premium switch tile with icon container
  - `CharoProgressRing` — premium circular progress ring with center label

### Changed — Screen Upgrades
- **Profile Screen**: Full premium redesign
  - Gradient header with avatar (CharoHeaderCard + CharoAvatar with shimmer ring + edit badge)
  - Grouped info sections with CharoSection/CharoTile
  - Premium action buttons (rounded 16px corners, full-width FilledButton)
  - BottomSheet edit dialog with rounded corners instead of AlertDialog
  - Avatar change sheet with premium CharoTile items
- **Settings Main Screen**: Premium grouped layout
  - Profile header card with gradient background and CharoAvatar
  - All sections converted from flat Divider+ListTile → CharoSection+CharoTile
  - Each tile has colored 40×40 icon containers
  - Delete account button with rounded 16px corners
  - Fixed "О Ауре" → "О ЧАРО" (Aura remnant eliminated)
- **Chat List Screen**: Premium redesign
  - Logo header with gradient icon container + premium typography
  - Chat tiles with CharoAvatar (online indicator, pinned shimmer ring)
  - CharoBadge for animated unread count
  - Pinned separator with label
  - New chat bottom sheet with premium CharoTile items
- **Chat Detail Screen**: Premium redesign
  - AppBar with CharoAvatar for chat partner
  - Premium input bar with rounded containers (20px top corners, shadow)
  - Icon buttons in 40×40 rounded containers
  - Animated scale transition on send/mic button swap
  - Attach sheet with rounded icon containers
  - Message actions sheet with CharoTile
- **All Settings Sub-screens**: Converted to CharoSection/CharoTile/CharoSwitchTile
  - Privacy: 6 grouped sections, privacy chips, delete account warning card
  - Notifications: 5 grouped sections with icon containers
  - Network: Proxy config in CharoCard, DoH picker in bottom sheet
  - Storage: CharoProgressRing with gradient header, grouped sections
  - Energy: Power saving card with gradient when active, grouped sections
  - Language: System language in highlighted CharoCard, grouped language tiles
  - Appearance: Theme picker with animated containers, accent colors, text scale demo card, wallpaper grid picker
  - Media Quality: Custom radio circles (not standard RadioListTile), info card
  - About: Gradient header card with logo + shadow, grouped legal/feedback/social sections
- **Login Screen**: Logo gradient container with shadow
- **Register Screen**: Logo gradient container added, fixed "Ауре" → "ЧАРО"
- **Bottom Navigation**: HapticService.selection() on tab switch, shadow decoration
- **HapticService**: Added static convenience methods (selection, lightImpact, mediumImpact, heavyImpact)
- **App Router**: Removed unused flutter_bloc import

### Fixed
- Eliminated "Аура" remnant in `settings_main_screen.dart` (was "О Ауре" → now "О ЧАРО")
- Eliminated "Ауре" remnant in `register_screen.dart` (was "в Ауре" → now "в ЧАРО")
- ChatItem model now includes `isOnline` field for online indicator display

---

## [1.0.0] — 2026-07-24

### Added
- **Flutter client** (40+ Dart files): Full cross-platform UI — Android, iOS, Web, Windows, macOS, Linux
- **BLoC architecture**: ChatDetailBloc, ChatListBloc, AuthBloc, CallsBloc, StoriesBloc, SettingsBloc, ProfileBloc, ContactsBloc, NearbyBloc, AiAssistantBloc
- **Node.js Fastify backend** (20+ TypeScript files): REST API + WebSocket server
- **Prisma ORM** (29 models, 29 @@map): PostgreSQL schema with MLS extensions
- **E2EE Signal Protocol**: Full implementation — E2EEKeyManager with signMessage, encryptText/decryptText, encryptFileData, encryptForDataChannel, encryptForGroup/decryptForGroup, Safety Numbers, key rotation, wipe, Cheval attack protection
- **MLS (Messaging Layer Security)**: GroupContext, MlsWelcomeMessage, RatchetTree, Commit+Proposal — 8 Prisma models, 16 server endpoints
- **WebRTC calls**: AdaptiveQualityManager, WebRtcMonitor, SecureDataChannel, DataChannelService
- **Anti-blocking mechanisms**: DoH, domain fronting, proxy, mirror domains, obfuscation — AntiBlockInterceptor
- **ICQ-style sound pack**: 5 notification sounds (message, send, call, online, system)
- **Haptic feedback service**: Platform-adaptive haptic patterns
- **Notification service**: ICQ sounds + FlutterLocalNotifications + FCM integration
- **File upload service**: E2EE + progress stream + 512KB chunked upload
- **Account deletion**: Full privacy compliance with GDPR/Russian data law
- **Privacy policy**: PRIVACY_POLICY.md
- **Store descriptions**: Google Play, App Store, RuStore — STORE_DESCRIPTIONS/all_stores.md
- **CI/CD**: GitHub Actions (5 jobs + charo-check for legacy name + TODO verification)
- **Docker compose**: charo-postgres, charo-redis, charo-minio, charo-clickhouse, charo-meilisearch, charo-api, charo-nginx
- **Build script**: scripts/build_all.sh — all 6 platforms from one command
- **SBOM**: Full Software Bill of Materials — SBOM.md
- **Documentation**: README, ARCHITECTURE, FEATURES, PRIVACY_POLICY, STORE_DESCRIPTIONS, CONTRIBUTING, LICENSE, AUDIT_REPORT, INTEGRATION_STATUS, CHANGELOG

### Security
- E2EE Signal Protocol + MLS for groups
- WebRTC DataChannel encryption
- Cheval attack protection
- Anti-blocking interceptor (DoH, domain fronting)
- TLS 1.3-only in nginx config
- AGPL-3.0 license for open-source guarantee
- JWT access/refresh token auth
- SecureStorage for key persistence
- Source maps stripped in production Docker build
- No hardcoded secrets in codebase
- Health check endpoints for all services

### Infrastructure
- Multi-stage Docker build with non-root `charo` user
- Nginx reverse proxy with rate limiting (30r/s API, 5r/s upload, 10r/s WS)
- PostgreSQL 16, Redis 7, MinIO, ClickHouse 24, Meilisearch v1.9
- Flutter Web served via nginx SPA routing
- CDN mirror domains configured

### Audit
- 5-pass deep audit completed — 30+ critical issues found and fixed
- 20-point release readiness audit completed — see AUDIT_REPORT_v2.md
- Zero Nexus/Aura remnants
- Zero TODO/FIXME stubs in code
- Zero secret leaks
- YAML/JSON validation passed
- Port conflict resolution (ClickHouse ↔ MinIO)
- LICENSE Nexus remnant fixed → Charo
