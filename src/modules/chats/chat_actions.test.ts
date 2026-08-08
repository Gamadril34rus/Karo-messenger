import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import { buildServer } from '../../index';

describe('Chat Actions API (Pin/Mute/Archive)', () => {
  let server: Awaited<ReturnType<typeof buildServer>>;

  beforeAll(async () => {
    server = await buildServer();
  });

  afterAll(async () => {
    await server.close();
  });

  it('should have PATCH /chats/:id/pin endpoint', async () => {
    const response = await server.inject({
      method: 'PATCH',
      url: '/api/v1/chats/test-chat-id/pin',
      headers: { authorization: 'Bearer test' },
      payload: { pinned: true },
    });
    expect(response.statusCode).not.toBe(404);
  });

  it('should have PATCH /chats/:id/mute endpoint', async () => {
    const response = await server.inject({
      method: 'PATCH',
      url: '/api/v1/chats/test-chat-id/mute',
      headers: { authorization: 'Bearer test' },
      payload: { muted: true },
    });
    expect(response.statusCode).not.toBe(404);
  });

  it('should have PATCH /chats/:id/archive endpoint', async () => {
    const response = await server.inject({
      method: 'PATCH',
      url: '/api/v1/chats/test-chat-id/archive',
      headers: { authorization: 'Bearer test' },
      payload: { archived: true },
    });
    expect(response.statusCode).not.toBe(404);
  });

  it('should have PATCH /chats/:id with is_pinned field', async () => {
    const response = await server.inject({
      method: 'PATCH',
      url: '/api/v1/chats/test-chat-id',
      headers: { authorization: 'Bearer test' },
      payload: { is_pinned: true },
    });
    expect(response.statusCode).not.toBe(404);
  });

  it('should have PATCH /chats/:id with is_muted field', async () => {
    const response = await server.inject({
      method: 'PATCH',
      url: '/api/v1/chats/test-chat-id',
      headers: { authorization: 'Bearer test' },
      payload: { is_muted: true },
    });
    expect(response.statusCode).not.toBe(404);
  });

  it('should have PATCH /chats/:id with is_archived field', async () => {
    const response = await server.inject({
      method: 'PATCH',
      url: '/api/v1/chats/test-chat-id',
      headers: { authorization: 'Bearer test' },
      payload: { is_archived: true },
    });
    expect(response.statusCode).not.toBe(404);
  });

  it('should have GET /chats with include_archived param', async () => {
    const response = await server.inject({
      method: 'GET',
      url: '/api/v1/chats?include_archived=true',
      headers: { authorization: 'Bearer test' },
    });
    expect(response.statusCode).not.toBe(404);
  });

  it('should have GET /chats with q param for search', async () => {
    const response = await server.inject({
      method: 'GET',
      url: '/api/v1/chats?q=test',
      headers: { authorization: 'Bearer test' },
    });
    expect(response.statusCode).not.toBe(404);
  });
});

describe('Chat Members API', () => {
  let server: Awaited<ReturnType<typeof buildServer>>;

  beforeAll(async () => {
    server = await buildServer();
  });

  afterAll(async () => {
    await server.close();
  });

  it('should have GET /chats/:id endpoint returning members', async () => {
    const response = await server.inject({
      method: 'GET',
      url: '/api/v1/chats/test-chat-id',
      headers: { authorization: 'Bearer test' },
    });
    expect(response.statusCode).not.toBe(404);
  });

  it('should have POST /chats/:id/members endpoint', async () => {
    const response = await server.inject({
      method: 'POST',
      url: '/api/v1/chats/test-chat-id/members',
      headers: { authorization: 'Bearer test' },
      payload: { userId: 'new-member-id' },
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
});

describe('Notification Settings with Quiet Hours', () => {
  let server: Awaited<ReturnType<typeof buildServer>>;

  beforeAll(async () => {
    server = await buildServer();
  });

  afterAll(async () => {
    await server.close();
  });

  it('should have PATCH /settings/notifications with quiet hours', async () => {
    const response = await server.inject({
      method: 'PATCH',
      url: '/api/v1/settings/notifications',
      headers: { authorization: 'Bearer test' },
      payload: {
        pushEnabled: true,
        soundEnabled: true,
        vibrationEnabled: true,
        previewEnabled: true,
        groupMentions: true,
        quietHoursEnabled: true,
        quietHoursStart: '23:00',
        quietHoursEnd: '07:00',
      },
    });
    expect(response.statusCode).not.toBe(404);
  });
});
