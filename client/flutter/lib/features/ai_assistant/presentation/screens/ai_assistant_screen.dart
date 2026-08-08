// © 2024-2026 Бутаев Алексей Юрьевич. All rights reserved. PROPRIETARY AND CONFIDENTIAL.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/haptic/haptic_service.dart';
import '../../../../shared/widgets/charo_widgets.dart';
import '../bloc/ai_assistant_bloc.dart';
import '../../data/ai_message.dart';

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
      appBar: AppBar(
        title: const Text('AI-ассистент'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              HapticService.light();
              context.read<AiAssistantBloc>().add(AiConversationCreated());
            },
          ),
          PopupMenuButton(
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 'voice', child: Text('Голосовой режим')),
              const PopupMenuItem(value: 'translate', child: Text('Переводчик')),
              const PopupMenuItem(value: 'summarize', child: Text('Саммаризация чата')),
              const PopupMenuItem(value: 'sticker', child: Text('Сгенерировать стикер')),
            ],
            onSelected: (v) {
              HapticService.light();
              if (v == 'voice') _startVoiceMode();
              if (v == 'translate') _startTranslateMode();
              if (v == 'summarize') _startSummarizeMode();
              if (v == 'sticker') _startStickerGeneration();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: BlocBuilder<AiAssistantBloc, AiAssistantState>(
              builder: (context, state) {
                if (state is AiAssistantLoading) return const Center(child: CircularProgressIndicator());
                if (state is AiAssistantError) return Center(
                  child: CharoCard(
                    gradientColors: [context.colors.error.withOpacity(0.08), context.colors.outlineVariant],
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.error_outline, size: 48, color: context.colors.error),
                      const SizedBox(height: 16),
                      Text(state.message),
                    ]),
                  ),
                );
                final messages = state is AiAssistantLoaded ? state.messages : <AiMessage>[];
                if (messages.isEmpty) return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [context.colors.primary.withOpacity(0.15), context.colors.accentLight.withOpacity(0.1)],
                          ),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Icon(Icons.smart_toy_outlined, size: 40, color: context.colors.primary),
                      ),
                      const SizedBox(height: 24),
                      Text('Привет! Я ваш AI-ассистент', style: context.typography.titleLarge),
                      const SizedBox(height: 8),
                      Text('Спросите меня о чём угодно', style: context.typography.bodyMedium?.copyWith(
                        color: context.colors.onSurface.withOpacity(0.5),
                      )),
                      const SizedBox(height: 32),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          _SuggestionChip(label: 'Переведи текст', onTap: () => _sendQuick('Переведи: ')),
                          _SuggestionChip(label: 'Кратко перескажи', onTap: () => _sendQuick('Перескажи кратко: ')),
                          _SuggestionChip(label: 'Сгенерируй стикер', onTap: _startStickerGeneration),
                          _SuggestionChip(label: 'Помоги с ответом', onTap: () => _sendQuick('Помоги составить ответ: ')),
                        ],
                      ),
                    ]),
                  ),
                );
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) => _AiMessageBubble(message: messages[index]),
                );
              },
            ),
          ),
          _buildInputBar(context),
        ],
      ),
    );
  }

  Widget _buildInputBar(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.outline, width: 0.5)),
        color: colors.surface,
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: Icon(Icons.mic, color: colors.primary, size: 20),
                onPressed: _startVoiceMode,
                padding: EdgeInsets.zero,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _inputController,
                decoration: InputDecoration(
                  hintText: 'Спросите AI...',
                  border: InputBorder.none,
                ),
                maxLines: 4,
                minLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colors.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white, size: 20),
                onPressed: _sendMessage,
                padding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _sendMessage() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    HapticService.light();
    context.read<AiAssistantBloc>().add(AiMessageSent(text: text));
    _inputController.clear();
  }

  void _sendQuick(String prefix) {
    _inputController.text = prefix;
  }

  void _startVoiceMode() {
    HapticService.medium();
    context.read<AiAssistantBloc>().add(AiVoiceModeRequested());
  }

  void _startTranslateMode() {
    _inputController.text = 'Переведи: ';
  }

  void _startSummarizeMode() {
    HapticService.light();
    context.read<AiAssistantBloc>().add(AiSummarizeRequested(chatId: 'current'));
  }

  void _startStickerGeneration() {
    final controller = TextEditingController();
    HapticService.medium();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Сгенерировать стикер'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Опишите стикер...'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AiAssistantBloc>().add(AiStickerGenerateRequested(prompt: controller.text.trim()));
            },
            child: const Text('Создать'),
          ),
        ],
      ),
    );
  }
}

class _AiMessageBubble extends StatelessWidget {
  final AiMessage message;
  const _AiMessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    final colors = context.colors;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isUser ? colors.primary.withOpacity(0.12) : colors.outlineVariant,
          borderRadius: BorderRadius.only(
            topLeft: isUser ? const Radius.circular(18) : const Radius.circular(4),
            topRight: isUser ? const Radius.circular(4) : const Radius.circular(18),
            bottomLeft: const Radius.circular(18),
            bottomRight: const Radius.circular(18),
          ),
          border: isUser ? null : Border.all(color: colors.outline.withOpacity(0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isUser)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: colors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.smart_toy, size: 14, color: colors.primary),
                    ),
                    const SizedBox(width: 6),
                    Text('AI', style: context.typography.bodySmall?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w700,
                    )),
                  ],
                ),
              ),
            Text(message.content, style: context.typography.bodyLarge),
            const SizedBox(height: 4),
            Text(_formatTime(message.createdAt), style: context.typography.bodySmall?.copyWith(fontSize: 10)),
          ],
        ),
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
    return ActionChip(
      label: Text(label),
      labelStyle: context.typography.bodySmall?.copyWith(color: context.colors.primary),
      backgroundColor: context.colors.primary.withOpacity(0.08),
      side: BorderSide(color: context.colors.primary.withOpacity(0.2)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onPressed: () {
        HapticService.light();
        onTap();
      },
    );
  }
}
