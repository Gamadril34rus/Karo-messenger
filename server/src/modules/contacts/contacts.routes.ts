import { FastifyInstance } from 'fastify';

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
}
