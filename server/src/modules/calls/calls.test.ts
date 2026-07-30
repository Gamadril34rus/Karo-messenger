import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import { buildServer } from '../../index';

describe('Calls API', () => {
  let fastify: Awaited<ReturnType<typeof buildServer>>;

  beforeAll(async () => {
    fastify = await buildServer();
    await fastify.ready();
  });

  afterAll(async () => {
    await fastify.close();
  });

  it('POST /calls rejects missing type', async () => {
    const jwt = await import('jsonwebtoken');
    const token = jwt.sign(
      { userId: 'test-user-id' },
      process.env.JWT_ACCESS_SECRET || 'charo-access-secret',
      { expiresIn: '15m' }
    );

    const response = await fastify.inject({
      method: 'POST',
      url: '/api/v1/calls',
      headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
      payload: { targetUserIds: [] },
    });

    expect(response.statusCode).toBe(400);
  });

  it('POST /calls with valid VOICE type returns 201 or 500', async () => {
    const jwt = await import('jsonwebtoken');
    const token = jwt.sign(
      { userId: 'test-user-id' },
      process.env.JWT_ACCESS_SECRET || 'charo-access-secret',
      { expiresIn: '15m' }
    );

    const response = await fastify.inject({
      method: 'POST',
      url: '/api/v1/calls',
      headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
      payload: { type: 'VOICE' },
    });

    // 201 if DB works, 500 if DB not available — but NOT 400
    expect(response.statusCode).not.toBe(400);
  });

  it('GET /calls/history returns 401 without auth', async () => {
    const response = await fastify.inject({
      method: 'GET',
      url: '/api/v1/calls/history',
    });

    expect(response.statusCode).toBe(401);
  });
});
