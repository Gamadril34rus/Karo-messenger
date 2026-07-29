import 'package:flutter_test/flutter_test.dart';
import 'package:charo_messenger/core/services/webrtc_config.dart';

void main() {
  group('WebRTCConfig', () {
    test('defaultIceServers has 5 Google STUN servers', () {
      expect(WebRTCConfig.defaultIceServers.length, 5);
    });

    test('defaultIceServers all have stun: URLs', () {
      for (final server in WebRTCConfig.defaultIceServers) {
        expect(server['urls'] as String, startsWith('stun:stun'));
      }
    });

    test('productionIceServers includes default STUN servers', () {
      final servers = WebRTCConfig.productionIceServers;
      expect(servers.length, greaterThanOrEqualTo(5));
    });

    test('peerConnectionConfiguration has iceServers', () {
      final config = WebRTCConfig.peerConnectionConfiguration;
      expect(config.containsKey('iceServers'), isTrue);
      expect(config['sdpSemantics'], 'unified-plan');
      expect(config['iceCandidatePoolSize'], 10);
    });

    test('audioOnlyConstraints has audio enabled', () {
      expect(WebRTCConfig.audioOnlyConstraints['audio'], isTrue);
      expect(WebRTCConfig.audioOnlyConstraints['video'], isFalse);
    });

    test('videoCallConstraints has video enabled', () {
      expect(WebRTCConfig.videoCallConstraints['audio'], isTrue);
      expect(WebRTCConfig.videoCallConstraints['video'], isNotNull);
    });
  });
}
