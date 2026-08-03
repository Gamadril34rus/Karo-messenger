-- CreateSchema
CREATE SCHEMA IF NOT EXISTS "public";

-- CreateEnum
CREATE TYPE "AccountStatus" AS ENUM ('ACTIVE', 'SUSPENDED', 'DELETED');

-- CreateEnum
CREATE TYPE "ChatType" AS ENUM ('PRIVATE', 'GROUP', 'CHANNEL', 'SECRET');

-- CreateEnum
CREATE TYPE "MemberRole" AS ENUM ('OWNER', 'ADMIN', 'MEMBER');

-- CreateEnum
CREATE TYPE "MessageType" AS ENUM ('TEXT', 'IMAGE', 'VIDEO', 'VOICE', 'VIDEO_NOTE', 'FILE', 'STICKER', 'GIF', 'LOCATION', 'CONTACT', 'POLL', 'STORY_REPLY', 'AI_REPLY', 'SYSTEM');

-- CreateEnum
CREATE TYPE "DeliveryStatus" AS ENUM ('SENT', 'DELIVERED', 'READ');

-- CreateEnum
CREATE TYPE "MediaType" AS ENUM ('IMAGE', 'VIDEO', 'AUDIO', 'FILE', 'STICKER', 'GIF');

-- CreateEnum
CREATE TYPE "PrivacyLevel" AS ENUM ('EVERYONE', 'CONTACTS', 'NOBODY');

-- CreateEnum
CREATE TYPE "StoryType" AS ENUM ('IMAGE', 'VIDEO', 'TEXT');

-- CreateEnum
CREATE TYPE "CallType" AS ENUM ('VOICE', 'VIDEO');

-- CreateEnum
CREATE TYPE "CallStatus" AS ENUM ('RINGING', 'ACTIVE', 'ENDED', 'MISSED', 'DECLINED');

-- CreateEnum
CREATE TYPE "CallRole" AS ENUM ('CALLER', 'RECIPIENT');

-- CreateEnum
CREATE TYPE "StickerSource" AS ENUM ('CHARO', 'TELEGRAM', 'WHATSAPP', 'VIBER', 'VK', 'CUSTOM');

-- CreateEnum
CREATE TYPE "AiRole" AS ENUM ('USER', 'ASSISTANT');

-- CreateEnum
CREATE TYPE "MlsMessageType" AS ENUM ('PROPOSAL', 'COMMIT', 'APPLICATION');

-- CreateEnum
CREATE TYPE "MlsProposalType" AS ENUM ('ADD', 'REMOVE', 'UPDATE', 'EXTERNAL_INIT');

-- CreateTable
CREATE TABLE "users" (
    "id" UUID NOT NULL,
    "phone" TEXT,
    "email" TEXT,
    "username" VARCHAR(64) NOT NULL,
    "display_name" VARCHAR(128),
    "bio" VARCHAR(256),
    "avatar_url" VARCHAR(512),
    "password_hash" TEXT,
    "two_factor_secret" TEXT,
    "is_online" BOOLEAN NOT NULL DEFAULT false,
    "last_seen" TIMESTAMP(3),
    "language" VARCHAR(10) NOT NULL DEFAULT 'ru',
    "status" "AccountStatus" NOT NULL DEFAULT 'ACTIVE',
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3),
    "deleted_at" TIMESTAMP(3),

    CONSTRAINT "users_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "chats" (
    "id" UUID NOT NULL,
    "type" "ChatType" NOT NULL,
    "title" VARCHAR(255),
    "avatar_url" VARCHAR(512),
    "description" VARCHAR(2048),
    "created_by" UUID,
    "is_disappearing" BOOLEAN NOT NULL DEFAULT false,
    "disappear_timer" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3),

    CONSTRAINT "chats_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "chat_members" (
    "id" UUID NOT NULL,
    "chat_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "role" "MemberRole" NOT NULL DEFAULT 'MEMBER',
    "joined_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "last_read_at" TIMESTAMP(3),
    "is_muted" BOOLEAN NOT NULL DEFAULT false,

    CONSTRAINT "chat_members_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "messages" (
    "id" UUID NOT NULL,
    "chat_id" UUID NOT NULL,
    "sender_id" UUID NOT NULL,
    "type" "MessageType" NOT NULL,
    "content" JSONB,
    "reply_to_id" UUID,
    "forwarded_from_id" UUID,
    "is_edited" BOOLEAN NOT NULL DEFAULT false,
    "is_pinned" BOOLEAN NOT NULL DEFAULT false,
    "is_deleted" BOOLEAN NOT NULL DEFAULT false,
    "disappear_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3),

    CONSTRAINT "messages_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "message_status" (
    "id" UUID NOT NULL,
    "message_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "status" "DeliveryStatus" NOT NULL DEFAULT 'SENT',
    "timestamp" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "message_status_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "reactions" (
    "id" UUID NOT NULL,
    "message_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "emoji" VARCHAR(32) NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "reactions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "media" (
    "id" UUID NOT NULL,
    "message_id" UUID,
    "type" "MediaType" NOT NULL,
    "url" VARCHAR(512) NOT NULL,
    "thumbnail_url" VARCHAR(512),
    "mime_type" VARCHAR(128),
    "size_bytes" BIGINT,
    "width" INTEGER,
    "height" INTEGER,
    "duration_ms" INTEGER,
    "uploaded_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "media_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "contacts" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "contact_user_id" UUID NOT NULL,
    "display_name" VARCHAR(128),
    "is_blocked" BOOLEAN NOT NULL DEFAULT false,
    "added_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "contacts_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "privacy_settings" (
    "userId" UUID NOT NULL,
    "profile_visibility" "PrivacyLevel" NOT NULL DEFAULT 'EVERYONE',
    "last_seen_visibility" "PrivacyLevel" NOT NULL DEFAULT 'EVERYONE',
    "avatar_visibility" "PrivacyLevel" NOT NULL DEFAULT 'EVERYONE',
    "phone_visibility" "PrivacyLevel" NOT NULL DEFAULT 'CONTACTS',
    "who_can_message" "PrivacyLevel" NOT NULL DEFAULT 'EVERYONE',
    "who_can_add_to_groups" "PrivacyLevel" NOT NULL DEFAULT 'CONTACTS',
    "who_can_call" "PrivacyLevel" NOT NULL DEFAULT 'EVERYONE',
    "read_receipts" BOOLEAN NOT NULL DEFAULT true,
    "typing_indicator" BOOLEAN NOT NULL DEFAULT true,

    CONSTRAINT "privacy_settings_pkey" PRIMARY KEY ("userId")
);

-- CreateTable
CREATE TABLE "stories" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "type" "StoryType" NOT NULL,
    "media_url" VARCHAR(512),
    "content" TEXT,
    "background_color" VARCHAR(20),
    "expires_at" TIMESTAMP(3) NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "stories_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "story_views" (
    "id" UUID NOT NULL,
    "story_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "viewed_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "story_views_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "calls" (
    "id" UUID NOT NULL,
    "chat_id" UUID,
    "caller_id" UUID NOT NULL,
    "type" "CallType" NOT NULL,
    "status" "CallStatus" NOT NULL DEFAULT 'RINGING',
    "started_at" TIMESTAMP(3),
    "ended_at" TIMESTAMP(3),
    "duration_sec" INTEGER,

    CONSTRAINT "calls_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "call_members" (
    "id" UUID NOT NULL,
    "call_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "role" "CallRole" NOT NULL DEFAULT 'RECIPIENT',

    CONSTRAINT "call_members_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "devices" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "device_type" VARCHAR(32) NOT NULL,
    "device_name" VARCHAR(128),
    "platform" VARCHAR(32),
    "ip" VARCHAR(45),
    "push_token" VARCHAR(512),
    "last_active" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "devices_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "sticker_packs" (
    "id" UUID NOT NULL,
    "name" VARCHAR(128) NOT NULL,
    "source" "StickerSource" NOT NULL DEFAULT 'CHARO',
    "source_id" VARCHAR(128),
    "thumbnail_url" VARCHAR(512),
    "is_featured" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "sticker_packs_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "stickers" (
    "id" UUID NOT NULL,
    "pack_id" UUID NOT NULL,
    "image_url" VARCHAR(512) NOT NULL,
    "emoji" VARCHAR(64),
    "sort_order" INTEGER NOT NULL,
    "width" INTEGER,
    "height" INTEGER,

    CONSTRAINT "stickers_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ai_conversations" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "title" VARCHAR(255),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ai_conversations_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ai_messages" (
    "id" UUID NOT NULL,
    "conversation_id" UUID NOT NULL,
    "role" "AiRole" NOT NULL,
    "content" TEXT NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ai_messages_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "push_settings" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "push_enabled" BOOLEAN NOT NULL DEFAULT true,
    "sound_enabled" BOOLEAN NOT NULL DEFAULT true,
    "vibration_enabled" BOOLEAN NOT NULL DEFAULT true,
    "preview_enabled" BOOLEAN NOT NULL DEFAULT true,
    "group_mentions" BOOLEAN NOT NULL DEFAULT true,

    CONSTRAINT "push_settings_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "blocked_users" (
    "id" UUID NOT NULL,
    "blocker_id" UUID NOT NULL,
    "blocked_user_id" UUID NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "blocked_users_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "otp_codes" (
    "id" UUID NOT NULL,
    "identifier" VARCHAR(255) NOT NULL,
    "code" VARCHAR(10) NOT NULL,
    "method" VARCHAR(20) NOT NULL,
    "expires_at" TIMESTAMP(3) NOT NULL,
    "is_used" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "otp_codes_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "mls_groups" (
    "id" UUID NOT NULL,
    "name" VARCHAR(255) NOT NULL,
    "cipher_suite" VARCHAR(128) NOT NULL DEFAULT 'MLS128_DHKEMX25519_AES128GCM_SHA256_Ed25519',
    "epoch" INTEGER NOT NULL DEFAULT 0,
    "tree_data" JSONB NOT NULL,
    "confirmation_key" VARCHAR(512),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3),

    CONSTRAINT "mls_groups_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "mls_group_members" (
    "id" UUID NOT NULL,
    "group_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "leaf_index" INTEGER,
    "joined_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "mls_group_members_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "mls_commits" (
    "id" UUID NOT NULL,
    "group_id" UUID NOT NULL,
    "epoch" INTEGER NOT NULL,
    "proposals" JSONB NOT NULL,
    "update_path" JSONB,
    "confirmation_tag" VARCHAR(512) NOT NULL,
    "sender_id" UUID NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "mls_commits_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "mls_messages" (
    "id" UUID NOT NULL,
    "group_id" UUID NOT NULL,
    "epoch" INTEGER NOT NULL,
    "type" "MlsMessageType" NOT NULL,
    "encrypted_content" VARCHAR(8192) NOT NULL,
    "signature" VARCHAR(512) NOT NULL,
    "sender_id" UUID NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "mls_messages_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "mls_proposals" (
    "id" UUID NOT NULL,
    "group_id" UUID NOT NULL,
    "epoch" INTEGER NOT NULL,
    "type" "MlsProposalType" NOT NULL,
    "sender_id" UUID NOT NULL,
    "target_user_id" UUID,
    "reference" VARCHAR(128),
    "is_valid" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "mls_proposals_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "user_keys" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "identity_key_public" VARCHAR(512) NOT NULL,
    "signed_prekey_id" INTEGER NOT NULL,
    "signed_prekey_public" VARCHAR(512) NOT NULL,
    "signed_prekey_signature" VARCHAR(512) NOT NULL,
    "registration_id" INTEGER NOT NULL,
    "prekey_bundle" JSONB,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3),

    CONSTRAINT "user_keys_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "key_requests" (
    "id" UUID NOT NULL,
    "requester_id" UUID NOT NULL,
    "target_id" UUID NOT NULL,
    "status" VARCHAR(20) NOT NULL DEFAULT 'pending',
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "fulfilled_at" TIMESTAMP(3),

    CONSTRAINT "key_requests_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ratchet_tree_nodes" (
    "id" UUID NOT NULL,
    "group_id" UUID NOT NULL,
    "index" INTEGER NOT NULL,
    "type" VARCHAR(20) NOT NULL,
    "public_key" VARCHAR(512) NOT NULL,
    "private_key" VARCHAR(512),
    "user_id" UUID,
    "is_blank" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ratchet_tree_nodes_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "users_phone_key" ON "users"("phone");

-- CreateIndex
CREATE UNIQUE INDEX "users_email_key" ON "users"("email");

-- CreateIndex
CREATE UNIQUE INDEX "users_username_key" ON "users"("username");

-- CreateIndex
CREATE UNIQUE INDEX "chat_members_chat_id_user_id_key" ON "chat_members"("chat_id", "user_id");

-- CreateIndex
CREATE INDEX "messages_chat_id_created_at_idx" ON "messages"("chat_id", "created_at");

-- CreateIndex
CREATE INDEX "messages_sender_id_idx" ON "messages"("sender_id");

-- CreateIndex
CREATE UNIQUE INDEX "message_status_message_id_user_id_key" ON "message_status"("message_id", "user_id");

-- CreateIndex
CREATE UNIQUE INDEX "reactions_message_id_user_id_emoji_key" ON "reactions"("message_id", "user_id", "emoji");

-- CreateIndex
CREATE UNIQUE INDEX "contacts_user_id_contact_user_id_key" ON "contacts"("user_id", "contact_user_id");

-- CreateIndex
CREATE UNIQUE INDEX "story_views_story_id_user_id_key" ON "story_views"("story_id", "user_id");

-- CreateIndex
CREATE UNIQUE INDEX "call_members_call_id_user_id_key" ON "call_members"("call_id", "user_id");

-- CreateIndex
CREATE UNIQUE INDEX "push_settings_user_id_key" ON "push_settings"("user_id");

-- CreateIndex
CREATE UNIQUE INDEX "blocked_users_blocker_id_blocked_user_id_key" ON "blocked_users"("blocker_id", "blocked_user_id");

-- CreateIndex
CREATE INDEX "otp_codes_identifier_code_idx" ON "otp_codes"("identifier", "code");

-- CreateIndex
CREATE UNIQUE INDEX "mls_group_members_group_id_user_id_key" ON "mls_group_members"("group_id", "user_id");

-- CreateIndex
CREATE INDEX "mls_commits_group_id_epoch_idx" ON "mls_commits"("group_id", "epoch");

-- CreateIndex
CREATE INDEX "mls_messages_group_id_created_at_idx" ON "mls_messages"("group_id", "created_at");

-- CreateIndex
CREATE INDEX "mls_proposals_group_id_epoch_idx" ON "mls_proposals"("group_id", "epoch");

-- CreateIndex
CREATE UNIQUE INDEX "user_keys_user_id_key" ON "user_keys"("user_id");

-- CreateIndex
CREATE INDEX "key_requests_requester_id_target_id_idx" ON "key_requests"("requester_id", "target_id");

-- CreateIndex
CREATE UNIQUE INDEX "ratchet_tree_nodes_group_id_index_key" ON "ratchet_tree_nodes"("group_id", "index");

-- AddForeignKey
ALTER TABLE "chats" ADD CONSTRAINT "chats_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "chat_members" ADD CONSTRAINT "chat_members_chat_id_fkey" FOREIGN KEY ("chat_id") REFERENCES "chats"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "chat_members" ADD CONSTRAINT "chat_members_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "messages" ADD CONSTRAINT "messages_chat_id_fkey" FOREIGN KEY ("chat_id") REFERENCES "chats"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "messages" ADD CONSTRAINT "messages_sender_id_fkey" FOREIGN KEY ("sender_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "messages" ADD CONSTRAINT "messages_reply_to_id_fkey" FOREIGN KEY ("reply_to_id") REFERENCES "messages"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "message_status" ADD CONSTRAINT "message_status_message_id_fkey" FOREIGN KEY ("message_id") REFERENCES "messages"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "message_status" ADD CONSTRAINT "message_status_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "reactions" ADD CONSTRAINT "reactions_message_id_fkey" FOREIGN KEY ("message_id") REFERENCES "messages"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "reactions" ADD CONSTRAINT "reactions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "media" ADD CONSTRAINT "media_message_id_fkey" FOREIGN KEY ("message_id") REFERENCES "messages"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "contacts" ADD CONSTRAINT "contacts_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "contacts" ADD CONSTRAINT "contacts_contact_user_id_fkey" FOREIGN KEY ("contact_user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "privacy_settings" ADD CONSTRAINT "privacy_settings_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "stories" ADD CONSTRAINT "stories_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "story_views" ADD CONSTRAINT "story_views_story_id_fkey" FOREIGN KEY ("story_id") REFERENCES "stories"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "story_views" ADD CONSTRAINT "story_views_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "calls" ADD CONSTRAINT "calls_chat_id_fkey" FOREIGN KEY ("chat_id") REFERENCES "chats"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "calls" ADD CONSTRAINT "calls_caller_id_fkey" FOREIGN KEY ("caller_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "call_members" ADD CONSTRAINT "call_members_call_id_fkey" FOREIGN KEY ("call_id") REFERENCES "calls"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "call_members" ADD CONSTRAINT "call_members_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "devices" ADD CONSTRAINT "devices_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "stickers" ADD CONSTRAINT "stickers_pack_id_fkey" FOREIGN KEY ("pack_id") REFERENCES "sticker_packs"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ai_conversations" ADD CONSTRAINT "ai_conversations_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ai_messages" ADD CONSTRAINT "ai_messages_conversation_id_fkey" FOREIGN KEY ("conversation_id") REFERENCES "ai_conversations"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "push_settings" ADD CONSTRAINT "push_settings_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "blocked_users" ADD CONSTRAINT "blocked_users_blocker_id_fkey" FOREIGN KEY ("blocker_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "blocked_users" ADD CONSTRAINT "blocked_users_blocked_user_id_fkey" FOREIGN KEY ("blocked_user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "mls_group_members" ADD CONSTRAINT "mls_group_members_group_id_fkey" FOREIGN KEY ("group_id") REFERENCES "mls_groups"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "mls_group_members" ADD CONSTRAINT "mls_group_members_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "mls_commits" ADD CONSTRAINT "mls_commits_group_id_fkey" FOREIGN KEY ("group_id") REFERENCES "mls_groups"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "mls_commits" ADD CONSTRAINT "mls_commits_sender_id_fkey" FOREIGN KEY ("sender_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "mls_messages" ADD CONSTRAINT "mls_messages_group_id_fkey" FOREIGN KEY ("group_id") REFERENCES "mls_groups"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "mls_messages" ADD CONSTRAINT "mls_messages_sender_id_fkey" FOREIGN KEY ("sender_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "mls_proposals" ADD CONSTRAINT "mls_proposals_group_id_fkey" FOREIGN KEY ("group_id") REFERENCES "mls_groups"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "mls_proposals" ADD CONSTRAINT "mls_proposals_sender_id_fkey" FOREIGN KEY ("sender_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "mls_proposals" ADD CONSTRAINT "mls_proposals_target_user_id_fkey" FOREIGN KEY ("target_user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "user_keys" ADD CONSTRAINT "user_keys_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "key_requests" ADD CONSTRAINT "key_requests_requester_id_fkey" FOREIGN KEY ("requester_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "key_requests" ADD CONSTRAINT "key_requests_target_id_fkey" FOREIGN KEY ("target_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ratchet_tree_nodes" ADD CONSTRAINT "ratchet_tree_nodes_group_id_fkey" FOREIGN KEY ("group_id") REFERENCES "mls_groups"("id") ON DELETE CASCADE ON UPDATE CASCADE;


-- CreateTable: consent_records (ФЗ-152 Art.9, GDPR Art.7)
CREATE TABLE "consent_records" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "type" VARCHAR(32) NOT NULL,
    "consent_given" BOOLEAN NOT NULL DEFAULT true,
    "age_confirmed" BOOLEAN NOT NULL DEFAULT false,
    "terms_accepted" BOOLEAN NOT NULL DEFAULT false,
    "privacy_policy_version" VARCHAR(20),
    "terms_version" VARCHAR(20),
    "ip_address" VARCHAR(45),
    "user_agent" VARCHAR(512),
    "oauth_provider" VARCHAR(32),
    "created_at" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "consent_records_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "consent_records_user_id_idx" ON "consent_records"("user_id");

ALTER TABLE "consent_records" ADD CONSTRAINT "consent_records_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

