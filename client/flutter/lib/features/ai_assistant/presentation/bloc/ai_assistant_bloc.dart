// © 2024-2026 Бутаев Алексей Юрьевич. All rights reserved. PROPRIETARY AND CONFIDENTIAL.
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/domain/charo_repository.dart';
import '../../../../core/network/api_client.dart' show CharoApiException;
import '../../data/ai_message.dart';

// Events
sealed class AiAssistantEvent extends Equatable { @override List<Object?> get props => []; }
final class AiConversationsLoadRequested extends AiAssistantEvent {}
final class AiConversationCreated extends AiAssistantEvent {}
final class AiMessageSent extends AiAssistantEvent {
  final String text;
  AiMessageSent({required this.text});
  @override List<Object?> get props => [text];
}
final class AiVoiceModeRequested extends AiAssistantEvent {}
final class AiSummarizeRequested extends AiAssistantEvent {
  final String chatId;
  AiSummarizeRequested({required this.chatId});
  @override List<Object?> get props => [chatId];
}
final class AiStickerGenerateRequested extends AiAssistantEvent {
  final String prompt;
  AiStickerGenerateRequested({required this.prompt});
  @override List<Object?> get props => [prompt];
}

// States
sealed class AiAssistantState extends Equatable { @override List<Object?> get props => []; }
final class AiAssistantInitial extends AiAssistantState {}
final class AiAssistantLoading extends AiAssistantState {}
final class AiAssistantLoaded extends AiAssistantState {
  final List<AiMessage> messages;
  AiAssistantLoaded({required this.messages});
  @override List<Object?> get props => [messages];
}
final class AiAssistantError extends AiAssistantState {
  final String message;
  AiAssistantError({required this.message});
  @override List<Object?> get props => [message];
}

// BLoC
class AiAssistantBloc extends Bloc<AiAssistantEvent, AiAssistantState> {
  final CharoRepository _repository;
  AiAssistantBloc({required CharoRepository repository}) : _repository = repository, super(AiAssistantInitial()) {
    on<AiConversationsLoadRequested>(_onConversationsLoadRequested);
    on<AiConversationCreated>(_onConversationCreated);
    on<AiMessageSent>(_onMessageSent);
    on<AiVoiceModeRequested>(_onVoiceModeRequested);
    on<AiSummarizeRequested>(_onSummarizeRequested);
    on<AiStickerGenerateRequested>(_onStickerGenerateRequested);
  }

  Future<void> _onConversationsLoadRequested(
    AiConversationsLoadRequested event, Emitter<AiAssistantState> emit,
  ) async {
    emit(AiAssistantLoading());
    try {
      final conversations = await _repository.getAiConversations();
      final messages = conversations.map((c) => AiMessage(
        id: c.id,
        role: c.role,
        content: c.content,
        createdAt: c.createdAt,
      )).toList();
      emit(AiAssistantLoaded(messages: messages));
    } on CharoApiException catch (e) {
      emit(AiAssistantError(message: e.message));
    }
  }

  Future<void> _onConversationCreated(
    AiConversationCreated event, Emitter<AiAssistantState> emit,
  ) async {
    await _repository.createAiConversation();
    add(AiConversationsLoadRequested());
  }

  Future<void> _onMessageSent(
    AiMessageSent event, Emitter<AiAssistantState> emit,
  ) async {
    final current = state;
    if (current is AiAssistantLoaded) {
      final userMsg = AiMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        role: 'user',
        content: event.text,
        createdAt: DateTime.now(),
      );
      emit(AiAssistantLoaded(messages: [...current.messages, userMsg]));

      try {
        final result = await _repository.sendAiMessage(event.text);
        final assistantMsg = AiMessage(
          id: result.conversationId,
          role: 'assistant',
          content: result.content,
          createdAt: DateTime.now(),
        );
        emit(AiAssistantLoaded(messages: [...current.messages, userMsg, assistantMsg]));
      } on CharoApiException catch (e) {
        emit(AiAssistantError(message: e.message));
      }
    }
  }

  void _onVoiceModeRequested(
    AiVoiceModeRequested event, Emitter<AiAssistantState> emit,
  ) {
    // Voice mode activation — UI state change only
  }

  Future<void> _onSummarizeRequested(
    AiSummarizeRequested event, Emitter<AiAssistantState> emit,
  ) async {
    try {
      final summary = await _repository.summarizeChat(event.chatId);
      final current = state;
      if (current is AiAssistantLoaded) {
        final msg = AiMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          role: 'assistant',
          content: summary,
          createdAt: DateTime.now(),
        );
        emit(AiAssistantLoaded(messages: [...current.messages, msg]));
      }
    } on CharoApiException catch (e) {
      emit(AiAssistantError(message: e.message));
    }
  }

  Future<void> _onStickerGenerateRequested(
    AiStickerGenerateRequested event, Emitter<AiAssistantState> emit,
  ) async {
    try {
      await _repository.generateAiSticker(event.prompt);
    } on CharoApiException catch (e) {
      emit(AiAssistantError(message: e.message));
    }
  }
}
