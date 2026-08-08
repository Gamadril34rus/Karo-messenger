// © 2024-2026 Бутаев Алексей Юрьевич. All rights reserved. PROPRIETARY AND CONFIDENTIAL.
/**
 * Auth Routes — Регистрация, вход, верификация, OAuth, удаление аккаунта,
 * восстановление, экспорт данных, согласие на обработку данных
 */

import { FastifyInstance } from 'fastify';
import { z } from 'zod';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import crypto from 'crypto';
import { nanoid } from 'nanoid';

import { logger } from '../../utils/logger';

// ─── Validation helper ─────────────────────────────────────────────
function validateBody<T>(schema: import('zod').ZodSchema<T>, body: unknown): T {
  const result = schema.safeParse(body);
  if (!result.success) {
    const err = new Error(result.error.issues[0]?.message || 'Validation error') as any;
    err.statusCode = 400;
    throw err;
  }
  return result.data;
}

// ─── Схемы валидации ───────────────────────────────────────────────

const loginSchema = z.object({
  identifier: z.string().min(1, 'Введите номер или email'),
  method: z.enum(['phone', 'email']),
});

const loginPasswordSchema = z.object({
  identifier: z.string().min(1),
  password: z.string().min(6, 'Минимум 6 символов'),
});

const verifySchema = z.object({
  identifier: z.string(),
  code: z.string().length(6, 'Код должен содержать 6 цифр'),
  method: z.enum(['phone', 'email']),
});

const registerSchema = z.object({
  username: z.string().min(3).max(64).regex(/^[a-zA-Z0-9_]+$/),
  display_name: z.string().min(1).max(128),
  phone: z.string().min(10, 'Укажите реальный номер телефона').regex(/^\+?\d{10,15}$/, 'Неверный формат номера телефона'),
  email: z.string().email().optional(),
  password: z.string().min(6).max(128).optional(),
  consent_given: z.literal(true, { message: 'Необходимо согласие на обработку данных' }),
  age_confirmed: z.literal(true, { message: 'Необходимо подтвердить возраст (13+)' }),
  terms_accepted: z.literal(true, { message: 'Необходимо принять Условия использования' }),
});

const deleteAccountSchema = z.object({
  confirmation: z.literal('DELETE'),
});

const refreshSchema = z.object({
  refresh_token: z.string(),
});

const recoverSchema = z.object({
  username: z.string().min(3),
  backup_identifier: z.string().min(1, 'Укажите запасной телефон или email'),
});

const restoreSchema = z.object({
  account_id: z.string(),
  verification_code: z.string().length(8),
});

const exportDataSchema = z.object({
  format: z.enum(['json', 'csv']).optional(),
});

// ─── Константы ─────────────────────────────────────────────────────

const JWT_ACCESS_EXPIRY = '15m';
const JWT_REFRESH_EXPIRY = '30d'; // 30 days — matches recovery window
const OTP_EXPIRY_MINUTES = 5;
const MAX_OTP_VERIFY_ATTEMPTS = 5; // Anti brute-force
const OTP_VERIFY_LOCKOUT_MINUTES = 15; // Lockout after max attempts
const ACCOUNT_RECOVERY_WINDOW_DAYS = 30;

// ─── Routes ────────────────────────────────────────────────────────

export async function authRoutes(fastify: FastifyInstance) {
  const { prisma, redis } = fastify;

  // ─── POST /auth/login — Отправить OTP ─────────────────────────
  fastify.post('/login', {
    config: { rateLimit: { max: 5, timeWindow: '1 minute' } },
  }, async (request, reply) => {
    const { identifier, method } = validateBody(loginSchema, request.body);

    // Rate limit: 1 OTP per minute
    const lastSent = await redis.get(`otp_limit:${identifier}`);
    if (lastSent) {
      const elapsed = Date.now() - parseInt(lastSent);
      if (elapsed < 60_000) {
        return reply.code(429).send({
          message: 'Код уже отправлен. Подождите 1 минуту.',
          retry_after: Math.ceil((60_000 - elapsed) / 1000),
        });
      }
    }

    const user = await prisma.user.findFirst({
      where: {
        OR: [{ phone: identifier }, { email: identifier }],
        status: 'ACTIVE',
      },
    });

    if (!user) {
      // SECURITY: Do NOT reveal whether user exists — return same message
      // to prevent user enumeration attack
      return reply.code(200).send({
        message: 'Если этот номер/email зарегистрирован, код отправлен.',
        expires_in: OTP_EXPIRY_MINUTES * 60,
      });
    }

    const code = generateSecureOtp();

    await prisma.otpCode.create({
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

    await redis.set(`otp_limit:${identifier}`, Date.now().toString(), 'EX', 60);

    logger.info(`OTP sent to ${identifier} via ${method}`);

    return reply.send({
      message: 'Если этот номер/email зарегистрирован, код отправлен.',
      expires_in: OTP_EXPIRY_MINUTES * 60,
    });
  });

  // ─── POST /auth/login/password — Вход по паролю ──────────────
  fastify.post('/login/password', {
    config: { rateLimit: { max: 5, timeWindow: '1 minute' } },
  }, async (request, reply) => {
    const { identifier, password } = validateBody(loginPasswordSchema, request.body);

    // Rate limit: 5 password attempts per 15 minutes
    const attemptsKey = `pw_attempts:${identifier}`;
    const attempts = parseInt(await redis.get(attemptsKey) || '0');
    if (attempts >= MAX_OTP_VERIFY_ATTEMPTS) {
      return reply.code(429).send({
        message: 'Слишком много попыток. Попробуйте позже или используйте OTP.',
      });
    }

    const user = await prisma.user.findFirst({
      where: {
        OR: [{ phone: identifier }, { email: identifier }, { username: identifier }],
        status: 'ACTIVE',
      },
    });

    if (!user || !user.passwordHash) {
      await redis.set(attemptsKey, (attempts + 1).toString(), 'EX', OTP_VERIFY_LOCKOUT_MINUTES * 60);
      return reply.code(401).send({ message: 'Неверные данные' });
    }

    const valid = await bcrypt.compare(password, user.passwordHash);
    if (!valid) {
      await redis.set(attemptsKey, (attempts + 1).toString(), 'EX', OTP_VERIFY_LOCKOUT_MINUTES * 60);
      return reply.code(401).send({ message: 'Неверные данные' });
    }

    // Check 2FA
    if (user.twoFactorSecret) {
      return reply.send({
        requires_2fa: true,
        identifier,
        message: 'Введите код 2FA',
      });
    }

    // Clear attempt counter
    await redis.del(attemptsKey);

    const { accessToken, refreshToken } = generateTokens(user.id);
    await storeSession(redis, user.id);

    return reply.send({
      access_token: accessToken,
      refresh_token: refreshToken,
      user: formatUser(user),
    });
  });

  // ─── POST /auth/verify — Верифицировать OTP ───────────────────
  fastify.post('/verify', {
    config: { rateLimit: { max: 10, timeWindow: '1 minute' } },
  }, async (request, reply) => {
    const { identifier, code, method } = validateBody(verifySchema, request.body);

    // Anti brute-force: max 5 attempts per 15 minutes
    const attemptsKey = `otp_verify:${identifier}`;
    const attempts = parseInt(await redis.get(attemptsKey) || '0');
    if (attempts >= MAX_OTP_VERIFY_ATTEMPTS) {
      return reply.code(429).send({
        message: `Слишком много попыток. Попробуйте через ${OTP_VERIFY_LOCKOUT_MINUTES} минут.`,
      });
    }

    const otp = await prisma.otpCode.findFirst({
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
      await redis.set(attemptsKey, (attempts + 1).toString(), 'EX', OTP_VERIFY_LOCKOUT_MINUTES * 60);
      return reply.code(400).send({ message: 'Неверный или просроченный код' });
    }

    await prisma.otpCode.update({
      where: { id: otp.id },
      data: { isUsed: true },
    });

    // Clear attempt counter
    await redis.del(attemptsKey);

    const user = await prisma.user.findFirst({
      where: {
        OR: [{ phone: identifier }, { email: identifier }],
        status: 'ACTIVE',
      },
    });

    if (!user) {
      return reply.code(404).send({ message: 'Пользователь не найден' });
    }

    // Check 2FA — user must also verify 2FA code
    if (user.twoFactorSecret) {
      const tempToken = jwt.sign(
        { userId: user.id, pending2fa: true },
        process.env.JWT_ACCESS_SECRET || 'charo-access-secret',
        { expiresIn: '5m' },
      );
      return reply.send({
        requires_2fa: true,
        temp_token: tempToken,
        message: 'Введите код 2FA',
      });
    }

    const { accessToken, refreshToken } = generateTokens(user.id);
    await storeSession(redis, user.id);

    return reply.send({
      access_token: accessToken,
      refresh_token: refreshToken,
      user: formatUser(user),
    });
  });

  // ─── POST /auth/register — Регистрация ────────────────────────
  fastify.post('/register', {
    config: { rateLimit: { max: 3, timeWindow: '1 minute' } },
  }, async (request, reply) => {
    const data = validateBody(registerSchema, request.body);

    // CRITICAL: Check consent, age, terms acceptance
    if (!data.consent_given) {
      return reply.code(400).send({ message: 'Необходимо согласие на обработку персональных данных' });
    }
    if (!data.age_confirmed) {
      return reply.code(400).send({ message: 'Необходимо подтвердить, что вы старше 13 лет' });
    }
    if (!data.terms_accepted) {
      return reply.code(400).send({ message: 'Необходимо принять Условия использования' });
    }

    // Check uniqueness
    const existing = await prisma.user.findUnique({ where: { username: data.username } });
    if (existing) {
      return reply.code(409).send({ message: 'Имя пользователя занято' });
    }

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

    // Hash password if provided
    const passwordHash = data.password ? await bcrypt.hash(data.password, 12) : null;

    const user = await prisma.user.create({
      data: {
        username: data.username,
        displayName: data.display_name,
        phone: data.phone,
        email: data.email,
        passwordHash,
      },
    });

    // Create default privacy settings
    await prisma.privacySettings.create({ data: { userId: user.id } });

    // Store consent record (LEGAL REQUIREMENT — ФЗ-152 Art.9, GDPR Art.7)
    await prisma.consentRecord.create({
      data: {
        userId: user.id,
        type: 'REGISTRATION',
        consentGiven: true,
        ageConfirmed: true,
        termsAccepted: true,
        privacyPolicyVersion: '2026-07-27',
        termsVersion: '2026-07-27',
        ipAddress: request.ip,
        userAgent: request.headers['user-agent'] || 'unknown',
      },
    });

    // Send OTP
    const identifier = data.phone || data.email!;
    const method = data.phone ? 'phone' : 'email';
    const code = generateSecureOtp();

    await prisma.otpCode.create({
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

    logger.info(`User registered: ${user.username} (consent recorded, IP: ${request.ip})`);

    return reply.code(201).send({
      message: 'Аккаунт создан. Проверьте код.',
      identifier,
      method,
    });
  });

  // ─── POST /auth/refresh — Обновить токен ─────────────────────
  fastify.post('/refresh', {
  }, async (request, reply) => {
    const { refresh_token } = validateBody(refreshSchema, request.body);

    try {
      const decoded = jwt.verify(
        refresh_token,
        process.env.JWT_REFRESH_SECRET || 'charo-refresh-secret',
      ) as { userId: string };

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
    await redis.del(`session:${userId}`);
    await prisma.user.update({
      where: { id: userId },
      data: { isOnline: false, lastSeen: new Date() },
    });
    return reply.send({ message: 'Вы вышли из аккаунта' });
  });

  // ─── DELETE /auth/account — Удаление аккаунта ─────────────────
  fastify.delete('/account', {
    preHandler: [fastify.authenticate],
  }, async (request, reply) => {
    const userId = request.userId!;
    const { confirmation } = validateBody(deleteAccountSchema, request.body);

    if (confirmation !== 'DELETE') {
      return reply.code(400).send({ message: 'Введите DELETE для подтверждения удаления' });
    }

    logger.info(`Account deletion requested: ${userId}`);

    // Soft delete — 30-day recovery window (GDPR right to restore, ФЗ-152)
    const recoveryCode = crypto.randomBytes(4).toString('hex').toUpperCase(); // 8-char code

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

    // Store recovery info in Redis (30 days TTL)
    await redis.set(
      `account_recovery:${userId}`,
      JSON.stringify({
        recoveryCode,
        deletedAt: Date.now(),
        expiresAt: Date.now() + ACCOUNT_RECOVERY_WINDOW_DAYS * 24 * 60 * 60 * 1000,
      }),
      'EX',
      ACCOUNT_RECOVERY_WINDOW_DAYS * 24 * 60 * 60,
    );

    await redis.del(`session:${userId}`);
    await redis.del(`presence:${userId}`);
    await prisma.device.deleteMany({ where: { userId } });

    return reply.send({
      message: `Аккаунт удалён. Восстановление возможно в течение ${ACCOUNT_RECOVERY_WINDOW_DAYS} дней.`,
      account_id: userId,
      recovery_code: recoveryCode,
      recovery_url: `${process.env.APP_URL || 'https://app.charo.chat'}/auth/recover?id=${userId}&code=${recoveryCode}`,
    });
  });

  // ─── POST /auth/recover — Восстановление удалённого аккаунта ──
  fastify.post('/recover', {
    config: { rateLimit: { max: 3, timeWindow: '1 minute' } },
  }, async (request, reply) => {
    const { account_id, verification_code } = validateBody(restoreSchema, request.body);

    const recoveryData = await redis.get(`account_recovery:${account_id}`);
    if (!recoveryData) {
      return reply.code(404).send({
        message: 'Восстановление невозможно — срок истёк или аккаунт не был удалён.',
      });
    }

    const parsed = JSON.parse(recoveryData);
    if (parsed.recoveryCode !== verification_code.toUpperCase()) {
      return reply.code(400).send({ message: 'Неверный код восстановления' });
    }

    // Restore account
    await prisma.user.update({
      where: { id: account_id },
      data: {
        status: 'ACTIVE',
        deletedAt: null,
        displayName: 'Restored Account',
      },
    });

    // Clear recovery data
    await redis.del(`account_recovery:${account_id}`);

    logger.info(`Account restored: ${account_id}`);

    // Generate new tokens
    const { accessToken, refreshToken } = generateTokens(account_id);
    await storeSession(redis, account_id);

    return reply.send({
      message: 'Аккаунт восстановлен. Установите новый телефон/email в настройках.',
      access_token: accessToken,
      refresh_token: refreshToken,
    });
  });

  // ─── POST /auth/forgot — Запросить восстановление доступа ─────
  fastify.post('/forgot', {
  }, async (request, reply) => {
    const { username, backup_identifier } = validateBody(recoverSchema, request.body);

    const user = await prisma.user.findUnique({
      where: { username },
    });

    if (!user || user.status !== 'ACTIVE') {
      // Same anti-enumeration: don't reveal if username exists
      return reply.send({
        message: 'Если аккаунт существует и запасной контакт совпадает — код отправлен.',
      });
    }

    // Check if backup_identifier matches user's email or phone
    const isPhoneMatch = user.phone === backup_identifier;
    const isEmailMatch = user.email === backup_identifier;
    if (!isPhoneMatch && !isEmailMatch) {
      return reply.send({
        message: 'Если аккаунт существует и запасной контакт совпадает — код отправлен.',
      });
    }

    // Send recovery OTP to backup contact
    const method = isPhoneMatch ? 'phone' : 'email';
    const code = generateSecureOtp();

    await prisma.otpCode.create({
      data: {
        identifier: backup_identifier,
        code,
        method,
        expiresAt: new Date(Date.now() + OTP_EXPIRY_MINUTES * 60 * 1000),
      },
    });

    if (method === 'phone') {
      await sendOtpSms(backup_identifier, code);
    } else {
      await sendOtpEmail(backup_identifier, code);
    }

    return reply.send({
      message: 'Код восстановления отправлен на запасной контакт.',
    });
  });

  // ─── GET /auth/export-data — Экспорт данных пользователя (GDPR/ФЗ-152) ──
  fastify.get('/export-data', {
    preHandler: [fastify.authenticate],
  }, async (request, reply) => {
    const userId = request.userId!;

    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        username: true,
        displayName: true,
        bio: true,
        avatarUrl: true,
        phone: true,
        email: true,
        language: true,
        createdAt: true,
      },
    });

    if (!user) {
      return reply.code(404).send({ message: 'Пользователь не найден' });
    }

    // Contacts
    const contacts = await prisma.contact.findMany({
      where: { userId },
      select: { contactUserId: true, displayName: true, addedAt: true },
    });

    // Chats (own messages only — cannot export other's E2EE messages)
    const memberships = await prisma.chatMember.findMany({
      where: { userId },
      include: { chat: { select: { id: true, type: true, title: true } } },
    });

    const ownMessages = await prisma.message.findMany({
      where: { senderId: userId, isDeleted: false },
      select: { id: true, chatId: true, type: true, createdAt: true, isEdited: true },
      take: 10000, // Reasonable limit
    });

    // Privacy settings
    const privacySettings = await prisma.privacySettings.findUnique({
      where: { userId },
    });

    // Consent records
    const consents = await prisma.consentRecord.findMany({
      where: { userId },
      select: { type: true, consentGiven: true, createdAt: true },
    });

    const exportData = {
      export_date: new Date().toISOString(),
      format_version: '1.0',
      user: {
        id: user.id,
        username: user.username,
        display_name: user.displayName,
        bio: user.bio,
        phone: user.phone,
        email: user.email,
        language: user.language,
        created_at: user.createdAt.toISOString(),
      },
      contacts: contacts.map(c => ({
        user_id: c.contactUserId,
        display_name: c.displayName,
        added_at: c.addedAt.toISOString(),
      })),
      chats: memberships.map(m => ({
        id: m.chat.id,
        type: m.chat.type,
        title: m.chat.title,
        role: m.role,
      })),
      own_messages: ownMessages.map(m => ({
        id: m.id,
        chat_id: m.chatId,
        type: m.type,
        created_at: m.createdAt.toISOString(),
        is_edited: m.isEdited,
      })),
      privacy_settings: privacySettings,
      consent_records: consents,
      note: 'E2EE-encrypted message content cannot be exported from server. Use local chat export for full message content.',
    };

    logger.info(`Data export requested by ${userId}`);

    return reply.send(exportData);
  });

  // ─── GET /auth/oauth/:provider — OAuth авторизация ────────────
  fastify.get('/oauth/:provider', async (request, reply) => {
    const { provider } = request.params as { provider: string };

    const supportedProviders = ['google', 'apple', 'vk'];
    if (!supportedProviders.includes(provider)) {
      return reply.code(400).send({ message: `Провайдер ${provider} не поддерживается` });
    }

    const state = nanoid(32);
    await redis.set(`oauth_state:${state}`, provider, 'EX', 600);

    const redirectUrl = buildOAuthUrl(provider, state);
    return reply.redirect(redirectUrl);
  });

  // ─── GET /auth/oauth/callback — OAuth callback ────────────────
  fastify.get('/oauth/callback', async (request, reply) => {
    const { code, state } = request.query as { code?: string; state?: string };

    if (!code || !state) {
      return reply.code(400).send({ message: 'Отсутствует code или state' });
    }

    const storedProvider = await redis.get(`oauth_state:${state}`);
    if (!storedProvider) {
      return reply.code(400).send({ message: 'Невалидный или истёкший state' });
    }

    // Exchange code for token with OAuth provider
    const provider = storedProvider;
    const tokens = await exchangeOAuthCode(provider, code, state);

    if (!tokens) {
      return reply.code(400).send({ message: 'Ошибка авторизации через OAuth' });
    }

    // Get user info from provider
    const userInfo = await getOAuthUserInfo(provider, tokens.access_token);

    // Find or create user by OAuth email/id
    let user = await prisma.user.findFirst({
      where: {
        OR: [{ email: userInfo.email }, { phone: userInfo.phone }],
        status: 'ACTIVE',
      },
    });

    if (!user) {
      // Auto-register with consent (OAuth inherently provides consent)
      user = await prisma.user.create({
        data: {
          username: userInfo.username || `oauth_${nanoid(8)}`,
          displayName: userInfo.name || userInfo.username || 'OAuth User',
          email: userInfo.email,
          phone: userInfo.phone,
          avatarUrl: userInfo.picture,
        },
      });

      await prisma.privacySettings.create({ data: { userId: user.id } });

      // Record OAuth consent
      await prisma.consentRecord.create({
        data: {
          userId: user.id,
          type: 'OAUTH_REGISTRATION',
          consentGiven: true,
          ageConfirmed: true,
          termsAccepted: true,
          privacyPolicyVersion: '2026-07-27',
          termsVersion: '2026-07-27',
          ipAddress: request.ip,
          userAgent: request.headers['user-agent'] || 'unknown',
          oauthProvider: provider,
        },
      });

      logger.info(`OAuth auto-registration: ${user.username} via ${provider}`);
    }

    // Clear state
    await redis.del(`oauth_state:${state}`);

    const { accessToken, refreshToken } = generateTokens(user.id);
    await storeSession(redis, user.id);

    // Redirect to app with tokens
    const appUrl = process.env.APP_URL || 'https://app.charo.chat';
    return reply.redirect(
      `${appUrl}/auth/callback?access_token=${accessToken}&refresh_token=${refreshToken}`
    );
  });

  // ─── POST /auth/2fa/enable — Enable TOTP 2FA ────────────────
  fastify.post('/2fa/enable', {
    config: { rateLimit: { max: 3, timeWindow: '1 minute' } },
    preHandler: [fastify.authenticate],
  }, async (request, reply) => {
    const userId = request.userId!;
    const { code } = request.body as { code?: string };

    const user = await prisma.user.findUnique({ where: { id: userId } });
    if (!user) return reply.code(404).send({ message: 'Пользователь не найден' });

    if (user.twoFactorSecret && code) {
      const { authenticator } = await import('otplib');
      const isValid = authenticator.check(code, user.twoFactorSecret);
      if (!isValid) {
        return reply.code(400).send({ message: 'Неверный код 2FA' });
      }

      // Generate recovery codes for 2FA (CRITICAL — user can recover if device lost)
      const recoveryCodes = Array.from({ length: 8 }, () =>
        crypto.randomBytes(4).toString('hex').toUpperCase(),
      );

      await redis.set(
        `2fa_recovery:${userId}`,
        JSON.stringify(recoveryCodes),
        'EX',
        365 * 24 * 60 * 60, // 1 year
      );

      logger.info(`2FA enabled for user ${userId}`);
      return reply.send({
        message: '2FA подтверждена и активирована',
        enabled: true,
        recovery_codes: recoveryCodes,
        warning: 'Сохраните recovery codes! Они нужны для входа при потере OTP-устройства.',
      });
    }

    const { authenticator } = await import('otplib');
    const secret = authenticator.generateSecret();
    const appName = 'ЧАРО';

    await prisma.user.update({
      where: { id: userId },
      data: { twoFactorSecret: secret },
    });

    const otpAuthUrl = authenticator.keyuri(user.username || userId, appName, secret);
    const QRCode = await import('qrcode');
    const qrImageDataUrl = await QRCode.toDataURL(otpAuthUrl);

    return reply.send({
      message: '2FA секрет создан. Подтвердите код из приложения.',
      secret,
      otp_auth_url: otpAuthUrl,
      qr_code: qrImageDataUrl,
      enabled: false,
    });
  });

  // ─── GET /auth/sessions — List active sessions ───────────────
  fastify.get('/sessions', {
    preHandler: [fastify.authenticate],
  }, async (request, reply) => {
    const userId = request.userId!;

    // Get all devices/sessions for this user
    const devices = await prisma.device.findMany({
      where: { userId },
      orderBy: { lastActive: 'desc' },
    });

    // Get current session from Redis
    const currentSession = await redis.get(`session:${userId}`);

    const sessions = devices.map((device) => ({
      id: device.id,
      device_name: device.deviceName || 'Неизвестное устройство',
      platform: device.platform || device.deviceType || 'unknown',
      ip: device.ip || '',
      last_active: device.lastActive.toISOString(),
      is_current: device.id === currentSession ? true : false,
    }));

    // Mark the most recent device as current
    if (sessions.length > 0 && !sessions.some(s => s.is_current)) {
      sessions[0].is_current = true;
    }

    return reply.send(sessions);
  });

  // ─── DELETE /auth/sessions/:sessionId — Terminate specific session ──
  fastify.delete('/sessions/:sessionId', {
    preHandler: [fastify.authenticate],
  }, async (request, reply) => {
    const userId = request.userId!;
    const { sessionId } = request.params as { sessionId: string };

    const device = await prisma.device.findFirst({
      where: { id: sessionId, userId },
    });

    if (!device) {
      return reply.code(404).send({ message: 'Сессия не найдена' });
    }

    await prisma.device.delete({ where: { id: sessionId } });

    logger.info(`Session ${sessionId} terminated by ${userId}`);
    return reply.send({ message: 'Сессия завершена' });
  });

  // ─── DELETE /auth/sessions — Terminate all other sessions ────
  fastify.delete('/sessions', {
    preHandler: [fastify.authenticate],
  }, async (request, reply) => {
    const userId = request.userId!;
    const { keep_current } = request.body as { keep_current?: boolean };

    // Get current device
    const currentDevice = await prisma.device.findFirst({
      where: { userId },
      orderBy: { lastActive: 'desc' },
    });

    if (keep_current && currentDevice) {
      await prisma.device.deleteMany({
        where: { userId, id: { not: currentDevice.id } },
      });
    } else {
      await prisma.device.deleteMany({ where: { userId } });
    }

    logger.info(`All other sessions terminated by ${userId}`);
    return reply.send({ message: 'Все другие сессии завершены' });
  });

  // ─── POST /auth/2fa/verify — Verify 2FA during login ─────────
  fastify.post('/2fa/verify', async (request, reply) => {
    const { temp_token, code } = request.body as { temp_token?: string; code: string; identifier?: string };

    // Option 1: Verify with temp_token (after OTP verified)
    if (temp_token) {
      try {
        const decoded = jwt.verify(
          temp_token,
          process.env.JWT_ACCESS_SECRET || 'charo-access-secret',
        ) as { userId: string; pending2fa: boolean };

        if (!decoded.pending2fa) {
          return reply.code(400).send({ message: 'Невалидный temp token' });
        }

        const user = await prisma.user.findUnique({ where: { id: decoded.userId } });
        if (!user || !user.twoFactorSecret) {
          return reply.code(400).send({ message: '2FA не настроена' });
        }

        const { authenticator } = await import('otplib');
        const isValid = authenticator.check(code, user.twoFactorSecret);

        if (!isValid) {
          // Check recovery codes
          const recoveryData = await redis.get(`2fa_recovery:${user.id}`);
          if (recoveryData) {
            const recoveryCodes = JSON.parse(recoveryData) as string[];
            if (recoveryCodes.includes(code.toUpperCase())) {
              // Recovery code used — remove it from list
              const remaining = recoveryCodes.filter(c => c !== code.toUpperCase());
              await redis.set(`2fa_recovery:${user.id}`, JSON.stringify(remaining), 'EX', 365 * 24 * 60 * 60);
              logger.info(`2FA recovery code used by ${user.id}`);
              // Continue to generate tokens below
            } else {
              return reply.code(400).send({ message: 'Неверный код 2FA' });
            }
          } else {
            return reply.code(400).send({ message: 'Неверный код 2FA' });
          }
        }

        const { accessToken, refreshToken } = generateTokens(user.id);
        await storeSession(redis, user.id);

        return reply.send({
          access_token: accessToken,
          refresh_token: refreshToken,
          user: formatUser(user),
        });
      } catch {
        return reply.code(401).send({ message: 'Невалидный temp token' });
      }
    }

    // Option 2: Verify with identifier (legacy, after password login)
    const { identifier } = request.body as { identifier?: string };
    if (!identifier) {
      return reply.code(400).send({ message: 'Укажите temp_token или identifier' });
    }

    const user = await prisma.user.findFirst({
      where: {
        OR: [{ phone: identifier }, { email: identifier }],
        status: 'ACTIVE',
      },
    });

    if (!user || !user.twoFactorSecret) {
      return reply.code(400).send({ message: '2FA не настроена' });
    }

    const { authenticator } = await import('otplib');
    const isValid = authenticator.check(code, user.twoFactorSecret);
    if (!isValid) {
      return reply.code(400).send({ message: 'Неверный код 2FA' });
    }

    const { accessToken, refreshToken } = generateTokens(user.id);
    await storeSession(redis, user.id);

    return reply.send({
      access_token: accessToken,
      refresh_token: refreshToken,
      user: formatUser(user),
    });
  });

  // ─── POST /auth/verify-email — Отправить код подтверждения email ──
  fastify.post('/verify-email', async (request, reply) => {
    const userId = request.userId!;
    const { email } = request.body as { email: string };

    if (!email) {
      return reply.code(400).send({ message: 'Укажите email' });
    }

    // Validate email format
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
      return reply.code(400).send({ message: 'Неверный формат email' });
    }

    // Generate 6-digit code
    const code = generateSecureOtp();

    // Store verification code in DB
    await prisma.otpCode.create({
      data: {
        identifier: email,
        code,
        method: 'email',
        expiresAt: new Date(Date.now() + 5 * 60 * 1000), // 5 minutes
      },
    });

    // Send email
    await sendOtpEmail(email, code);

    logger.info(`Email verification code sent to ${email}`);

    return reply.send({ message: 'Код подтверждения отправлен', expires_in: 300 });
  });

  // ─── POST /auth/verify-email/confirm — Подтвердить email кодом ──
  fastify.post('/verify-email/confirm', async (request, reply) => {
    const userId = request.userId!;
    const { email, code } = request.body as { email: string; code: string };

    if (!email || !code) {
      return reply.code(400).send({ message: 'Укажите email и код' });
    }

    // Anti brute-force
    const attemptsKey = `email_verify:${email}`;
    const attempts = parseInt(await redis.get(attemptsKey) || '0');
    if (attempts >= 5) {
      return reply.code(429).send({ message: 'Слишком много попыток. Попробуйте через 15 минут.' });
    }

    const otp = await prisma.otpCode.findFirst({
      where: {
        identifier: email,
        code,
        method: 'email',
        isUsed: false,
        expiresAt: { gt: new Date() },
      },
      orderBy: { createdAt: 'desc' },
    });

    if (!otp) {
      await redis.set(attemptsKey, (attempts + 1).toString(), 'EX', 15 * 60);
      return reply.code(400).send({ message: 'Неверный или просроченный код' });
    }

    // Mark OTP as used
    await prisma.otpCode.update({
      where: { id: otp.id },
      data: { isUsed: true },
    });

    // Clear attempt counter
    await redis.del(attemptsKey);

    // Mark email as verified
    await prisma.user.update({
      where: { id: userId },
      data: { emailVerified: true },
    });

    logger.info(`Email verified for user ${userId}: ${email}`);

    return reply.send({ message: 'Email подтверждён', verified: true });
  });

  // ─── POST /auth/devices/register — Регистрация push-токена устройства ──
  fastify.post('/devices/register', async (request, reply) => {
    const userId = request.userId!;
    const { platform, push_token, device_name, device_type } = request.body as {
      platform: string;
      push_token: string;
      device_name?: string;
      device_type?: string;
    };

    if (!platform || !push_token) {
      return reply.code(400).send({ message: 'Укажите platform и push_token' });
    }

    // Upsert device with push token
    const device = await prisma.device.upsert({
      where: {
        id: `${userId}_${platform}_${push_token.substring(0, 32)}`,
      },
      create: {
        id: `${userId}_${platform}_${push_token.substring(0, 32)}`,
        userId,
        deviceType: device_type || platform,
        deviceName: device_name || `${platform} device`,
        platform,
        pushToken: push_token,
        lastActive: new Date(),
      },
      update: {
        pushToken: push_token,
        lastActive: new Date(),
        deviceName: device_name || `${platform} device`,
      },
    });

    logger.info(`Push token registered for user ${userId}: ${platform}`);

    return reply.send({ message: 'Устройство зарегистрировано', device_id: device.id });
  });
}

// ─── Helper functions ──────────────────────────────────────────────

function generateTokens(userId: string) {
  const accessToken = jwt.sign(
    { userId },
    process.env.JWT_ACCESS_SECRET || 'charo-access-secret',
    { expiresIn: JWT_ACCESS_EXPIRY },
  );

  const refreshToken = jwt.sign(
    { userId },
    process.env.JWT_REFRESH_SECRET || 'charo-refresh-secret',
    { expiresIn: JWT_REFRESH_EXPIRY },
  );

  return { accessToken, refreshToken };
}

function generateSecureOtp(): string {
  // CRYPTO-SAFE OTP generation — NOT Math.random()
  return crypto.randomInt(100000, 999999).toString();
}

async function storeSession(redis: any, userId: string) {
  await redis.set(
    `session:${userId}`,
    JSON.stringify({ lastActive: Date.now() }),
    'EX',
    30 * 24 * 60 * 60, // 30 days (matches refresh token expiry)
  );
}

function formatUser(user: any) {
  return {
    id: user.id,
    username: user.username,
    display_name: user.displayName,
    avatar_url: user.avatarUrl,
  };
}

async function sendOtpSms(phone: string, code: string): Promise<void> {
  const smsProvider = process.env.SMS_PROVIDER || 'smsaero';
  const smsApiKey = process.env.SMS_API_KEY || '';
  const smsFrom = process.env.SMS_FROM || 'Charo';

  if (!smsApiKey) {
    logger.info(`[SMS] OTP ${code} for ${phone} (no SMS_API_KEY set — logged only)`);
    return;
  }

  try {
    if (smsProvider === 'smsaero') {
      const response = await fetch('https://gate.smsaero.ru/v2/sms/send', {
        method: 'POST',
        headers: {
          'Authorization': `Basic ${Buffer.from(`${smsApiKey}:`).toString('base64')}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          number: phone,
          text: `ЧАРО: Ваш код авторизации — ${code}. Не сообщайте его третьим лицам.`,
          sign: smsFrom,
          channel: 'INFO',
        }),
      });
      if (!response.ok) {
        logger.error(`SMSAero API error: ${response.status}`);
      } else {
        logger.info(`SMS OTP sent to ${phone} via SMSAero`);
      }
    } else if (smsProvider === 'twilio') {
      const twilioAccountSid = process.env.TWILIO_ACCOUNT_SID || '';
      const twilioAuthToken = process.env.TWILIO_AUTH_TOKEN || '';
      const twilioFrom = process.env.TWILIO_FROM || '+1234567890';

      if (!twilioAccountSid || !twilioAuthToken) {
        logger.error('Twilio credentials not configured');
        return;
      }

      const response = await fetch(
        `https://api.twilio.com/2010-04-01/Accounts/${twilioAccountSid}/Messages.json`,
        {
          method: 'POST',
          headers: {
            'Authorization': `Basic ${Buffer.from(`${twilioAccountSid}:${twilioAuthToken}`).toString('base64')}`,
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body: new URLSearchParams({
            From: twilioFrom,
            To: phone,
            Body: `ЧАРО: Ваш код авторизации — ${code}. Не сообщайте его третьим лицам.`,
          }).toString(),
        },
      );
      if (!response.ok) {
        logger.error(`Twilio API error: ${response.status}`);
      } else {
        logger.info(`SMS OTP sent to ${phone} via Twilio`);
      }
    }
  } catch (err) {
    logger.error(`SMS delivery failed: ${err}`);
  }
}

async function sendOtpEmail(email: string, code: string): Promise<void> {
  const emailProvider = process.env.EMAIL_PROVIDER || 'resend';
  const emailApiKey = process.env.EMAIL_API_KEY || '';
  const emailFrom = process.env.EMAIL_FROM || 'noreply@charo.chat';

  if (!emailApiKey) {
    logger.info(`[EMAIL] OTP ${code} for ${email} (no EMAIL_API_KEY set — logged only)`);
    return;
  }

  try {
    if (emailProvider === 'resend') {
      const response = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${emailApiKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          from: `ЧАРО <${emailFrom}>`,
          to: [email],
          subject: 'ЧАРО — Код авторизации',
          html: `
            <div style="font-family: sans-serif; max-width: 400px; margin: 0 auto; padding: 20px;">
              <h2 style="color: #2563EB;">ЧАРО</h2>
              <p>Ваш код авторизации:</p>
              <div style="font-size: 32px; font-weight: bold; color: #2563EB; padding: 16px; background: #EFF6FF; border-radius: 8px; text-align: center;">
                ${code}
              </div>
              <p style="color: #888; font-size: 14px;">Код действителен 5 минут. Не сообщайте его третьим лицам.</p>
              <p style="color: #888; font-size: 12px;">Если вы не запрашивали код — проигнорируйте это письмо.</p>
            </div>
          `,
        }),
      });
      if (!response.ok) {
        logger.error(`Resend API error: ${response.status}`);
      } else {
        logger.info(`Email OTP sent to ${email} via Resend`);
      }
    } else if (emailProvider === 'sendgrid') {
      const response = await fetch('https://api.sendgrid.com/v3/mail/send', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${emailApiKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          personalizations: [{ to: [{ email }] }],
          from: { email: emailFrom, name: 'ЧАРО' },
          subject: 'ЧАРО — Код авторизации',
          content: [{
            type: 'text/html',
            value: `<div style="font-family:sans-serif;text-align:center;"><h2 style="color:#2563EB">ЧАРО</h2><p>Код: <b style="font-size:32px;color:#2563EB">${code}</b></p><p style="color:#888">Действителен 5 минут</p><p style="color:#888;font-size:12px">Если вы не запрашивали код — проигнорируйте это письмо.</p></div>`,
          }],
        }),
      });
      if (!response.ok) {
        logger.error(`SendGrid API error: ${response.status}`);
      } else {
        logger.info(`Email OTP sent to ${email} via SendGrid`);
      }
    }
  } catch (err) {
    logger.error(`Email delivery failed: ${err}`);
  }
}

function buildOAuthUrl(provider: string, state: string): string {
  const baseUrls: Record<string, string> = {
    google: `https://accounts.google.com/o/oauth2/v2/auth?client_id=${process.env.GOOGLE_CLIENT_ID}&redirect_uri=${process.env.OAUTH_REDIRECT_URL}/callback&response_type=code&scope=openid%20email%20profile&state=${state}`,
    apple: `https://appleid.apple.com/auth/authorize?client_id=${process.env.APPLE_CLIENT_ID}&redirect_uri=${process.env.OAUTH_REDIRECT_URL}/callback&response_type=code&scope=name%20email&state=${state}`,
    vk: `https://oauth.vk.com/authorize?client_id=${process.env.VK_CLIENT_ID}&redirect_uri=${process.env.OAUTH_REDIRECT_URL}/callback&response_type=code&scope=email&state=${state}`,
  };
  return baseUrls[provider] || '';
}

async function exchangeOAuthCode(provider: string, code: string, state: string): Promise<any> {
  const configs: Record<string, any> = {
    google: {
      tokenUrl: 'https://oauth2.googleapis.com/token',
      clientId: process.env.GOOGLE_CLIENT_ID,
      clientSecret: process.env.GOOGLE_CLIENT_SECRET,
      redirectUri: `${process.env.OAUTH_REDIRECT_URL}/callback`,
    },
    apple: {
      tokenUrl: 'https://appleid.apple.com/auth/token',
      clientId: process.env.APPLE_CLIENT_ID,
      clientSecret: process.env.APPLE_CLIENT_SECRET,
      redirectUri: `${process.env.OAUTH_REDIRECT_URL}/callback`,
    },
    vk: {
      tokenUrl: 'https://oauth.vk.com/access_token',
      clientId: process.env.VK_CLIENT_ID,
      clientSecret: process.env.VK_CLIENT_SECRET,
      redirectUri: `${process.env.OAUTH_REDIRECT_URL}/callback`,
    },
  };

  const config = configs[provider];
  if (!config) return null;

  try {
    const response = await fetch(config.tokenUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        code,
        client_id: config.clientId,
        client_secret: config.clientSecret,
        redirect_uri: config.redirectUri,
        grant_type: 'authorization_code',
      }).toString(),
    });

    if (!response.ok) {
      logger.error(`OAuth token exchange failed for ${provider}: ${response.status}`);
      return null;
    }

    return await response.json();
  } catch (err) {
    logger.error(`OAuth exchange error: ${err}`);
    return null;
  }
}

async function getOAuthUserInfo(provider: string, accessToken: string): Promise<any> {
  const urls: Record<string, string> = {
    google: 'https://www.googleapis.com/oauth2/v2/userinfo',
    vk: 'https://api.vk.com/method/users.get?fields=photo_max,email&access_token=',
  };

  try {
    if (provider === 'google') {
      const response = await fetch(urls.google, {
        headers: { Authorization: `Bearer ${accessToken}` },
      });
      const data: any = await response.json();
      return {
        email: data.email as string | undefined,
        name: data.name as string | undefined,
        picture: data.picture as string | undefined,
        username: (data.email as string)?.split('@')[0],
      };
    } else if (provider === 'vk') {
      const response = await fetch(`${urls.vk}${accessToken}`);
      const vkData: any = await response.json();
      const vkUser = vkData.response?.[0];
      return {
        name: `${vkUser?.first_name ?? ''} ${vkUser?.last_name ?? ''}`,
        picture: vkUser?.photo_max as string | undefined,
        username: `vk_${vkUser?.id ?? nanoid(8)}`,
      };
    } else if (provider === 'apple') {
      // Apple returns user info in the ID token
      // Decode JWT id_token to get email and name
      return { username: `apple_${Date.now()}` };
    }
  } catch (err) {
    logger.error(`OAuth userinfo error: ${err}`);
  }

  return { username: `oauth_${nanoid(8)}` };
}
