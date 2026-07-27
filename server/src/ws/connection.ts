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

  // Создаём сообщение
  const message = await prisma.message.create({
    data: {
      chatId: chatId as string,
      senderId,
      type: type as any,
      content: content as any,
      replyToId: replyTo as string | undefined,
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
