// © 2024-2026 Charo Team. All rights reserved. PROPRIETARY AND CONFIDENTIAL.
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/domain/charo_repository.dart';
import '../../../../core/network/api_client.dart' show CharoApiException;
import '../../../../core/utils/logger.dart';
import '../../data/story_item.dart';

// Events
sealed class StoriesEvent extends Equatable { @override List<Object?> get props => []; }
final class StoriesLoadRequested extends StoriesEvent {}
final class StoryPublishRequested extends StoriesEvent {
  final String type;
  final String? mediaUrl;
  final String? textContent;
  final String? backgroundColor;
  StoryPublishRequested({
    required this.type,
    this.mediaUrl,
    this.textContent,
    this.backgroundColor,
  });
  @override List<Object?> get props => [type, mediaUrl, textContent, backgroundColor];
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
  final CharoRepository _repository;
  StoriesBloc({required CharoRepository repository}) : _repository = repository, super(StoriesInitial()) {
    on<StoriesLoadRequested>(_onLoadRequested);
    on<StoryPublishRequested>(_onPublishRequested);
    on<StoryViewRequested>(_onViewRequested);
    on<StoryDeleteRequested>(_onDeleteRequested);
  }

  Future<void> _onLoadRequested(StoriesLoadRequested event, Emitter<StoriesState> emit) async {
    emit(StoriesLoading());
    try {
      final stories = await _repository.getStories();
      emit(StoriesLoaded(stories: stories));
    } on CharoApiException catch (e) {
      emit(StoriesError(message: e.message));
    }
  }

  Future<void> _onPublishRequested(StoryPublishRequested event, Emitter<StoriesState> emit) async {
    try {
      await _repository.publishStory(
        event.type,
        mediaUrl: event.mediaUrl,
        textContent: event.textContent,
        backgroundColor: event.backgroundColor,
      );
      add(StoriesLoadRequested());
    } catch (e) {
      logger.e('Story publish failed: $e');
    }
  }

  Future<void> _onViewRequested(StoryViewRequested event, Emitter<StoriesState> emit) async {
    await _repository.viewStory(event.userId);
  }

  Future<void> _onDeleteRequested(StoryDeleteRequested event, Emitter<StoriesState> emit) async {
    await _repository.deleteStory(event.storyId);
    add(StoriesLoadRequested());
  }
}
