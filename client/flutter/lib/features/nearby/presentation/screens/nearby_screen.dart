import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/haptic/haptic_service.dart';
import '../../../../shared/widgets/charo_widgets.dart';
import '../bloc/nearby_bloc.dart';
import '../../data/nearby_user.dart';

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
      appBar: AppBar(
        title: const Text('Кто рядом'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              HapticService.medium();
              context.read<NearbyBloc>().add(NearbyLoadRequested());
            },
          ),
        ],
      ),
      body: BlocBuilder<NearbyBloc, NearbyState>(
        builder: (context, state) {
          if (state is NearbyLoading) return const Center(child: CircularProgressIndicator());
          if (state is NearbyError) return Center(
            child: CharoCard(
              gradientColors: [context.colors.error.withOpacity(0.08), context.colors.outlineVariant],
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.location_off, size: 48, color: context.colors.error),
                const SizedBox(height: 16),
                Text(state.message, style: context.typography.bodyLarge),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    HapticService.light();
                    context.read<NearbyBloc>().add(NearbyLoadRequested());
                  },
                  child: const Text('Повторить'),
                ),
              ]),
            ),
          );
          final users = state is NearbyLoaded ? state.users : <NearbyUser>[];
          return Column(
            children: [
              // Map placeholder with premium styling
              CharoHeaderCard(
                height: 240,
                gradientColors: [
                  context.colors.primary.withOpacity(0.08),
                  context.colors.outlineVariant,
                  context.colors.surface,
                ],
                radius: 16,
                child: Stack(
                  children: [
                    Center(
                      child: Icon(Icons.map, size: 64, color: context.colors.onSurface.withOpacity(0.15)),
                    ),
                    Positioned(
                      right: 16,
                      bottom: 16,
                      child: FloatingActionButton.small(
                        onPressed: () {
                          HapticService.light();
                          context.read<NearbyBloc>().add(NearbyLoadRequested());
                        },
                        child: const Icon(Icons.my_location),
                      ),
                    ),
                    for (final u in users.take(5))
                      Positioned(
                        left: 50 + (users.indexOf(u) * 60.0) % 300,
                        top: 40 + (users.indexOf(u) * 40.0) % 150,
                        child: GestureDetector(
                          onTap: () {
                            HapticService.light();
                            _showUserSheet(context, u);
                          },
                          child: Column(
                            children: [
                              CharoAvatar(
                                radius: 20,
                                fallbackText: u.displayName,
                                showRing: true,
                                ringColors: [context.colors.primary, context.colors.success],
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: context.colors.surface,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: context.colors.primary.withOpacity(0.3)),
                                ),
                                child: Text(
                                  u.distance,
                                  style: context.typography.bodySmall?.copyWith(
                                    fontSize: 10,
                                    color: context.colors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // List header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
                child: Row(
                  children: [
                    Text('Люди рядом', style: context.typography.titleLarge),
                    const Spacer(),
                    CharoBadge(count: users.length),
                  ],
                ),
              ),
              Expanded(
                child: users.isEmpty
                  ? Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.location_off, size: 48, color: context.colors.onSurface.withOpacity(0.15)),
                      const SizedBox(height: 12),
                      Text('Никого рядом', style: context.typography.bodyLarge?.copyWith(
                        color: context.colors.onSurface.withOpacity(0.4),
                      )),
                    ]),
                  )
                  : ListView.builder(
                    itemCount: users.length,
                    itemBuilder: (context, index) => _NearbyUserTile(user: users[index]),
                  ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showUserSheet(BuildContext context, NearbyUser user) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 16),
          CharoAvatar(
            radius: 40,
            fallbackText: user.displayName,
            showRing: true,
            ringColors: [context.colors.primary, context.colors.success],
          ),
          const SizedBox(height: 8),
          Text(user.displayName, style: context.typography.titleLarge),
          Text(user.distance, style: context.typography.bodyMedium?.copyWith(
            color: context.colors.onSurface.withOpacity(0.5),
          )),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () { HapticService.light(); Navigator.pop(ctx); },
                    icon: const Icon(Icons.chat_bubble),
                    label: const Text('Написать'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () { HapticService.light(); Navigator.pop(ctx); },
                    icon: const Icon(Icons.call),
                    label: const Text('Позвонить'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }
}

class _NearbyUserTile extends StatelessWidget {
  final NearbyUser user;
  const _NearbyUserTile({required this.user});

  @override
  Widget build(BuildContext context) {
    return CharoTile(
      icon: Icons.location_on,
      iconColor: context.colors.success,
      title: user.displayName,
      subtitle: user.status ?? 'Анонимно',
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: context.colors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          user.distance,
          style: context.typography.bodySmall?.copyWith(
            color: context.colors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      onTap: () => _showUserSheet(context, user),
    );
  }

  void _showUserSheet(BuildContext context, NearbyUser user) {
    HapticService.light();
  }
}
