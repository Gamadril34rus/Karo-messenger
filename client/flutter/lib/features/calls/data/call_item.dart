/// Модель звонка — история входящих, исходящих, пропущенных
class CallItem {
  final String id;
  final String? name;
  final String? avatarUrl;
  final String type;       // voice, video
  final String direction;  // incoming, outgoing
  final String status;     // active, ended, missed, declined
  final DateTime time;
  final int? duration;

  const CallItem({
    required this.id,
    this.name,
    this.avatarUrl,
    required this.type,
    required this.direction,
    required this.status,
    required this.time,
    this.duration,
  });
}
