import { FastifyInstance } from 'fastify';

export async function aiRoutes(fastify: FastifyInstance) {
  const { prisma } = fastify;

  // POST /ai/chat — Чат с AI
  fastify.post('/chat', async (request, reply) => {
    const userId = request.userId!;
    const { conversation_id, message, action } = request.body as {
      conversation_id?: string;
      message?: string;
      action?: string;
    };

    // Если action=new — создаём новую беседу
    if (action === 'new') {
      const conv = await prisma.aiConversation.create({ data: { userId, title: 'Новая беседа' } });
      return reply.send({ id: conv.id, messages: [] });
    }

    // Сохраняем сообщение пользователя
    if (message) {
      let convId = conversation_id;
      if (!convId) {
        const conv = await prisma.aiConversation.create({ data: { userId, title: message.substring(0, 50) } });
        convId = conv.id;
      }

      await prisma.aiMessage.create({
        data: { conversationId: convId, role: 'USER', content: message },
      });

      // Генерируем ответ AI (заглушка — в реальности вызов LLM API)
      const aiResponse = await _generateAiResponse(message);

      await prisma.aiMessage.create({
        data: { conversationId: convId, role: 'ASSISTANT', content: aiResponse },
      });

      return reply.send({
        conversation_id: convId,
        content: aiResponse,
      });
    }

    // Если нет сообщения — возвращаем историю
    if (conversation_id) {
      const messages = await prisma.aiMessage.findMany({
        where: { conversationId: conversation_id },
        orderBy: { createdAt: 'asc' },
      });
      return reply.send({ conversation_id, messages });
    }

    return reply.code(400).send({ message: 'Укажите message или action' });
  });

  // POST /ai/transcribe — Транскрипция голоса
  fastify.post('/transcribe', async (request, reply) => {
    const data = await request.file();
    if (!data) return reply.code(400).send({ message: 'Аудио не предоставлено' });

    // Заглушка — в реальности вызов Whisper API
    return reply.send({ text: 'Распознанный текст голосового сообщения', confidence: 0.95 });
  });

  // POST /ai/summarize — Саммаризация чата
  fastify.post('/summarize', async (request, reply) => {
    const { chat_id } = request.body as { chat_id: string };

    const messages = await prisma.message.findMany({
      where: { chatId: chat_id, isDeleted: false },
      take: 100,
      orderBy: { createdAt: 'desc' },
      include: { sender: { select: { displayName: true } } },
    });

    const context = messages.reverse().map(m =>
      `${m.sender.displayName}: ${(m.content as Record<string, unknown>)?.text ?? '[медиа]'}`
    ).join('\n');

    const summary = await _generateSummary(context);

    return reply.send({ summary });
  });

  // POST /ai/generate-sticker — Генерация стикера
  fastify.post('/generate-sticker', async (request, reply) => {
    const { prompt } = request.body as { prompt: string };

    // В реальности — вызов DALL-E / Stable Diffusion API
    const url = `https://cdn.charo.chat/ai-stickers/${Date.now()}.webp`;

    return reply.send({ url, prompt });
  });

  // POST /ai/generate-avatar — Генерация аватара
  fastify.post('/generate-avatar', async (request, reply) => {
    const { prompt } = request.body as { prompt?: string };

    const url = `https://cdn.charo.chat/ai-avatars/${Date.now()}.png`;

    return reply.send({ url });
  });
}

// Вспомогательные функции (заглушки для AI-провайдеров)
async function _generateAiResponse(userMessage: string): Promise<string> {
  // В реальности: вызов Google Gemini / OpenAI / Anthropic API
  await new Promise(r => setTimeout(r, 500)); // Имитация задержки

  if (userMessage.toLowerCase().includes('привет')) return 'Привет! Чем могу помочь?';
  if (userMessage.toLowerCase().includes('перевед')) return 'Конечно, отправьте текст для перевода, и я переведу его.';
  if (userMessage.toLowerCase().includes('погод')) return 'К сожалению, у меня нет доступа к данным о погоде в реальном времени. Попробуйте специализированный сервис.';
  return 'Я AI-ассистент ЧАРО. Могу помочь с переводом, саммаризацией чатов, генерацией стикеров и ответами на вопросы. Чем могу помочь?';
}

async function _generateSummary(context: string): Promise<string> {
  // В реальности: вызов LLM с промптом для саммаризации
  const lines = context.split('\n').length;
  return `В этом чате ${lines} сообщений. Основные темы обсуждения: общение, планирование, обмен медиа.`;
}
