import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:charo_messenger/core/network/api_client.dart';
import 'package:charo_messenger/features/stories/presentation/bloc/stories_bloc.dart';
import 'package:charo_messenger/features/stories/data/story_item.dart';

class MockApiClient extends Mock implements ApiClient {}

void main() {
  group('StoriesBloc', () {
    late MockApiClient mockApiClient;

    setUp(() {
      mockApiClient = MockApiClient();
    });

    test('initial state is StoriesInitial', () {
      final bloc = StoriesBloc(apiClient: mockApiClient);
      expect(bloc.state, equals(StoriesInitial()));
      bloc.close();
    });

    test('StoryPublishRequested event has all props', () {
      final event = StoryPublishRequested(
        type: 'image',
        mediaUrl: 'https://cdn.charo.chat/test.jpg',
        textContent: null,
        backgroundColor: null,
      );
      expect(event.props, contains('image'));
      expect(event.props, contains('https://cdn.charo.chat/test.jpg'));
    });

    test('StoryPublishRequested with text content has props', () {
      final event = StoryPublishRequested(
        type: 'text',
        textContent: 'Hello world',
        backgroundColor: '#6366F1',
      );
      expect(event.props, contains('text'));
      expect(event.props, contains('Hello world'));
      expect(event.props, contains('#6366F1'));
    });

    test('StoryItem copyWith works', () {
      final item = StoryItem(userId: 'user1');
      final copied = item.copyWith(isViewed: true, count: 5);
      expect(copied.isViewed, isTrue);
      expect(copied.count, 5);
      expect(copied.userId, 'user1');
    });

    test('StoryContentItem has correct fields', () {
      final item = StoryContentItem(
        id: 'story1',
        type: 'video',
        mediaUrl: 'https://cdn.charo.chat/video.mp4',
        viewCount: 42,
      );
      expect(item.type, 'video');
      expect(item.viewCount, 42);
    });
  });
}
