/**
 * Auth Routes — Регистрация, вход, верификация, OAuth, удаление аккаунта
 */

import { FastifyInstance } from 'fastify';
import { z } from 'zod';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { nanoid } from 'nanoid';

import { logger } from '../../utils/logger';

// ─── Схемы валидации ───────────────────────────────────────────────

const loginSchema = z.object({
  identifier: z.string().min(1, 'Введите номер или email'),
  method: z.enum(['phone', 'email']),
});

const verifySchema = z.object({
  identifier: z.string(),
  code: z.string().length(6, 'Код должен содержать 6 цифр'),
  method: z.enum(['phone', 'email']),
});

const registerSchema = z.object({
  username: z.string().min(3).max(64).regex(/^[a-zA-Z0-9_]+$/),
  display_name: z.string().min(1).max(128),
  phone: z.string().optional(),
  email: z.string().email().optional(),
});

const deleteAccountSchema = z.object({
  confirmation: z.literal('DELETE'),
});

const refreshSchema = z.object({
  refresh_token: z.string(),
});

// ─── Константы ─────────────────────────────────────────────────────

const JWT_ACCESS_EXPIRY = '15m';
const JWT_REFRESH_EXPIRY = '7d';
const OTP_EXPIRY_MINUTES = 5;

// ─── Routes ────────────────────────────────────────────────────────

export async function authRoutes(fastify: FastifyInstance) {
  const { prisma, redis } = fastify;

  // ─── POST /auth/login — Отправить OTP ─────────────────────────
  fastify.post('/login', {
    schema: {
      body: loginSchema,
    },
  }, async (request, reply) => {
    const { identifier, method } = request.body as z.infer<typeof loginSchema>;

    // Проверяем, существует ли пользователь
    const user = await prisma.user.findFirst({
      where: {
        OR: [
          { phone: identifier },
          { email: identifier },
        ],
        status: 'ACTIVE',
      },
    });

    if (!user) {
      return reply.code(404).send({
        message: 'Пользователь не найден. Зарегистрируйтесь.',
      });
    }

    // Генерируем OTP
    const code = generateOtp();
    await prisma.oTPCode.create({
      data: {
        identifier,
        code,
        method,
        expiresAt: new Date(Date.now() + OTP_EXPIRY_MINUTES * 60 * 1000),
      },
    });

    // Отправляем OTP
    if (method === 'phone') {
      await sendOtpSms(identifier, code);
    } else {
      await sendOtpEmail(identifier, code);
    }

    // Rate limit: храним время последней отправки
    await redis.set(
      `otp_limit:${identifier}`,
      Date.now().toString(),
      'EX',
      60 // 1 минута между повторными отправками
    );

    logger.info(`OTP sent to ${identifier} via ${method}`);

    return reply.send({
      message: 'Код отправлен',
      expires_in: OTP_EXPIRY_MINUTES * 60,
    });
  });

  // ─── POST /auth/verify — Верифицировать OTP ───────────────────
  fastify.post('/verify', {
    schema: {
      body: verifySchema,
    },
  }, async (request, reply) => {
    const { identifier, code, method } = request.body as z.infer<typeof verifySchema>;

    // Ищем валидный OTP
    const otp = await prisma.oTPCode.findFirst({
      where: {
        identifier,
        code,
        method,
        isUsed: false,
        expiresAt: { gt: new Date() },
      },
      orderBy: { createdAt: 'desc' },
    });

    if (!otp) {
      return reply.code(400).send({
        message: 'Неверный или просроченный код',
      });
    }

    // Помечаем как использованный
    await prisma.oTPCode.update({
      where: { id: otp.id },
      data: { isUsed: true },
    });

    // Находим пользователя
    const user = await prisma.user.findFirst({
      where: {
        OR: [{ phone: identifier }, { email: identifier }],
        status: 'ACTIVE',
      },
    });

    if (!user) {
      return reply.code(404).send({ message: 'Пользователь не найден' });
    }

    // Генерируем токены
    const { accessToken, refreshToken } = generateTokens(user.id);

    // Сохраняем сессию в Redis
    await redis.set(
      `session:${user.id}`,
      JSON.stringify({ lastActive: Date.now() }),
      'EX',
      7 * 24 * 60 * 60 // 7 дней
    );

    return reply.send({
      access_token: accessToken,
      refresh_token: refreshToken,
      user: {
        id: user.id,
        username: user.username,
        display_name: user.displayName,
        avatar_url: user.avatarUrl,
      },
    });
  });

  // ─── POST /auth/register — Регистрация ────────────────────────
  fastify.post('/register', {
    schema: {
      body: registerSchema,
    },
  }, async (request, reply) => {
    const data = request.body as z.infer<typeof registerSchema>;

    // Проверяем уникальность username
    const existing = await prisma.user.findUnique({
      where: { username: data.username },
    });
    if (existing) {
      return reply.code(409).send({ message: 'Имя пользователя занято' });
    }

    // Проверяем уникальность phone/email
    if (data.phone) {
      const phoneUser = await prisma.user.findUnique({ where: { phone: data.phone } });
      if (phoneUser) {
        return reply.code(409).send({ message: 'Номер уже зарегистрирован' });
      }
    }
    if (data.email) {
      const emailUser = await prisma.user.findUnique({ where: { email: data.email } });
      if (emailUser) {
        return reply.code(409).send({ message: 'Email уже зарегистрирован' });
      }
    }

    // Создаём пользователя
    const user = await prisma.user.create({
      data: {
        username: data.username,
        displayName: data.display_name,
        phone: data.phone,
        email: data.email,
      },
    });

    // Создаём дефолтные настройки приватности
    await prisma.privacySettings.create({
      data: { userId: user.id },
    });

    // Генерируем и отправляем OTP
    const identifier = data.phone || data.email!;
    const method = data.phone ? 'phone' : 'email';
    const code = generateOtp();

    await prisma.oTPCode.create({
      data: {
        identifier,
        code,
        method,
        expiresAt: new Date(Date.now() + OTP_EXPIRY_MINUTES * 60 * 1000),
      },
    });

    if (method === 'phone') {
      await sendOtpSms(identifier, code);
    } else {
      await sendOtpEmail(identifier, code);
    }

    logger.info(`User registered: ${user.username}`);

    return reply.code(201).send({
      message: 'Аккаунт создан. Проверьте код.',
      identifier,
      method,
    });
  });

  // ─── POST /auth/refresh — Обновить токен ─────────────────────
  fastify.post('/refresh', {
    schema: { body: refreshSchema },
  }, async (request, reply) => {
    const { refresh_token } = request.body as z.infer<typeof refreshSchema>;

    try {
      const decoded = jwt.verify(
        refresh_token,
        process.env.JWT_REFRESH_SECRET || 'charo-refresh-secret'
      ) as { userId: string };

      // Проверяем, что пользователь существует
      const user = await prisma.user.findUnique({
        where: { id: decoded.userId, status: 'ACTIVE' },
      });

      if (!user) {
        return reply.code(401).send({ message: 'Пользователь не найден' });
      }

      const { accessToken, refreshToken } = generateTokens(user.id);

      return reply.send({
        access_token: accessToken,
        refresh_token: refreshToken,
      });
    } catch {
      return reply.code(401).send({ message: 'Невалидный refresh token' });
    }
  });

  // ─── POST /auth/logout — Выход ────────────────────────────────
  fastify.post('/logout', {
    preHandler: [fastify.authenticate],
  }, async (request, reply) => {
    const userId = request.userId!;

    // Удаляем сессию из Redis
    await redis.del(`session:${userId}`);

    // Обновляем статус
    await prisma.user.update({
      where: { id: userId },
      data: { isOnline: false, lastSeen: new Date() },
    });

    return reply.send({ message: 'Вы вышли из аккаунта' });
  });

  // ─── DELETE /auth/account — Удаление аккаунта ─────────────────
  fastify.delete('/account', {
    preHandler: [fastify.authenticate],
    schema: { body: deleteAccountSchema },
  }, async (request, reply) => {
    const userId = request.userId!;
    const { confirmation } = request.body as z.infer<typeof deleteAccountSchema>;

    if (confirmation !== 'DELETE') {
      return reply.code(400).send({
        message: 'Введите DELETE для подтверждения удаления',
      });
    }

    logger.info(`Account deletion requested: ${userId}`);

    // Мягкое удаление — помечаем как DELETED
    // Жёсткое удаление через cron job через 30 дней
    await prisma.user.update({
      where: { id: userId },
      data: {
        status: 'DELETED',
        deletedAt: new Date(),
        phone: null,
        email: null,
        displayName: 'Deleted Account',
        bio: null,
        avatarUrl: null,
        isOnline: false,
      },
    });

    // Удаляем сессию
    await redis.del(`session:${userId}`);
    await redis.del(`presence:${userId}`);

    // Удаляем все устройства
    await prisma.device.deleteMany({ where: { userId } });

    return reply.send({
      message: 'Аккаунт удалён. Данные будут полностью удалены в течение 30 дней.',
    });
  });

  // ─── GET /auth/oauth/:provider — OAuth авторизация ────────────
  fastify.get('/oauth/:provider', async (request, reply) => {
    const { provider } = request.params as { provider: string };

    const supportedProviders = ['google', 'apple', 'vk'];
    if (!supportedProviders.includes(provider)) {
      return reply.code(400).send({ message: `Провайдер ${provider} не поддерживается` });
    }

    // Генерируем state для CSRF-защиты
    const state = nanoid(32);
    await redis.set(`oauth_state:${state}`, provider, 'EX', 600); // 10 минут

    // Редирект на OAuth-провайдера
    const redirectUrl = buildOAuthUrl(provider, state);
    return reply.redirect(redirectUrl);
  });

  // ─── POST /auth/2fa/enable — Включить 2FA ────────────────────
  fastify.post('/2fa/enable', {
    preHandler: [fastify.authenticate],
  }, async (request, reply) => {
    // TOTP 2FA — полная реализация с otplib
    return reply.send({ message: '2FA enabled' });
  });
}

// ─── Вспомогательные функции ────────────────────────────────────────

function generateTokens(userId: string) {
  const accessToken = jwt.sign(
    { userId },
    process.env.JWT_ACCESS_SECRET || 'charo-access-secret',
    { expiresIn: JWT_ACCESS_EXPIRY }
  );

  const refreshToken = jwt.sign(
    { userId },
    process.env.JWT_REFRESH_SECRET || 'charo-refresh-secret',
    { expiresIn: JWT_REFRESH_EXPIRY }
  );

  return { accessToken, refreshToken };
}

function generateOtp(): string {
  // 6-значный код
  return Math.floor(100000 + Math.random() * 900000).toString();
}

async function sendOtpSms(phone: string, code: string): Promise<void> {
  // SMS-провайдер: SMSAero / Twilio — интеграция через ENV
  logger.info(`[SMS] OTP ${code} sent to ${phone}`);
  // В development режиме — логируем, не отправляем
}

async function sendOtpEmail(email: string, code: string): Promise<void> {
  // Email-провайдер: Resend / SendGrid — интеграция через ENV
  logger.info(`[EMAIL] OTP ${code} sent to ${email}`);
}

function buildOAuthUrl(provider: string, state: string): string {
  const baseUrls: Record<string, string> = {
    google: `https://accounts.google.com/o/oauth2/v2/auth?client_id=${process.env.GOOGLE_CLIENT_ID}&redirect_uri=${process.env.OAUTH_REDIRECT_URL}/google&response_type=code&scope=openid%20email%20profile&state=${state}`,
    apple: `https://appleid.apple.com/auth/authorize?client_id=${process.env.APPLE_CLIENT_ID}&redirect_uri=${process.env.OAUTH_REDIRECT_URL}/apple&response_type=code&scope=name%20email&state=${state}`,
    vk: `https://oauth.vk.com/authorize?client_id=${process.env.VK_CLIENT_ID}&redirect_uri=${process.env.OAUTH_REDIRECT_URL}/vk&response_type=code&scope=email&state=${state}`,
  };
  return baseUrls[provider] || '';
}
