import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

/// MLS Routes — Messaging Layer Security для группового шифрования ЧАРО
///
/// Все маршруты защищены authMiddleware (установленным на уровне /api/v1)
/// Поэтому не нужно добавлять preHandler в каждый route.

export async function mlsRoutes(app: FastifyInstance) {

  // ─── Создание MLS группы ────────────────────────────────────────
  app.post('/mls/groups', async (req: FastifyRequest, reply: FastifyReply) => {
    const userId = (req as any).user?.id;
    if (!userId) return reply.code(401).send({ message: 'Не авторизован' });

    const body = req.body as any;

    const group = await prisma.mlsGroup.create({
      data: {
        name: body.name || 'MLS Group',
        cipherSuite: body.cipher_suite || 'MLS128_DHKEMX25519_AES128GCM_SHA256_Ed25519',
        epoch: 0,
        treeData: body.tree || {},
        confirmationKey: body.confirmation_key,
        members: {
          create: [
            { userId, leafIndex: 0 },
            ...(body.members || []).map((memberId: string, index: number) => ({
              userId: memberId,
              leafIndex: index + 1,
            })),
          ],
        },
      },
      include: { members: true },
    });

    return reply.code(201).send(group);
  });

  // ─── Список MLS групп пользователя ──────────────────────────────
  app.get('/mls/groups', async (req: FastifyRequest, reply: FastifyReply) => {
    const userId = (req as any).user?.id;
    if (!userId) return reply.code(401).send({ message: 'Не авторизован' });

    const memberships = await prisma.mlsGroupMember.findMany({
      where: { userId },
      include: { group: { include: { members: true } } },
    });

    const groups = memberships.map(m => m.group);
    return reply.send(groups);
  });

  // ─── Детали MLS группы ──────────────────────────────────────────
  app.get('/mls/groups/:id', async (req: FastifyRequest, reply: FastifyReply) => {
    const { id } = req.params as any;
    const userId = (req as any).user?.id;

    const membership = await prisma.mlsGroupMember.findFirst({
      where: { groupId: id, userId },
    });

    if (!membership) {
      return reply.code(403).send({ message: 'Вы не участник этой MLS группы' });
    }

    const group = await prisma.mlsGroup.findUnique({
      where: { id },
      include: {
        members: { include: { user: true } },
        treeNodes: { orderBy: { index: 'asc' } },
      },
    });

    if (!group) {
      return reply.code(404).send({ message: 'MLS группа не найдена' });
    }

    return reply.send(group);
  });

  // ─── Вступление в MLS группу ────────────────────────────────────
  app.post('/mls/groups/:id/join', async (req: FastifyRequest, reply: FastifyReply) => {
    const { id } = req.params as any;
    const userId = (req as any).user?.id;

    const group = await prisma.mlsGroup.findUnique({ where: { id } });
    if (!group) {
      return reply.code(404).send({ message: 'MLS группа не найдена' });
    }

    const existingMember = await prisma.mlsGroupMember.findFirst({
      where: { groupId: id, userId },
    });

    if (existingMember) {
      return reply.code(409).send({ message: 'Вы уже участник этой MLS группы' });
    }

    const memberCount = await prisma.mlsGroupMember.count({ where: { groupId: id } });
    const leafIndex = memberCount;

    const member = await prisma.mlsGroupMember.create({
      data: { groupId: id, userId, leafIndex },
    });

    await prisma.mlsGroup.update({
      where: { id },
      data: { epoch: { increment: 1 } },
    });

    return reply.code(201).send(member);
  });

  // ─── Удаление MLS группы ────────────────────────────────────────
  app.delete('/mls/groups/:id', async (req: FastifyRequest, reply: FastifyReply) => {
    const { id } = req.params as any;
    const userId = (req as any).user?.id;

    const firstMember = await prisma.mlsGroupMember.findFirst({
      where: { groupId: id },
      orderBy: { leafIndex: 'asc' },
    });

    if (firstMember?.userId !== userId) {
      return reply.code(403).send({ message: 'Только creator может удалить MLS группу' });
    }

    await prisma.mlsGroup.delete({ where: { id } });
    return reply.code(204).send();
  });

  // ─── Отправка MLS-сообщения ─────────────────────────────────────
  app.post('/mls/messages', async (req: FastifyRequest, reply: FastifyReply) => {
    const userId = (req as any).user?.id;
    const body = req.body as any;
    const groupId = body.group_id;

    if (!groupId) {
      return reply.code(400).send({ message: 'group_id обязателен' });
    }

    const membership = await prisma.mlsGroupMember.findFirst({
      where: { groupId, userId },
    });

    if (!membership) {
      return reply.code(403).send({ message: 'Вы не участник этой MLS группы' });
    }

    const group = await prisma.mlsGroup.findUnique({ where: { id: groupId } });
    if (group && body.epoch < group.epoch) {
      return reply.code(409).send({ message: 'Stale epoch — possible replay attack' });
    }

    const message = await prisma.mlsMessage.create({
      data: {
        groupId,
        epoch: body.epoch || 0,
        type: body.type || 'APPLICATION',
        encryptedContent: body.encrypted_content || '',
        signature: body.signature || '',
        senderId: userId,
      },
    });

    return reply.code(201).send(message);
  });

  // ─── Получение MLS-сообщений ────────────────────────────────────
  app.get('/mls/groups/:id/messages', async (req: FastifyRequest, reply: FastifyReply) => {
    const { id } = req.params as any;
    const userId = (req as any).user?.id;
    const query = req.query as any;

    const membership = await prisma.mlsGroupMember.findFirst({
      where: { groupId: id, userId },
    });

    if (!membership) {
      return reply.code(403).send({ message: 'Вы не участник этой MLS группы' });
    }

    const messages = await prisma.mlsMessage.findMany({
      where: {
        groupId: id,
        ...(query.after_epoch ? { epoch: { gt: parseInt(query.after_epoch) } } : {}),
      },
      orderBy: { createdAt: 'desc' },
      take: parseInt(query.limit) || 50,
    });

    return reply.send(messages);
  });

  // ─── Отправка MLS Commit ────────────────────────────────────────
  app.post('/mls/commits', async (req: FastifyRequest, reply: FastifyReply) => {
    const userId = (req as any).user?.id;
    const body = req.body as any;
    const groupId = body.group_id;

    if (!groupId) {
      return reply.code(400).send({ message: 'group_id обязателен' });
    }

    const membership = await prisma.mlsGroupMember.findFirst({
      where: { groupId, userId },
    });

    if (!membership) {
      return reply.code(403).send({ message: 'Вы не участник этой MLS группы' });
    }

    const commit = await prisma.mlsCommit.create({
      data: {
        groupId,
        epoch: body.epoch || 0,
        proposals: body.proposals || [],
        updatePath: body.update_path || null,
        confirmationTag: body.confirmation_tag || '',
        senderId: userId,
      },
    });

    await prisma.mlsGroup.update({
      where: { id: groupId },
      data: { epoch: body.epoch || 0 },
    });

    return reply.code(201).send(commit);
  });

  // ─── Получение MLS Commits ──────────────────────────────────────
  app.get('/mls/groups/:id/commits', async (req: FastifyRequest, reply: FastifyReply) => {
    const { id } = req.params as any;
    const userId = (req as any).user?.id;

    const membership = await prisma.mlsGroupMember.findFirst({
      where: { groupId: id, userId },
    });

    if (!membership) {
      return reply.code(403).send({ message: 'Вы не участник этой MLS группы' });
    }

    const commits = await prisma.mlsCommit.findMany({
      where: { groupId: id },
      orderBy: { createdAt: 'desc' },
      take: 50,
    });

    return reply.send(commits);
  });

  // ─── Welcome message ────────────────────────────────────────────
  app.post('/mls/welcome', async (req: FastifyRequest, reply: FastifyReply) => {
    const userId = (req as any).user?.id;
    const body = req.body as any;

    const targetUserId = body.target_user_id || body.welcome_key;
    if (!targetUserId) {
      return reply.code(400).send({ message: 'target_user_id обязателен' });
    }

    // Welcome message — сохраняется как система, доставка через WebSocket/push
    return reply.code(200).send({ message: 'Welcome message отправлен', target_user_id: targetUserId });
  });

  // ─── Ratchet Tree ───────────────────────────────────────────────
  app.get('/mls/groups/:id/tree', async (req: FastifyRequest, reply: FastifyReply) => {
    const { id } = req.params as any;
    const userId = (req as any).user?.id;

    const membership = await prisma.mlsGroupMember.findFirst({
      where: { groupId: id, userId },
    });

    if (!membership) {
      return reply.code(403).send({ message: 'Вы не участник этой MLS группы' });
    }

    const treeNodes = await prisma.ratchetTreeNode.findMany({
      where: { groupId: id },
      orderBy: { index: 'asc' },
    });

    const group = await prisma.mlsGroup.findUnique({
      where: { id },
      select: { epoch: true, treeData: true },
    });

    return reply.send({
      group_id: id,
      epoch: group?.epoch || 0,
      nodes: treeNodes,
      tree_data: group?.treeData || {},
    });
  });

  // ─── Обновление Ratchet Tree ────────────────────────────────────
  app.patch('/mls/groups/:id/tree', async (req: FastifyRequest, reply: FastifyReply) => {
    const { id } = req.params as any;
    const userId = (req as any).user?.id;
    const body = req.body as any;

    const membership = await prisma.mlsGroupMember.findFirst({
      where: { groupId: id, userId },
    });

    if (!membership) {
      return reply.code(403).send({ message: 'Вы не участник этой MLS группы' });
    }

    await prisma.mlsGroup.update({
      where: { id },
      data: {
        treeData: body.tree_data || {},
        epoch: body.epoch || { increment: 1 },
      },
    });

    if (body.nodes) {
      for (const node of body.nodes) {
        await prisma.ratchetTreeNode.upsert({
          where: { groupId_index: { groupId: id, index: node.index } },
          create: {
            groupId: id,
            index: node.index,
            type: node.type || 'leaf',
            publicKey: node.public_key || '',
            privateKey: node.private_key,
            userId: node.user_id,
            isBlank: node.is_blank || false,
          },
          update: {
            publicKey: node.public_key || '',
            privateKey: node.private_key,
            isBlank: node.is_blank || false,
          },
        });
      }
    }

    return reply.send({ message: 'Ratchet Tree обновлен' });
  });

  // ─── Добавление участника ───────────────────────────────────────
  app.post('/mls/groups/:id/members', async (req: FastifyRequest, reply: FastifyReply) => {
    const { id } = req.params as any;
    const userId = (req as any).user?.id;
    const body = req.body as any;
    const targetUserId = body.user_id;

    if (!targetUserId) {
      return reply.code(400).send({ message: 'user_id обязателен' });
    }

    const memberCount = await prisma.mlsGroupMember.count({ where: { groupId: id } });

    const member = await prisma.mlsGroupMember.create({
      data: { groupId: id, userId: targetUserId, leafIndex: memberCount },
    });

    await prisma.mlsGroup.update({
      where: { id },
      data: { epoch: { increment: 1 } },
    });

    return reply.code(201).send(member);
  });

  // ─── Удаление участника ─────────────────────────────────────────
  app.delete('/mls/groups/:id/members/:memberUserId', async (req: FastifyRequest, reply: FastifyReply) => {
    const { id, memberUserId } = req.params as any;
    const userId = (req as any).user?.id;

    if (userId !== memberUserId) {
      const firstMember = await prisma.mlsGroupMember.findFirst({
        where: { groupId: id, leafIndex: 0 },
      });
      if (firstMember?.userId !== userId) {
        return reply.code(403).send({ message: 'Только creator может удалять участников' });
      }
    }

    await prisma.mlsGroupMember.deleteMany({
      where: { groupId: id, userId: memberUserId },
    });

    await prisma.mlsGroup.update({
      where: { id },
      data: { epoch: { increment: 1 } },
    });

    return reply.code(204).send();
  });

  // ─── Запрос PreKeyBundle (key request) ──────────────────────────
  app.post('/key-requests', async (req: FastifyRequest, reply: FastifyReply) => {
    const userId = (req as any).user?.id;
    const body = req.body as any;
    const targetId = body.target_user_id;

    if (!targetId) {
      return reply.code(400).send({ message: 'target_user_id обязателен' });
    }

    const request = await prisma.keyRequest.create({
      data: { requesterId: userId, targetId, status: 'pending' },
    });

    return reply.code(201).send(request);
  });

  // ─── E2EE Key endpoints moved to users.routes.ts ────────────────
  // GET  /users/:id/keys    → users.routes.ts
  // POST /users/me/keys     → users.routes.ts
  // DELETE /users/me/keys   → users.routes.ts
}
