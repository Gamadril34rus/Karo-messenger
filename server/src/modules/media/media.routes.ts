import { FastifyInstance } from 'fastify';
import { MediaType } from '@prisma/client';
import * as Minio from 'minio';
import { logger } from '../../utils/logger';

/// MinIO Client — real object storage integration
let _minioClient: Minio.Client | null = null;
let _minioReady = false;

function getMinioClient(): Minio.Client {
  if (!_minioClient) {
    _minioClient = new Minio.Client({
      endPoint: process.env.MINIO_ENDPOINT || 'localhost',
      port: Number(process.env.MINIO_PORT) || 9000,
      useSSL: process.env.MINIO_USE_SSL === 'true',
      accessKey: process.env.MINIO_ACCESS_KEY || 'minioadmin',
      secretKey: process.env.MINIO_SECRET_KEY || 'minioadmin',
    });
  }
  return _minioClient;
}

const CDN_BASE = process.env.CDN_BASE_URL || 'https://cdn.charo.chat';
const BUCKET = process.env.MINIO_BUCKET || 'charo-media';

/// Ensure bucket exists on startup — gracefully handles MinIO being unavailable
async function ensureBucket(client: Minio.Client): Promise<void> {
  const exists = await client.bucketExists(BUCKET);
  if (!exists) {
    await client.makeBucket(BUCKET);
    logger.info(`MinIO bucket "${BUCKET}" created`);
  }
}

export async function mediaRoutes(fastify: FastifyInstance) {
  const { prisma } = fastify;
  const minioClient = getMinioClient();

  // Ensure bucket exists — non-fatal if MinIO is unavailable (e.g. CI without MinIO)
  try {
    await ensureBucket(minioClient);
    _minioReady = true;
  } catch (err) {
    logger.warn(`MinIO not available, media uploads will be disabled: ${err}`);
    _minioReady = false;
  }

  // POST /media/upload — Upload file to MinIO
  fastify.post('/upload', async (request, reply) => {
    const userId = request.userId!;
    if (!_minioReady) return reply.code(503).send({ message: 'Хранилище файлов недоступно' });
    const data = await request.file();
    if (!data) return reply.code(400).send({ message: 'Файл не предоставлен' });

    const fileBuffer = await data.toBuffer();
    const sizeBytes = fileBuffer.length;

    // Generate unique object key
    const timestamp = Date.now();
    const objectKey = `uploads/${userId}/${timestamp}_${data.filename}`;

    // Upload to MinIO
    try {
      await minioClient.putObject(BUCKET, objectKey, fileBuffer, sizeBytes, {
        'Content-Type': data.mimetype,
        'x-amz-meta-user-id': userId,
        'x-amz-meta-original-name': data.filename,
      });
      logger.info(`File uploaded to MinIO: ${objectKey} (${sizeBytes} bytes)`);
    } catch (err) {
      logger.error(`MinIO upload failed: ${err}`);
      return reply.code(500).send({ message: 'Ошибка загрузки файла' });
    }

    const url = `${CDN_BASE}/${objectKey}`;
    let thumbnailUrl = `${CDN_BASE}/thumbnails/${userId}/${timestamp}_${data.filename}`;

    // Generate thumbnail for images
    if (data.mimetype.startsWith('image/')) {
      const thumbKey = `thumbnails/${userId}/${timestamp}_${data.filename}`;
      try {
        // Thumbnail generation for images — resize via sharp in production deployment
        // Sharp integration would resize to 200x200
        await minioClient.putObject(BUCKET, thumbKey, fileBuffer, sizeBytes, {
          'Content-Type': data.mimetype,
        });
        thumbnailUrl = `${CDN_BASE}/${thumbKey}`;
      } catch (err) {
        logger.warn(`Thumbnail generation failed: ${err}`);
      }
    }

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

  // POST /media/upload/session — Create chunked upload session
  fastify.post('/upload/session', async (request, reply) => {
    const userId = request.userId!;
    const body = request.body as {
      chat_id?: string;
      file_name: string;
      file_size: number;
      mime_type: string;
      total_chunks: number;
      is_encrypted?: boolean;
    };

    // Create a unique session ID and object key prefix
    const sessionId = `session_${userId}_${Date.now()}`;
    const objectKey = `uploads/${userId}/${Date.now()}_${body.file_name}`;

    // Store session metadata in Redis
    await fastify.redis.set(
      `upload_session:${sessionId}`,
      JSON.stringify({
        objectKey,
        fileName: body.file_name,
        fileSize: body.file_size,
        mimeType: body.mime_type,
        totalChunks: body.total_chunks,
        receivedChunks: 0,
        userId,
      }),
      'EX',
      3600, // 1 hour TTL
    );

    return reply.code(201).send({
      file_id: sessionId,
      upload_url: `/api/v1/media/upload/chunk`,
      object_key: objectKey,
    });
  });

  // POST /media/upload/chunk — Upload a chunk
  fastify.post('/upload/chunk', async (request, reply) => {
    const userId = request.userId!;
    if (!_minioReady) return reply.code(503).send({ message: 'Хранилище файлов недоступно' });
    const data = await request.file();
    if (!data) return reply.code(400).send({ message: 'Chunk data required' });

    const chunkBuffer = await data.toBuffer();

    // Get session metadata
    const fields = data.fields as Record<string, { value: string }>;
    const fileId = fields['file_id']?.value || '';
    const chunkIndex = parseInt(fields['chunk_index']?.value || '0');
    const totalChunks = parseInt(fields['total_chunks']?.value || '1');

    const sessionJson = await fastify.redis.get(`upload_session:${fileId}`);
    if (!sessionJson) {
      return reply.code(404).send({ message: 'Upload session not found or expired' });
    }
    const session = JSON.parse(sessionJson);

    // Upload chunk to MinIO with chunk index suffix
    const chunkKey = `${session.objectKey}.part.${chunkIndex}`;
    try {
      await minioClient.putObject(BUCKET, chunkKey, chunkBuffer, chunkBuffer.length, {
        'Content-Type': 'application/octet-stream',
        'x-amz-meta-chunk-index': chunkIndex.toString(),
        'x-amz-meta-total-chunks': totalChunks.toString(),
        'x-amz-meta-session-id': fileId,
      });
    } catch (err) {
      logger.error(`MinIO chunk upload failed: ${err}`);
      return reply.code(500).send({ message: 'Chunk upload failed' });
    }

    // Update session metadata
    session.receivedChunks = (session.receivedChunks || 0) + 1;
    await fastify.redis.set(`upload_session:${fileId}`, JSON.stringify(session), 'EX', 3600);

    return reply.send({ chunk_index: chunkIndex, received: true });
  });

  // POST /media/upload/:sessionId/complete — Finalize chunked upload
  fastify.post('/upload/:sessionId/complete', async (request, reply) => {
    const { sessionId } = request.params as { sessionId: string };
    const userId = request.userId!;
    if (!_minioReady) return reply.code(503).send({ message: 'Хранилище файлов недоступно' });
    const body = request.body as { total_chunks?: number; file_size?: number };

    const sessionJson = await fastify.redis.get(`upload_session:${sessionId}`);
    if (!sessionJson) {
      return reply.code(404).send({ message: 'Upload session not found' });
    }
    const session = JSON.parse(sessionJson);

    // Concatenate chunks into final object
    // In production with MinIO: use composeObject to merge parts
    // Here: we download all parts and re-upload as single object
    try {
      const chunks: Buffer[] = [];
      for (let i = 0; i < session.totalChunks; i++) {
        const chunkKey = `${session.objectKey}.part.${i}`;
        const chunkStream = await minioClient.getObject(BUCKET, chunkKey);
        const chunksBuffers: Buffer[] = [];
        for await (const chunk of chunkStream) {
          chunksBuffers.push(chunk as Buffer);
        }
        chunks.push(Buffer.concat(chunksBuffers));
        // Clean up part file
        await minioClient.removeObject(BUCKET, chunkKey);
      }

      const finalBuffer = Buffer.concat(chunks);
      await minioClient.putObject(BUCKET, session.objectKey, finalBuffer, finalBuffer.length, {
        'Content-Type': session.mimeType,
        'x-amz-meta-user-id': userId,
        'x-amz-meta-original-name': session.fileName,
      });

      logger.info(`Chunked upload completed: ${session.objectKey} (${finalBuffer.length} bytes)`);
    } catch (err) {
      logger.error(`Upload completion failed: ${err}`);
      return reply.code(500).send({ message: 'Upload completion failed' });
    }

    // Create media record
    const url = `${CDN_BASE}/${session.objectKey}`;
    const thumbnailUrl = `${CDN_BASE}/thumbnails/${userId}/${Date.now()}_${session.fileName}`;

    const media = await prisma.media.create({
      data: {
        type: _mimeToType(session.mimeType),
        url,
        thumbnailUrl,
        mimeType: session.mimeType,
        sizeBytes: BigInt(session.fileSize),
      },
    });

    // Clean up session
    await fastify.redis.del(`upload_session:${sessionId}`);

    return reply.send({
      url,
      thumbnail_url: thumbnailUrl,
      media_id: media.id,
    });
  });

  // GET /media/:id — Get file info
  fastify.get('/:id', async (request, reply) => {
    const { id } = request.params as { id: string };

    const media = await prisma.media.findUnique({ where: { id } });
    if (!media) return reply.code(404).send({ message: 'Файл не найден' });

    return reply.send({ url: media.url, mime_type: media.mimeType, size: Number(media.sizeBytes) });
  });

  // DELETE /media/:id — Delete file from MinIO and DB
  fastify.delete('/:id', async (request, reply) => {
    const { id } = request.params as { id: string };

    const media = await prisma.media.findUnique({ where: { id } });
    if (!media) return reply.code(404).send({ message: 'Файл не найден' });

    // Delete from MinIO
    if (_minioReady) {
      try {
        // Extract object key from CDN URL
        const objectKey = media.url.replace(`${CDN_BASE}/`, '');
        await minioClient.removeObject(BUCKET, objectKey);
        logger.info(`File deleted from MinIO: ${objectKey}`);

        // Delete thumbnail if exists
        if (media.thumbnailUrl) {
          const thumbKey = media.thumbnailUrl.replace(`${CDN_BASE}/`, '');
          try { await minioClient.removeObject(BUCKET, thumbKey); } catch { /* ignore */ }
        }
      } catch (err) {
        logger.warn(`MinIO delete failed: ${err}`);
      }
    }

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
