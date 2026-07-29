import { FastifyInstance } from 'fastify';
import { z } from 'zod';

export async function contactsRoutes(fastify: FastifyInstance) {
  const { prisma } = fastify;

  // GET /contacts — Список контактов
  fastify.get('/', async (request, reply) => {
    const userId = request.userId!;

    const contacts = await prisma.contact.findMany({
      where: { userId, isBlocked: false },
      include: {
        contactUser: {
          select: { id: true, username: true, displayName: true, avatarUrl: true, isOnline: true, lastSeen: true },
        },
      },
      orderBy: { contactUser: { displayName: 'asc' } },
    });

    return reply.send({ data: contacts });
  });

  // POST /contacts — Добавить контакт
  fastify.post('/', async (request, reply) => {
    const userId = request.userId!;
    const { identifier, contactUserId } = request.body as {
      identifier?: string;
      contactUserId?: string;
    };

    let targetId = contactUserId;

    if (!targetId && identifier) {
      const user = await prisma.user.findFirst({
        where: {
          OR: [{ username: identifier }, { phone: identifier }],
          status: 'ACTIVE',
        },
      });
      if (!user) return reply.code(404).send({ message: 'Пользователь не найден' });
      targetId = user.id;
    }

    if (!targetId) return reply.code(400).send({ message: 'Укажите идентификатор' });

    const contact = await prisma.contact.upsert({
      where: { userId_contactUserId: { userId, contactUserId: targetId } },
      create: { userId, contactUserId: targetId! },
      update: { isBlocked: false },
    });

    return reply.code(201).send(contact);
  });

  // DELETE /contacts/:id — Удалить контакт
  fastify.delete('/:id', async (request, reply) => {
    const { id } = request.params as { id: string };
    const userId = request.userId!;

    await prisma.contact.deleteMany({
      where: { userId, contactUserId: id },
    });

    return reply.code(204).send();
  });

  // POST /contacts/sync — Синхронизация телефонной книги
  fastify.post('/sync', async (request, reply) => {
    const userId = request.userId!;
    const { phones } = request.body as { phones: string[] };

    const existingUsers = await prisma.user.findMany({
      where: { phone: { in: phones }, status: 'ACTIVE' },
      select: { id: true, phone: true },
    });

    let addedCount = 0;
    for (const user of existingUsers) {
      try {
        await prisma.contact.upsert({
          where: { userId_contactUserId: { userId, contactUserId: user.id } },
          create: { userId, contactUserId: user.id },
          update: {},
        });
        addedCount++;
      } catch { /* already exists */ }
    }

    return reply.send({ added: addedCount, total: existingUsers.length });
  });

  // ─── POST /contacts/block — Заблокировать пользователя ────────────
  fastify.post('/block', async (request, reply) => {
    const userId = request.userId!;
    const { userId: targetUserId } = request.body as { userId: string };

    if (!targetUserId) {
      return reply.code(400).send({ message: 'Укажите userId' });
    }

    if (targetUserId === userId) {
      return reply.code(400).send({ message: 'Нельзя заблокировать самого себя' });
    }

    // Verify target user exists
    const targetUser = await prisma.user.findUnique({ where: { id: targetUserId } });
    if (!targetUser) {
      return reply.code(404).send({ message: 'Пользователь не найден' });
    }

    // Upsert blocked user record
    const blocked = await prisma.blockedUser.upsert({
      where: { blockerId_blockedUserId: { blockerId: userId, blockedUserId: targetUserId } },
      create: { blockerId: userId, blockedUserId: targetUserId },
      update: {},
    });

    // Also mark contact as blocked if it exists
    await prisma.contact.updateMany({
      where: { userId, contactUserId: targetUserId },
      data: { isBlocked: true },
    }).catch(() => {});

    return reply.code(200).send({ message: 'Пользователь заблокирован', blocked });
  });

  // ─── DELETE /contacts/block/:userId — Разблокировать пользователя ──
  fastify.delete('/block/:userId', async (request, reply) => {
    const { userId: targetUserId } = request.params as { userId: string };
    const userId = request.userId!;

    const blocked = await prisma.blockedUser.findUnique({
      where: { blockerId_blockedUserId: { blockerId: userId, blockedUserId: targetUserId } },
    });

    if (!blocked) {
      return reply.code(404).send({ message: 'Пользователь не в чёрном списке' });
    }

    await prisma.blockedUser.delete({
      where: { id: blocked.id },
    });

    // Also unmark contact block
    await prisma.contact.updateMany({
      where: { userId, contactUserId: targetUserId },
      data: { isBlocked: false },
    }).catch(() => {});

    return reply.code(200).send({ message: 'Пользователь разблокирован' });
  });

  // ─── GET /contacts/blocked — Список заблокированных ──────────────
  fastify.get('/blocked', async (request, reply) => {
    const userId = request.userId!;

    const blocked = await prisma.blockedUser.findMany({
      where: { blockerId: userId },
      include: {
        blockedUser: {
          select: { id: true, username: true, displayName: true, avatarUrl: true },
        },
      },
      orderBy: { createdAt: 'desc' },
    });

    return reply.send({ data: blocked });
  });
}
