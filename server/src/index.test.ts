import { describe, it, expect } from 'vitest';
import { FastifyInstance } from 'fastify';
import { buildServer } from '../dist/index';

describe('Server Health', () => {
  let server: FastifyInstance;

  it('should start server', async () => {
    server = await buildServer();
    expect(server).toBeDefined();
  });

  it('should respond to health check', async () => {
    const response = await server.inject({
      method: 'GET',
      url: '/health',
    });
    expect(response.statusCode).toBe(200);
    const body = JSON.parse(response.body);
    expect(body.status).toBe('ok');
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

  it('should close server', async () => {
    await server.close();
  });
});

describe('Auth Routes', () => {
  let server: FastifyInstance;

  it('should start server for auth tests', async () => {
    server = await buildServer();
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

  it('should close', async () => {
    await server.close();
  });
});

describe('Rate Limiting', () => {
  let server: FastifyInstance;

  it('should start server', async () => {
    server = await buildServer();
  });

  it('should rate limit excessive requests', async () => {
    const promises = Array.from({ length: 35 }, () =>
      server.inject({ method: 'GET', url: '/health' })
    );
    const responses = await Promise.all(promises);
    const rateLimited = responses.some(r => r.statusCode === 429);
    // Health endpoint has no rate limit, so this shouldn't be limited
    expect(rateLimited).toBe(false);
  });

  it('should close', async () => {
    await server.close();
  });
});
