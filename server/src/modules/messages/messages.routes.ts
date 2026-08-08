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

const sendSchema = z.object({
  chatId: z.string().uuid(),
  type: z.enum(['text', 'image', 'video', 'voice', 'video_note', 'file', 'sticker', 'gif', 'location', 'contact', 'poll']),
  content: z.any(),
  replyToId: z.string().uuid().optional(),
});

const editSchema = z.object({ content: z.any() });

const reactSchema = z.object({
  emoji: z.string().min(1).max(10),
});

export async function messagesRoutes(fastify: FastifyInstance) {
  const { prisma } = fastify;

  // GET /messages/:id — Одно сообщение
  fastify.get('/:id', async (request, reply) => {
    const { id } = request.params as { id: string };
    const message = await prisma.message.findUnique({
      where: { id },
      include: {
        sender: { select: { id: true, username: true, displayName: true, avatarUrl: true } },
        statuses: true,
        reactions: true,
        media: true,
      },
    });
    if (!message) return reply.code(404).send({ message: 'Сообщение не найдено' });
    return reply.send(message);
  });

  // PATCH /messages/:id — Редактировать сообщение
  fastify.patch('/:id', {}, async (request, reply) => {
    const { id } = request.params as { id: string };
    const userId = request.userId!;
    const { content } = validateBody(editSchema, request.body);

    const message = await prisma.message.findUnique({ where: { id } });
    if (!message) return reply.code(404).send({ message: 'Сообщение не найдено' });
    if (message.senderId !== userId) return reply.code(403).send({ message: 'Можно редактировать только свои сообщения' });

    const updated = await prisma.message.update({
      where: { id },
      data: { content, isEdited: true },
    });

    return reply.send(updated);
  });

  // DELETE /messages/:id — Удалить сообщение
  fastify.delete('/:id', async (request, reply) => {
    const { id } = request.params as { id: string };
    const userId = request.userId!;

    const message = await prisma.message.findUnique({ where: { id } });
    if (!message) return reply.code(404).send({ message: 'Сообщение не найдено' });

    const membership = await prisma.chatMember.findUnique({
      where: { chatId_userId: { chatId: message.chatId, userId } },
    });
    if (!membership) return reply.code(403).send({ message: 'Нет доступа' });

    // Пользователь может удалить своё сообщение, админ — любое
    if (message.senderId !== userId && membership.role !== 'ADMIN' && membership.role !== 'OWNER') {
      return reply.code(403).send({ message: 'Недостаточно прав' });
    }

    await prisma.message.update({ where: { id }, data: { isDeleted: true, content: { isSet: false } } });
    return reply.code(204).send();
  });

  // POST /messages/:id/react — Реакция
  fastify.post('/:id/react', {}, async (request, reply) => {
    const { id } = request.params as { id: string };
    const userId = request.userId!;
    const { emoji } = validateBody(reactSchema, request.body);

    const existing = await prisma.reaction.findUnique({
      where: { messageId_userId_emoji: { messageId: id, userId, emoji } },
    });

    if (existing) {
      await prisma.reaction.delete({ where: { id: existing.id } });
      return reply.send({ action: 'removed' });
    } else {
      const reaction = await prisma.reaction.create({
        data: { messageId: id, userId, emoji },
      });
      return reply.code(201).send(reaction);
    }
  });
}
