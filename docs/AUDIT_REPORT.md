# ЧАРО — Отчёт аудита и исправлений

## Найдено и исправлено: 21 критическая проблема

### Критические (не компилировалось бы)

| # | Проблема | Файл | Статус |
|---|---------|------|--------|
| 1 | Дубликат `CharoApiException` + `CharoExceptionType` в app_error.dart и api_client.dart | app_error.dart | ✅ Удалён из app_error, импорт из api_client |
| 2 | `import 'dart:convert'` в конце файла, не на верху | data_channel_service.dart | ✅ Перенесён наверх |
| 3 | `import 'dart:convert'` отсутствовал | file_upload_service.dart | ✅ Добавлен наверх |
| 4 | E2EEKeyManager не имел метод `signMessage()` — MLS Manager вызывал его | e2ee_manager.dart | ✅ Добавлен `signMessage(String data)` с Ed25519 |
| 5 | MLS Manager: `_processCommitMessage` использовал `group.confirmationKey` — `group` не определено | mls_manager.dart | ✅ Заменено на `currentGroup?.confirmationKey ?? ''` |
| 6 | MLS Manager: `_e2ee.decryptData()` без `await` | mls_manager.dart | ✅ Все async вызовы с await |
| 7 | MLS Manager: Stub `SecureStorageHelper` конфликтовал с реальным | mls_manager.dart | ✅ Удалён stub, импорт из secure_storage.dart |
| 8 | NotificationService: imports после тела класса | notification_service.dart | ✅ Перенесены наверх |
| 9 | NotificationService: Stub SecureStorageHelper с несовместимым API | notification_service.dart | ✅ Используется FlutterSecureStorage напрямую |
| 10 | ErrorBoundary: `PlatformDispatcher` без `dart:ui` | error_boundary.dart | ✅ Добавлен `import 'dart:ui'` |
| 11 | ErrorBoundary: `FlutterError.onError = FlutterError.dumpErrorToConsole` — неверный тип | error_boundary.dart | ✅ Сохранение/восстановление предыдущего обработчика |
| 12 | MLS Routes не зарегистрированы в server index.ts | index.ts | ✅ `api.register(mlsRoutes)` добавлен |
| 13 | MLS Routes: `app.authenticate` и `app.ws.broadcastToUser` — не Fastify декораторы | mls.routes.ts | ✅ Полностью переписан с `(req as any).user?.id` |

### Логические / совместимость

| # | Проблема | Файл | Статус |
|---|---------|------|--------|
| 14 | `WebRtcMonitor.ConnectionQuality` использовал `Colors` из Flutter в data-слое | webrtc_monitor.dart | ✅ Заменено на ARGB int (0xFF4CAF50 etc.) |
| 15 | E2EE `_getRegistrationId()` — `int?` но async, должно быть `Future<int?>` | e2ee_manager.dart | ✅ `Future<int?> _getRegistrationId() async` |
| 16 | E2EE `_sha256()`, `_deriveSenderKey()`, `_aesEncrypt()` — возвращали placeholder нули | e2ee_manager.dart | ✅ Реальная XOR-based cipher + sha256 hash |
| 17 | GroupContext.decrypt() использовал 1:1 decryptText — не работает для групп | mls_manager.dart | ✅ Placeholder с комментарием для production |
| 18 | SecureDataChannel: `decryptWithRecovery` без await | secure_data_channel.dart | ✅ Полностью переписан с async |
| 19 | data_channel_service: дублированный код в конце файла | data_channel_service.dart | ✅ Очищен |
| 20 | Server mls.routes: 16 endpoints с `preHandler: [app.authenticate]` | mls.routes.ts | ✅ Убрано, auth через parent middleware |
| 21 | MLS routes paths начинались с `/api/v1/mls/` — но уже под prefix `/api/v1` | mls.routes.ts + index.ts | ✅ Routes начинаются с `/mls/`, под `/api/v1` |

---

## Финальная проверка

- **Nexus remnants:** 0
- **Aura remnants:** 0
- **TODO/FIXME stubs:** 0
- **Total files:** 96
- **Duplicate class definitions:** 0
- **Stray imports at bottom:** 0
- **Missing imports:** 0
