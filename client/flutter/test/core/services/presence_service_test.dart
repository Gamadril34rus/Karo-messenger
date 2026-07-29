import 'package:flutter_test/flutter_test.dart';
import 'package:charo_messenger/core/services/presence_service.dart';

void main() {
  group('PresenceService', () {
    test('formatLastSeen returns "давно" for null', () {
      expect(PresenceService.formatLastSeen(null), 'давно');
    });

    test('formatLastSeen returns "только что" for <1 min', () {
      final now = DateTime.now();
      expect(PresenceService.formatLastSeen(now), 'только что');
    });

    test('formatLastSeen returns "недавно" for <5 min', () {
      final time = DateTime.now().subtract(const Duration(minutes: 2));
      expect(PresenceService.formatLastSeen(time), 'недавно');
    });

    test('formatLastSeen returns minutes for <60 min', () {
      final time = DateTime.now().subtract(const Duration(minutes: 30));
      final result = PresenceService.formatLastSeen(time);
      expect(result, contains('мин'));
    });

    test('formatLastSeen returns hours for <24h', () {
      final time = DateTime.now().subtract(const Duration(hours: 5));
      final result = PresenceService.formatLastSeen(time);
      expect(result, contains('ч'));
    });

    test('formatLastSeen returns days for <7d', () {
      final time = DateTime.now().subtract(const Duration(days: 3));
      final result = PresenceService.formatLastSeen(time);
      expect(result, contains('дн'));
    });

    test('formatLastSeen returns date for older', () {
      final time = DateTime.now().subtract(const Duration(days: 14));
      final result = PresenceService.formatLastSeen(time);
      expect(result, contains('.'));
    });
  });

  group('UserPresence', () {
    test('isOnline is true for online status', () {
      const presence = UserPresence(userId: '1', status: 'online');
      expect(presence.isOnline, isTrue);
    });

    test('isOnline is true for away status', () {
      const presence = UserPresence(userId: '1', status: 'away');
      expect(presence.isOnline, isTrue);
    });

    test('isOnline is false for offline status', () {
      const presence = UserPresence(userId: '1', status: 'offline');
      expect(presence.isOnline, isFalse);
    });

    test('isOnline is false for dnd status', () {
      const presence = UserPresence(userId: '1', status: 'dnd');
      expect(presence.isOnline, isFalse);
    });
  });
}
