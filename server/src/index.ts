// © 2024-2026 Charo Team. All rights reserved. PROPRIETARY AND CONFIDENTIAL.
/**
 * ЧАРО — Backend Server
 * Fastify + TypeScript + Prisma + WebSocket
 */

import Fastify, { FastifyInstance } from 'fastify';
import cors from '@fastify/cors';
import helmet from '@fastify/helmet';
import rateLimit from '@fastify/rate-limit';
import multipart from '@fastify/multipart';
import websocket from '@fastify/websocket';
import swagger from '@fastify/swagger';
import swaggerUi from '@fastify/swagger-ui';
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
import { searchRoutes } from './modules/search/search.routes';

import { wsHandler } from './ws/connection';
import { errorHandler } from './middleware/errorHandler';
import { authMiddleware } from './middleware/auth';

import { logger } from './utils/logger';

// ─── Fastify type augmentation ──────────────────────────────────────

declare module 'fastify' {
  interface FastifyRequest {
    userId?: string;
    deviceId?: string;
  }
  interface FastifyInstance {
    prisma: import('@prisma/client').PrismaClient;
    redis: import('ioredis').Redis;
    authenticate: typeof authMiddleware;
  }
}

// ─── Build Server (exported for testing) ───────────────────────────

export async function buildServer(): Promise<FastifyInstance> {
  const prisma = new PrismaClient();
  const redis = new Redis({
    host: process.env.REDIS_HOST || 'localhost',
    port: Number(process.env.REDIS_PORT) || 6379,
    password: process.env.REDIS_PASSWORD,
    maxRetriesPerRequest: null,
    lazyConnect: true,
  });

  const fastify = Fastify({
    logger: {
      level: process.env.LOG_LEVEL || 'info',
      transport: process.env.NODE_ENV !== 'test'
        ? {
            target: 'pino-pretty',
            options: { colorize: true },
          }
        : undefined,
    },
    requestIdHeader: 'x-request-id',
  });

  // ─── Глобальные декораторы ─────────────────────────────────────────

  fastify.decorate('prisma', prisma);
  fastify.decorate('redis', redis);
  fastify.decorate('authenticate', authMiddleware);

  // ─── Плагины ──────────────────────────────────────────────────────

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

  // Rate limiting — global defaults
  await fastify.register(rateLimit, {
    max: 100,
    timeWindow: '1 minute',
    keyGenerator: (request) => {
      return request.ip;
    },
    // Per-route overrides applied in route registrations
  });

  // Multipart upload
  await fastify.register(multipart, {
    limits: {
      fileSize: 2 * 1024 * 1024 * 1024, // 2 GB
      files: 10,
    },
  });

  // OpenAPI / Swagger
  await fastify.register(swagger, {
    openapi: {
      openapi: '3.0.3',
      info: {
        title: 'ЧАРО Messenger API',
        description: 'Production-ready API for ЧАРО messenger — real-time messaging, calls, stories, contacts, E2EE, and more.',
        version: '1.0.0',
        contact: {
          name: 'ЧАРО Team',
          url: 'https://charo.chat',
        },
        license: {
          name: 'Proprietary',
        },
      },
      servers: [
        { url: 'http://localhost:3000', description: 'Development' },
        { url: 'https://api.charo.chat', description: 'Production' },
      ],
      components: {
        securitySchemes: {
          bearerAuth: {
            type: 'http',
            scheme: 'bearer',
            bearerFormat: 'JWT',
          },
        },
      },
      tags: [
        { name: 'auth', description: 'Authentication & sessions' },
        { name: 'users', description: 'User profiles' },
        { name: 'chats', description: 'Chat management' },
        { name: 'messages', description: 'Message CRUD' },
        { name: 'contacts', description: 'Contact management' },
        { name: 'calls', description: 'Voice & video calls' },
        { name: 'stories', description: 'Stories' },
        { name: 'media', description: 'File upload & media' },
        { name: 'settings', description: 'User settings' },
        { name: 'ai', description: 'AI assistant' },
        { name: 'stickers', description: 'Sticker packs' },
        { name: 'nearby', description: 'Nearby users' },
        { name: 'mls', description: 'MLS (E2EE groups)' },
      ],
    },
  });

  await fastify.register(swaggerUi, {
    routePrefix: '/docs',
    uiConfig: {
      docExpansion: 'list',
      deepLinking: true,
      persistAuthorization: true,
    },
    staticCSP: true,
  });

  // WebSocket
  await fastify.register(websocket);

  // ─── Маршруты ──────────────────────────────────────────────────

  // Health check (detailed)
  fastify.get('/health', async () => {
    let dbStatus = 'ok';
    let redisStatus = 'ok';

    try {
      await Promise.race([
        prisma.$queryRaw`SELECT 1`,
        new Promise((_, reject) => setTimeout(() => reject(new Error('timeout')), 3000)),
      ]);
    } catch {
      dbStatus = 'error';
    }

    try {
      const pingResult = await Promise.race([
        redis.ping(),
        new Promise((_, reject) => setTimeout(() => reject(new Error('timeout')), 3000)),
      ]) as string;
      if (pingResult !== 'PONG') redisStatus = 'error';
    } catch {
      redisStatus = 'error';
    }

    const overallStatus = dbStatus === 'ok' && redisStatus === 'ok' ? 'ok' : 'degraded';

    return {
      status: overallStatus,
      version: '1.0.0',
      timestamp: new Date().toISOString(),
      checks: {
        database: dbStatus,
        redis: redisStatus,
      },
    };
  });

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

      // MLS маршруты
      api.register(mlsRoutes);

      // Global search (top-level)
      api.register(searchRoutes, { prefix: '/search' });
    },
    { prefix: '/api/v1' }
  );

  // WebSocket handler
  fastify.register(async (ws) => {
    ws.get('/ws', { websocket: true }, wsHandler(prisma, redis));
  });

  // ─── Обработка ошибок ─────────────────────────────────────────

  fastify.setErrorHandler(errorHandler);

  return fastify;
}

// ─── Main (production entry point) ─────────────────────────────────

async function main() {
  const fastify = await buildServer();

  // ─── Graceful shutdown ─────────────────────────────────────────

  const shutdown = async (signal: string) => {
    logger.info(`${signal} received, shutting down gracefully...`);
    await fastify.close();
    await fastify.prisma.$disconnect();
    await fastify.redis.quit();
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
    logger.info(`📖 API docs: http://${host}:${port}/docs`);
  } catch (err) {
    logger.error(err);
    process.exit(1);
  }
}

// Only run main() when executed directly, not when imported by tests
// Vitest sets process.env.VITEST; tsx/node direct execution does not
if (!process.env.VITEST) {
  main();
}
