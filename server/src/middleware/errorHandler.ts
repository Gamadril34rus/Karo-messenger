/**
 * Централизованный обработчик ошибок Fastify
 */

import { FastifyError, FastifyRequest, FastifyReply } from 'fastify';
import { logger } from '../utils/logger';

export function errorHandler(
  error: FastifyError,
  request: FastifyRequest,
  reply: FastifyReply,
) {
  // Логируем ошибку
  logger.error({
    error: error.message,
    stack: error.stack,
    url: request.url,
    method: request.method,
    statusCode: error.statusCode,
  });

  // Zod validation errors
  if (error.validation) {
    return reply.code(400).send({
      message: 'Ошибка валидации',
      details: error.validation,
    });
  }

  // JWT errors
  if (error.message.includes('jwt') || error.message.includes('token')) {
    return reply.code(401).send({
      message: 'Ошибка авторизации',
    });
  }

  // Rate limit
  if (error.statusCode === 429) {
    return reply.code(429).send({
      message: 'Слишком много запросов. Попробуйте позже.',
    });
  }

  // Default error
  const statusCode = error.statusCode || 500;
  const message = statusCode === 500
    ? 'Внутренняя ошибка сервера'
    : error.message;

  return reply.code(statusCode).send({
    message,
    statusCode,
  });
}
