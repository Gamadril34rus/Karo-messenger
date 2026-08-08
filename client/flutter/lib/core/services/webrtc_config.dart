// © 2024-2026 Бутаев Алексей Юрьевич. All rights reserved. PROPRIETARY AND CONFIDENTIAL.
/// ─── WebRTC Configuration ────────────────────────────────────────
/// STUN/TURN серверы для обхода NAT.
/// Необходимы для работы звонков за NAT/firewall.

class WebRTCConfig {
  /// Google STUN серверы (бесплатные, для базовой работы)
  static const List<Map<String, dynamic>> defaultIceServers = [
    {'urls': 'stun:stun.l.google.com:19302'},
    {'urls': 'stun:stun1.l.google.com:19302'},
    {'urls': 'stun:stun2.l.google.com:19302'},
    {'urls': 'stun:stun3.l.google.com:19302'},
    {'urls': 'stun:stun4.l.google.com:19302'},
  ];

  /// TURN серверы (требуют настройки для production)
  /// Без TURN — звонки не работают за симметричным NAT.
  /// Для production необходимо:
  /// - Установить coturn или использовать коммерческий TURN сервис
  /// - Настроить credentials
  static List<Map<String, dynamic>> get productionIceServers {
    final servers = <Map<String, dynamic>>[
      ...defaultIceServers,
    ];

    // TURN серверы — заполнить перед production
    const turnUrl = String.fromEnvironment('TURN_URL');
    const turnUsername = String.fromEnvironment('TURN_USERNAME');
    const turnCredential = String.fromEnvironment('TURN_CREDENTIAL');

    if (turnUrl.isNotEmpty) {
      servers.add({
        'urls': turnUrl,
        'username': turnUsername,
        'credential': turnCredential,
      });
    }

    return servers;
  }

  /// Полная конфигурация RTCPeerConnection
  static Map<String, dynamic> get peerConnectionConfiguration => {
    'iceServers': productionIceServers,
    'sdpSemantics': 'unified-plan',
    'iceCandidatePoolSize': 10,
  };

  /// Медиа-ограничения для звонков
  static const Map<String, dynamic> audioOnlyConstraints = {
    'audio': true,
    'video': false,
  };

  static const Map<String, dynamic> videoCallConstraints = {
    'audio': true,
    'video': {
      'mandatory': {
        'minWidth': 640,
        'minHeight': 480,
        'minFrameRate': 15,
      },
      'optional': [
        {'minWidth': 1280},
        {'minHeight': 720},
        {'minFrameRate': 30},
      ],
    },
  };
}
