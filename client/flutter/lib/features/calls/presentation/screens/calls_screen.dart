import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../bloc/calls_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
          IconButton(icon: const Icon(Icons.search), onPressed: _showSearch),
        ],
      ),
      body: BlocBuilder<CallsBloc, CallsState>(
        builder: (context, state) {
          if (state is CallsLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is CallsError) {
            return Center(child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 48, color: context.colors.error),
                const SizedBox(height: 16),
                Text(state.message),
                FilledButton(onPressed: () => context.read<CallsBloc>().add(CallsLoadRequested()), child: const Text('Повторить')),
              ],
            ));
          }
          final calls = state is CallsLoaded ? state.calls : <CallItem>[];
          if (calls.isEmpty) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.call_outlined, size: 64, color: context.colors.onSurface.withOpacity(0.2)),
                const SizedBox(height: 16),
                Text('Нет звонков', style: context.typography.titleLarge?.copyWith(color: context.colors.onSurface.withOpacity(0.5))),
              ]),
            );
          }
          return ListView.builder(
            itemCount: calls.length,
            itemBuilder: (context, index) => _CallTile(call: calls[index]),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showNewCallSheet(context),
        child: const Icon(Icons.dialpad),
      ),
    );
  }

  void _showSearch() {
    showSearch(context: context, delegate: _CallsSearchDelegate());
  }

  void _showNewCallSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(padding: const EdgeInsets.all(16), child: Text('Новый звонок', style: context.typography.titleLarge)),
          ListTile(leading: const Icon(Icons.person_add), title: const Text('Выбрать контакт'), onTap: () { Navigator.pop(ctx); context.go('/contacts'); }),
        ]),
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
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: context.colors.primary.withOpacity(0.1),
        child: call.avatarUrl != null
            ? null
            : Text((call.name ?? '?')[0].toUpperCase(), style: TextStyle(color: context.colors.primary)),
      ),
      title: Text(call.name ?? 'Неизвестный', style: TextStyle(
        color: isMissed ? context.colors.error : context.colors.onSurface,
        fontWeight: isMissed ? FontWeight.w600 : FontWeight.w500,
      )),
      subtitle: Row(children: [
        Icon(
          isIncoming ? Icons.call_received : Icons.call_made,
          size: 16,
          color: isMissed ? context.colors.error : context.colors.success,
        ),
        const SizedBox(width: 4),
        Text(call.type == 'video' ? 'Видеозвонок' : 'Голосовой звонок', style: context.typography.bodySmall),
        if (call.duration != null) ...[
          const SizedBox(width: 8),
          Text('• ${_formatDuration(call.duration!)}', style: context.typography.bodySmall),
        ],
      ]),
      trailing: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(_formatTime(call.time), style: context.typography.bodySmall),
        IconButton(
          icon: Icon(call.type == 'video' ? Icons.videocam : Icons.call, color: context.colors.primary),
          onPressed: () {/* Перезвонить */},
        ),
      ]),
      onTap: () {/* Показать детали звонка */},
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

class _CallsSearchDelegate extends SearchDelegate {
  @override
  List<Widget> buildActions(BuildContext context) => [IconButton(icon: const Icon(Icons.clear), onPressed: () => query = '')];

  @override
  Widget buildLeading(BuildContext context) => IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => close(context, null));

  @override
  Widget buildResults(BuildContext context) => const Center(child: Text('Результаты поиска'));

  @override
  Widget buildSuggestions(BuildContext context) => const Center(child: Text('Поиск звонков...'));
}

class CallItem {
  final String id;
  final String? name;
  final String? avatarUrl;
  final String type;       // voice, video
  final String direction;  // incoming, outgoing
  final String status;     // active, ended, missed, declined
  final DateTime time;
  final int? duration;

  const CallItem({required this.id, this.name, this.avatarUrl, required this.type, required this.direction, required this.status, required this.time, this.duration});
}
