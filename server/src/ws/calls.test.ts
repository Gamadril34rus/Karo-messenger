import { describe, it, expect } from 'vitest';
import { buildServer } from '../index';

describe('Calls API', () => {
  it('should have call history endpoint', async () => {
    const server = await buildServer();
    const response = await server.inject({
      method: 'GET',
      url: '/api/v1/calls/history',
      headers: { authorization: 'Bearer test' },
    });
    // Should not be 404
    expect(response.statusCode).not.toBe(404);
    await server.close();
  });

  it('should have call initiate endpoint', async () => {
    const server = await buildServer();
    const response = await server.inject({
      method: 'POST',
      url: '/api/v1/calls',
      headers: { authorization: 'Bearer test' },
      payload: {
        type: 'VOICE',
        targetUserIds: ['user-123'],
      },
    });
    // Should not be 404
    expect(response.statusCode).not.toBe(404);
    await server.close();
  });
});

describe('Stories API', () => {
  it('should have stories list endpoint', async () => {
    const server = await buildServer();
    const response = await server.inject({
      method: 'GET',
      url: '/api/v1/stories',
      headers: { authorization: 'Bearer test' },
    });
    expect(response.statusCode).not.toBe(404);
    await server.close();
  });

  it('should have story create endpoint', async () => {
    const server = await buildServer();
    const response = await server.inject({
      method: 'POST',
      url: '/api/v1/stories',
      headers: { authorization: 'Bearer test' },
      payload: {
        type: 'TEXT',
        content: 'Hello world',
        backgroundColor: '#6366F1',
      },
    });
    expect(response.statusCode).not.toBe(404);
    await server.close();
  });

  it('should have story delete endpoint', async () => {
    const server = await buildServer();
    const response = await server.inject({
      method: 'DELETE',
      url: '/api/v1/stories/story-123',
      headers: { authorization: 'Bearer test' },
    });
    expect(response.statusCode).not.toBe(404);
    await server.close();
  });

  it('should have story views endpoint', async () => {
    const server = await buildServer();
    const response = await server.inject({
      method: 'GET',
      url: '/api/v1/stories/story-123/views',
      headers: { authorization: 'Bearer test' },
    });
    expect(response.statusCode).not.toBe(404);
    await server.close();
  });
});

describe('Contacts API', () => {
  it('should have contacts list endpoint', async () => {
    const server = await buildServer();
    const response = await server.inject({
      method: 'GET',
      url: '/api/v1/contacts',
      headers: { authorization: 'Bearer test' },
    });
    expect(response.statusCode).not.toBe(404);
    await server.close();
  });

  it('should have contact add endpoint', async () => {
    const server = await buildServer();
    const response = await server.inject({
      method: 'POST',
      url: '/api/v1/contacts',
      headers: { authorization: 'Bearer test' },
      payload: { identifier: 'alice' },
    });
    expect(response.statusCode).not.toBe(404);
    await server.close();
  });

  it('should have contact delete endpoint', async () => {
    const server = await buildServer();
    const response = await server.inject({
      method: 'DELETE',
      url: '/api/v1/contacts/user-123',
      headers: { authorization: 'Bearer test' },
    });
    expect(response.statusCode).not.toBe(404);
    await server.close();
  });

  it('should have contact sync endpoint', async () => {
    const server = await buildServer();
    const response = await server.inject({
      method: 'POST',
      url: '/api/v1/contacts/sync',
      headers: { authorization: 'Bearer test' },
    });
    expect(response.statusCode).not.toBe(404);
    await server.close();
  });

  it('should have block endpoint', async () => {
    const server = await buildServer();
    const response = await server.inject({
      method: 'POST',
      url: '/api/v1/contacts/block',
      headers: { authorization: 'Bearer test' },
      payload: { userId: 'user-123' },
    });
    expect(response.statusCode).not.toBe(404);
    await server.close();
  });
});
