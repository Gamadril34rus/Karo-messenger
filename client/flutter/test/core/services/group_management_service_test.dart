import 'package:flutter_test/flutter_test.dart';
import 'package:charo_messenger/core/services/group_management_service.dart';

void main() {
  group('GroupInfo', () {
    test('creates from JSON with all fields', () {
      final json = {
        'id': 'chat-1',
        'title': 'Test Group',
        'type': 'group',
        'avatar_url': 'https://example.com/avatar.png',
        'description': 'A test group',
        'members': [
          {
            'user_id': 'user-1',
            'username': 'alice',
            'display_name': 'Alice',
            'role': 'OWNER',
          },
        ],
        'member_count': 5,
      };

      final info = GroupInfo.fromJson(json);
      expect(info.id, 'chat-1');
      expect(info.title, 'Test Group');
      expect(info.type, 'group');
      expect(info.avatarUrl, 'https://example.com/avatar.png');
      expect(info.description, 'A test group');
      expect(info.members.length, 1);
      expect(info.memberCount, 5);
    });

    test('creates from JSON with missing fields', () {
      final json = <String, dynamic>{};
      final info = GroupInfo.fromJson(json);
      expect(info.id, '');
      expect(info.title, '');
      expect(info.type, 'group');
      expect(info.members, isEmpty);
      expect(info.memberCount, 0);
    });
  });

  group('GroupMember', () {
    test('creates from JSON with snake_case fields', () {
      final json = {
        'user_id': 'u1',
        'username': 'bob',
        'display_name': 'Bob Smith',
        'avatar_url': 'https://example.com/bob.png',
        'role': 'ADMIN',
      };

      final member = GroupMember.fromJson(json);
      expect(member.userId, 'u1');
      expect(member.username, 'bob');
      expect(member.displayName, 'Bob Smith');
      expect(member.avatarUrl, 'https://example.com/bob.png');
      expect(member.role, 'ADMIN');
    });

    test('creates from JSON with camelCase fields', () {
      final json = {
        'userId': 'u2',
        'username': 'carol',
        'displayName': 'Carol',
        'avatarUrl': 'https://example.com/carol.png',
        'role': 'MEMBER',
      };

      final member = GroupMember.fromJson(json);
      expect(member.userId, 'u2');
      expect(member.username, 'carol');
      expect(member.displayName, 'Carol');
      expect(member.role, 'MEMBER');
    });

    test('defaults to MEMBER role when not specified', () {
      final json = {'user_id': 'u3', 'username': 'dave'};
      final member = GroupMember.fromJson(json);
      expect(member.role, 'MEMBER');
    });
  });
}
