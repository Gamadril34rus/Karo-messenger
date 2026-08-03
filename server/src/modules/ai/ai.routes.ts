import { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { logger } from '../../utils/logger';

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

/// Gemini AI Integration — real Google Gemini API
/// Uses @google/generative-ai server-side SDK concept implemented via direct HTTP calls

const GEMINI_API_KEY = process.env.GEMINI_API_KEY || '';
const GEMINI_API_URL = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${GEMINI_API_KEY}`;

async function callGemini(prompt: string): Promise<string> {
  if (!GEMINI_API_KEY) {
    logger.warn('GEMINI_API_KEY not configured — AI responses are limited to pattern-matching fallback');
    return _fallbackResponse(prompt);
  }

  try {
    const response = await fetch(GEMINI_API_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents: [{ parts: [{ text: prompt }] }],
        generationConfig: {
          temperature: 0.7,
          maxOutputTokens: 2048,
          topP: 0.95,
        },
        safetySettings: [
          { category: 'HARM_CATEGORY_HARASSMENT', threshold: 'BLOCK_ONLY_HIGH' },
          { category: 'HARM_CATEGORY_HATE_SPEECH', threshold: 'BLOCK_ONLY_HIGH' },
          { category: 'HARM_CATEGORY_SEXUALLY_EXPLICIT', threshold: 'BLOCK_ONLY_HIGH' },
          { category: 'HARM_CATEGORY_DANGEROUS_CONTENT', threshold: 'BLOCK_ONLY_HIGH' },
        ],
      }),
    });

    if (!response.ok) {
      logger.error(`Gemini API error: ${response.status} ${response.statusText}`);
      return _fallbackResponse(prompt);
    }

    const data = await response.json() as any;
    const text = data?.candidates?.[0]?.content?.parts?.[0]?.text;
    if (text) {
      logger.info(`Gemini response generated (${text.length} chars)`);
      return text;
    }

    return _fallbackResponse(prompt);
  } catch (err) {
    logger.error(`Gemini API call failed: ${err}`);
    return _fallbackResponse(prompt);
  }
}

/// Fallback when Gemini API key is not available
function _fallbackResponse(prompt: string): string {
  const lower = prompt.toLowerCase();
  if (lower.includes('привет') || lower.includes('hello')) return 'Привет! Я AI-ассистент ЧАРО. Чем могу помочь?';
  if (lower.includes('перевед') || lower.includes('translate')) return 'Отправьте текст для перевода, и я переведу его на нужный язык.';
  if (lower.includes('суммар') || lower.includes('summarize')) return 'Отправьте текст или ID чата, и я сделаю краткую саммаризацию.';
  if (lower.includes('стикер') || lower.includes('sticker')) return 'Опишите стикер, и я постараюсь помочь с его генерацией или поиском.';
  return 'Я AI-ассистент ЧАРО. Могу помочь с переводом, саммаризацией чатов, генерацией стикеров и ответами на вопросы. Чем могу помочь?';
}

const aiChatSchema = z.object({
  conversation_id: z.string().uuid().optional(),
  message: z.string().max(4000).optional(),
  action: z.enum(['new']).optional(),
});

const aiSummarizeSchema = z.object({
  chat_id: z.string().uuid(),
});

const aiGenerateSchema = z.object({
  prompt: z.string().min(1).max(500),
});

export async function aiRoutes(fastify: FastifyInstance) {
  const { prisma } = fastify;

  // POST /ai/chat — Chat with AI (real Gemini integration)
  fastify.post('/chat', {}, async (request, reply) => {
    const userId = request.userId!;
    const { conversation_id, message, action } = validateBody(aiChatSchema, request.body);

    // If action=new — create a new conversation
    if (action === 'new') {
      const conv = await prisma.aiConversation.create({ data: { userId, title: 'Новая беседа' } });
      return reply.send({ id: conv.id, messages: [] });
    }

    // Save user message and generate AI response
    if (message) {
      let convId = conversation_id;
      if (!convId) {
        const conv = await prisma.aiConversation.create({ data: { userId, title: message.substring(0, 50) } });
        convId = conv.id;
      }

      await prisma.aiMessage.create({
        data: { conversationId: convId, role: 'USER', content: message },
      });

      // Build conversation context for Gemini (last 10 messages)
      const recentMessages = await prisma.aiMessage.findMany({
        where: { conversationId: convId },
        orderBy: { createdAt: 'asc' },
        take: 10,
      });

      const contextPrompt = recentMessages
        .map(m => `${m.role === 'USER' ? 'Пользователь' : 'ЧАРО AI'}: ${m.content}`)
        .join('\n');

      const fullPrompt = `Вы — AI-ассистент мессенджера ЧАРО. Отвечайте на русском языке. Будьте дружелюбным, полезным и кратким.\n\n${contextPrompt}\nЧАРО AI:`;

      // Generate response via Gemini
      const aiResponse = await callGemini(fullPrompt);

      await prisma.aiMessage.create({
        data: { conversationId: convId, role: 'ASSISTANT', content: aiResponse },
      });

      return reply.send({
        conversation_id: convId,
        content: aiResponse,
      });
    }

    // If no message — return conversation history
    if (conversation_id) {
      const messages = await prisma.aiMessage.findMany({
        where: { conversationId: conversation_id },
        orderBy: { createdAt: 'asc' },
      });
      return reply.send({ conversation_id, messages });
    }

    return reply.code(400).send({ message: 'Укажите message или action' });
  });

  // POST /ai/transcribe — Transcribe voice message (real Whisper API)
  fastify.post('/transcribe', async (request, reply) => {
    const data = await request.file();
    if (!data) return reply.code(400).send({ message: 'Аудио не предоставлено' });

    const audioBuffer = await data.toBuffer();
    const mimeType = data.mimetype;

    // Real Whisper API integration
    const WHISPER_API_KEY = process.env.OPENAI_API_KEY || process.env.WHISPER_API_KEY || '';

    if (!WHISPER_API_KEY) {
      // Whisper API not configured — return pending status
      logger.info(`Audio transcription request received (${audioBuffer.length} bytes, ${mimeType})`);
      return reply.send({
        text: 'Аудиосообщение получено. Транскрипция будет доступна после настройки Whisper API.',
        confidence: 0.5,
        status: 'pending',
      });
    }

    try {
      const formData = new FormData();
      formData.append('file', new Blob([audioBuffer], { type: mimeType }), data.filename);
      formData.append('model', 'whisper-1');
      formData.append('language', 'ru');

      const response = await fetch('https://api.openai.com/v1/audio/transcriptions', {
        method: 'POST',
        headers: { 'Authorization': `Bearer ${WHISPER_API_KEY}` },
        body: formData,
      });

      if (!response.ok) {
        logger.error(`Whisper API error: ${response.status}`);
        return reply.send({ text: 'Ошибка транскрипции', confidence: 0, status: 'error' });
      }

      const result = await response.json() as { text: string };
      logger.info(`Voice transcribed: "${result.text}"`);

      return reply.send({
        text: result.text,
        confidence: 0.9,
        status: 'completed',
      });
    } catch (err) {
      logger.error(`Whisper transcription failed: ${err}`);
      return reply.send({ text: 'Ошибка транскрипции', confidence: 0, status: 'error' });
    }
  });

  // POST /ai/summarize — Summarize chat messages
  fastify.post('/summarize', {}, async (request, reply) => {
    const { chat_id } = validateBody(aiSummarizeSchema, request.body);

    const messages = await prisma.message.findMany({
      where: { chatId: chat_id, isDeleted: false },
      take: 100,
      orderBy: { createdAt: 'desc' },
      include: { sender: { select: { displayName: true } } },
    });

    const context = messages.reverse().map(m =>
      `${m.sender.displayName}: ${(m.content as Record<string, unknown>)?.text ?? '[медиа]'}`
    ).join('\n');

    const prompt = `Сделайте краткую саммаризацию этого чата на русском языке (3-5 предложений):\n\n${context}`;

    const summary = await callGemini(prompt);

    return reply.send({ summary });
  });

  // POST /ai/generate-sticker — Generate sticker image (real AI generation)
  fastify.post('/generate-sticker', {}, async (request, reply) => {
    const { prompt } = validateBody(aiGenerateSchema, request.body);

    if (!GEMINI_API_KEY) {
      return reply.code(503).send({ message: 'AI генерация требует Gemini API key' });
    }

    try {
      // Use Imagen API for image generation (Gemini's image model)
      const IMAGEN_URL = `https://generativelanguage.googleapis.com/v1beta/models/imagen-3.0-generate:predict?key=${GEMINI_API_KEY}`;

      const response = await fetch(IMAGEN_URL, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          instances: [{ prompt: ` sticker style, cute, simple design: ${prompt}` }],
          parameters: { sampleCount: 1, aspectRatio: '1:1' },
        }),
      });

      if (!response.ok) {
        logger.error(`Imagen API error: ${response.status}`);
        return reply.code(503).send({ message: 'Сервис генерации временно недоступен' });
      }

      const result = await response.json() as any;
      const imageBytesBase64 = result?.predictions?.[0]?.bytesBase64Encoded;

      if (imageBytesBase64) {
        // Upload generated image to MinIO
        const minioClient = new (await import('minio')).Client({
          endPoint: process.env.MINIO_ENDPOINT || 'localhost',
          port: Number(process.env.MINIO_PORT) || 9000,
          useSSL: process.env.MINIO_USE_SSL === 'true',
          accessKey: process.env.MINIO_ACCESS_KEY || 'minioadmin',
          secretKey: process.env.MINIO_SECRET_KEY || 'minioadmin',
        });

        const bucket = process.env.MINIO_BUCKET || 'charo-media';
        const objectKey = `ai-stickers/${Date.now()}.webp`;
        const imageBuffer = Buffer.from(imageBytesBase64, 'base64');

        await minioClient.putObject(bucket, objectKey, imageBuffer, imageBuffer.length, {
          'Content-Type': 'image/webp',
        });

        const cdnBase = process.env.CDN_BASE_URL || 'https://cdn.charo.chat';
        const url = `${cdnBase}/${objectKey}`;

        return reply.send({ url, prompt });
      }

      return reply.code(503).send({ message: 'Не удалось сгенерировать стикер' });
    } catch (err) {
      logger.error(`Sticker generation failed: ${err}`);
      return reply.code(503).send({ message: 'Сервис генерации временно недоступен' });
    }
  });

  // POST /ai/generate-avatar — Generate avatar image
  fastify.post('/generate-avatar', {}, async (request, reply) => {
    const { prompt } = validateBody(aiGenerateSchema, request.body);

    if (!GEMINI_API_KEY) {
      return reply.code(503).send({ message: 'AI генерация требует Gemini API key' });
    }

    try {
      const IMAGEN_URL = `https://generativelanguage.googleapis.com/v1beta/models/imagen-3.0-generate:predict?key=${GEMINI_API_KEY}`;
      const avatarPrompt = prompt || 'funny cartoon avatar, friendly face, vibrant colors';

      const response = await fetch(IMAGEN_URL, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          instances: [{ prompt: `avatar, profile picture style: ${avatarPrompt}` }],
          parameters: { sampleCount: 1, aspectRatio: '1:1' },
        }),
      });

      if (!response.ok) {
        logger.error(`Imagen API error: ${response.status}`);
        return reply.code(503).send({ message: 'Сервис генерации временно недоступен' });
      }

      const result = await response.json() as any;
      const imageBytesBase64 = result?.predictions?.[0]?.bytesBase64Encoded;

      if (imageBytesBase64) {
        const minioClient = new (await import('minio')).Client({
          endPoint: process.env.MINIO_ENDPOINT || 'localhost',
          port: Number(process.env.MINIO_PORT) || 9000,
          useSSL: process.env.MINIO_USE_SSL === 'true',
          accessKey: process.env.MINIO_ACCESS_KEY || 'minioadmin',
          secretKey: process.env.MINIO_SECRET_KEY || 'minioadmin',
        });

        const bucket = process.env.MINIO_BUCKET || 'charo-media';
        const objectKey = `ai-avatars/${Date.now()}.png`;
        const imageBuffer = Buffer.from(imageBytesBase64, 'base64');

        await minioClient.putObject(bucket, objectKey, imageBuffer, imageBuffer.length, {
          'Content-Type': 'image/png',
        });

        const cdnBase = process.env.CDN_BASE_URL || 'https://cdn.charo.chat';
        const url = `${cdnBase}/${objectKey}`;

        return reply.send({ url });
      }

      return reply.code(503).send({ message: 'Не удалось сгенерировать аватар' });
    } catch (err) {
      logger.error(`Avatar generation failed: ${err}`);
      return reply.code(503).send({ message: 'Сервис генерации временно недоступен' });
    }
  });
}
