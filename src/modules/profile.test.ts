import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import { buildServer } from '../index';

describe('Profile API', () => {
  let server: Awaited<ReturnType<typeof buildServer>>;

  beforeAll(async () => {
    server = await buildServer();
  });

  afterAll(async () => {
    await server.close();
  });

  it('should have GET /users/me endpoint', async () => {
    const response = await server.inject({
      method: 'GET',
      url: '/api/v1/users/me',
      headers: { authorization: 'Bearer test' },
    });
    expect(response.statusCode).not.toBe(404);
  });

  it('should have PATCH /users/me endpoint', async () => {
    const response = await server.inject({
      method: 'PATCH',
      url: '/api/v1/users/me',
      headers: { authorization: 'Bearer test' },
      payload: { display_name: 'Test User' },
    });
    expect(response.statusCode).not.toBe(404);
  });

  it('should have PATCH /users/me/avatar endpoint', async () => {
    const response = await server.inject({
      method: 'PATCH',
      url: '/api/v1/users/me/avatar',
      headers: { authorization: 'Bearer test' },
    });
    expect(response.statusCode).not.toBe(404);
  });

  it('should have GET /users/:id endpoint', async () => {
    const response = await server.inject({
      method: 'GET',
      url: '/api/v1/users/test-user-id',
      headers: { authorization: 'Bearer test' },
    });
    expect(response.statusCode).not.toBe(404);
  });

  it('should have GET /users/search endpoint', async () => {
    const response = await server.inject({
      method: 'GET',
      url: '/api/v1/users/search?q=test',
      headers: { authorization: 'Bearer test' },
    });
    expect(response.statusCode).not.toBe(404);
  });

  it('should have POST /users/me/keys endpoint', async () => {
    const response = await server.inject({
      method: 'POST',
      url: '/api/v1/users/me/keys',
      headers: { authorization: 'Bearer test' },
      payload: { identity_key: 'test' },
    });
    expect(response.statusCode).not.toBe(404);
  });

  it('should have GET /users/:id/keys endpoint', async () => {
    const response = await server.inject({
      method: 'GET',
      url: '/api/v1/users/test-user-id/keys',
      headers: { authorization: 'Bearer test' },
    });
    expect(response.statusCode).not.toBe(404);
  });
});

describe('Chat Operations API', () => {
  let server: Awaited<ReturnType<typeof buildServer>>;

  beforeAll(async () => {
    server = await buildServer();
  });

  afterAll(async () => {
    await server.close();
  });

  it('should have PATCH /chats/:id endpoint', async () => {
    const response = await server.inject({
      method: 'PATCH',
      url: '/api/v1/chats/test-chat-id',
      headers: { authorization: 'Bearer test' },
      payload: { title: 'Updated Title' },
    });
    expect(response.statusCode).not.toBe(404);
  });

  it('should have DELETE /chats/:id/messages endpoint', async () => {
    const response = await server.inject({
      method: 'DELETE',
      url: '/api/v1/chats/test-chat-id/messages',
      headers: { authorization: 'Bearer test' },
    });
    expect(response.statusCode).not.toBe(404);
  });

  it('should have GET /chats/:id/export endpoint', async () => {
    const response = await server.inject({
      method: 'GET',
      url: '/api/v1/chats/test-chat-id/export',
      headers: { authorization: 'Bearer test' },
    });
    expect(response.statusCode).not.toBe(404);
  });

  it('should have GET /chats/:id/search endpoint', async () => {
    const response = await server.inject({
      method: 'GET',
      url: '/api/v1/chats/test-chat-id/search?q=test',
      headers: { authorization: 'Bearer test' },
    });
    expect(response.statusCode).not.toBe(404);
  });

  it('should have POST /chats/:id/members endpoint', async () => {
    const response = await server.inject({
      method: 'POST',
      url: '/api/v1/chats/test-chat-id/members',
      headers: { authorization: 'Bearer test' },
      payload: { userId: 'new-user-id' },
    });
    expect(response.statusCode).not.toBe(404);
  });

  it('should have DELETE /chats/:id/members/:uid endpoint', async () => {
    const response = await server.inject({
      method: 'DELETE',
      url: '/api/v1/chats/test-chat-id/members/some-user-id',
      headers: { authorization: 'Bearer test' },
    });
    expect(response.statusCode).not.toBe(404);
  });

  it('should have POST /chats (create chat) endpoint', async () => {
    const response = await server.inject({
      method: 'POST',
      url: '/api/v1/chats',
      headers: { authorization: 'Bearer test' },
      payload: { type: 'private', targetUserId: 'test-user-id' },
    });
    expect(response.statusCode).not.toBe(404);
  });
});

describe('Settings API', () => {
  let server: Awaited<ReturnType<typeof buildServer>>;

  beforeAll(async () => {
    server = await buildServer();
  });

  afterAll(async () => {
    await server.close();
  });

  it('should have GET /settings endpoint', async () => {
    const response = await server.inject({
      method: 'GET',
      url: '/api/v1/settings',
      headers: { authorization: 'Bearer test' },
    });
    expect(response.statusCode).not.toBe(404);
  });

  it('should have GET /settings/privacy endpoint', async () => {
    const response = await server.inject({
      method: 'GET',
      url: '/api/v1/settings/privacy',
      headers: { authorization: 'Bearer test' },
    });
    expect(response.statusCode).not.toBe(404);
  });

  it('should have GET /settings/notifications endpoint', async () => {
    const response = await server.inject({
      method: 'GET',
      url: '/api/v1/settings/notifications',
      headers: { authorization: 'Bearer test' },
    });
    expect(response.statusCode).not.toBe(404);
  });
});

describe('Media API', () => {
  let server: Awaited<ReturnType<typeof buildServer>>;

  beforeAll(async () => {
    server = await buildServer();
  });

  afterAll(async () => {
    await server.close();
  });

  it('should have POST /media/upload endpoint', async () => {
    const response = await server.inject({
      method: 'POST',
      url: '/api/v1/media/upload',
      headers: { authorization: 'Bearer test' },
    });
    expect(response.statusCode).not.toBe(404);
  });
});
