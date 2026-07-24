import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/network/api_client.dart';
import '../screens/ai_assistant_screen.dart';

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
  final String? conversationId;
  AiAssistantLoaded({required this.messages, this.conversationId});
  @override List<Object?> get props => [messages, conversationId];
}
final class AiAssistantError extends AiAssistantState {
  final String message;
  AiAssistantError({required this.message});
  @override List<Object?> get props => [message];
}

// BLoC
class AiAssistantBloc extends Bloc<AiAssistantEvent, AiAssistantState> {
  final ApiClient _apiClient;
  AiAssistantBloc({required ApiClient apiClient}) : _apiClient = apiClient, super(AiAssistantInitial()) {
    on<AiConversationsLoadRequested>(_onConversationsLoad);
    on<AiConversationCreated>(_onConversationCreated);
    on<AiMessageSent>(_onMessageSent);
    on<AiVoiceModeRequested>(_onVoiceMode);
    on<AiSummarizeRequested>(_onSummarize);
    on<AiStickerGenerateRequested>(_onStickerGenerate);
  }

  Future<void> _onConversationsLoad(AiConversationsLoadRequested event, Emitter<AiAssistantState> emit) async {
    emit(AiAssistantLoading());
    try {
      final response = await _apiClient.get('/api/v1/ai/chat');
      final messages = (response.data is List ? response.data as List : (response.asMap['messages'] as List? ?? []))
          .map<AiMessage>((json) => AiMessage(
            id: json['id'] as String? ?? '',
            role: json['role'] as String? ?? 'assistant',
            content: json['content'] as String? ?? '',
            createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : DateTime.now(),
          )).toList();
      emit(AiAssistantLoaded(messages: messages, conversationId: response.asMap['conversation_id'] as String?));
    } on CharoApiException {
      emit(const AiAssistantLoaded(messages: []));
    }
  }

  Future<void> _onConversationCreated(AiConversationCreated event, Emitter<AiAssistantState> emit) async {
    final response = await _apiClient.post('/api/v1/ai/chat', data: {'action': 'new'});
    emit(AiAssistantLoaded(messages: [], conversationId: response.asMap['id'] as String?));
  }

  Future<void> _onMessageSent(AiMessageSent event, Emitter<AiAssistantState> emit) async {
    final current = state;
    final existingMessages = current is AiAssistantLoaded ? current.messages : <AiMessage>[];
    final conversationId = current is AiAssistantLoaded ? current.conversationId : null;

    // Оптимистично добавляем сообщение пользователя
    final userMsg = AiMessage(id: 'temp_${DateTime.now().millisecondsSinceEpoch}', role: 'user', content: event.text, createdAt: DateTime.now());
    emit(AiAssistantLoading());
    emit(AiAssistantLoaded(messages: [...existingMessages, userMsg], conversationId: conversationId));

    // Отправляем на сервер
    final response = await _apiClient.post('/api/v1/ai/chat', data: {
      'conversation_id': conversationId,
      'message': event.text,
    });

    final assistantMsg = AiMessage(
      id: response.asMap['id'] as String? ?? '',
      role: 'assistant',
      content: response.asMap['content'] as String? ?? 'Не удалось получить ответ',
      createdAt: DateTime.now(),
    );

    emit(AiAssistantLoaded(
      messages: [...existingMessages, userMsg, assistantMsg],
      conversationId: conversationId ?? response.asMap['conversation_id'] as String?,
    ));
  }

  Future<void> _onVoiceMode(AiVoiceModeRequested event, Emitter<AiAssistantState> emit) async {
    final response = await _apiClient.post('/api/v1/ai/transcribe', data: {'action': 'start_listening'});
    // После распознавания отправляем как обычное сообщение
  }

  Future<void> _onSummarize(AiSummarizeRequested event, Emitter<AiAssistantState> emit) async {
    final response = await _apiClient.post('/api/v1/ai/summarize', data: {'chat_id': event.chatId});
    final summary = response.asMap['summary'] as String? ?? 'Не удалось создать саммаризацию';
    final msg = AiMessage(id: 'sum_${DateTime.now().millisecondsSinceEpoch}', role: 'assistant', content: '📝 Краткое содержание чата:\n\n$summary', createdAt: DateTime.now());
    final current = state;
    final existing = current is AiAssistantLoaded ? current.messages : <AiMessage>[];
    emit(AiAssistantLoaded(messages: [...existing, msg], conversationId: current is AiAssistantLoaded ? current.conversationId : null));
  }

  Future<void> _onStickerGenerate(AiStickerGenerateRequested event, Emitter<AiAssistantState> emit) async {
    final response = await _apiClient.post('/api/v1/ai/generate-sticker', data: {'prompt': event.prompt});
    final url = response.asMap['url'] as String?;
    final msg = AiMessage(id: 'stk_${DateTime.now().millisecondsSinceEpoch}', role: 'assistant', content: url != null ? '🎨 Стикер создан!' : 'Не удалось создать стикер', createdAt: DateTime.now());
    final current = state;
    final existing = current is AiAssistantLoaded ? current.messages : <AiMessage>[];
    emit(AiAssistantLoaded(messages: [...existing, msg], conversationId: current is AiAssistantLoaded ? current.conversationId : null));
  }
}
