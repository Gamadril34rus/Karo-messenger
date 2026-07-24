/**
 * Auth Middleware — JWT верификация для Fastify
 */

import { FastifyRequest, FastifyReply } from 'fastify';
import jwt from 'jsonwebtoken';

export async function authMiddleware(
  request: FastifyRequest,
  reply: FastifyReply,
) {
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
