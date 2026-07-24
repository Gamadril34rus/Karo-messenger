import { FastifyInstance } from 'fastify';

export async function storyRoutes(fastify: FastifyInstance) {
  const { prisma } = fastify;

  // POST /stories — Опубликовать историю
  fastify.post('/', async (request, reply) => {
    const userId = request.userId!;
    const { type, content, backgroundColor } = request.body as {
      type: 'IMAGE' | 'VIDEO' | 'TEXT';
      content?: string;
      backgroundColor?: string;
    };

    const story = await prisma.story.create({
      data: {
        userId,
        type,
        content,
        backgroundColor,
        expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000), // 24 часа
      },
    });

    return reply.code(201).send(story);
  });

  // GET /stories — Лента историй
  fastify.get('/', async (request, reply) => {
    const userId = request.userId!;

    // Получаем контакты пользователя
    const contacts = await prisma.contact.findMany({
      where: { userId, isBlocked: false },
      select: { contactUserId: true },
    });
    const contactIds = contacts.map(c => c.contactUserId);
    const userIds = [userId, ...contactIds];

    const stories = await prisma.story.findMany({
      where: {
        userId: { in: userIds },
        expiresAt: { gt: new Date() },
      },
      orderBy: { createdAt: 'desc' },
      include: {
        user: { select: { id: true, displayName: true, avatarUrl: true } },
        views: { where: { userId } },
      },
    });

    // Группируем по пользователю
    const grouped = new Map<string, object>();
    for (const story of stories) {
      const uid = story.userId;
      if (!grouped.has(uid)) {
        grouped.set(uid, {
          userId: uid,
          userName: story.user.displayName,
          avatarUrl: story.user.avatarUrl,
          stories: [],
        });
      }
      const entry = grouped.get(uid) as Record<string, unknown>;
      (entry['stories'] as Array<unknown>).push(story);
    }

    return reply.send({ data: Array.from(grouped.values()) });
  });

  // DELETE /stories/:id — Удалить историю
  fastify.delete('/:id', async (request, reply) => {
    const { id } = request.params as { id: string };
    const userId = request.userId!;

    const story = await prisma.story.findUnique({ where: { id } });
    if (!story || story.userId !== userId) {
      return reply.code(403).send({ message: 'Нельзя удалить чужую историю' });
    }

    await prisma.story.delete({ where: { id } });
    return reply.code(204).send();
  });

  // GET /stories/:id/views — Просмотры истории
  fastipy.get('/:id/views', async (request, reply) => {
    const { id } = request.params as { id: string };
    const userId = request.userId!;

    const story = await prisma.story.findUnique({ where: { id } });
    if (!story) return reply.code(404).send({ message: 'История не найдена' });

    // Отмечаем просмотр
    await prisma.storyView.upsert({
      where: { storyId_userId: { storyId: id, userId } },
      create: { storyId: id, userId },
      update: {},
    });

    const views = await prisma.storyView.findMany({
      where: { storyId: id },
      include: { user: { select: { id: true, displayName: true, avatarUrl: true } } },
    });

    return reply.send({ views });
  });
}
