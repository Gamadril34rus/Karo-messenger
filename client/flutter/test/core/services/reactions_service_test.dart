import 'package:flutter_test/flutter_test.dart';
import 'package:charo_messenger/core/services/reactions_service.dart';

void main() {
  group('ReactionsPicker', () {
    test('quickReactions has 6 entries', () {
      expect(ReactionsPicker.quickReactions.length, 6);
    });

    test('extendedReactions has 24 entries', () {
      expect(ReactionsPicker.extendedReactions.length, 24);
    });

    test('quickReactions are all emojis', () {
      for (final emoji in ReactionsPicker.quickReactions) {
        expect(emoji, isNotEmpty);
        // Each emoji should be a non-empty string
        expect(emoji.length, greaterThanOrEqualTo(1));
      }
    });

    test('extendedReactions includes all quickReactions', () {
      for (final emoji in ReactionsPicker.quickReactions) {
        expect(ReactionsPicker.extendedReactions, contains(emoji));
      }
    });

    test('extendedReactions has no duplicates', () {
      final unique = ReactionsPicker.extendedReactions.toSet();
      expect(unique.length, ReactionsPicker.extendedReactions.length);
    });
  });
}
