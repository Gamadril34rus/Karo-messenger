import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import { buildServer } from '../../index';

describe('Story Routes', () => {
  let server: Awaited<ReturnType<typeof buildServer>>;

  beforeAll(async () => {
    server = await buildServer();
  });

  afterAll(async () => {
    await server.close();
  });

  it('should have GET /stories endpoint', async () => {
    const response = await server.inject({
      method: 'GET',
      url: '/api/v1/stories',
      headers: { authorization: 'Bearer test' },
    });
    expect(response.statusCode).not.toBe(404);
  });

  it('should have POST /stories endpoint', async () => {
    const response = await server.inject({
      method: 'POST',
      url: '/api/v1/stories',
      headers: { authorization: 'Bearer test' },
      payload: { type: 'IMAGE', media_url: 'https://cdn.charo.chat/test.jpg' },
    });
    expect(response.statusCode).not.toBe(404);
  });

  it('should have DELETE /stories/:id endpoint', async () => {
    const response = await server.inject({
      method: 'DELETE',
      url: '/api/v1/stories/test-story-id',
      headers: { authorization: 'Bearer test' },
    });
    expect(response.statusCode).not.toBe(404);
  });

  it('should have GET /stories/:id/views endpoint', async () => {
    const response = await server.inject({
      method: 'GET',
      url: '/api/v1/stories/test-user-id/views',
      headers: { authorization: 'Bearer test' },
    });
    expect(response.statusCode).not.toBe(404);
  });
});

describe('Chat Search with OR conditions', () => {
  let server: Awaited<ReturnType<typeof buildServer>>;

  beforeAll(async () => {
    server = await buildServer();
  });

  afterAll(async () => {
    await server.close();
  });

  it('should have GET /chats/:id/search endpoint', async () => {
    const response = await server.inject({
      method: 'GET',
      url: '/api/v1/chats/test-chat-id/search?q=hello',
      headers: { authorization: 'Bearer test' },
    });
    expect(response.statusCode).not.toBe(404);
  });
});

describe('Contact Routes', () => {
  let server: Awaited<ReturnType<typeof buildServer>>;

  beforeAll(async () => {
    server = await buildServer();
  });

  afterAll(async () => {
    await server.close();
  });

  it('should have GET /contacts endpoint', async () => {
    const response = await server.inject({
      method: 'GET',
      url: '/api/v1/contacts',
      headers: { authorization: 'Bearer test' },
    });
    expect(response.statusCode).not.toBe(404);
  });

  it('should have POST /contacts endpoint', async () => {
    const response = await server.inject({
      method: 'POST',
      url: '/api/v1/contacts',
      headers: { authorization: 'Bearer test' },
      payload: { identifier: 'testuser' },
    });
    expect(response.statusCode).not.toBe(404);
  });

  it('should have POST /contacts/sync endpoint', async () => {
    const response = await server.inject({
      method: 'POST',
      url: '/api/v1/contacts/sync',
      headers: { authorization: 'Bearer test' },
    });
    expect(response.statusCode).not.toBe(404);
  });

  it('should have POST /contacts/block endpoint', async () => {
    const response = await server.inject({
      method: 'POST',
      url: '/api/v1/contacts/block',
      headers: { authorization: 'Bearer test' },
      payload: { userId: 'test-user-id' },
    });
    expect(response.statusCode).not.toBe(404);
  });

  it('should have DELETE /contacts/:id endpoint', async () => {
    const response = await server.inject({
      method: 'DELETE',
      url: '/api/v1/contacts/test-contact-id',
      headers: { authorization: 'Bearer test' },
    });
    expect(response.statusCode).not.toBe(404);
  });
});
