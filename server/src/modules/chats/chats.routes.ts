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
    const query = request.query as { q?: string; include_archived?: string };

    const whereClause: Record<string, unknown> = { userId };
    if (query.include_archived !== 'true') {
      whereClause.isArchived = false;
    }

    const memberships = await prisma.chatMember.findMany({
      where: whereClause,
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
      orderBy: [
        { isPinned: 'desc' },
        { chat: { updatedAt: 'desc' } },
      ],
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

      const lastMessage = m.chat.messages[0];

      return {
        id: m.chat.id,
        type: m.chat.type,
        title: m.chat.type === 'PRIVATE'
          ? m.chat.members.find(mem => mem.userId !== userId)?.user.displayName ?? 'Чат'
          : m.chat.title,
        avatar_url: m.chat.avatarUrl,
        last_message: lastMessage?.content ?? null,
        last_message_sender: lastMessage?.senderId ?? null,
        last_message_at: lastMessage?.createdAt ?? null,
        unread_count: unreadCount,
        is_muted: m.isMuted,
        is_pinned: m.isPinned,
        is_archived: m.isArchived,
        member_count: m.chat.members.length,
        is_online: m.chat.type === 'PRIVATE'
          ? m.chat.members.find(mem => mem.userId !== userId)?.user?.displayName != null
          : false,
      };
    }));

    // Client-side search filter
    if (query.q) {
      const q = query.q.toLowerCase();
      const filtered = chats.filter((c) =>
        (c.title ?? '').toLowerCase().includes(q)
      );
      return reply.send({ data: filtered });
    }

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

  // PATCH /chats/:id — Обновить чат (title, avatar, disappear_timer, is_muted, is_pinned, is_archived)
  fastify.patch('/:id', async (request, reply) => {
    const { id } = request.params as { id: string };
    const userId = request.userId!;
    const body = request.body as Record<string, unknown>;

    // Chat-level updates (title, avatar, disappear_timer) — require OWNER/ADMIN
    const chatUpdates: Record<string, unknown> = {};
    const memberUpdates: Record<string, unknown> = {};

    if (body.title !== undefined) chatUpdates.title = body.title as string;
    if (body.avatar_url !== undefined) chatUpdates.avatarUrl = body.avatar_url as string;
    if (body.disappear_timer !== undefined) chatUpdates.disappearTimer = body.disappear_timer as number;
    if (body.is_muted !== undefined) memberUpdates.isMuted = body.is_muted as boolean;
    if (body.is_pinned !== undefined) memberUpdates.isPinned = body.is_pinned as boolean;
    if (body.is_archived !== undefined) memberUpdates.isArchived = body.is_archived as boolean;

    // For chat-level updates, check OWNER/ADMIN
    if (Object.keys(chatUpdates).length > 0) {
      const member = await prisma.chatMember.findUnique({
        where: { chatId_userId: { chatId: id, userId } },
      });
      if (!member || (member.role !== 'OWNER' && member.role !== 'ADMIN')) {
        return reply.code(403).send({ message: 'Недостаточно прав' });
      }
      await prisma.chat.update({ where: { id }, data: chatUpdates });
    }

    // For member-level updates (mute, pin, archive) — just need to be a member
    if (Object.keys(memberUpdates).length > 0) {
      await prisma.chatMember.update({
        where: { chatId_userId: { chatId: id, userId } },
        data: memberUpdates,
      });
    }

    const chat = await prisma.chat.findUnique({
      where: { id },
      include: {
        members: {
          include: { user: { select: { id: true, username: true, displayName: true, avatarUrl: true } } },
        },
      },
    });

    return reply.send(chat);
  });

  // PATCH /chats/:id/pin — Закрепить/открепить чат
  fastify.patch('/:id/pin', async (request, reply) => {
    const { id } = request.params as { id: string };
    const userId = request.userId!;
    const body = request.body as { pinned?: boolean };

    const membership = await prisma.chatMember.findUnique({
      where: { chatId_userId: { chatId: id, userId } },
    });
    if (!membership) return reply.code(403).send({ message: 'Вы не участник этого чата' });

    const updated = await prisma.chatMember.update({
      where: { chatId_userId: { chatId: id, userId } },
      data: { isPinned: body.pinned ?? !membership.isPinned },
    });

    return reply.send({ is_pinned: updated.isPinned });
  });

  // PATCH /chats/:id/mute — Отключить/включить уведомления
  fastify.patch('/:id/mute', async (request, reply) => {
    const { id } = request.params as { id: string };
    const userId = request.userId!;
    const body = request.body as { muted?: boolean };

    const membership = await prisma.chatMember.findUnique({
      where: { chatId_userId: { chatId: id, userId } },
    });
    if (!membership) return reply.code(403).send({ message: 'Вы не участник этого чата' });

    const updated = await prisma.chatMember.update({
      where: { chatId_userId: { chatId: id, userId } },
      data: { isMuted: body.muted ?? !membership.isMuted },
    });

    return reply.send({ is_muted: updated.isMuted });
  });

  // PATCH /chats/:id/archive — Архивировать/разархивировать чат
  fastify.patch('/:id/archive', async (request, reply) => {
    const { id } = request.params as { id: string };
    const userId = request.userId!;
    const body = request.body as { archived?: boolean };

    const membership = await prisma.chatMember.findUnique({
      where: { chatId_userId: { chatId: id, userId } },
    });
    if (!membership) return reply.code(403).send({ message: 'Вы не участник этого чата' });

    const updated = await prisma.chatMember.update({
      where: { chatId_userId: { chatId: id, userId } },
      data: { isArchived: body.archived ?? !membership.isArchived },
    });

    return reply.send({ is_archived: updated.isArchived });
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

  // GET /chats/:id/messages — Сообщения чата (with gap-filling after_id support)
  fastify.get('/:id/messages', async (request, reply) => {
    const { id } = request.params as { id: string };
    const { before, after_id, limit = '50' } = request.query as { before?: string; after_id?: string; limit?: string };
    const userId = request.userId!;

    const membership = await prisma.chatMember.findUnique({
      where: { chatId_userId: { chatId: id, userId } },
    });
    if (!membership) return reply.code(403).send({ message: 'Нет доступа' });

    // Gap-filling: after_id — загрузить сообщения после указанного ID
    let afterDate: Date | undefined;
    if (after_id) {
      const afterMessage = await prisma.message.findUnique({
        where: { id: after_id },
        select: { createdAt: true },
      });
      if (afterMessage) {
        afterDate = afterMessage.createdAt;
      }
    }

    const messages = await prisma.message.findMany({
      where: {
        chatId: id,
        isDeleted: false,
        ...(before ? { createdAt: { lt: new Date(before) } } : {}),
        ...(afterDate ? { createdAt: { gt: afterDate } } : {}),
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

    // Search messages — content is JSON, search in text field or string_contains on raw content
    const messages = await prisma.message.findMany({
      where: {
        chatId: id,
        isDeleted: false,
        OR: [
          { content: { path: ['text'], string_contains: q } },
          { content: { string_contains: q } },
        ],
      },
      take: 50,
      orderBy: { createdAt: 'desc' },
      include: { sender: { select: { id: true, displayName: true } } },
    });

    return reply.send(messages.reverse());
  });
}
