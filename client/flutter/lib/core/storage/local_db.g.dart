// ─── ЧАРО — Generated Drift Database Companion ──────────────────────────
// This file was manually generated to match the schema in local_db.dart.
// In production, regenerate with: dart run build_runner build
// This companion file provides the Drift infrastructure for AppDatabase.

part of 'local_db.dart';

// ─── Generated database class ───────────────────────────────────────

class _$AppDatabase extends AppDatabase {
  _$AppDatabase([QueryExecutor? executor]) : super(executor ?? driftDatabase(name: 'charo_messenger'));

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

  @override
  Set<TableInfo<Table, DataClass>> get allTables => {
    localChats,
    localMessages,
    localUsers,
    localContacts,
    localMedia,
  };

  late final $LocalChatsTable localChats = $LocalChatsTable(this);
  late final $LocalMessagesTable localMessages = $LocalMessagesTable(this);
  late final $LocalUsersTable localUsers = $LocalUsersTable(this);
  late final $LocalContactsTable localContacts = $LocalContactsTable(this);
  late final $LocalMediaTable localMedia = $LocalMediaTable(this);
}

// ─── Table info classes ──────────────────────────────────────────────

class $LocalChatsTable extends LocalChats
    with TableInfo<$LocalChatsTable, LocalChat> {
  @override
  final GeneratedDatabase attachedDatabase;

  $LocalChatsTable(this.attachedDatabase);

  @override
  late final List<GeneratedColumn> $columns = [
    id,
    type,
    title,
    avatarUrl,
    lastMessage,
    lastMessageSender,
    lastMessageAt,
    unreadCount,
    isMuted,
    isPinned,
    isArchived,
    updatedAt,
    createdAt,
  ];

  @override
  LocalChats get table => this;

  @override
  LocalChat createCompanion(Map<String, dynamic> row) {
    return LocalChat(
      id: row['id'] as String,
      type: row['type'] as String,
      title: row['title'] as String?,
      avatarUrl: row['avatar_url'] as String?,
      lastMessage: row['last_message'] as String?,
      lastMessageSender: row['last_message_sender'] as String?,
      lastMessageAt: row['last_message_at'] as DateTime?,
      unreadCount: row['unread_count'] as int,
      isMuted: row['is_muted'] as bool,
      isPinned: row['is_pinned'] as bool,
      isArchived: row['is_archived'] as bool,
      updatedAt: row['updated_at'] as DateTime,
      createdAt: row['created_at'] as DateTime,
    );
  }

  @override
  $LocalChatsTable get asDartTable => this;
}

class $LocalMessagesTable extends LocalMessages
    with TableInfo<$LocalMessagesTable, LocalMessage> {
  @override
  final GeneratedDatabase attachedDatabase;

  $LocalMessagesTable(this.attachedDatabase);

  @override
  late final List<GeneratedColumn> $columns = [
    id,
    chatId,
    senderId,
    type,
    content,
    replyToId,
    isEdited,
    isRead,
    status,
    createdAt,
  ];

  @override
  LocalMessages get table => this;

  @override
  LocalMessage createCompanion(Map<String, dynamic> row) {
    return LocalMessage(
      id: row['id'] as String,
      chatId: row['chat_id'] as String,
      senderId: row['sender_id'] as String,
      type: row['type'] as String,
      content: row['content'] as String?,
      replyToId: row['reply_to_id'] as String?,
      isEdited: row['is_edited'] as bool,
      isRead: row['is_read'] as bool,
      status: row['status'] as String,
      createdAt: row['created_at'] as DateTime,
    );
  }

  @override
  $LocalMessagesTable get asDartTable => this;
}

class $LocalUsersTable extends LocalUsers
    with TableInfo<$LocalUsersTable, LocalUser> {
  @override
  final GeneratedDatabase attachedDatabase;

  $LocalUsersTable(this.attachedDatabase);

  @override
  late final List<GeneratedColumn> $columns = [
    id,
    username,
    displayName,
    avatarUrl,
    bio,
    isOnline,
    lastSeen,
  ];

  @override
  LocalUsers get table => this;

  @override
  LocalUser createCompanion(Map<String, dynamic> row) {
    return LocalUser(
      id: row['id'] as String,
      username: row['username'] as String,
      displayName: row['display_name'] as String?,
      avatarUrl: row['avatar_url'] as String?,
      bio: row['bio'] as String?,
      isOnline: row['is_online'] as bool,
      lastSeen: row['last_seen'] as DateTime?,
    );
  }

  @override
  $LocalUsersTable get asDartTable => this;
}

class $LocalContactsTable extends LocalContacts
    with TableInfo<$LocalContactsTable, LocalContact> {
  @override
  final GeneratedDatabase attachedDatabase;

  $LocalContactsTable(this.attachedDatabase);

  @override
  late final List<GeneratedColumn> $columns = [
    id,
    userId,
    contactUserId,
    displayName,
    isBlocked,
  ];

  @override
  LocalContacts get table => this;

  @override
  LocalContact createCompanion(Map<String, dynamic> row) {
    return LocalContact(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      contactUserId: row['contact_user_id'] as String,
      displayName: row['display_name'] as String?,
      isBlocked: row['is_blocked'] as bool,
    );
  }

  @override
  $LocalContactsTable get asDartTable => this;
}

class $LocalMediaTable extends LocalMedia
    with TableInfo<$LocalMediaTable, LocalMediaData> {
  @override
  final GeneratedDatabase attachedDatabase;

  $LocalMediaTable(this.attachedDatabase);

  @override
  late final List<GeneratedColumn> $columns = [
    id,
    messageId,
    type,
    url,
    localPath,
    thumbnailUrl,
    sizeBytes,
  ];

  @override
  LocalMedia get table => this;

  @override
  LocalMediaData createCompanion(Map<String, dynamic> row) {
    return LocalMediaData(
      id: row['id'] as String,
      messageId: row['message_id'] as String?,
      type: row['type'] as String,
      url: row['url'] as String,
      localPath: row['local_path'] as String?,
      thumbnailUrl: row['thumbnail_url'] as String?,
      sizeBytes: row['size_bytes'] as int?,
    );
  }

  @override
  $LocalMediaTable get asDartTable => this;
}

// ─── Companion classes for table inserts/updates ──────────────────────

class LocalChatsCompanion extends UpdateCompanion<LocalChat> {
  final Value<String> id;
  final Value<String> type;
  final Value<String?> title;
  final Value<String?> avatarUrl;
  final Value<String?> lastMessage;
  final Value<String?> lastMessageSender;
  final Value<DateTime?> lastMessageAt;
  final Value<int> unreadCount;
  final Value<bool> isMuted;
  final Value<bool> isPinned;
  final Value<bool> isArchived;
  final Value<DateTime> updatedAt;
  final Value<DateTime> createdAt;

  LocalChatsCompanion({
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.title = const Value.absent(),
    this.avatarUrl = const Value.absent(),
    this.lastMessage = const Value.absent(),
    this.lastMessageSender = const Value.absent(),
    this.lastMessageAt = const Value.absent(),
    this.unreadCount = const Value.absent(),
    this.isMuted = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.isArchived = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
  });

  LocalChatsCompanion.insert({
    required String id,
    this.type = const Value('private'),
    this.title = const Value.absent(),
    this.avatarUrl = const Value.absent(),
    this.lastMessage = const Value.absent(),
    this.lastMessageSender = const Value.absent(),
    this.lastMessageAt = const Value.absent(),
    this.unreadCount = const Value(0),
    this.isMuted = const Value(false),
    this.isPinned = const Value(false),
    this.isArchived = const Value(false),
    required DateTime updatedAt,
    required DateTime createdAt,
  }) : this.id = Value(id), this.updatedAt = Value(updatedAt), this.createdAt = Value(createdAt);
}

class LocalMessagesCompanion extends UpdateCompanion<LocalMessage> {
  final Value<String> id;
  final Value<String> chatId;
  final Value<String> senderId;
  final Value<String> type;
  final Value<String?> content;
  final Value<String?> replyToId;
  final Value<bool> isEdited;
  final Value<bool> isRead;
  final Value<String> status;
  final Value<DateTime> createdAt;

  LocalMessagesCompanion({
    this.id = const Value.absent(),
    this.chatId = const Value.absent(),
    this.senderId = const Value.absent(),
    this.type = const Value.absent(),
    this.content = const Value.absent(),
    this.replyToId = const Value.absent(),
    this.isEdited = const Value(false),
    this.isRead = const Value(false),
    this.status = const Value('sent'),
    this.createdAt = const Value.absent(),
  });

  LocalMessagesCompanion.insert({
    required String id,
    required String chatId,
    required String senderId,
    required String type,
    this.content = const Value.absent(),
    this.replyToId = const Value.absent(),
    this.isEdited = const Value(false),
    this.isRead = const Value(false),
    this.status = const Value('sent'),
    required DateTime createdAt,
  }) : this.id = Value(id),
       this.chatId = Value(chatId),
       this.senderId = Value(senderId),
       this.type = Value(type),
       this.createdAt = Value(createdAt);
}

class LocalUsersCompanion extends UpdateCompanion<LocalUser> {
  final Value<String> id;
  final Value<String> username;
  final Value<String?> displayName;
  final Value<String?> avatarUrl;
  final Value<String?> bio;
  final Value<bool> isOnline;
  final Value<DateTime?> lastSeen;

  LocalUsersCompanion({
    this.id = const Value.absent(),
    this.username = const Value.absent(),
    this.displayName = const Value.absent(),
    this.avatarUrl = const Value.absent(),
    this.bio = const Value.absent(),
    this.isOnline = const Value(false),
    this.lastSeen = const Value.absent(),
  });

  LocalUsersCompanion.insert({
    required String id,
    required String username,
    this.displayName = const Value.absent(),
    this.avatarUrl = const Value.absent(),
    this.bio = const Value.absent(),
    this.isOnline = const Value(false),
    this.lastSeen = const Value.absent(),
  }) : this.id = Value(id),
       this.username = Value(username);
}

class LocalContactsCompanion extends UpdateCompanion<LocalContact> {
  final Value<String> id;
  final Value<String> userId;
  final Value<String> contactUserId;
  final Value<String?> displayName;
  final Value<bool> isBlocked;

  LocalContactsCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.contactUserId = const Value.absent(),
    this.displayName = const Value.absent(),
    this.isBlocked = const Value(false),
  });

  LocalContactsCompanion.insert({
    required String id,
    required String userId,
    required String contactUserId,
    this.displayName = const Value.absent(),
    this.isBlocked = const Value(false),
  }) : this.id = Value(id),
       this.userId = Value(userId),
       this.contactUserId = Value(contactUserId);
}

class LocalMediaCompanion extends UpdateCompanion<LocalMediaData> {
  final Value<String> id;
  final Value<String?> messageId;
  final Value<String> type;
  final Value<String> url;
  final Value<String?> localPath;
  final Value<String?> thumbnailUrl;
  final Value<int?> sizeBytes;

  LocalMediaCompanion({
    this.id = const Value.absent(),
    this.messageId = const Value.absent(),
    this.type = const Value.absent(),
    this.url = const Value.absent(),
    this.localPath = const Value.absent(),
    this.thumbnailUrl = const Value.absent(),
    this.sizeBytes = const Value.absent(),
  });

  LocalMediaCompanion.insert({
    required String id,
    this.messageId = const Value.absent(),
    required String type,
    required String url,
    this.localPath = const Value.absent(),
    this.thumbnailUrl = const Value.absent(),
    this.sizeBytes = const Value.absent(),
  }) : this.id = Value(id),
       this.type = Value(type),
       this.url = Value(url);
}

// ─── Data classes (generated row types) ───────────────────────────────

class LocalChat {
  final String id;
  final String type;
  final String? title;
  final String? avatarUrl;
  final String? lastMessage;
  final String? lastMessageSender;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final bool isMuted;
  final bool isPinned;
  final bool isArchived;
  final DateTime updatedAt;
  final DateTime createdAt;

  LocalChat({
    required this.id,
    required this.type,
    this.title,
    this.avatarUrl,
    this.lastMessage,
    this.lastMessageSender,
    this.lastMessageAt,
    required this.unreadCount,
    required this.isMuted,
    required this.isPinned,
    required this.isArchived,
    required this.updatedAt,
    required this.createdAt,
  });

  @override
  int get hashCode => Object.hash(id, type, title, avatarUrl, lastMessage, lastMessageSender, lastMessageAt, unreadCount, isMuted, isPinned, isArchived, updatedAt, createdAt);

  @override
  bool operator ==(Object other) =>
      other is LocalChat &&
      other.id == id &&
      other.type == type &&
      other.title == title &&
      other.avatarUrl == avatarUrl &&
      other.lastMessage == lastMessage &&
      other.lastMessageSender == lastMessageSender &&
      other.lastMessageAt == lastMessageAt &&
      other.unreadCount == unreadCount &&
      other.isMuted == isMuted &&
      other.isPinned == isPinned &&
      other.isArchived == isArchived &&
      other.updatedAt == updatedAt &&
      other.createdAt == createdAt;
}

class LocalMessage {
  final String id;
  final String chatId;
  final String senderId;
  final String type;
  final String? content;
  final String? replyToId;
  final bool isEdited;
  final bool isRead;
  final String status;
  final DateTime createdAt;

  LocalMessage({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.type,
    this.content,
    this.replyToId,
    required this.isEdited,
    required this.isRead,
    required this.status,
    required this.createdAt,
  });

  @override
  int get hashCode => Object.hash(id, chatId, senderId, type, content, replyToId, isEdited, isRead, status, createdAt);

  @override
  bool operator ==(Object other) =>
      other is LocalMessage &&
      other.id == id &&
      other.chatId == chatId &&
      other.senderId == senderId &&
      other.type == type &&
      other.content == content &&
      other.replyToId == replyToId &&
      other.isEdited == isEdited &&
      other.isRead == isRead &&
      other.status == status &&
      other.createdAt == createdAt;
}

class LocalUser {
  final String id;
  final String username;
  final String? displayName;
  final String? avatarUrl;
  final String? bio;
  final bool isOnline;
  final DateTime? lastSeen;

  LocalUser({
    required this.id,
    required this.username,
    this.displayName,
    this.avatarUrl,
    this.bio,
    required this.isOnline,
    this.lastSeen,
  });

  @override
  int get hashCode => Object.hash(id, username, displayName, avatarUrl, bio, isOnline, lastSeen);

  @override
  bool operator ==(Object other) =>
      other is LocalUser &&
      other.id == id &&
      other.username == username &&
      other.displayName == displayName &&
      other.avatarUrl == avatarUrl &&
      other.bio == bio &&
      other.isOnline == isOnline &&
      other.lastSeen == lastSeen;
}

class LocalContact {
  final String id;
  final String userId;
  final String contactUserId;
  final String? displayName;
  final bool isBlocked;

  LocalContact({
    required this.id,
    required this.userId,
    required this.contactUserId,
    this.displayName,
    required this.isBlocked,
  });

  @override
  int get hashCode => Object.hash(id, userId, contactUserId, displayName, isBlocked);

  @override
  bool operator ==(Object other) =>
      other is LocalContact &&
      other.id == id &&
      other.userId == userId &&
      other.contactUserId == contactUserId &&
      other.displayName == displayName &&
      other.isBlocked == isBlocked;
}

class LocalMediaData {
  final String id;
  final String? messageId;
  final String type;
  final String url;
  final String? localPath;
  final String? thumbnailUrl;
  final int? sizeBytes;

  LocalMediaData({
    required this.id,
    this.messageId,
    required this.type,
    required this.url,
    this.localPath,
    this.thumbnailUrl,
    this.sizeBytes,
  });

  @override
  int get hashCode => Object.hash(id, messageId, type, url, localPath, thumbnailUrl, sizeBytes);

  @override
  bool operator ==(Object other) =>
      other is LocalMediaData &&
      other.id == id &&
      other.messageId == messageId &&
      other.type == type &&
      other.url == url &&
      other.localPath == localPath &&
      other.thumbnailUrl == thumbnailUrl &&
      other.sizeBytes == sizeBytes;
}
