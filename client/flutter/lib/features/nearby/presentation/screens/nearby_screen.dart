import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../bloc/nearby_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Экран «Кто рядом» — карта с ближайшими пользователями
class NearbyScreen extends StatefulWidget {
  const NearbyScreen({super.key});

  @override
  State<NearbyScreen> createState() => _NearbyScreenState();
}

class _NearbyScreenState extends State<NearbyScreen> {
  @override
  void initState() {
    super.initState();
    context.read<NearbyBloc>().add(NearbyLoadRequested());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Кто рядом'), actions: [
        IconButton(icon: const Icon(Icons.refresh), onPressed: () => context.read<NearbyBloc>().add(NearbyLoadRequested())),
      ]),
      body: BlocBuilder<NearbyBloc, NearbyState>(
        builder: (context, state) {
          if (state is NearbyLoading) return const Center(child: CircularProgressIndicator());
          if (state is NearbyError) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.location_off, size: 48, color: context.colors.error),
            const SizedBox(height: 16),
            Text(state.message),
            FilledButton(onPressed: () => context.read<NearbyBloc>().add(NearbyLoadRequested()), child: const Text('Повторить')),
          ]));
          final users = state is NearbyLoaded ? state.users : <NearbyUser>[];
          return Column(children: [
            // Карта-заглушка
            Container(
              height: 240,
              width: double.infinity,
              color: context.colors.outlineVariant,
              child: Stack(children: [
                Center(child: Icon(Icons.map, size: 64, color: context.colors.onSurface.withOpacity(0.2))),
                Positioned(right: 16, bottom: 16, child: FloatingActionButton.small(
                  onPressed: () => context.read<NearbyBloc>().add(NearbyLoadRequested()),
                  child: const Icon(Icons.my_location),
                )),
                for (final u in users.take(5))
                  Positioned(
                    left: 50 + (users.indexOf(u) * 60.0) % 300,
                    top: 40 + (users.indexOf(u) * 40.0) % 150,
                    child: GestureDetector(
                      onTap: () => _showUserSheet(context, u),
                      child: Column(children: [
                        CircleAvatar(radius: 20, backgroundColor: context.colors.primary,
                          child: Text(u.displayName[0].toUpperCase(), style: const TextStyle(color: Colors.white))),
                        const SizedBox(height: 2),
                        Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(color: context.colors.surface, borderRadius: BorderRadius.circular(8)),
                          child: Text(u.distance, style: context.typography.bodySmall?.copyWith(fontSize: 10))),
                      ]),
                    ),
                  ),
              ]),
            ),
            // Список
            Padding(padding: const EdgeInsets.all(16), child: Row(children: [
              Text('Люди рядом', style: context.typography.titleLarge),
              const Spacer(),
              Text('${users.length}', style: context.typography.bodyMedium?.copyWith(color: context.colors.onSurface.withOpacity(0.5))),
            ])),
            Expanded(child: users.isEmpty
              ? Center(child: Text('Никого рядом', style: context.typography.bodyLarge?.copyWith(color: context.colors.onSurface.withOpacity(0.5))))
              : ListView.builder(itemCount: users.length, itemBuilder: (context, index) => _NearbyUserTile(user: users[index])),
            ),
          ]);
        },
      ),
    );
  }

  void _showUserSheet(BuildContext context, NearbyUser user) {
    showModalBottomSheet(context: context, builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const SizedBox(height: 16),
      CircleAvatar(radius: 40, backgroundColor: context.colors.primary.withOpacity(0.1),
        child: Text(user.displayName[0].toUpperCase(), style: TextStyle(color: context.colors.primary, fontSize: 24))),
      const SizedBox(height: 8),
      Text(user.displayName, style: context.typography.titleLarge),
      Text(user.distance, style: context.typography.bodyMedium?.copyWith(color: context.colors.onSurface.withOpacity(0.5))),
      const SizedBox(height: 16),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Row(children: [
        Expanded(child: FilledButton.icon(onPressed: () { Navigator.pop(ctx); }, icon: const Icon(Icons.chat_bubble), label: const Text('Написать'))),
        const SizedBox(width: 8),
        Expanded(child: OutlinedButton.icon(onPressed: () { Navigator.pop(ctx); }, icon: const Icon(Icons.call), label: const Text('Позвонить'))),
      ])),
      const SizedBox(height: 16),
    ])));
  }
}

class _NearbyUserTile extends StatelessWidget {
  final NearbyUser user;
  const _NearbyUserTile({required this.user});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(backgroundColor: context.colors.primary.withOpacity(0.1),
        child: Text(user.displayName[0].toUpperCase(), style: TextStyle(color: context.colors.primary))),
      title: Text(user.displayName),
      subtitle: Text(user.status ?? 'Анонимно'),
      trailing: Text(user.distance, style: context.typography.bodySmall?.copyWith(color: context.colors.primary)),
      onTap: () => _showUserSheet(context, user),
    );
  }
}

class NearbyUser {
  final String userId;
  final String displayName;
  final String distance;
  final String? status;
  const NearbyUser({required this.userId, required this.displayName, required this.distance, this.status});
}
