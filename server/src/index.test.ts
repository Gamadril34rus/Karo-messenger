import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import { FastifyInstance } from 'fastify';
import { buildServer } from '../index';

describe('Server Health & Infrastructure', () => {
  let server: FastifyInstance;

  beforeAll(async () => {
    server = await buildServer();
  });

  afterAll(async () => {
    await server.close();
  });

  it('should respond to health check with status', async () => {
    const response = await server.inject({
      method: 'GET',
      url: '/health',
    });
    expect(response.statusCode).toBe(200);
    const body = JSON.parse(response.body);
    expect(body.status).toBeDefined();
    expect(body.version).toBe('1.0.0');
    expect(body.timestamp).toBeDefined();
    expect(body.checks).toBeDefined();
    expect(body.checks.database).toBeDefined();
    expect(body.checks.redis).toBeDefined();
  });

  it('should have CORS headers', async () => {
    const response = await server.inject({
      method: 'OPTIONS',
      url: '/api/v1/auth/login',
      headers: {
        origin: 'http://localhost:3000',
      },
    });
    expect(response.headers['access-control-allow-origin']).toBeDefined();
  });

  it('should serve Swagger UI docs', async () => {
    const response = await server.inject({
      method: 'GET',
      url: '/docs',
    });
    // Swagger UI returns HTML or redirect
    expect(response.statusCode).toBeLessThan(400);
  });

  it('should serve OpenAPI JSON spec', async () => {
    const response = await server.inject({
      method: 'GET',
      url: '/docs/json',
    });
    expect(response.statusCode).toBe(200);
    const body = JSON.parse(response.body);
    expect(body.openapi).toBe('3.0.3');
    expect(body.info.title).toContain('ЧАРО');
    expect(body.paths).toBeDefined();
  });
});

describe('Auth Routes', () => {
  let server: FastifyInstance;

  beforeAll(async () => {
    server = await buildServer();
  });

  afterAll(async () => {
    await server.close();
  });

  it('should reject invalid login', async () => {
    const response = await server.inject({
      method: 'POST',
      url: '/api/v1/auth/login',
      payload: { phone: '', password: '' },
    });
    expect(response.statusCode).toBeGreaterThanOrEqual(400);
  });

  it('should reject missing token', async () => {
    const response = await server.inject({
      method: 'GET',
      url: '/api/v1/users/me',
    });
    expect(response.statusCode).toBe(401);
  });

  it('should reject invalid token', async () => {
    const response = await server.inject({
      method: 'GET',
      url: '/api/v1/users/me',
      headers: {
        authorization: 'Bearer invalid-token-here',
      },
    });
    expect(response.statusCode).toBe(401);
  });
});

describe('API Structure', () => {
  let server: FastifyInstance;

  beforeAll(async () => {
    server = await buildServer();
  });

  afterAll(async () => {
    await server.close();
  });

  it('should have /api/v1/auth routes', async () => {
    const response = await server.inject({
      method: 'POST',
      url: '/api/v1/auth/register',
      payload: {},
    });
    // Should not be 404 (route exists)
    expect(response.statusCode).not.toBe(404);
  });

  it('should have /api/v1/chats routes', async () => {
    const response = await server.inject({
      method: 'GET',
      url: '/api/v1/chats',
      headers: { authorization: 'Bearer test' },
    });
    expect(response.statusCode).not.toBe(404);
  });

  it('should have /api/v1/stories routes', async () => {
    const response = await server.inject({
      method: 'GET',
      url: '/api/v1/stories',
      headers: { authorization: 'Bearer test' },
    });
    expect(response.statusCode).not.toBe(404);
  });

  it('should have /api/v1/contacts routes', async () => {
    const response = await server.inject({
      method: 'GET',
      url: '/api/v1/contacts',
      headers: { authorization: 'Bearer test' },
    });
    expect(response.statusCode).not.toBe(404);
  });

  it('should have /api/v1/calls routes', async () => {
    const response = await server.inject({
      method: 'GET',
      url: '/api/v1/calls/history',
      headers: { authorization: 'Bearer test' },
    });
    expect(response.statusCode).not.toBe(404);
  });

  it('should have /api/v1/messages routes', async () => {
    const response = await server.inject({
      method: 'GET',
      url: '/api/v1/messages/nonexistent',
      headers: { authorization: 'Bearer test' },
    });
    expect(response.statusCode).not.toBe(404);
  });

  it('should have /api/v1/settings routes', async () => {
    const response = await server.inject({
      method: 'GET',
      url: '/api/v1/settings',
      headers: { authorization: 'Bearer test' },
    });
    expect(response.statusCode).not.toBe(404);
  });

  it('should have /api/v1/users routes', async () => {
    const response = await server.inject({
      method: 'GET',
      url: '/api/v1/users/me',
      headers: { authorization: 'Bearer test' },
    });
    expect(response.statusCode).not.toBe(404);
  });

  it('should have /api/v1/media routes', async () => {
    const response = await server.inject({
      method: 'POST',
      url: '/api/v1/media/upload',
      headers: { authorization: 'Bearer test' },
    });
    expect(response.statusCode).not.toBe(404);
  });

  it('should have /api/v1/ai routes', async () => {
    const response = await server.inject({
      method: 'POST',
      url: '/api/v1/ai/chat',
      headers: { authorization: 'Bearer test' },
    });
    expect(response.statusCode).not.toBe(404);
  });
});
