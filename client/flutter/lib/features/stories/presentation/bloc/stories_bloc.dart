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
      final stories = (response.asList).map<StoryItem>((json) => StoryItem(
        userId: json['user_id'] as String? ?? '',
        userName: json['user']?['display_name'] as String?,
        avatarUrl: json['user']?['avatar_url'] as String?,
        type: json['type'] as String? ?? 'image',
        textContent: json['content'] as String?,
        count: json['count'] as int? ?? 1,
        isViewed: json['is_viewed'] as bool? ?? false,
      )).toList();
      emit(StoriesLoaded(stories: stories));
    } on CharoApiException catch (e) {
      emit(StoriesError(message: e.message));
    }
  }

  Future<void> _onPublishRequested(StoryPublishRequested event, Emitter<StoriesState> emit) async {
    await _apiClient.post('/api/v1/stories', data: {'type': event.type});
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
