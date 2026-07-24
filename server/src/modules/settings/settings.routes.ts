import { FastifyInstance } from 'fastify';
import { z } from 'zod';

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

  // PATCH /settings/privacy — Настройки приватности
  fastify.patch('/privacy', { schema: { body: privacySchema } }, async (request, reply) => {
    const userId = request.userId!;
    const body = request.body as z.infer<typeof privacySchema>;

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
  fastify.patch('/notifications', { schema: { body: notificationSchema } }, async (request, reply) => {
    const userId = request.userId!;
    const body = request.body as z.infer<typeof notificationSchema>;

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
  fastify.patch('/appearance', async (request, reply) => {
    const userId = request.userId!;
    const body = request.body as { language?: string; theme?: string };
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
