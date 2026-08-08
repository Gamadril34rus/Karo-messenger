import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import { buildServer } from '../../index';

describe('GET /api/v1/search', () => {
  let fastify: Awaited<ReturnType<typeof buildServer>>;

  beforeAll(async () => {
    fastify = await buildServer();
    await fastify.ready();
  });

  afterAll(async () => {
    await fastify.close();
  });

  it('returns 401 without auth', async () => {
    const response = await fastify.inject({
      method: 'GET',
      url: '/api/v1/search',
      query: { q: 'test' },
    });

    expect(response.statusCode).toBe(401);
  });

  it('returns validation error for q < 2 chars', async () => {
    const jwt = await import('jsonwebtoken');
    const token = jwt.sign(
      { userId: 'test-user-id' },
      process.env.JWT_ACCESS_SECRET || 'charo-access-secret',
      { expiresIn: '15m' }
    );

    const response = await fastify.inject({
      method: 'GET',
      url: '/api/v1/search',
      query: { q: 'a' },
      headers: { authorization: `Bearer ${token}` },
    });

    expect(response.statusCode).toBe(400);
  });

  it('returns empty results for valid query with no data', async () => {
    const jwt = await import('jsonwebtoken');
    const token = jwt.sign(
      { userId: 'test-user-id' },
      process.env.JWT_ACCESS_SECRET || 'charo-access-secret',
      { expiresIn: '15m' }
    );

    const response = await fastify.inject({
      method: 'GET',
      url: '/api/v1/search',
      query: { q: 'nonexistent' },
      headers: { authorization: `Bearer ${token}` },
    });

    expect(response.statusCode).toBe(200);
    const body = JSON.parse(response.body);
    expect(body).toHaveProperty('chats');
    expect(body).toHaveProperty('messages');
    expect(body).toHaveProperty('contacts');
  });
});
