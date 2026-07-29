import 'package:flutter_test/flutter_test.dart';
import 'package:charo_messenger/core/network/api_client.dart';
import 'package:charo_messenger/features/contacts/presentation/bloc/contacts_bloc.dart';
import 'package:charo_messenger/features/contacts/data/contact_item.dart';

/// Тесты ContactsBloc — загрузка, добавление, удаление контактов
void main() {
  group('ContactsBloc', () {
    test('initial state is ContactsInitial', () {
      final apiClient = _MockContactsApiClient();
      final bloc = ContactsBloc(apiClient: apiClient);
      expect(bloc.state, isA<ContactsInitial>());
      bloc.close();
    });

    test('ContactsLoadRequested emits loading then loaded', () async {
      final apiClient = _MockContactsApiClient();
      final bloc = ContactsBloc(apiClient: apiClient);

      final states = <ContactsState>[];
      bloc.stream.listen(states.add);

      bloc.add(ContactsLoadRequested());
      await Future.delayed(const Duration(milliseconds: 100));

      expect(states.any((s) => s is ContactsLoading), isTrue);
      expect(states.any((s) => s is ContactsLoaded), isTrue);

      bloc.close();
    });

    test('ContactAdded triggers reload', () async {
      final apiClient = _MockContactsApiClient();
      final bloc = ContactsBloc(apiClient: apiClient);

      final states = <ContactsState>[];
      bloc.stream.listen(states.add);

      // Load first
      bloc.add(ContactsLoadRequested());
      await Future.delayed(const Duration(milliseconds: 100));

      // Add contact
      bloc.add(ContactAdded(identifier: 'newuser'));
      await Future.delayed(const Duration(milliseconds: 100));

      // Should have loaded again after add
      expect(states.where((s) => s is ContactsLoaded).length, greaterThanOrEqualTo(2));

      bloc.close();
    });

    test('ContactDeleted removes from list', () async {
      final apiClient = _MockContactsApiClient();
      final bloc = ContactsBloc(apiClient: apiClient);

      // Load first
      bloc.add(ContactsLoadRequested());
      await Future.delayed(const Duration(milliseconds: 100));

      // Delete
      bloc.add(ContactDeleted(userId: 'user1'));
      await Future.delayed(const Duration(milliseconds: 100));

      final loadedState = bloc.state;
      if (loadedState is ContactsLoaded) {
        expect(loadedState.contacts.any((c) => c.userId == 'user1'), isFalse);
      }

      bloc.close();
    });

    test('ContactsSyncRequested triggers reload', () async {
      final apiClient = _MockContactsApiClient();
      final bloc = ContactsBloc(apiClient: apiClient);

      bloc.add(ContactsSyncRequested());
      await Future.delayed(const Duration(milliseconds: 100));

      // Should have loaded after sync
      expect(bloc.state, isA<ContactsLoaded>());

      bloc.close();
    });
  });

  group('ContactItem', () {
    test('default values', () {
      const item = ContactItem(
        userId: 'test',
        displayName: 'Test User',
        username: 'testuser',
      );
      expect(item.isOnline, isFalse);
      expect(item.avatarUrl, isNull);
    });
  });
}

/// Mock ApiClient that returns contact data
class _MockContactsApiClient extends ApiClient {
  _MockContactsApiClient() : super(_MockSecureStorage());

  @override
  Future<ApiResponse> get(String path, {Map<String, dynamic>? queryParameters}) async {
    if (path == '/api/v1/contacts') {
      return ApiResponse(data: [
        {
          'contact_user_id': 'user1',
          'display_name': 'Alice',
          'contact_user': {
            'username': 'alice',
            'avatar_url': null,
            'is_online': true,
          },
        },
        {
          'contact_user_id': 'user2',
          'display_name': 'Bob',
          'contact_user': {
            'username': 'bob',
            'avatar_url': null,
            'is_online': false,
          },
        },
      ]);
    }
    return ApiResponse(data: []);
  }

  @override
  Future<ApiResponse> post(String path, {dynamic data}) async {
    return ApiResponse(data: {});
  }

  @override
  Future<ApiResponse> delete(String path) async {
    return ApiResponse(data: {});
  }
}

class _MockSecureStorage extends SecureStorageHelper {
  @override
  Future<String?> getAccessToken() async => 'mock-token';
}
