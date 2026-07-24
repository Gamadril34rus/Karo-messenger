import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../bloc/ai_assistant_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// AI-ассистент — чат, голосовой помощник, генерация
class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final _inputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<AiAssistantBloc>().add(AiConversationsLoadRequested());
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI-ассистент'), actions: [
        IconButton(icon: const Icon(Icons.add), onPressed: () => context.read<AiAssistantBloc>().add(AiConversationCreated())),
        PopupMenuButton(itemBuilder: (ctx) => [
          const PopupMenuItem(value: 'voice', child: Text('Голосовой режим')),
          const PopupMenuItem(value: 'translate', child: Text('Переводчик')),
          const PopupMenuItem(value: 'summarize', child: Text('Саммаризация чата')),
          const PopupMenuItem(value: 'sticker', child: Text('Сгенерировать стикер')),
        ], onSelected: (v) {
          if (v == 'voice') _startVoiceMode();
          if (v == 'translate') _startTranslateMode();
          if (v == 'summarize') _startSummarizeMode();
          if (v == 'sticker') _startStickerGeneration();
        }),
      ]),
      body: Column(children: [
        Expanded(child: BlocBuilder<AiAssistantBloc, AiAssistantState>(
          builder: (context, state) {
            if (state is AiAssistantLoading) return const Center(child: CircularProgressIndicator());
            final messages = state is AiAssistantLoaded ? state.messages : <AiMessage>[];
            if (messages.isEmpty) return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.smart_toy_outlined, size: 64, color: context.colors.onSurface.withOpacity(0.2)),
                const SizedBox(height: 16),
                Text('Привет! Я ваш AI-ассистент', style: context.typography.titleLarge),
                const SizedBox(height: 8),
                Text('Спросите меня о чём угодно', style: context.typography.bodyMedium?.copyWith(color: context.colors.onSurface.withOpacity(0.5))),
                const SizedBox(height: 24),
                Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
                  _SuggestionChip(label: 'Переведи текст', onTap: () => _sendQuick('Переведи: ')),
                  _SuggestionChip(label: 'Кратко перескажи', onTap: () => _sendQuick('Перескажи кратко: ')),
                  _SuggestionChip(label: 'Сгенерируй стикер', onTap: _startStickerGeneration),
                  _SuggestionChip(label: 'Помоги с ответом', onTap: () => _sendQuick('Помоги составить ответ: ')),
                ]),
              ]),
            );
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              itemBuilder: (context, index) => _AiMessageBubble(message: messages[index]),
            );
          },
        )),
        _buildInputBar(context),
      ]),
    );
  }

  Widget _buildInputBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: context.colors.outline, width: 0.5))),
      child: SafeArea(top: false, child: Row(children: [
        IconButton(icon: Icon(Icons.mic, color: context.colors.onSurface.withOpacity(0.7)), onPressed: _startVoiceMode),
        Expanded(child: TextField(controller: _inputController, decoration: const InputDecoration(hintText: 'Спросите AI...', border: InputBorder.none), maxLines: 4, minLines: 1, textInputAction: TextInputAction.send, onSubmitted: (_) => _sendMessage())),
        IconButton(icon: Icon(Icons.send, color: context.colors.primary), onPressed: _sendMessage),
      ])),
    );
  }

  void _sendMessage() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    context.read<AiAssistantBloc>().add(AiMessageSent(text: text));
    _inputController.clear();
  }

  void _sendQuick(String prefix) {
    _inputController.text = prefix;
    FocusScope.of(context).requestFocus(FocusNode());
  }

  void _startVoiceMode() {
    context.read<AiAssistantBloc>().add(AiVoiceModeRequested());
  }

  void _startTranslateMode() {
    _inputController.text = 'Переведи: ';
    FocusScope.of(context).requestFocus(FocusNode());
  }

  void _startSummarizeMode() {
    context.read<AiAssistantBloc>().add(AiSummarizeRequested(chatId: 'current'));
  }

  void _startStickerGeneration() {
    final controller = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Сгенерировать стикер'),
      content: TextField(controller: controller, decoration: const InputDecoration(hintText: 'Опишите стикер...'), autofocus: true),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
        FilledButton(onPressed: () { Navigator.pop(ctx); context.read<AiAssistantBloc>().add(AiStickerGenerateRequested(prompt: controller.text.trim())); }, child: const Text('Создать')),
      ],
    ));
  }
}

class _AiMessageBubble extends StatelessWidget {
  final AiMessage message;
  const _AiMessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isUser ? context.colors.primary.withOpacity(0.12) : context.colors.outlineVariant,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(message.content, style: context.typography.bodyLarge),
          const SizedBox(height: 4),
          Text(_formatTime(message.createdAt), style: context.typography.bodySmall?.copyWith(fontSize: 10)),
        ]),
      ),
    );
  }

  String _formatTime(DateTime dt) => '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

class _SuggestionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _SuggestionChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(label: Text(label), onPressed: onTap);
  }
}

class AiMessage {
  final String id;
  final String role; // user, assistant
  final String content;
  final DateTime createdAt;

  const AiMessage({required this.id, required this.role, required this.content, required this.createdAt});
}
