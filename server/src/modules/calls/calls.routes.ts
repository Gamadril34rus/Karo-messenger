import { FastifyInstance } from 'fastify';

export async function callsRoutes(fastify: FastifyInstance) {
  const { prisma } = fastify;

  // POST /calls — Инициировать звонок
  fastify.post('/', async (request, reply) => {
    const userId = request.userId!;
    const { chatId, type, targetUserIds } = request.body as {
      chatId?: string;
      type: 'VOICE' | 'VIDEO';
      targetUserIds?: string[];
    };

    const call = await prisma.call.create({
      data: {
        chatId: chatId ?? null,
        callerId: userId,
        type,
        status: 'RINGING',
        members: {
          create: [
            { userId },
            ...(targetUserIds?.map(uid => ({ userId: uid })) ?? []),
          ],
        },
      },
    });

    return reply.code(201).send(call);
  });

  // GET /calls/history — История звонков
  fastify.get('/history', async (request, reply) => {
    const userId = request.userId!;

    const calls = await prisma.call.findMany({
      where: { members: { some: { userId } } },
      orderBy: { startedAt: 'desc' },
      take: 50,
      include: {
        caller: { select: { id: true, displayName: true, avatarUrl: true } },
      },
    });

    const formatted = calls.map(call => ({
      id: call.id,
      type: call.type,
      status: call.status,
      direction: call.callerId === userId ? 'outgoing' : 'incoming',
      started_at: call.startedAt,
      ended_at: call.endedAt,
      duration_sec: call.durationSec,
      caller: call.caller,
    }));

    return reply.send({ data: formatted });
  });
}
