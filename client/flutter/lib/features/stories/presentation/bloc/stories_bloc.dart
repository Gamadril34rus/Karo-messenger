import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/network/api_client.dart';
import '../../data/story_item.dart';

// Events
sealed class StoriesEvent extends Equatable { @override List<Object?> get props => []; }
final class StoriesLoadRequested extends StoriesEvent {}
final class StoryPublishRequested extends StoriesEvent {
  final String type;
  StoryPublishRequested({required this.type});
  @override List<Object?> get props => [type];
}
final class StoryViewRequested extends StoriesEvent {
  final String userId;
  StoryViewRequested({required this.userId});
  @override List<Object?> get props => [userId];
}
final class StoryDeleteRequested extends StoriesEvent {
  final String storyId;
  StoryDeleteRequested({required this.storyId});
  @override List<Object?> get props => [storyId];
}

// States
sealed class StoriesState extends Equatable { @override List<Object?> get props => []; }
final class StoriesInitial extends StoriesState {}
final class StoriesLoading extends StoriesState {}
final class StoriesLoaded extends StoriesState {
  final List<StoryItem> stories;
  StoriesLoaded({required this.stories});
  @override List<Object?> get props => [stories];
}
final class StoriesError extends StoriesState {
  final String message;
  StoriesError({required this.message});
  @override List<Object?> get props => [message];
}

// BLoC
class StoriesBloc extends Bloc<StoriesEvent, StoriesState> {
  final ApiClient _apiClient;
  StoriesBloc({required ApiClient apiClient}) : _apiClient = apiClient, super(StoriesInitial()) {
    on<StoriesLoadRequested>(_onLoadRequested);
    on<StoryPublishRequested>(_onPublishRequested);
    on<StoryViewRequested>(_onViewRequested);
    on<StoryDeleteRequested>(_onDeleteRequested);
  }

  Future<void> _onLoadRequested(StoriesLoadRequested event, Emitter<StoriesState> emit) async {
    emit(StoriesLoading());
    try {
      final response = await _apiClient.get('/api/v1/stories');
      final data = response.asList;

      // Server returns grouped stories: [{userId, userName, avatarUrl, stories: [...]}]
      final stories = data.map<StoryItem>((json) {
        final storyItems = (json['stories'] as List<dynamic>?) ?? [];
        final items = storyItems.map<StoryContentItem>((s) {
          final sMap = s as Map<String, dynamic>;
          return StoryContentItem(
            id: sMap['id'] as String? ?? '',
            type: _mapStoryType(sMap['type'] as String?),
            mediaUrl: sMap['mediaUrl'] as String? ?? sMap['media_url'] as String?,
            textContent: sMap['content'] as String?,
            backgroundColor: sMap['backgroundColor'] as String? ?? sMap['background_color'] as String?,
            createdAt: sMap['createdAt'] != null
                ? DateTime.tryParse(sMap['createdAt'].toString())
                : null,
            isViewed: (sMap['views'] as List?)?.isNotEmpty ?? false,
            viewCount: (sMap['views'] as List?)?.length ?? 0,
          );
        }).toList();

        return StoryItem(
          userId: json['userId'] as String? ?? json['user_id'] as String? ?? '',
          userName: json['userName'] as String? ?? json['user']?['display_name'] as String?,
          avatarUrl: json['avatarUrl'] as String? ?? json['user']?['avatar_url'] as String?,
          type: items.isNotEmpty ? items.first.type : 'image',
          count: items.length,
          isViewed: items.every((i) => i.isViewed),
          items: items,
        );
      }).toList();

      emit(StoriesLoaded(stories: stories));
    } on CharoApiException catch (e) {
      emit(StoriesError(message: e.message));
    }
  }

  String _mapStoryType(String? type) {
    if (type == null) return 'image';
    final lower = type.toLowerCase();
    if (lower == 'video') return 'video';
    if (lower == 'text') return 'text';
    return 'image';
  }

  Future<void> _onPublishRequested(StoryPublishRequested event, Emitter<StoriesState> emit) async {
    await _apiClient.post('/api/v1/stories', data: {'type': event.type.toUpperCase()});
    add(StoriesLoadRequested());
  }

  Future<void> _onViewRequested(StoryViewRequested event, Emitter<StoriesState> emit) async {
    await _apiClient.get('/api/v1/stories/${event.userId}/views');
  }

  Future<void> _onDeleteRequested(StoryDeleteRequested event, Emitter<StoriesState> emit) async {
    await _apiClient.delete('/api/v1/stories/${event.storyId}');
    add(StoriesLoadRequested());
  }
}
