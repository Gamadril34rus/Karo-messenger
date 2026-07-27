/// Модель пользователя рядом (Nearby)
class NearbyUser {
  final String userId;
  final String displayName;
  final String distance;
  final String? status;

  const NearbyUser({
    required this.userId,
    required this.displayName,
    required this.distance,
    this.status,
  });
}
