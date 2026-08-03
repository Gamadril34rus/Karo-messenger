import { FastifyInstance } from 'fastify';
import { z } from 'zod';

// ─── Validation helper ─────────────────────────────────────────────
function validateBody<T>(schema: import('zod').ZodSchema<T>, body: unknown): T {
  const result = schema.safeParse(body);
  if (!result.success) {
    const err = new Error(result.error.issues[0]?.message || 'Validation error') as any;
    err.statusCode = 400;
    throw err;
  }
  return result.data;
}

const searchQuerySchema = z.object({
  q: z.string().min(2).max(200),
});

/**
 * GET /search — Глобальный поиск (чаты + сообщения + контакты)
 *
 * Standalone top-level search route that mirrors /users/search
 * but is accessible at /api/v1/search for client convenience.
 */
export async function searchRoutes(fastify: FastifyInstance) {
  const { prisma } = fastify;

  fastify.get('/', { schema: { querystring: searchQuerySchema } }, async (request, reply) => {
    const userId = request.userId!;
    const { q } = request.query as z.infer<typeof searchQuerySchema>;

    const query = q.trim();

    // ─── Search chats ──────────────────────────────────────────────
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

    // ─── Search messages ───────────────────────────────────────────
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

    // ─── Search contacts ───────────────────────────────────────────
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
