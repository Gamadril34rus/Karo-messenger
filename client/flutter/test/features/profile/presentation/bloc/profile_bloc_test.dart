import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:charo_messenger/core/network/api_client.dart';
import 'package:charo_messenger/core/storage/secure_storage.dart';
import 'package:charo_messenger/core/network/ws_client.dart';
import 'package:charo_messenger/features/profile/presentation/bloc/profile_bloc.dart';

class MockApiClient extends Mock implements ApiClient {}
class MockSecureStorage extends Mock implements SecureStorageHelper {}
class MockWsClient extends Mock implements WsClient {}

void main() {
  group('ProfileBloc', () {
    late MockApiClient mockApiClient;
    late MockSecureStorage mockSecureStorage;
    late MockWsClient mockWsClient;

    setUp(() {
      mockApiClient = MockApiClient();
      mockSecureStorage = MockSecureStorage();
      mockWsClient = MockWsClient();
    });

    test('initial state is ProfileInitial', () {
      final bloc = ProfileBloc(
        apiClient: mockApiClient,
        secureStorage: mockSecureStorage,
        wsClient: mockWsClient,
      );
      expect(bloc.state, equals(ProfileInitial()));
      bloc.close();
    });

    test('ProfileMeRequested event has empty props', () {
      final event = ProfileMeRequested();
      expect(event.props, isEmpty);
    });

    test('ProfileLoadRequested event has userId in props', () {
      final event = ProfileLoadRequested(userId: 'user123');
      expect(event.props, contains('user123'));
    });

    test('ProfileUpdated event has displayName in props', () {
      final event = ProfileUpdated(displayName: 'Test User', bio: 'Hello');
      expect(event.props, contains('Test User'));
      expect(event.props, contains('Hello'));
    });

    test('ProfileAvatarChanged event has source in props', () {
      final event = ProfileAvatarChanged(source: 'camera');
      expect(event.props, contains('camera'));
    });

    test('ProfileBlocked event has empty props', () {
      final event = ProfileBlocked();
      expect(event.props, isEmpty);
    });

    test('ProfileLoaded state has correct fields', () {
      final state = ProfileLoaded(
        userId: 'user1',
        username: 'testuser',
        displayName: 'Test User',
        bio: 'Hello world',
        isOnline: true,
        isBlocked: false,
      );
      expect(state.userId, 'user1');
      expect(state.username, 'testuser');
      expect(state.displayName, 'Test User');
      expect(state.isOnline, isTrue);
      expect(state.isBlocked, isFalse);
    });
  });
}
