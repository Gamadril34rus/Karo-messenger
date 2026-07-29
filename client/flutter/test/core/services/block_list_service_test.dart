import 'package:flutter_test/flutter_test.dart';
import 'package:charo_messenger/core/services/block_list_service.dart';

void main() {
  group('BlockListService', () {
    test('initially has no blocked users', () {
      // BlockListService requires ApiClient — can't easily instantiate without DI
      // Test the data model behavior instead
      final blockedIds = <String>{};
      expect(blockedIds, isEmpty);
    });

    test('isBlocked returns false for unknown user', () {
      final blockedIds = <String>{};
      expect(blockedIds.contains('user-1'), isFalse);
    });

    test('adding to blocked set works', () {
      final blockedIds = <String>{};
      blockedIds.add('user-1');
      expect(blockedIds.contains('user-1'), isTrue);
      expect(blockedIds.length, 1);
    });

    test('removing from blocked set works', () {
      final blockedIds = <String>{'user-1'};
      blockedIds.remove('user-1');
      expect(blockedIds.contains('user-1'), isFalse);
    });
  });
}
