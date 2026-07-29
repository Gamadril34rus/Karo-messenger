import { FastifyInstance } from 'fastify';
import { z } from 'zod';
import * as Minio from 'minio';
import { logger } from '../../utils/logger';

const CDN_BASE = process.env.CDN_BASE_URL || 'https://cdn.charo.chat';
const BUCKET = process.env.MINIO_BUCKET || 'charo-media';

function getMinioClient(): Minio.Client {
  return new Minio.Client({
    endPoint: process.env.MINIO_ENDPOINT || 'localhost',
    port: Number(process.env.MINIO_PORT) || 9000,
    useSSL: process.env.MINIO_USE_SSL === 'true',
    accessKey: process.env.MINIO_ACCESS_KEY || 'minioadmin',
    secretKey: process.env.MINIO_SECRET_KEY || 'minioadmin',
  });
}

const updateProfileSchema = z.object({
  display_name: z.string().max(128).optional(),
  bio: z.string().max(256).optional(),
  language: z.string().max(10).optional(),
});

export async function usersRoutes(fastify: FastifyInstance) {
  const { prisma } = fastify;

  // GET /users/me — Свой профиль
  fastify.get('/me', async (request, reply) => {
    const userId = request.userId!;
    const user = await prisma.user.findUnique({
      where: { id: userId, status: 'ACTIVE' },
      include: { privacySettings: true },
    });
    if (!user) return reply.code(404).send({ message: 'Пользователь не найден' });
    return reply.send(user);
  });

  // PATCH /users/me — Обновить профиль
  fastify.patch('/me', { schema: { body: updateProfileSchema } }, async (request, reply) => {
    const userId = request.userId!;
    const body = request.body as z.infer<typeof updateProfileSchema>;

    const user = await prisma.user.update({
      where: { id: userId },
      data: {
        ...(body.display_name !== undefined ? { displayName: body.display_name } : {}),
        ...(body.bio !== undefined ? { bio: body.bio } : {}),
        ...(body.language !== undefined ? { language: body.language } : {}),
      },
    });

    return reply.send(user);
  });

  // DELETE /users/me — Удалить профиль (делегирует auth/account)
  fastify.delete('/me', async (request, reply) => {
    return reply.code(400).send({ message: 'Используйте DELETE /auth/account для удаления аккаунта' });
  });

  // GET /users/:id — Чужой профиль
  fastify.get('/:id', async (request, reply) => {
    const { id } = request.params as { id: string };
    const viewerId = request.userId!;

    const user = await prisma.user.findUnique({
      where: { id, status: 'ACTIVE' },
      include: { privacySettings: true },
    });
    if (!user) return reply.code(404).send({ message: 'Пользователь не найден' });

    // Применяем настройки приватности
    const isContact = await prisma.contact.findFirst({
      where: { userId: viewerId, contactUserId: id },
    });

    const privacy = user.privacySettings;
    const canSeePhone = privacy?.phoneVisibility === 'EVERYONE' || (privacy?.phoneVisibility === 'CONTACTS' && isContact);

    return reply.send({
      id: user.id,
      username: user.username,
      display_name: user.displayName,
      bio: privacy?.profileVisibility === 'EVERYONE' || (privacy?.profileVisibility === 'CONTACTS' && isContact) ? user.bio : null,
      avatar_url: privacy?.avatarVisibility === 'EVERYONE' || (privacy?.avatarVisibility === 'CONTACTS' && isContact) ? user.avatarUrl : null,
      phone: canSeePhone ? user.phone : null,
      is_online: privacy?.lastSeenVisibility === 'EVERYONE' || (privacy?.lastSeenVisibility === 'CONTACTS' && isContact) ? user.isOnline : false,
      last_seen: privacy?.lastSeenVisibility === 'EVERYONE' || (privacy?.lastSeenVisibility === 'CONTACTS' && isContact) ? user.lastSeen : null,
    });
  });

  // GET /users/search?q= — Поиск пользователей
  fastify.get('/search', async (request, reply) => {
    const { q } = request.query as { q: string };
    if (!q || q.length < 2) return reply.send({ data: [] });

    const users = await prisma.user.findMany({
      where: {
        status: 'ACTIVE',
        OR: [
          { username: { contains: q, mode: 'insensitive' } },
          { displayName: { contains: q, mode: 'insensitive' } },
          { phone: { contains: q } },
        ],
      },
      take: 20,
      select: { id: true, username: true, displayName: true, avatarUrl: true },
    });

    return reply.send({ data: users });
  });

  // PATCH /users/me/avatar — Upload avatar to MinIO
  fastify.patch('/me/avatar', async (request, reply) => {
    const userId = request.userId!;
    const data = await request.file();
    if (!data) return reply.code(400).send({ message: 'Файл не предоставлен' });

    const fileBuffer = await data.toBuffer();

    // Upload to MinIO
    const objectKey = `avatars/${userId}/${Date.now()}_${data.filename}`;
    const minioClient = getMinioClient();

    try {
      await minioClient.putObject(BUCKET, objectKey, fileBuffer, fileBuffer.length, {
        'Content-Type': data.mimetype,
        'x-amz-meta-user-id': userId,
      });
      logger.info(`Avatar uploaded to MinIO: ${objectKey}`);
    } catch (err) {
      logger.error(`MinIO avatar upload failed: ${err}`);
      return reply.code(500).send({ message: 'Ошибка загрузки аватара' });
    }

    const avatarUrl = `${CDN_BASE}/${objectKey}`;
    await prisma.user.update({ where: { id: userId }, data: { avatarUrl } });

    return reply.send({ avatar_url: avatarUrl });
  });

  // ─── E2EE Key Bundle Routes ─────────────────────────────────────

  // GET /users/:id/keys — Получить PreKeyBundle другого пользователя
  fastify.get('/:id/keys', async (request, reply) => {
    const { id } = request.params as { id: string };

    const keys = await prisma.userKey.findUnique({
      where: { userId: id },
    });

    if (!keys) {
      return reply.code(404).send({ message: 'PreKeyBundle не найден' });
    }

    // Return prekeys as a proper list from the JSON bundle field
    const prekeysBundle = keys.preKeyBundle as any;
    const prekeys = Array.isArray(prekeysBundle) ? prekeysBundle :
      (prekeysBundle?.prekeys ? prekeysBundle.prekeys : []);

    return reply.send({
      identity_key: keys.identityKeyPublic,
      signed_prekey_id: keys.signedPreKeyId,
      signed_prekey_public: keys.signedPreKeyPublic,
      signed_prekey_signature: keys.signedPreKeySignature,
      registration_id: keys.registrationId,
      prekeys: prekeys,
    });
  });

  // POST /users/me/keys — Публикация своего PreKeyBundle
  fastify.post('/me/keys', async (request, reply) => {
    const userId = request.userId!;
    const body = request.body as any;

    const keys = await prisma.userKey.upsert({
      where: { userId },
      create: {
        userId,
        identityKeyPublic: body.identity_key || '',
        signedPreKeyId: body.signed_prekey_id || 0,
        signedPreKeyPublic: body.signed_prekey_public || '',
        signedPreKeySignature: body.signed_prekey_signature || '',
        registrationId: body.registration_id || 0,
        preKeyBundle: body.prekeys || {},
      },
      update: {
        identityKeyPublic: body.identity_key || '',
        signedPreKeyId: body.signed_prekey_id || 0,
        signedPreKeyPublic: body.signed_prekey_public || '',
        signedPreKeySignature: body.signed_prekey_signature || '',
        registrationId: body.registration_id || 0,
        preKeyBundle: body.prekeys || {},
      },
    });

    return reply.code(201).send(keys);
  });

  // DELETE /users/me/keys — Удалить свои ключи (при удалении аккаунта)
  fastify.delete('/me/keys', async (request, reply) => {
    const userId = request.userId!;

    try {
      await prisma.userKey.delete({ where: { userId } });
    } catch {
      // Keys might not exist — that's OK
    }

    await prisma.keyRequest.deleteMany({
      where: { OR: [{ requesterId: userId }, { targetId: userId }] },
    });

    return reply.code(204).send();
  });

  // ─── GET /users/search — Глобальный поиск ────────────────────────
  fastify.get('/search', async (request, reply) => {
    const userId = request.userId!;
    const { q } = request.query as { q: string };

    if (!q || q.trim().length < 2) {
      return reply.send({ chats: [], messages: [], contacts: [] });
    }

    const query = q.trim();

    // Search chats
    const chatMemberships = await prisma.chatMember.findMany({
      where: { userId },
      include: {
        chat: {
          include: {
            members: {
              include: { user: { select: { id: true, displayName: true, avatarUrl: true } } },
            },
          },
        },
      },
    });

    const chats = chatMemberships
      .filter(m => {
        const chat = m.chat;
        return chat.title?.toLowerCase().includes(query.toLowerCase()) ?? false;
      })
      .map(m => ({
        id: m.chat.id,
        title: m.chat.type === 'PRIVATE'
          ? m.chat.members.find(mem => mem.userId !== userId)?.user.displayName ?? 'Чат'
          : m.chat.title,
        last_message: null,
      }))
      .slice(0, 10);

    // Search messages
    const messages = await prisma.message.findMany({
      where: {
        chat: { members: { some: { userId } } },
        isDeleted: false,
        content: { string_contains: query },
      },
      take: 20,
      orderBy: { createdAt: 'desc' },
      select: {
        id: true,
        chatId: true,
        content: true,
        senderId: true,
        sender: { select: { id: true, displayName: true, username: true } },
      },
    });

    const formattedMessages = messages.map(m => ({
      id: m.id,
      chat_id: m.chatId,
      content: m.content,
      sender_id: m.senderId,
      sender_name: m.sender.displayName ?? m.sender.username,
    }));

    // Search contacts
    const contacts = await prisma.contact.findMany({
      where: {
        userId,
        isBlocked: false,
        contactUser: {
          OR: [
            { username: { contains: query, mode: 'insensitive' } },
            { displayName: { contains: query, mode: 'insensitive' } },
          ],
        },
      },
      include: {
        contactUser: { select: { id: true, username: true, displayName: true, avatarUrl: true } },
      },
      take: 10,
    });

    const formattedContacts = contacts.map(c => ({
      id: c.contactUser.id,
      username: c.contactUser.username,
      display_name: c.contactUser.displayName,
      avatar_url: c.contactUser.avatarUrl,
    }));

    return reply.send({ chats, messages: formattedMessages, contacts: formattedContacts });
  });
}
