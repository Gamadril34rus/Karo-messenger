import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'local_db.g.dart';

/// Локальная база данных (Drift/SQLite) — кэш сообщений и чатов
@DriftDatabase(tables: [
  LocalChats,
  LocalMessages,
  LocalUsers,
  LocalContacts,
  LocalMedia,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'charo_messenger'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      // Будущие миграции
    },
  );

  // ─── Chats ──────────────────────────────────────────────────────

  Future<List<LocalChat>> getAllChats() => select(localChats).get();

  Stream<List<LocalChat>> watchAllChats() {
    final query = select(localChats)
      ..orderBy([
        (t) => OrderingTerm.desc(t.updatedAt),
      ]);
    return query.watch();
  }

  Future<void> insertChat(LocalChatsCompanion chat) =>
      into(localChats).insertOnConflictUpdate(chat);

  Future<void> deleteChat(String id) =>
      (delete(localChats)..where((t) => t.id.equals(id))).go();

  // ─── Messages ───────────────────────────────────────────────────

  Stream<List<LocalMessage>> watchMessages(String chatId) {
    final query = select(localMessages)
      ..where((t) => t.chatId.equals(chatId))
      ..orderBy([
        (t) => OrderingTerm.asc(t.createdAt),
      ]);
    return query.watch();
  }

  Future<void> insertMessage(LocalMessagesCompanion message) =>
      into(localMessages).insertOnConflictUpdate(message);

  Future<void> markMessageRead(String id) =>
      (update(localMessages)..where((t) => t.id.equals(id))).write(
        const LocalMessagesCompanion(isRead: Value(true)),
      );

  // ─── Users ──────────────────────────────────────────────────────

  Future<void> upsertUser(LocalUsersCompanion user) =>
      into(localUsers).insertOnConflictUpdate(user);

  // ─── Очистка ────────────────────────────────────────────────────

  Future<void> clearAll() async {
    await delete(localChats).go();
    await delete(localMessages).go();
    await delete(localUsers).go();
    await delete(localContacts).go();
    await delete(localMedia).go();
  }
}

// ─── Таблицы ───────────────────────────────────────────────────────

class LocalChats extends Table {
  TextColumn get id => text()();
  TextColumn get type => text().withDefault(const Constant('private'))();
  TextColumn get title => text().nullable()();
  TextColumn get avatarUrl => text().nullable()();
  TextColumn get lastMessage => text().nullable()();
  TextColumn get lastMessageSender => text().nullable()();
  DateTimeColumn get lastMessageAt => dateTime().nullable()();
  IntColumn get unreadCount => integer().withDefault(const Constant(0))();
  BoolColumn get isMuted => boolean().withDefault(const Constant(false))();
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalMessages extends Table {
  TextColumn get id => text()();
  TextColumn get chatId => text()();
  TextColumn get senderId => text()();
  TextColumn get type => text()();
  TextColumn get content => text().nullable()();
  TextColumn get replyToId => text().nullable()();
  BoolColumn get isEdited => boolean().withDefault(const Constant(false))();
  BoolColumn get isRead => boolean().withDefault(const Constant(false))();
  TextColumn get status => text().withDefault(const Constant('sent'))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalUsers extends Table {
  TextColumn get id => text()();
  TextColumn get username => text()();
  TextColumn get displayName => text().nullable()();
  TextColumn get avatarUrl => text().nullable()();
  TextColumn get bio => text().nullable()();
  BoolColumn get isOnline => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastSeen => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalContacts extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get contactUserId => text()();
  TextColumn get displayName => text().nullable()();
  BoolColumn get isBlocked => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalMedia extends Table {
  TextColumn get id => text()();
  TextColumn get messageId => text().nullable()();
  TextColumn get type => text()();
  TextColumn get url => text()();
  TextColumn get localPath => text().nullable()();
  TextColumn get thumbnailUrl => text().nullable()();
  IntColumn get sizeBytes => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
