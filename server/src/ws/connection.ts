// © 2024-2026 Charo Team. All rights reserved. PROPRIETARY AND CONFIDENTIAL.
/**
 * WebSocket Connection Manager
 * Обработка real-time соединений для мессенджера
 */

import { FastifyRequest } from 'fastify';
import { WebSocket } from 'ws';
import { PrismaClient } from '@prisma/client';
import Redis from 'ioredis';

import { logger } from '../utils/logger';

// ─── Типы ──────────────────────────────────────────────────────────

interface WsMessage {
  type: string;
  data: Record<string, unknown>;
  timestamp?: number;
}

interface ClientConnection {
  ws: WebSocket;
  userId: string;
  deviceId: string;
  connectedAt: Date;
  isAlive: boolean;
}

// ─── Connection Manager ────────────────────────────────────────────

class ConnectionManager {
  connections: Map<string, Map<string, ClientConnection>> = new Map();
  // userId -> deviceId -> connection

  constructor(
    private prisma: PrismaClient,
    private _redis: Redis,
  ) {}

  get redis(): Redis { return this._redis; }

  addConnection(userId: string, deviceId: string, ws: WebSocket): void {
    if (!this.connections.has(userId)) {
      this.connections.set(userId, new Map());
    }
    this.connections.get(userId)!.set(deviceId, {
      ws,
      userId,
      deviceId,
      connectedAt: new Date(),
      isAlive: true,
    });

    logger.info(`WS: ${userId} connected on device ${deviceId}`);
  }

  removeConnection(userId: string, deviceId: string): void {
    this.connections.get(userId)?.delete(deviceId);
    if (this.connections.get(userId)?.size === 0) {
      this.connections.delete(userId);
    }
  }

  getUserConnections(userId: string): ClientConnection[] {
    return Array.from(this.connections.get(userId)?.values() || []);
  }

  getOnlineUserIds(): string[] {
    return Array.from(this.connections.keys());
  }

  isUserOnline(userId: string): boolean {
    return (this.connections.get(userId)?.size ?? 0) > 0;
  }

  // Отправить конкретному пользователю
  sendToUser(userId: string, message: WsMessage): void {
    const connections = this.getUserConnections(userId);
    const payload = JSON.stringify(message);
    for (const conn of connections) {
      if (conn.isAlive && conn.ws.readyState === WebSocket.OPEN) {
        conn.ws.send(payload);
      }
    }
  }

  // Отправить в чат (всем участникам)
  async sendToChat(chatId: string, message: WsMessage): Promise<void> {
    const members = await this.prisma.chatMember.findMany({
      where: { chatId },
      select: { userId: true },
    });

    for (const member of members) {
      this.sendToUser(member.userId, message);
    }
  }

  // Обновить присутствие
  async updatePresence(userId: string, status: string): Promise<void> {
    const isOnline = status === 'online';
    await this.prisma.user.update({
      where: { id: userId },
      data: {
        isOnline,
        lastSeen: new Date(),
      },
    });

    await this.redis.set(
      `presence:${userId}`,
      JSON.stringify({ status, lastSeen: Date.now() }),
      'EX',
      300 // 5 минут
    );
  }
}

// ─── WebSocket Handler ─────────────────────────────────────────────

export function wsHandler(prisma: PrismaClient, redis: Redis) {
  const manager = new ConnectionManager(prisma, redis);

  // Heartbeat interval
  const heartbeatInterval = setInterval(() => {
    for (const [, devices] of manager.connections) {
      for (const [, conn] of devices) {
        if (!conn.isAlive) {
          conn.ws.terminate();
          manager.removeConnection(conn.userId, conn.deviceId);
        } else {
          conn.isAlive = false;
          conn.ws.ping();
        }
      }
    }
  }, 30000);

  return async (ws: WebSocket, request: FastifyRequest) => {
    // Аутентификация через query parameter
    const token = (request.query as Record<string, string>).token;
    if (!token) {
      ws.close(4001, 'Authentication required');
      return;
    }

    // Верификация JWT
    let userId: string;
    try {
      const jwt = await import('jsonwebtoken');
      const decoded = jwt.verify(
        token,
        process.env.JWT_ACCESS_SECRET || 'charo-access-secret'
      ) as { userId: string };
      userId = decoded.userId;
    } catch {
      ws.close(4001, 'Invalid token');
      return;
    }

    const deviceId = (request.headers['x-device-id'] as string) || 'default';
    manager.addConnection(userId, deviceId, ws);

    // Обновляем статус онлайн
    await manager.updatePresence(userId, 'online');

    // Broadcast presence to contacts
    await broadcastPresenceToContacts(manager, prisma, userId, 'online');

    // Pong handler
    ws.on('pong', () => {
      const conn = manager.connections.get(userId)?.get(deviceId);
      if (conn) conn.isAlive = true;
    });

    // Message handler
    ws.on('message', async (raw: Buffer) => {
      try {
        const msg: WsMessage = JSON.parse(raw.toString());

        switch (msg.type) {
          case 'ping':
            ws.send(JSON.stringify({ type: 'pong', data: {} }));
            break;

          case 'message.send':
            await handleMessageSend(manager, prisma, userId, msg);
            break;

          case 'message.delete':
            await handleMessageDelete(manager, prisma, userId, msg);
            break;

          case 'message.forward':
            await handleMessageForward(manager, prisma, userId, msg);
            break;

          case 'message.react':
            await handleMessageReact(manager, prisma, userId, msg);
            break;

          case 'message.update':
            await handleMessageUpdate(manager, prisma, userId, msg);
            break;

          case 'typing.start':
            await handleTyping(manager, prisma, userId, msg.data.chatId as string, true);
            break;

          case 'typing.stop':
            await handleTyping(manager, prisma, userId, msg.data.chatId as string, false);
            break;

          case 'read':
            await handleRead(manager, prisma, redis, userId, msg);
            break;

          case 'presence':
            await manager.updatePresence(userId, msg.data.status as string);
            break;

          case 'call.offer':
          case 'call.answer':
          case 'call.ice':
            await handleCallSignal(manager, prisma, msg);
            break;

          case 'call.initiate':
            await handleCallInitiate(manager, prisma, userId, msg);
            break;

          case 'call.hangup':
            await handleCallHangup(manager, prisma, userId, msg);
            break;

          default:
            logger.warn(`Unknown WS event: ${msg.type}`);
        }
      } catch (err) {
        (logger as any).error('WS message error:', String(err));
      }
    });

    // Close handler
    ws.on('close', async () => {
      manager.removeConnection(userId, deviceId);
      await manager.updatePresence(userId, 'offline');

      // Broadcast presence to contacts
      await broadcastPresenceToContacts(manager, prisma, userId, 'offline');

      logger.info(`WS: ${userId} disconnected`);
    });

    // Error handler
    ws.on('error', (err) => {
      (logger as any).error("WS error for " + userId + ": " + String(err));
      manager.removeConnection(userId, deviceId);
    });
  };
}

// ─── Обработчики событий ───────────────────────────────────────────

async function handleMessageSend(
  manager: ConnectionManager,
  prisma: PrismaClient,
  senderId: string,
  msg: WsMessage,
): Promise<void> {
  const { chatId, type, content, replyTo, tempId } = msg.data;

  // Проверяем, что пользователь — участник чата
  const membership = await prisma.chatMember.findUnique({
    where: {
      chatId_userId: { chatId: chatId as string, userId: senderId },
    },
  });

  if (!membership) {
    return; // Неавторизованная отправка
  }

  // Проверяем disappearing timer чата
  const chat = await prisma.chat.findUnique({
    where: { id: chatId as string },
    select: { isDisappearing: true, disappearTimer: true },
  });

  // Вычисляем disappearAt если чат — исчезающий
  const disappearAt = (chat?.isDisappearing && chat.disappearTimer > 0)
    ? new Date(Date.now() + chat.disappearTimer * 1000)
    : undefined;

  // Создаём сообщение
  const message = await prisma.message.create({
    data: {
      chatId: chatId as string,
      senderId,
      type: type as any,
      content: content as any,
      replyToId: replyTo as string | undefined,
      ...(disappearAt ? { disappearAt } : {}),
    },
    include: {
      sender: {
        select: { id: true, username: true, displayName: true, avatarUrl: true },
      },
    },
  });

  // Обновляем чат
  await prisma.chat.update({
    where: { id: chatId as string },
    data: { updatedAt: new Date() },
  });

  // Создаём статусы доставки для всех участников
  const members = await prisma.chatMember.findMany({
    where: { chatId: chatId as string, userId: { not: senderId } },
    select: { userId: true },
  });

  await prisma.messageStatus.createMany({
    data: members.map(m => ({
      messageId: message.id,
      userId: m.userId,
      status: 'SENT',
    })),
  });

  // Статус для отправителя — DELIVERED (ему самому)
  await prisma.messageStatus.create({
    data: {
      messageId: message.id,
      userId: senderId,
      status: 'DELIVERED',
    },
  });

  // Отправляем всем участникам чата
  await manager.sendToChat(chatId as string, {
    type: 'message.new',
    data: {
      ...message,
      tempId, // Клиент заменит временное ID
    },
  });

  // Отправляем отправителю статус доставки
  manager.sendToUser(senderId, {
    type: 'message.status',
    data: {
      messageId: message.id,
      tempId,
      status: 'sent',
    },
  });
}

async function handleTyping(
  manager: ConnectionManager,
  prisma: PrismaClient,
  userId: string,
  chatId: string,
  isTyping: boolean,
): Promise<void> {
  // Проверяем участие в чате
  const membership = await prisma.chatMember.findUnique({
    where: { chatId_userId: { chatId, userId } },
  });
  if (!membership) return;

  // Отправляем всем, кроме самого пользователя
  const members = await prisma.chatMember.findMany({
    where: { chatId, userId: { not: userId } },
    select: { userId: true },
  });

  for (const member of members) {
    manager.sendToUser(member.userId, {
      type: isTyping ? 'typing' : 'typing.stop',
      data: { chatId, userId },
    });
  }

  // Сохраняем в Redis с TTL
  if (isTyping) {
    await manager.redis.set(
      `typing:${chatId}:${userId}`,
      '1',
      'EX',
      5 // 5 секунд
    );
  } else {
    await manager.redis.del(`typing:${chatId}:${userId}`);
  }
}

async function handleRead(
  manager: ConnectionManager,
  prisma: PrismaClient,
  redis: Redis,
  userId: string,
  msg: WsMessage,
): Promise<void> {
  const { chatId, lastMessageId } = msg.data;

  // Обновляем lastReadAt
  await prisma.chatMember.update({
    where: { chatId_userId: { chatId: chatId as string, userId } },
    data: { lastReadAt: new Date() },
  });

  // Обновляем статус сообщений на READ
  await prisma.messageStatus.updateMany({
    where: {
      messageId: lastMessageId as string,
      userId,
      status: { not: 'READ' },
    },
    data: { status: 'READ', timestamp: new Date() },
  });

  // Уведомляем отправителя о прочтении
  const message = await prisma.message.findUnique({
    where: { id: lastMessageId as string },
    select: { senderId: true },
  });

  if (message) {
    manager.sendToUser(message.senderId, {
      type: 'message.status',
      data: {
        messageId: lastMessageId,
        userId,
        status: 'read',
        timestamp: Date.now(),
      },
    });
  }
}

async function handleMessageDelete(
  manager: ConnectionManager,
  prisma: PrismaClient,
  userId: string,
  msg: WsMessage,
): Promise<void> {
  const { messageId } = msg.data;
  if (!messageId) return;

  try {
    const message = await prisma.message.findUnique({ where: { id: messageId as string } });
    if (!message) return;

    // Verify sender or admin/owner can delete
    const membership = await prisma.chatMember.findUnique({
      where: { chatId_userId: { chatId: message.chatId, userId } },
    });
    if (!membership) return;

    if (message.senderId !== userId && membership.role !== 'ADMIN' && membership.role !== 'OWNER') return;

    await prisma.message.update({
      where: { id: messageId as string },
      data: { isDeleted: true, content: { isSet: false } },
    });

    // Notify all chat members
    await manager.sendToChat(message.chatId, {
      type: 'message.deleted',
      data: { messageId, chatId: message.chatId },
    });

    logger.info(`Message ${messageId} deleted by ${userId}`);
  } catch (err) {
    logger.error(`Message delete error: ${err}`);
  }
}

async function handleMessageForward(
  manager: ConnectionManager,
  prisma: PrismaClient,
  userId: string,
  msg: WsMessage,
): Promise<void> {
  const { messageId, targetChatId } = msg.data;
  if (!messageId) return;

  try {
    const originalMessage = await prisma.message.findUnique({
      where: { id: messageId as string },
      include: { sender: { select: { id: true, displayName: true } } },
    });
    if (!originalMessage) return;

    // Verify user is member of both source and target chats
    if (targetChatId) {
      const targetMembership = await prisma.chatMember.findUnique({
        where: { chatId_userId: { chatId: targetChatId as string, userId } },
      });
      if (!targetMembership) return;
    }

    // Create forwarded message in target chat
    const forwardedMessage = await prisma.message.create({
      data: {
        chatId: (targetChatId as string) ?? originalMessage.chatId,
        senderId: userId,
        type: originalMessage.type,
        content: originalMessage.content ?? undefined,
        forwardedFromId: messageId as string,
      },
      include: {
        sender: { select: { id: true, username: true, displayName: true, avatarUrl: true } },
      },
    });

    // Notify target chat members
    await manager.sendToChat(forwardedMessage.chatId, {
      type: 'message.new',
      data: { ...forwardedMessage, isForwarded: true },
    });

    logger.info(`Message ${messageId} forwarded to ${targetChatId} by ${userId}`);
  } catch (err) {
    logger.error(`Message forward error: ${err}`);
  }
}

async function handleMessageReact(
  manager: ConnectionManager,
  prisma: PrismaClient,
  userId: string,
  msg: WsMessage,
): Promise<void> {
  const { chatId, messageId, emoji } = msg.data;
  if (!messageId || !emoji) return;

  try {
    const messageIdStr = messageId as string;
    const emojiStr = emoji as string;

    // Verify user is member of the chat
    const message = await prisma.message.findUnique({
      where: { id: messageIdStr },
    });
    if (!message) return;

    const membership = await prisma.chatMember.findUnique({
      where: { chatId_userId: { chatId: message.chatId, userId } },
    });
    if (!membership) return;

    // Toggle reaction (remove if exists, create if not)
    const existing = await prisma.reaction.findUnique({
      where: { messageId_userId_emoji: { messageId: messageIdStr, userId, emoji: emojiStr } },
    });

    if (existing) {
      await prisma.reaction.delete({ where: { id: existing.id } });
    } else {
      await prisma.reaction.create({
        data: { messageId: messageIdStr, userId, emoji: emojiStr },
      });
    }

    // Notify chat members
    const reactions = await prisma.reaction.findMany({
      where: { messageId: messageIdStr },
      select: { emoji: true, userId: true },
    });

    const reactionCounts = reactions.reduce((acc: Record<string, number>, r) => {
      acc[r.emoji] = (acc[r.emoji] || 0) + 1;
      return acc;
    }, {});

    await manager.sendToChat(message.chatId, {
      type: 'message.updated',
      data: { messageId: messageIdStr, reactions: reactionCounts },
    });

    logger.info(`Reaction ${emojiStr} ${existing ? 'removed' : 'added'} on ${messageIdStr} by ${userId}`);
  } catch (err) {
    logger.error(`Message react error: ${err}`);
  }
}

async function handleMessageUpdate(
  manager: ConnectionManager,
  prisma: PrismaClient,
  userId: string,
  msg: WsMessage,
): Promise<void> {
  const { messageId, content } = msg.data;
  if (!messageId || !content) return;

  try {
    const messageIdStr = messageId as string;

    const message = await prisma.message.findUnique({
      where: { id: messageIdStr },
    });
    if (!message) return;
    if (message.senderId !== userId) return;

    const updated = await prisma.message.update({
      where: { id: messageIdStr },
      data: { content: content as any, isEdited: true },
    });

    await manager.sendToChat(message.chatId, {
      type: 'message.updated',
      data: { messageId: messageIdStr, content: updated.content, isEdited: true },
    });

    logger.info(`Message ${messageIdStr} updated by ${userId}`);
  } catch (err) {
    logger.error(`Message update error: ${err}`);
  }
}

async function handleCallInitiate(
  manager: ConnectionManager,
  prisma: PrismaClient,
  userId: string,
  msg: WsMessage,
): Promise<void> {
  const { targetUserId, chatId, type } = msg.data;
  if (!targetUserId && !chatId) {
    logger.warn('Call initiate missing target');
    return;
  }

  try {
    // Create call record
    const call = await prisma.call.create({
      data: {
        chatId: chatId as string | undefined,
        callerId: userId,
        type: (type as string)?.toUpperCase() === 'VIDEO' ? 'VIDEO' : 'VOICE',
        status: 'RINGING',
      },
    });

    // Determine call participants
    const participants: string[] = [];
    if (targetUserId) {
      participants.push(targetUserId as string);
    } else if (chatId) {
      const members = await prisma.chatMember.findMany({
        where: { chatId: chatId as string, userId: { not: userId } },
        select: { userId: true },
      });
      participants.push(...members.map(m => m.userId));
    }

    // Create call member records
    await prisma.callMember.createMany({
      data: [
        { callId: call.id, userId, role: 'CALLER' },
        ...participants.map(pid => ({
          callId: call.id,
          userId: pid,
          role: 'RECIPIENT' as const,
        })),
      ],
    });

    // Notify all participants of incoming call
    // Include caller name and avatar for the incoming call screen
    const caller = await prisma.user.findUnique({
      where: { id: userId },
      select: { displayName: true, avatarUrl: true },
    });

    for (const participantId of participants) {
      manager.sendToUser(participantId, {
        type: 'call.incoming',
        data: {
          callId: call.id,
          callerId: userId,
          callerName: caller?.displayName ?? 'Неизвестный',
          callerAvatarUrl: caller?.avatarUrl ?? null,
          type: type ?? 'voice',
          chatId: chatId ?? null,
        },
      });
    }

    logger.info(`Call ${call.id} initiated by ${userId} for ${participants.length} participants`);
  } catch (err) {
    logger.error(`Call initiate error: ${err}`);
  }
}

async function handleCallHangup(
  manager: ConnectionManager,
  prisma: PrismaClient,
  userId: string,
  msg: WsMessage,
): Promise<void> {
  const { callId, reason } = msg.data;
  if (!callId) {
    logger.warn('Call hangup missing callId');
    return;
  }

  try {
    const call = await prisma.call.findUnique({
      where: { id: callId as string },
      include: { members: { select: { userId: true } } },
    });

    if (!call) {
      logger.warn(`Call ${callId} not found for hangup`);
      return;
    }

    // Update call status
    const status = (reason as string) === 'declined' ? 'DECLINED' : 'ENDED';
    const now = new Date();
    const durationSec = call.startedAt
      ? Math.round((now.getTime() - call.startedAt.getTime()) / 1000)
      : null;

    await prisma.call.update({
      where: { id: callId as string },
      data: {
        status,
        endedAt: now,
        durationSec,
      },
    });

    // Notify all other participants
    for (const member of call.members) {
      if (member.userId !== userId) {
        manager.sendToUser(member.userId, {
          type: 'call.hangup',
          data: {
            callId,
            reason: reason ?? 'ended',
            endedBy: userId,
          },
        });
      }
    }

    logger.info(`Call ${callId} hung up by ${userId} (reason: ${reason ?? 'ended'})`);
  } catch (err) {
    logger.error(`Call hangup error: ${err}`);
  }
}

async function handleCallSignal(
  manager: ConnectionManager,
  prisma: PrismaClient,
  msg: WsMessage,
): Promise<void> {
  const { callId, data } = msg.data;
  if (!callId) {
    logger.warn('Call signal missing callId');
    return;
  }

  // Retrieve call members from DB and relay signal to all other participants
  try {
    const callMembers = await prisma.callMember.findMany({
      where: { callId: callId as string },
      select: { userId: true },
    });

    // Relay the signal to all call participants (except the sender is already handled by the WS loop)
    for (const member of callMembers) {
      manager.sendToUser(member.userId, {
        type: msg.type,
        data: {
          callId,
          data,
          from: msg.data.from || (msg as any).userId,
        },
      });
    }

    logger.info(`Call signal ${msg.type} relayed to ${callMembers.length} participants for call ${callId}`);
  } catch (err) {
    logger.error(`Call signal relay failed: ${err}`);
  }
}

// ─── Periodic Cleanup: Disappearing Messages ────────────────────────
// Запускается каждые 30 секунд, удаляет сообщения с истёкшим disappearAt

export function startDisappearingMessagesCleanup(prisma: PrismaClient, manager: ConnectionManager): NodeJS.Timeout {
  return setInterval(async () => {
    try {
      const expired = await prisma.message.findMany({
        where: {
          disappearAt: { not: null, lte: new Date() },
          isDeleted: false,
        },
        select: { id: true, chatId: true },
      });

      if (expired.length === 0) return;

      const ids = expired.map(m => m.id);

      // Mark as deleted instead of removing (for consistency)
      await prisma.message.updateMany({
        where: { id: { in: ids } },
        data: { isDeleted: true, content: { isSet: false } },
      });

      // Notify chats about expired messages
      const chatIds = [...new Set(expired.map(m => m.chatId))];
      for (const chatId of chatIds) {
        const chatExpired = expired.filter(m => m.chatId === chatId);
        await manager.sendToChat(chatId, {
          type: 'message.disappeared',
          data: { messageIds: chatExpired.map(m => m.id) },
        });
      }

      logger.info(`Disappearing messages cleanup: ${ids.length} messages expired`);
    } catch (err) {
      logger.error(`Disappearing messages cleanup error: ${err}`);
    }
  }, 30_000); // every 30 seconds
}

// ─── Presence Broadcast to Contacts ────────────────────────────────
async function broadcastPresenceToContacts(
  manager: ConnectionManager,
  prisma: PrismaClient,
  userId: string,
  status: string,
): Promise<void> {
  try {
    // Get user's contacts
    const contacts = await prisma.contact.findMany({
      where: { contactUserId: userId, isBlocked: false },
      select: { userId: true },
    });

    const presenceData = {
      type: 'presence',
      data: {
        userId,
        status,
        last_seen: new Date().toISOString(),
      },
    };

    for (const contact of contacts) {
      manager.sendToUser(contact.userId, presenceData);
    }
  } catch (err) {
    logger.error(`Presence broadcast failed: ${err}`);
  }
}
