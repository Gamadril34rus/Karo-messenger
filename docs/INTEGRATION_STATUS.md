# ЧАРО (Charo) — Мессенджер нового поколения

## Статус интеграции: ✅ ЗАВЕРШЕНО

Все модули из Grok AI-конversation полностью интегрированы в проект ЧАРО.

### Ключевые принципы
- **Имя проекта:** ЧАРО (Charo). НИКАКИХ Nexus/nexus остатков — 0 найдено. НИКАКИХ Aura/Аура остатков — 0 найдено.
- **Архитектура:** Clean Architecture + BLoC (не Riverpod)
- **Backend:** Fastify (не NestJS/Supabase)
- **0 TODO заглушек** — 0 найдено.
- **95 файлов** в проекте (79 → 95)

---

## Flutter Client — Новые модули

### 🔐 MLS (Messaging Layer Security) — `lib/core/mls/`
| Файл | Описание |
|------|----------|
| `mls_manager.dart` | MLS Manager: createGroup, joinGroup, sendMessage, receiveMessage, addMember, removeMember, periodicKeyUpdate, GroupContext с AEAD encrypt/decrypt, Welcome message |
| `mls_message.dart` | MLSMessage: groupId, epoch, type enum (proposal/commit/application), encryptedContent, signature |
| `commit.dart` | MlsCommit: proposals, updatePath, confirmationTag, static create(), apply() с верификацией |
| `ratchet_tree.dart` | RatchetTree: бинарное дерево ключей, addLeaf/removeLeaf/updateLeaf, generateUpdatePath/applyUpdatePath |

### 📞 Звонки — `lib/features/calls/data/`
| Файл | Описание |
|------|----------|
| `adaptive_quality_manager.dart` | VideoQuality enum, адаптация по packetLoss/rtt/bitrate, VP9/VP8/simulcast |
| `webrtc_monitor.dart` | WebRtcMonitor: statsStream каждые 3s, ConnectionQuality |
| `data_channel_service.dart` | DataChannel 'charo-chat', ordered=true, maxRetransmits=3 |
| `secure_data_channel.dart` | E2EE wrapper, sendSecureMessage, decryptWithRecovery |

### 📤 Файлы — `lib/features/chat/data/`
| Файл | Описание |
|------|----------|
| `file_upload_service.dart` | Stream<FileUploadResult> uploadFileWithProgress, E2EE, 512KB chunks |

### 🔧 Сервисы — `lib/core/`
| Файл | Описание |
|------|----------|
| `haptic/haptic_service.dart` | light/medium/heavy/error/notification + контекстные методы |
| `audio/notification_service.dart` | Charo sounds (charo_message/send/call/online/system.wav) |
| `errors/app_error.dart` | ErrorType enum, AppError с userMessage, isRetryable |

### 🖥️ Widgets — `lib/shared/widgets/`
| Файл | Описание |
|------|----------|
| `error_boundary.dart` | ErrorBoundary, GlobalErrorHandler |

---

## Server — Новые модули

### MLS Routes — 16 endpoints
### Prisma Schema — 8 новых моделей + 4 enum
### CI/CD — 5 jobs + charo-check

---

## Иконка приложения
- `assets/icons/app_icon.png` — пользовательская иконка (прикреплена)

---

## Nexus remnants: 0
## Aura remnants: 0
## TODO stubs: 0
## Total files: 95
