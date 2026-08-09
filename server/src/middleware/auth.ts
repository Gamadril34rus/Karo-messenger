// © 2024-2026 Бутаев Алексей Юрьевич. All rights reserved. PROPRIETARY AND CONFIDENTIAL.
/**
 * Auth Middleware — JWT верификация для Fastify
 *
 * Публичные маршруты (регистрация, вход, обновление токена)
 * пропускаются без проверки Authorization header.
 */

import { FastifyRequest, FastifyReply } from 'fastify';
import jwt from 'jsonwebtoken';

// ─── Публичные маршруты — авторизация не требуется ────────────────────

const PUBLIC_ROUTES = [
  '/health',
  '/docs',
  '/api/v1/auth/register',
  '/api/v1/auth/login',
  '/api/v1/auth/refresh',
  '/api/v1/auth/verify-email',
  '/api/v1/auth/forgot-password',
  '/api/v1/auth/reset-password',
];

function isPublicRoute(url: string): boolean {
  // Точное совпадение
  if (PUBLIC_ROUTES.includes(url)) return true;
  // Префиксное совпадение для /docs (Swagger UI подмаршруты)
  if (url.startsWith('/docs')) return true;
  // Префиксное совпадение для /health
  if (url.startsWith('/health')) return true;
  return false;
}

// ─── Middleware ───────────────────────────────────────────────────────

export async function authMiddleware(
  request: FastifyRequest,
  reply: FastifyReply,
) {
  // Пропускаем публичные маршруты
  if (isPublicRoute(request.url)) {
    return;
  }

  const authHeader = request.headers.authorization;

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return reply.code(401).send({ message: 'Authorization header required' });
  }

  const token = authHeader.split(' ')[1];

  try {
    const decoded = jwt.verify(
      token,
      process.env.JWT_ACCESS_SECRET || 'charo-access-secret'
    ) as { userId: string };

    request.userId = decoded.userId;
  } catch (err) {
    if (err instanceof jwt.TokenExpiredError) {
      return reply.code(401).send({ message: 'Token expired' });
    }
    return reply.code(401).send({ message: 'Invalid token' });
  }
}

// Декорируем Fastify для поддержки authenticate hook
declare module 'fastify' {
  interface FastifyInstance {
    authenticate: typeof authMiddleware;
  }
}
