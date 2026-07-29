import 'package:flutter_test/flutter_test.dart';
import 'package:charo_messenger/core/network/api_client.dart';
import 'package:charo_messenger/features/stories/presentation/bloc/stories_bloc.dart';
import 'package:charo_messenger/features/stories/data/story_item.dart';

/// Тесты StoriesBloc — загрузка, просмотр, удаление
void main() {
  group('StoriesBloc', () {
    test('initial state is StoriesInitial', () {
      final apiClient = _MockApiClient();
      final bloc = StoriesBloc(apiClient: apiClient);
      expect(bloc.state, isA<StoriesInitial>());
      bloc.close();
    });

    test('StoriesLoadRequested emits StoriesLoading then StoriesLoaded', () async {
      final apiClient = _MockApiClientWithStories();
      final bloc = StoriesBloc(apiClient: apiClient);

      final states = <StoriesState>[];
      bloc.stream.listen(states.add);

      bloc.add(StoriesLoadRequested());

      await Future.delayed(const Duration(milliseconds: 100));

      expect(states.any((s) => s is StoriesLoading), isTrue);
      expect(states.any((s) => s is StoriesLoaded), isTrue);

      bloc.close();
    });

    test('StoryViewRequested does not crash', () async {
      final apiClient = _MockApiClientWithStories();
      final bloc = StoriesBloc(apiClient: apiClient);

      bloc.add(StoryViewRequested(userId: 'test-user-id'));
      await Future.delayed(const Duration(milliseconds: 100));

      bloc.close();
    });

    test('StoryDeleteRequested does not crash', () async {
      final apiClient = _MockApiClientWithStories();
      final bloc = StoriesBloc(apiClient: apiClient);

      bloc.add(StoryDeleteRequested(storyId: 'test-story-id'));
      await Future.delayed(const Duration(milliseconds: 100));

      bloc.close();
    });
  });

  group('StoryItem', () {
    test('copyWith works correctly', () {
      const item = StoryItem(
        userId: 'user1',
        userName: 'Test User',
        type: 'image',
        count: 3,
        isViewed: false,
      );

      final updated = item.copyWith(isViewed: true, count: 5);
      expect(updated.isViewed, isTrue);
      expect(updated.count, 5);
      expect(updated.userId, 'user1');
      expect(updated.userName, 'Test User');
    });
  });

  group('StoryContentItem', () {
    test('default values', () {
      const item = StoryContentItem(
        id: 'story1',
        type: 'image',
      );
      expect(item.isViewed, isFalse);
      expect(item.viewCount, 0);
      expect(item.mediaUrl, isNull);
      expect(item.textContent, isNull);
    });
  });
}

/// Mock ApiClient that returns story data
class _MockApiClientWithStories extends ApiClient {
  _MockApiClientWithStories() : super(_MockSecureStorage());

  @override
  Future<ApiResponse> get(String path, {Map<String, dynamic>? queryParameters}) async {
    if (path == '/api/v1/stories') {
      return ApiResponse(data: [
        {
          'userId': 'user1',
          'userName': 'Alice',
          'avatarUrl': null,
          'stories': [
            {
              'id': 's1',
              'type': 'IMAGE',
              'mediaUrl': 'https://example.com/img.jpg',
              'content': null,
              'views': [{'userId': 'me'}],
            },
            {
              'id': 's2',
              'type': 'TEXT',
              'content': 'Hello world',
              'backgroundColor': '#6366F1',
              'views': [],
            },
          ],
        },
      ]);
    }
    if (path.contains('/views')) {
      return ApiResponse(data: {'views': []});
    }
    return ApiResponse(data: []);
  }

  @override
  Future<ApiResponse> delete(String path) async {
    return ApiResponse(data: {});
  }
}

class _MockApiClient extends ApiClient {
  _MockApiClient() : super(_MockSecureStorage());

  @override
  Future<ApiResponse> get(String path, {Map<String, dynamic>? queryParameters}) async {
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
