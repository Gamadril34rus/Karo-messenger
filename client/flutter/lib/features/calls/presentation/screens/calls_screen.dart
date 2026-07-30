import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/accessibility/charo_accessibility.dart';
import '../../../../core/haptic/haptic_service.dart';
import '../../../../shared/widgets/charo_widgets.dart';
import '../../../../shared/widgets/charo_empty_state.dart';
import '../bloc/calls_bloc.dart';
import '../../data/call_item.dart';

/// Экран звонков — история входящих, исходящих, пропущенных
class CallsScreen extends StatefulWidget {
  const CallsScreen({super.key});

  @override
  State<CallsScreen> createState() => _CallsScreenState();
}

class _CallsScreenState extends State<CallsScreen> {
  @override
  void initState() {
    super.initState();
    context.read<CallsBloc>().add(CallsLoadRequested());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Звонки'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => HapticService.light(),
          ),
        ],
      ),
      body: BlocBuilder<CallsBloc, CallsState>(
        builder: (context, state) {
          if (state is CallsLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is CallsError) {
            return Center(
              child: CharoCard(
                gradientColors: [context.colors.error.withOpacity(0.08), context.colors.outlineVariant],
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: context.colors.error),
                    const SizedBox(height: 16),
                    Text(state.message, style: context.typography.bodyLarge),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () {
                        HapticService.light();
                        context.read<CallsBloc>().add(CallsLoadRequested());
                      },
                      child: const Text('Повторить'),
                    ),
                  ],
                ),
              ),
            );
          }
          final calls = state is CallsLoaded ? state.calls : <CallItem>[];
          if (calls.isEmpty) {
            return const CharoEmptyState(
              emoji: '📞',
              title: 'Нет звонков',
              subtitle: 'Совершите первый звонок — нажмите кнопку ниже, чтобы выбрать контакт',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: calls.length,
            itemBuilder: (context, index) => _CallTile(call: calls[index]),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          HapticService.medium();
          _showNewCallSheet(context);
        },
        child: const Icon(Icons.dialpad),
      ),
    );
  }

  void _showNewCallSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Новый звонок', style: context.typography.titleLarge),
            ),
            CharoTile(
              icon: Icons.person_add,
              title: 'Выбрать контакт',
              onTap: () {
                HapticService.light();
                Navigator.pop(ctx);
                context.go('/contacts');
              },
            ),
            CharoTile(
              icon: Icons.dialpad,
              title: 'Набрать номер',
              onTap: () {
                HapticService.light();
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CallTile extends StatelessWidget {
  final CallItem call;
  const _CallTile({required this.call});

  @override
  Widget build(BuildContext context) {
    final isMissed = call.status == 'missed';
    final isIncoming = call.direction == 'incoming';
    final colors = context.colors;

    return CharoAccessibility.callItem(
      callerName: call.name ?? 'Неизвестный',
      callType: call.type == 'video' ? 'Видеозвонок' : 'Голосовой',
      direction: call.direction,
      time: _formatTime(call.time),
      isMissed: isMissed,
      child: CharoCard(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.all(12),
        radius: 14,
        borderWidth: isMissed ? 1 : 0,
        borderColor: isMissed ? colors.error.withOpacity(0.3) : null,
        child: Row(
          children: [
            CharoAvatar(
              radius: 22,
              imageUrl: call.avatarUrl,
              fallbackText: call.name ?? '?',
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    call.name ?? 'Неизвестный',
                    style: context.typography.titleMedium?.copyWith(
                      color: isMissed ? colors.error : colors.onSurface,
                      fontWeight: isMissed ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        isIncoming ? Icons.call_received : Icons.call_made,
                        size: 14,
                        color: isMissed ? colors.error : context.colors.success,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        call.type == 'video' ? 'Видеозвонок' : 'Голосовой',
                        style: context.typography.bodySmall,
                      ),
                      if (call.duration != null) ...[
                        const SizedBox(width: 6),
                        Text('• ${_formatDuration(call.duration!)}', style: context.typography.bodySmall),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_formatTime(call.time), style: context.typography.bodySmall),
                const SizedBox(height: 4),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: colors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: IconButton(
                    icon: Icon(
                      call.type == 'video' ? Icons.videocam : Icons.call,
                      color: colors.primary,
                      size: 18,
                    ),
                    onPressed: () {
                      HapticService.light();
                    },
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    if (diff.inDays == 1) return 'Вчера';
    return '${dt.day}.${dt.month}';
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
