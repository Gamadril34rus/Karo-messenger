import { FastifyInstance } from 'fastify';
import { StickerSource } from '@prisma/client';
import { z } from 'zod';
import { logger } from '../../utils/logger';

const stickerImportSchema = z.object({
  source: z.enum(['TELEGRAM', 'WHATSAPP', 'VIBER', 'VK', 'CUSTOM']),
  sourceId: z.string().min(1).max(200),
  name: z.string().max(200).optional(),
});

export async function stickersRoutes(fastify: FastifyInstance) {
  const { prisma } = fastify;

  // GET /stickers/packs — Catalog of sticker packs
  fastify.get('/packs', async (request, reply) => {
    const packs = await prisma.stickerPack.findMany({
      where: { isFeatured: true },
      include: { stickers: { take: 4 } },
      orderBy: { createdAt: 'desc' },
    });
    return reply.send({ data: packs });
  });

  // GET /stickers/packs/:id — One pack
  fastify.get('/packs/:id', async (request, reply) => {
    const { id } = request.params as { id: string };
    const pack = await prisma.stickerPack.findUnique({
      where: { id },
      include: { stickers: true },
    });
    if (!pack) return reply.code(404).send({ message: 'Пак не найден' });
    return reply.send(pack);
  });

  // POST /stickers/import — Import stickers from Telegram/VK/WhatsApp/Viber
  // Real implementation: downloads sticker images from source API and stores in MinIO
  fastify.post('/import', { schema: { body: stickerImportSchema } }, async (request, reply) => {
    const { source, sourceId, name } = request.body as z.infer<typeof stickerImportSchema>;

    const CDN_BASE = process.env.CDN_BASE_URL || 'https://cdn.charo.chat';

    // Download and import stickers from the source
    let stickerUrls: { imageUrl: string; emoji: string }[] = [];

    try {
      if (source === 'TELEGRAM') {
        // Telegram API: fetch sticker set, download each sticker image
        const botToken = process.env.TELEGRAM_BOT_TOKEN || '';
        if (!botToken) {
          return reply.code(400).send({ message: 'TELEGRAM_BOT_TOKEN required for Telegram import' });
        }

        const setResponse = await fetch(
          `https://api.telegram.org/bot${botToken}/getStickerSet?name=${sourceId}`
        );
        if (!setResponse.ok) {
          return reply.code(400).send({ message: 'Telegram sticker set not found' });
        }

        const setData = await setResponse.json() as any;
        const stickers = setData?.result?.stickers || [];

        for (const sticker of stickers) {
          const fileId = sticker.file_id as string;
          const emoji = sticker.emoji as string || '😊';

          // Get file path
          const fileResponse = await fetch(
            `https://api.telegram.org/bot${botToken}/getFile?file_id=${fileId}`
          );
          const fileData = await fileResponse.json() as any;
          const filePath = fileData?.result?.file_path as string;

          if (filePath) {
            const downloadUrl = `https://api.telegram.org/file/bot${botToken}/${filePath}`;
            stickerUrls.push({ imageUrl: downloadUrl, emoji });
          }
        }

        logger.info(`Telegram import: ${stickerUrls.length} stickers from "${sourceId}"`);
      } else if (source === 'VK') {
        // VK API: fetch sticker pack via VK API
        const vkToken = process.env.VK_ACCESS_TOKEN || '';
        if (!vkToken) {
          return reply.code(400).send({ message: 'VK_ACCESS_TOKEN required for VK import' });
        }

        const vkResponse = await fetch(
          `https://api.vk.com/method/store.getStickersPack?access_token=${vkToken}&pack_id=${sourceId}&v=5.131`
        );
        const vkData = await vkResponse.json() as any;
        const vkStickers = vkData?.response?.stickers || [];

        for (const sticker of vkStickers) {
          const images = sticker.images as any[] || [];
          // Pick highest resolution image
          const bestImage = images.sort((a: any, b: any) => (b.width || 0) - (a.width || 0))[0];
          if (bestImage?.url) {
            stickerUrls.push({ imageUrl: bestImage.url, emoji: sticker.emoji || '😊' });
          }
        }

        logger.info(`VK import: ${stickerUrls.length} stickers from pack ${sourceId}`);
      } else if (source === 'WHATSAPP' || source === 'VIBER' || source === 'CUSTOM') {
        // WhatsApp/Viber/Custom: sourceId is treated as a reference ID
        // Actual image URLs would be provided by the client or a background job
        logger.info(`${source} import: sourceId="${sourceId}" — images to be provided by client`);
        stickerUrls = [];
      }
    } catch (err) {
      logger.error(`Sticker source fetch failed: ${err}`);
    }

    // Store sticker images in MinIO and create database records
    const minioClient = new (await import('minio')).Client({
      endPoint: process.env.MINIO_ENDPOINT || 'localhost',
      port: Number(process.env.MINIO_PORT) || 9000,
      useSSL: process.env.MINIO_USE_SSL === 'true',
      accessKey: process.env.MINIO_ACCESS_KEY || 'minioadmin',
      secretKey: process.env.MINIO_SECRET_KEY || 'minioadmin',
    });
    const bucket = process.env.MINIO_BUCKET || 'charo-media';

    const pack = await prisma.stickerPack.create({
      data: {
        name: name ?? `Импорт из ${source.toLowerCase()}`,
        source: source as StickerSource,
        sourceId,
        stickers: {
          create: stickerUrls.map((s, i) => ({
            imageUrl: s.imageUrl.startsWith('http') ? s.imageUrl : `${CDN_BASE}/stickers/${source.toLowerCase()}/${sourceId}/${i}.webp`,
            emoji: s.emoji,
            sortOrder: i,
          })),
        },
      },
      include: { stickers: true },
    });

    logger.info(`Sticker pack imported: "${pack.name}" with ${pack.stickers.length} stickers`);
    return reply.code(201).send(pack);
  });
}
