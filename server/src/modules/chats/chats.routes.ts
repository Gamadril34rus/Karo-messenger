import { FastifyInstance } from 'fastify';
import { ChatType } from '@prisma/client';
import { z } from 'zod';

const createChatSchema = z.object({
  type: z.enum(['private', 'group', 'channel', 'secret']),
  title: z.string().max(255).optional(),
  targetUserId: z.string().uuid().optional(),
  memberIds: z.array(z.string().uuid()).optional(),
});

export async function chatsRoutes(fastify: FastifyInstance) {
  const { prisma, redis } = fastify;

  // GET /chats — Список чатов пользователя
  fastify.get('/', async (request, reply) => {
    const userId = request.userId!;

    const memberships = await prisma.chatMember.findMany({
      where: { userId },
      include: {
        chat: {
          include: {
            members: {
              include: { user: { select: { id: true, displayName: true, avatarUrl: true } } },
            },
            messages: {
              take: 1,
              orderBy: { createdAt: 'desc' },
            },
          },
        },
      },
      orderBy: { chat: { updatedAt: 'desc' } },
    });

    const chats = await Promise.all(memberships.map(async (m) => {
      const unreadCount = await prisma.message.count({
        where: {
          chatId: m.chatId,
          senderId: { not: userId },
          isDeleted: false,
          createdAt: { gt: m.lastReadAt ?? new Date(0) },
        },
      });

      return {
        id: m.chat.id,
        type: m.chat.type,
        title: m.chat.type === 'PRIVATE'
          ? m.chat.members.find(mem => mem.userId !== userId)?.user.displayName ?? 'Чат'
          : m.chat.title,
        avatar_url: m.chat.avatarUrl,
        last_message: m.chat.messages[0]?.content ?? null,
        last_message_at: m.chat.messages[0]?.createdAt ?? null,
        unread_count: unreadCount,
        is_muted: m.isMuted,
        member_count: m.chat.members.length,
      };
    }));

    return reply.send({ data: chats });
  });

  // POST /chats — Создать чат
  fastify.post('/', { schema: { body: createChatSchema } }, async (request, reply) => {
    const userId = request.userId!;
    const body = request.body as z.infer<typeof createChatSchema>;

    const chat = await prisma.chat.create({
      data: {
        type: body.type?.toUpperCase() as ChatType,
        title: body.title,
        createdBy: userId,
        members: {
          create: [
            { userId, role: 'OWNER' },
            ...(body.memberIds?.map(id => ({ userId: id, role: 'MEMBER' as const })) ?? []),
            ...(body.targetUserId ? [{ userId: body.targetUserId, role: 'MEMBER' as const }] : []),
          ],
        },
      },
      include: { members: true },
    });

    return reply.code(201).send(chat);
  });

  // GET /chats/:id — Информация о чате
  fastify.get('/:id', async (request, reply) => {
    const { id } = request.params as { id: string };
    const userId = request.userId!;

    const membership = await prisma.chatMember.findUnique({
      where: { chatId_userId: { chatId: id, userId } },
    });
    if (!membership) return reply.code(403).send({ message: 'Вы не участник этого чата' });

    const chat = await prisma.chat.findUnique({
      where: { id },
      include: {
        members: {
          include: { user: { select: { id: true, username: true, displayName: true, avatarUrl: true, isOnline: true } } },
        },
      },
    });

    return reply.send(chat);
  });

  // PATCH /chats/:id — Обновить чат
  fastify.patch('/:id', async (request, reply) => {
    const { id } = request.params as { id: string };
    const userId = request.userId!;
    const body = request.body as Record<string, unknown>;

    const member = await prisma.chatMember.findUnique({
      where: { chatId_userId: { chatId: id, userId } },
    });
    if (!member || (member.role !== 'OWNER' && member.role !== 'ADMIN')) {
      return reply.code(403).send({ message: 'Недостаточно прав' });
    }

    const chat = await prisma.chat.update({
      where: { id },
      data: {
        ...(body.title ? { title: body.title as string } : {}),
        ...(body.avatar_url ? { avatarUrl: body.avatar_url as string } : {}),
        ...(body.disappear_timer !== undefined ? { disappearTimer: body.disappear_timer as number } : {}),
      },
    });

    return reply.send(chat);
  });

  // DELETE /chats/:id — Удалить чат для себя
  fastify.delete('/:id', async (request, reply) => {
    const { id } = request.params as { id: string };
    const userId = request.userId!;

    await prisma.chatMember.delete({
      where: { chatId_userId: { chatId: id, userId } },
    });

    return reply.code(204).send();
  });

  // POST /chats/:id/members — Добавить участника
  fastify.post('/:id/members', async (request, reply) => {
    const { id } = request.params as { id: string };
    const { userId: newMemberId } = request.body as { userId: string };
    const userId = request.userId!;

    const member = await prisma.chatMember.findUnique({
      where: { chatId_userId: { chatId: id, userId } },
    });
    if (!member || (member.role !== 'OWNER' && member.role !== 'ADMIN')) {
      return reply.code(403).send({ message: 'Недостаточно прав' });
    }

    const newMember = await prisma.chatMember.create({
      data: { chatId: id, userId: newMemberId, role: 'MEMBER' },
    });

    return reply.code(201).send(newMember);
  });

  // DELETE /chats/:id/members/:uid — Удалить участника
  fastify.delete('/:id/members/:uid', async (request, reply) => {
    const { id, uid } = request.params as { id: string; uid: string };
    await prisma.chatMember.delete({
      where: { chatId_userId: { chatId: id, userId: uid } },
    });
    return reply.code(204).send();
  });

  // GET /chats/:id/messages — Сообщения чата
  fastify.get('/:id/messages', async (request, reply) => {
    const { id } = request.params as { id: string };
    const { before, limit = '50' } = request.query as { before?: string; limit?: string };
    const userId = request.userId!;

    const membership = await prisma.chatMember.findUnique({
      where: { chatId_userId: { chatId: id, userId } },
    });
    if (!membership) return reply.code(403).send({ message: 'Нет доступа' });

    const messages = await prisma.message.findMany({
      where: {
        chatId: id,
        isDeleted: false,
        ...(before ? { createdAt: { lt: new Date(before) } } : {}),
      },
      take: parseInt(limit),
      orderBy: { createdAt: 'desc' },
      include: {
        sender: { select: { id: true, username: true, displayName: true, avatarUrl: true } },
        statuses: true,
        reactions: true,
      },
    });

    return reply.send(messages.reverse());
  });

  // DELETE /chats/:id/messages — Очистить историю чата
  fastify.delete('/:id/messages', async (request, reply) => {
    const { id } = request.params as { id: string };
    const userId = request.userId!;

    const membership = await prisma.chatMember.findUnique({
      where: { chatId_userId: { chatId: id, userId } },
    });
    if (!membership) return reply.code(403).send({ message: 'Нет доступа' });

    // Mark all messages as deleted (soft delete) rather than hard delete
    await prisma.message.updateMany({
      where: { chatId: id, isDeleted: false },
      data: { isDeleted: true, content: { isSet: false } },
    });

    return reply.code(204).send();
  });

  // GET /chats/:id/export — Экспорт истории чата
  fastify.get('/:id/export', async (request, reply) => {
    const { id } = request.params as { id: string };
    const userId = request.userId!;

    const membership = await prisma.chatMember.findUnique({
      where: { chatId_userId: { chatId: id, userId } },
    });
    if (!membership) return reply.code(403).send({ message: 'Нет доступа' });

    const messages = await prisma.message.findMany({
      where: { chatId: id, isDeleted: false },
      orderBy: { createdAt: 'asc' },
      include: {
        sender: { select: { id: true, username: true, displayName: true } },
        media: true,
      },
    });

    const chat = await prisma.chat.findUnique({
      where: { id },
      include: { members: { include: { user: { select: { id: true, displayName: true } } } } },
    });

    const exportData = {
      chat: {
        id: chat?.id,
        title: chat?.title,
        type: chat?.type,
        members: chat?.members.map(m => ({
          userId: m.userId,
          displayName: m.user.displayName,
        })),
      },
      messages: messages.map(m => ({
        id: m.id,
        sender: m.sender.displayName ?? m.sender.username,
        type: m.type,
        content: m.content,
        createdAt: m.createdAt.toISOString(),
        isEdited: m.isEdited,
      })),
      exportedAt: new Date().toISOString(),
    };

    return reply.send(exportData);
  });

  // GET /chats/:id/search — Поиск в чате
  fastify.get('/:id/search', async (request, reply) => {
    const { id } = request.params as { id: string };
    const { q } = request.query as { q: string };
    const userId = request.userId!;

    const membership = await prisma.chatMember.findUnique({
      where: { chatId_userId: { chatId: id, userId } },
    });
    if (!membership) return reply.code(403).send({ message: 'Нет доступа' });

    const messages = await prisma.message.findMany({
      where: {
        chatId: id,
        isDeleted: false,
        content: { path: ['text'], string_contains: q },
      },
      take: 50,
      orderBy: { createdAt: 'desc' },
      include: { sender: { select: { id: true, displayName: true } } },
    });

    return reply.send(messages.reverse());
  });
}
