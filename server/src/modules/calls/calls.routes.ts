// © 2024-2026 Charo Team. All rights reserved. PROPRIETARY AND CONFIDENTIAL.
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

const createCallSchema = z.object({
  chatId: z.string().uuid().optional(),
  type: z.enum(['VOICE', 'VIDEO']),
  targetUserIds: z.array(z.string().uuid()).max(10).optional(),
});

export async function callsRoutes(fastify: FastifyInstance) {
  const { prisma } = fastify;

  // POST /calls — Инициировать звонок
  fastify.post('/', {}, async (request, reply) => {
    const userId = request.userId!;
    const { chatId, type, targetUserIds } = validateBody(createCallSchema, request.body);

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
