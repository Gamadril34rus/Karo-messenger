/**
 * ЧАРО — Backend Server
 * Fastify + TypeScript + Prisma + WebSocket
 */

import Fastify from 'fastify';
import cors from '@fastify/cors';
import helmet from '@fastify/helmet';
import rateLimit from '@fastify/rate-limit';
import multipart from '@fastify/multipart';
import websocket from '@fastify/websocket';
import { PrismaClient } from '@prisma/client';
import Redis from 'ioredis';

import { authRoutes } from './modules/auth/auth.routes';
import { messagesRoutes } from './modules/messages/messages.routes';
import { chatsRoutes } from './modules/chats/chats.routes';
import { usersRoutes } from './modules/users/users.routes';
import { mediaRoutes } from './modules/media/media.routes';
import { callsRoutes } from './modules/calls/calls.routes';
import { storyRoutes } from './modules/stories/stories.routes';
import { contactsRoutes } from './modules/contacts/contacts.routes';
import { settingsRoutes } from './modules/settings/settings.routes';
import { aiRoutes } from './modules/ai/ai.routes';
import { stickersRoutes } from './modules/stickers/stickers.routes';
import { nearbyRoutes } from './modules/nearby/nearby.routes';
import { mlsRoutes } from './modules/mls/mls.routes';

import { wsHandler } from './ws/connection';
import { errorHandler } from './middleware/errorHandler';
import { authMiddleware } from './middleware/auth';

import { logger } from './utils/logger';

// ─── Инициализация ────────────────────────────────────────────────

const prisma = new PrismaClient();
const redis = new Redis({
  host: process.env.REDIS_HOST || 'localhost',
  port: Number(process.env.REDIS_PORT) || 6379,
  password: process.env.REDIS_PASSWORD,
  maxRetriesPerRequest: null,
});

const fastify = Fastify({
  logger: {
    level: process.env.LOG_LEVEL || 'info',
    transport: {
      target: 'pino-pretty',
      options: { colorize: true },
    },
  },
  requestIdHeader: 'x-request-id',
  requestIdLogLabel: 'reqId',
});

// ─── Глобальные декораторы ─────────────────────────────────────────

declare module 'fastify' {
  interface FastifyRequest {
    userId?: string;
    deviceId?: string;
  }
  interface FastifyInstance {
    prisma: import('@prisma/client').PrismaClient;
    redis: import('ioredis').Redis;
  }
}

fastify.decorate('prisma', prisma);
fastify.decorate('redis', redis);

// Auth authenticate decorator — для preHandler в защищённых маршрутах
// (authRoutes.logout / authRoutes.delete-account используют fastify.authenticate)
fastify.decorate('authenticate', authMiddleware);

// ─── Плагины ──────────────────────────────────────────────────────

async function bootstrap() {
  // Security
  await fastify.register(helmet, {
    contentSecurityPolicy: false,
  });

  // CORS
  await fastify.register(cors, {
    origin: process.env.CORS_ORIGINS?.split(',') || ['*'],
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'X-Device-Id'],
    credentials: true,
  });

  // Rate limiting
  await fastify.register(rateLimit, {
    max: 100,
    timeWindow: '1 minute',
    keyGenerator: (request) => {
      return request.ip;
    },
  });

  // Multipart upload
  await fastify.register(multipart, {
    limits: {
      fileSize: 2 * 1024 * 1024 * 1024, // 2 GB
      files: 10,
    },
  });

  // WebSocket
  await fastify.register(websocket);

  // ─── Маршруты ──────────────────────────────────────────────────

  // Health check
  fastify.get('/health', async () => ({
    status: 'ok',
    version: '1.0.0',
    timestamp: new Date().toISOString(),
  }));

  // API v1
  fastify.register(
    async (api) => {
      // Публичные маршруты (без авторизации)
      api.register(authRoutes, { prefix: '/auth' });

      // Защищённые маршруты
      api.addHook('preHandler', authMiddleware);

      api.register(usersRoutes, { prefix: '/users' });
      api.register(chatsRoutes, { prefix: '/chats' });
      api.register(messagesRoutes, { prefix: '/messages' });
      api.register(mediaRoutes, { prefix: '/media' });
      api.register(callsRoutes, { prefix: '/calls' });
      api.register(storyRoutes, { prefix: '/stories' });
      api.register(contactsRoutes, { prefix: '/contacts' });
      api.register(settingsRoutes, { prefix: '/settings' });
      api.register(aiRoutes, { prefix: '/ai' });
      api.register(stickersRoutes, { prefix: '/stickers' });
      api.register(nearbyRoutes, { prefix: '/nearby' });

      // MLS маршруты — полные пути внутри mls.routes.ts (/api/v1/mls/...)
      // Поскольку MLS routes уже содержат полные пути, регистрируем без prefix
      api.register(mlsRoutes);
    },
    { prefix: '/api/v1' }
  );

  // WebSocket handler
  fastify.register(async (ws) => {
    ws.get('/ws', { websocket: true }, wsHandler(prisma, redis));
  });

  // ─── Обработка ошибок ─────────────────────────────────────────

  fastify.setErrorHandler(errorHandler);

  // ─── Graceful shutdown ─────────────────────────────────────────

  const shutdown = async (signal: string) => {
    logger.info(`${signal} received, shutting down gracefully...`);
    await fastify.close();
    await prisma.$disconnect();
    await redis.quit();
    process.exit(0);
  };

  process.on('SIGINT', () => shutdown('SIGINT'));
  process.on('SIGTERM', () => shutdown('SIGTERM'));

  // ─── Start ─────────────────────────────────────────────────────

  const host = process.env.HOST || '0.0.0.0';
  const port = Number(process.env.PORT) || 3000;

  try {
    await fastify.listen({ port, host });
    logger.info(`🚀 charo Server running on ${host}:${port}`);
  } catch (err) {
    logger.error(err);
    process.exit(1);
  }
}

bootstrap();
