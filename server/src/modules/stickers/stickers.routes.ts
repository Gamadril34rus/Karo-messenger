import { FastifyInstance } from 'fastify';

export async function stickersRoutes(fastify: FastifyInstance) {
  const { prisma } = fastify;

  // GET /stickers/packs — Каталог стикер-паков
  fastify.get('/packs', async (request, reply) => {
    const packs = await prisma.stickerPack.findMany({
      where: { isFeatured: true },
      include: { stickers: { take: 4 } },
      orderBy: { createdAt: 'desc' },
    });
    return reply.send({ data: packs });
  });

  // GET /stickers/packs/:id — Один пак
  fastify.get('/packs/:id', async (request, reply) => {
    const { id } = request.params as { id: string };
    const pack = await prisma.stickerPack.findUnique({
      where: { id },
      include: { stickers: true },
    });
    if (!pack) return reply.code(404).send({ message: 'Пак не найден' });
    return reply.send(pack);
  });

  // POST /stickers/import — Импорт стикеров из другого мессенджера
  fastify.post('/import', async (request, reply) => {
    const { source, sourceId, name } = request.body as {
      source: 'TELEGRAM' | 'WHATSAPP' | 'VIBER' | 'VK' | 'CUSTOM';
      sourceId: string;
      name?: string;
    };

    // В реальности: парсинг стикеров из источника
    const pack = await prisma.stickerPack.create({
      data: {
        name: name ?? `Импорт из ${source.toLowerCase()}`,
        source,
        sourceId,
        stickers: {
          create: Array.from({ length: 20 }, (_, i) => ({
            imageUrl: `https://cdn.charo.chat/stickers/${source.toLowerCase()}/${sourceId}/${i}.webp`,
            emoji: '😀',
            sortOrder: i,
          })),
        },
      },
      include: { stickers: true },
    });

    return reply.code(201).send(pack);
  });
}
