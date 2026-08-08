import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import { buildServer } from '../../index';

describe('Contacts validation', () => {
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

  it('POST /contacts rejects body without identifier or contactUserId', async () => {
    const response = await fastify.inject({
      method: 'POST',
      url: '/api/v1/contacts',
      headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
      payload: {},
    });

    expect(response.statusCode).toBe(400);
  });

  it('POST /contacts/block rejects invalid userId', async () => {
    const response = await fastify.inject({
      method: 'POST',
      url: '/api/v1/contacts/block',
      headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
      payload: { userId: 'not-a-uuid' },
    });

    expect(response.statusCode).toBe(400);
  });

  it('POST /contacts/sync rejects empty phones array', async () => {
    const response = await fastify.inject({
      method: 'POST',
      url: '/api/v1/contacts/sync',
      headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
      payload: { phones: [] },
    });

    expect(response.statusCode).toBe(400);
  });

  it('POST /contacts/sync rejects too many phones', async () => {
    const phones = Array(1001).fill('+1234567890');
    const response = await fastify.inject({
      method: 'POST',
      url: '/api/v1/contacts/sync',
      headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
      payload: { phones },
    });

    expect(response.statusCode).toBe(400);
  });
});
