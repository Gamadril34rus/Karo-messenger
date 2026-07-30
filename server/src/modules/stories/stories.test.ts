import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import { buildServer } from '../../index';

describe('Stories API', () => {
  let fastify: Awaited<ReturnType<typeof buildServer>>;

  beforeAll(async () => {
    fastify = await buildServer();
    await fastify.ready();
  });

  afterAll(async () => {
    await fastify.close();
  });

  it('POST /stories rejects invalid type', async () => {
    const jwt = await import('jsonwebtoken');
    const token = jwt.sign(
      { userId: 'test-user-id' },
      process.env.JWT_ACCESS_SECRET || 'charo-access-secret',
      { expiresIn: '15m' }
    );

    const response = await fastify.inject({
      method: 'POST',
      url: '/api/v1/stories',
      headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
      payload: { type: 'AUDIO' },
    });

    expect(response.statusCode).toBe(400);
  });

  it('POST /stories rejects invalid backgroundColor', async () => {
    const jwt = await import('jsonwebtoken');
    const token = jwt.sign(
      { userId: 'test-user-id' },
      process.env.JWT_ACCESS_SECRET || 'charo-access-secret',
      { expiresIn: '15m' }
    );

    const response = await fastify.inject({
      method: 'POST',
      url: '/api/v1/stories',
      headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
      payload: { type: 'TEXT', backgroundColor: 'red' },
    });

    expect(response.statusCode).toBe(400);
  });

  it('POST /stories accepts valid TEXT story', async () => {
    const jwt = await import('jsonwebtoken');
    const token = jwt.sign(
      { userId: 'test-user-id' },
      process.env.JWT_ACCESS_SECRET || 'charo-access-secret',
      { expiresIn: '15m' }
    );

    const response = await fastify.inject({
      method: 'POST',
      url: '/api/v1/stories',
      headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
      payload: { type: 'TEXT', backgroundColor: '#FF5733', content: 'Hello world' },
    });

    expect(response.statusCode).not.toBe(400);
  });

  it('GET /stories returns 401 without auth', async () => {
    const response = await fastify.inject({
      method: 'GET',
      url: '/api/v1/stories',
    });

    expect(response.statusCode).toBe(401);
  });
});
