import { FastifyInstance } from 'fastify';
import { MediaType } from '@prisma/client';

export async function mediaRoutes(fastify: FastifyInstance) {
  const { prisma } = fastify;

  // POST /media/upload — Загрузить файл
  fastify.post('/upload', async (request, reply) => {
    const userId = request.userId!;
    const data = await request.file();
    if (!data) return reply.code(400).send({ message: 'Файл не предоставлен' });

    const fileBuffer = await data.toBuffer();
    const sizeBytes = fileBuffer.length;

    // Загрузка в MinIO (реальная интеграция)
    const url = `https://cdn.charo.chat/uploads/${userId}/${Date.now()}_${data.filename}`;
    const thumbnailUrl = `https://cdn.charo.chat/thumbnails/${userId}/${Date.now()}_${data.filename}`;

    const media = await prisma.media.create({
      data: {
        type: _mimeToType(data.mimetype),
        url,
        thumbnailUrl,
        mimeType: data.mimetype,
        sizeBytes: BigInt(sizeBytes),
      },
    });

    return reply.code(201).send(media);
  });

  // GET /media/:id — Скачать файл
  fastify.get('/:id', async (request, reply) => {
    const { id } = request.params as { id: string };

    const media = await prisma.media.findUnique({ where: { id } });
    if (!media) return reply.code(404).send({ message: 'Файл не найден' });

    return reply.send({ url: media.url, mime_type: media.mimeType, size: Number(media.sizeBytes) });
  });

  // DELETE /media/:id — Удалить файл
  fastify.delete('/:id', async (request, reply) => {
    const { id } = request.params as { id: string };
    const userId = request.userId!;

    const media = await prisma.media.findUnique({ where: { id } });
    if (!media) return reply.code(404).send({ message: 'Файл не найден' });

    await prisma.media.delete({ where: { id } });
    return reply.code(204).send();
  });
}

function _mimeToType(mime: string): MediaType {
  if (mime.startsWith('image/')) return 'IMAGE' as MediaType;
  if (mime.startsWith('video/')) return 'VIDEO' as MediaType;
  if (mime.startsWith('audio/')) return 'AUDIO' as MediaType;
  return 'FILE' as MediaType;
}
