// © 2024-2026 Бутаев Алексей Юрьевич. All rights reserved. PROPRIETARY AND CONFIDENTIAL.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
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
              HapticService.instance.medium();
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
                    HapticService.instance.light();
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
              // Real map via flutter_map with OpenStreetMap tiles
              SizedBox(
                height: 240,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: LatLng(52.5187, 5.4712), // Lelystad, NL (default center)
                      initialZoom: 14,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.all,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'charo_messenger',
                        maxZoom: 19,
                      ),
                      MarkerLayer(
                        markers: [
                          // Self marker
                          Marker(
                            point: LatLng(52.5187, 5.4712),
                            width: 40,
                            height: 40,
                            child: Container(
                              decoration: BoxDecoration(
                                color: context.colors.primary,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(Icons.my_location, color: Colors.white, size: 20),
                            ),
                          ),
                          // Nearby user markers
                          ...users.map((u) => Marker(
                            point: _userPosition(u, LatLng(52.5187, 5.4712)),
                            width: 44,
                            height: 44,
                            child: GestureDetector(
                              onTap: () {
                                HapticService.instance.light();
                                _showUserSheet(context, u);
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: context.colors.surface,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: context.colors.primary, width: 2),
                                  boxShadow: [
                                    BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4),
                                  ],
                                ),
                                child: CharoAvatar(
                                  radius: 18,
                                  fallbackText: u.displayName,
                                ),
                              ),
                            ),
                          )),
                        ],
                      ),
                      RichAttributionWidget(
                        attributions: [
                          TextSourceAttribution('OpenStreetMap contributors',
                            onTap: () => {},
                          ),
                        ],
                      ),
                    ],
                  ),
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
            ringColors: [context.colors.primary, context.success],
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
                    onPressed: () { HapticService.instance.light(); Navigator.pop(ctx); },
                    icon: const Icon(Icons.chat_bubble),
                    label: const Text('Написать'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () { HapticService.instance.light(); Navigator.pop(ctx); },
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

  /// Calculate position on map from distance string and base position
  LatLng _userPosition(NearbyUser user, LatLng center) {
    final distanceStr = user.distance;
    double distanceMeters = 100;

    if (distanceStr.contains('м')) {
      distanceMeters = double.tryParse(
        distanceStr.replaceAll(RegExp(r'[^\d.]'), ''),
      ) ?? 100;
    } else if (distanceStr.contains('км')) {
      distanceMeters = (double.tryParse(
        distanceStr.replaceAll(RegExp(r'[^\d.]'), ''),
      ) ?? 0.1) * 1000;
    }

    final hash = user.userId.hashCode;
    final latOffset = (distanceMeters / 111320) * (hash % 2 == 0 ? 1 : -1) * 0.5;
    final lngOffset = (distanceMeters / (111320 * 0.7)) * (hash % 2 == 0 ? 1 : -1) * 0.5;

    return LatLng(center.latitude + latOffset, center.longitude + lngOffset);
  }
}

class _NearbyUserTile extends StatelessWidget {
  final NearbyUser user;
  const _NearbyUserTile({required this.user});

  @override
  Widget build(BuildContext context) {
    return CharoTile(
      icon: Icons.location_on,
      iconColor: context.success,
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
    HapticService.instance.light();
  }
}
