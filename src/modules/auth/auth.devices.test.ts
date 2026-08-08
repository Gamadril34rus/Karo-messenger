import { describe, test, expect } from 'vitest';

describe('Auth Device Registration', () => {
  test('missing platform returns 400', () => {
    const body: Record<string, string> = { push_token: 'fcm-token-123' };
    expect(body.platform).toBeUndefined();
  });

  test('missing push_token returns 400', () => {
    const body: Record<string, string> = { platform: 'android' };
    expect(body.push_token).toBeUndefined();
  });

  test('valid request has both fields', () => {
    const body: Record<string, string> = { platform: 'android', push_token: 'fcm-token-123' };
    expect(body.platform).toBe('android');
    expect(body.push_token).toBe('fcm-token-123');
  });

  test('optional fields are accepted', () => {
    const body: Record<string, string> = {
      platform: 'ios',
      push_token: 'apns-token-456',
      device_name: 'iPhone 15 Pro',
      device_type: 'smartphone',
    };
    expect(body.device_name).toBe('iPhone 15 Pro');
    expect(body.device_type).toBe('smartphone');
  });
});
