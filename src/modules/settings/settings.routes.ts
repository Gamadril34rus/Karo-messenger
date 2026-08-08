// © 2024-2026 Бутаев Алексей Юрьевич. All rights reserved. PROPRIETARY AND CONFIDENTIAL.
import { FastifyInstance } from 'fastify';
import { z } from 'zod';

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

const privacySchema = z.object({
  profileVisibility: z.enum(['EVERYONE', 'CONTACTS', 'NOBODY']).optional(),
  lastSeenVisibility: z.enum(['EVERYONE', 'CONTACTS', 'NOBODY']).optional(),
  avatarVisibility: z.enum(['EVERYONE', 'CONTACTS', 'NOBODY']).optional(),
  phoneVisibility: z.enum(['EVERYONE', 'CONTACTS', 'NOBODY']).optional(),
  whoCanMessage: z.enum(['EVERYONE', 'CONTACTS', 'NOBODY']).optional(),
  whoCanAddToGroups: z.enum(['EVERYONE', 'CONTACTS', 'NOBODY']).optional(),
  whoCanCall: z.enum(['EVERYONE', 'CONTACTS', 'NOBODY']).optional(),
  readReceipts: z.boolean().optional(),
  typingIndicator: z.boolean().optional(),
});

const notificationSchema = z.object({
  pushEnabled: z.boolean().optional(),
  soundEnabled: z.boolean().optional(),
  vibrationEnabled: z.boolean().optional(),
  previewEnabled: z.boolean().optional(),
  groupMentions: z.boolean().optional(),
  quietHoursEnabled: z.boolean().optional(),
  quietHoursStart: z.string().regex(/^\d{2}:\d{2}$/).optional(),
  quietHoursEnd: z.string().regex(/^\d{2}:\d{2}$/).optional(),
});

const appearanceSchema = z.object({
  language: z.string().max(10).optional(),
  theme: z.enum(['light', 'dark', 'system']).optional(),
});

export async function settingsRoutes(fastify: FastifyInstance) {
  const { prisma } = fastify;

  // GET /settings — Все настройки
  fastify.get('/', async (request, reply) => {
    const userId = request.userId!;

    const [privacy, push] = await Promise.all([
      prisma.privacySettings.findUnique({ where: { userId } }),
      prisma.pushSettings.findUnique({ where: { userId } }),
    ]);

    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: { language: true },
    });

    return reply.send({
      privacy: privacy ?? {},
      notifications: push ?? {},
      language: user?.language ?? 'ru',
    });
  });

  // GET /settings/privacy — Настройки приватности
  fastify.get('/privacy', async (request, reply) => {
    const userId = request.userId!;

    const privacy = await prisma.privacySettings.findUnique({ where: { userId } });

    return reply.send(privacy ?? {
      profileVisibility: 'EVERYONE',
      lastSeenVisibility: 'EVERYONE',
      avatarVisibility: 'EVERYONE',
      phoneVisibility: 'CONTACTS',
      whoCanMessage: 'EVERYONE',
      whoCanAddToGroups: 'CONTACTS',
      whoCanCall: 'EVERYONE',
      readReceipts: true,
      typingIndicator: true,
    });
  });

  // GET /settings/notifications — Настройки уведомлений
  fastify.get('/notifications', async (request, reply) => {
    const userId = request.userId!;

    const push = await prisma.pushSettings.findUnique({ where: { userId } });

    return reply.send(push ?? {
      pushEnabled: true,
      soundEnabled: true,
      vibrationEnabled: true,
      previewEnabled: true,
      groupMentions: true,
    });
  });

  // PATCH /settings/privacy — Настройки приватности
  fastify.patch('/privacy', {}, async (request, reply) => {
    const userId = request.userId!;
    const body = validateBody(privacySchema, request.body);

    const privacy = await prisma.privacySettings.upsert({
      where: { userId },
      update: {
        ...(body.profileVisibility !== undefined ? { profileVisibility: body.profileVisibility } : {}),
        ...(body.lastSeenVisibility !== undefined ? { lastSeenVisibility: body.lastSeenVisibility } : {}),
        ...(body.avatarVisibility !== undefined ? { avatarVisibility: body.avatarVisibility } : {}),
        ...(body.phoneVisibility !== undefined ? { phoneVisibility: body.phoneVisibility } : {}),
        ...(body.whoCanMessage !== undefined ? { whoCanMessage: body.whoCanMessage } : {}),
        ...(body.whoCanAddToGroups !== undefined ? { whoCanAddToGroups: body.whoCanAddToGroups } : {}),
        ...(body.whoCanCall !== undefined ? { whoCanCall: body.whoCanCall } : {}),
        ...(body.readReceipts !== undefined ? { readReceipts: body.readReceipts } : {}),
        ...(body.typingIndicator !== undefined ? { typingIndicator: body.typingIndicator } : {}),
      },
      create: { userId, ...body },
    });

    return reply.send(privacy);
  });

  // PATCH /settings/notifications — Настройки уведомлений
  fastify.patch('/notifications', {}, async (request, reply) => {
    const userId = request.userId!;
    const body = validateBody(notificationSchema, request.body);

    const push = await prisma.pushSettings.upsert({
      where: { userId },
      update: {
        ...(body.pushEnabled !== undefined ? { pushEnabled: body.pushEnabled } : {}),
        ...(body.soundEnabled !== undefined ? { soundEnabled: body.soundEnabled } : {}),
        ...(body.vibrationEnabled !== undefined ? { vibrationEnabled: body.vibrationEnabled } : {}),
        ...(body.previewEnabled !== undefined ? { previewEnabled: body.previewEnabled } : {}),
        ...(body.groupMentions !== undefined ? { groupMentions: body.groupMentions } : {}),
      },
      create: { userId, ...body },
    });

    return reply.send(push);
  });

  // PATCH /settings/appearance — Настройки внешнего вида
  fastify.patch('/appearance', {}, async (request, reply) => {
    const userId = request.userId!;
    const body = validateBody(appearanceSchema, request.body);
    if (body.language) {
      await prisma.user.update({ where: { id: userId }, data: { language: body.language } });
    }
    return reply.send({ updated: true });
  });

  // PATCH /settings/network — Настройки сети
  fastify.patch('/network', async (request, reply) => {
    // Настройки сети хранятся на клиенте (прокси, DNS)
    return reply.send({ updated: true });
  });

  // PATCH /settings/storage — Настройки хранилища
  fastify.patch('/storage', async (request, reply) => {
    return reply.send({ updated: true });
  });
}
