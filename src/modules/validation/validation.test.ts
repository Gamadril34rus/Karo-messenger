import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import { buildServer } from '../../index';

describe('Input validation across modules', () => {
  let fastify: Awaited<ReturnType<typeof buildServer>>;
  let token: string;

  beforeAll(async () => {
    fastify = await buildServer();
    await fastify.ready();

    const jwt = await import('jsonwebtoken');
    token = jwt.sign(
      { userId: 'test-user-id' },
      process.env.JWT_ACCESS_SECRET || 'charo-access-secret',
      { expiresIn: '15m' }
    );
  });

  afterAll(async () => {
    await fastify.close();
  });

  // ─── Calls validation ──────────────────────────────────────────

  it('POST /calls rejects invalid type', async () => {
    const response = await fastify.inject({
      method: 'POST',
      url: '/api/v1/calls',
      headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
      payload: { type: 'INVALID', targetUserIds: [] },
    });

    expect(response.statusCode).toBe(400);
  });

  it('POST /calls rejects missing type', async () => {
    const response = await fastify.inject({
      method: 'POST',
      url: '/api/v1/calls',
      headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
      payload: { targetUserIds: [] },
    });

    expect(response.statusCode).toBe(400);
  });

  it('POST /calls accepts valid VOICE call', async () => {
    const response = await fastify.inject({
      method: 'POST',
      url: '/api/v1/calls',
      headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
      payload: { type: 'VOICE' },
    });

    // May fail due to DB but should not be 400
    expect(response.statusCode).not.toBe(400);
  });

  // ─── Stories validation ─────────────────────────────────────────

  it('POST /stories rejects invalid type', async () => {
    const response = await fastify.inject({
      method: 'POST',
      url: '/api/v1/stories',
      headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
      payload: { type: 'AUDIO' },
    });

    expect(response.statusCode).toBe(400);
  });

  it('POST /stories rejects invalid backgroundColor', async () => {
    const response = await fastify.inject({
      method: 'POST',
      url: '/api/v1/stories',
      headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
      payload: { type: 'TEXT', backgroundColor: 'red' },
    });

    expect(response.statusCode).toBe(400);
  });

  it('POST /stories accepts valid TEXT story', async () => {
    const response = await fastify.inject({
      method: 'POST',
      url: '/api/v1/stories',
      headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
      payload: { type: 'TEXT', backgroundColor: '#FF5733' },
    });

    expect(response.statusCode).not.toBe(400);
  });

  // ─── Messages validation ─────────────────────────────────────────

  it('POST /messages/:id/react rejects empty emoji', async () => {
    const response = await fastify.inject({
      method: 'POST',
      url: '/api/v1/messages/any-id/react',
      headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
      payload: { emoji: '' },
    });

    expect(response.statusCode).toBe(400);
  });

  // ─── Settings validation ─────────────────────────────────────────

  it('PATCH /settings/appearance rejects invalid theme', async () => {
    const response = await fastify.inject({
      method: 'PATCH',
      url: '/api/v1/settings/appearance',
      headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
      payload: { theme: 'neon' },
    });

    expect(response.statusCode).toBe(400);
  });

  it('PATCH /settings/appearance accepts valid theme', async () => {
    const response = await fastify.inject({
      method: 'PATCH',
      url: '/api/v1/settings/appearance',
      headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
      payload: { theme: 'dark' },
    });

    expect(response.statusCode).toBe(200);
  });

  // ─── Nearby validation ─────────────────────────────────────────

  it('GET /nearby rejects missing lat/lng', async () => {
    const response = await fastify.inject({
      method: 'GET',
      url: '/api/v1/nearby',
      headers: { authorization: `Bearer ${token}` },
    });

    expect(response.statusCode).toBe(400);
  });

  it('GET /nearby rejects invalid lat format', async () => {
    const response = await fastify.inject({
      method: 'GET',
      url: '/api/v1/nearby',
      query: { lat: 'abc', lng: '50.1' },
      headers: { authorization: `Bearer ${token}` },
    });

    expect(response.statusCode).toBe(400);
  });

  // ─── AI validation ──────────────────────────────────────────────

  it('POST /ai/summarize rejects missing chat_id', async () => {
    const response = await fastify.inject({
      method: 'POST',
      url: '/api/v1/ai/summarize',
      headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
      payload: {},
    });

    expect(response.statusCode).toBe(400);
  });

  it('POST /ai/generate-sticker rejects empty prompt', async () => {
    const response = await fastify.inject({
      method: 'POST',
      url: '/api/v1/ai/generate-sticker',
      headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
      payload: { prompt: '' },
    });

    expect(response.statusCode).toBe(400);
  });

  // ─── Stickers validation ────────────────────────────────────────

  it('POST /stickers/import rejects invalid source', async () => {
    const response = await fastify.inject({
      method: 'POST',
      url: '/api/v1/stickers/import',
      headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
      payload: { source: 'DISCORD', sourceId: 'pack1' },
    });

    expect(response.statusCode).toBe(400);
  });
});
