import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deckbound/presentation/effects/combat_cue.dart';
import 'package:deckbound/presentation/effects/combat_feedback.dart';
import 'package:deckbound/presentation/effects/enemy_departure.dart';

void main() {
  for (final reduced in [false, true]) {
    testWidgets('damage tints and shakes only with motion enabled: $reduced', (
      t,
    ) async {
      await t.pumpWidget(
        MaterialApp(
          home: CombatFeedback(
            cues: const [
              CombatCue(1, 'player', CombatVisual.slash, '-6 HP', damage: true),
            ],
            reducedMotion: reduced,
            fastAnimations: false,
            child: const SizedBox(width: 200, height: 280),
          ),
        ),
      );
      await t.pump(const Duration(milliseconds: 40));
      final transform = t.widget<Transform>(
        find.byKey(const ValueKey('damage-shake')),
      );
      expect(transform.transform.getTranslation().x, reduced ? 0 : isNot(0));
      final filter = t
          .widget<ColorFiltered>(find.byKey(const ValueKey('damage-tint')))
          .colorFilter;
      await t.pumpAndSettle();
      expect(
        t
            .widget<ColorFiltered>(find.byKey(const ValueKey('damage-tint')))
            .colorFilter,
        isNot(filter),
      );
      expect(t.takeException(), isNull);
    });
    testWidgets('defeat fades and completes once, reduced=$reduced', (t) async {
      var completed = 0;
      await t.pumpWidget(
        MaterialApp(
          home: EnemyDeparture(
            defeated: true,
            reducedMotion: reduced,
            fast: false,
            onDeparted: () => completed++,
            child: const SizedBox(width: 200, height: 280),
          ),
        ),
      );
      await t.pump(const Duration(milliseconds: 90));
      final fade = t.widget<Opacity>(find.byType(Opacity));
      expect(fade.opacity, allOf(greaterThan(0), lessThan(1)));
      final shift = t.widget<Transform>(find.byType(Transform));
      expect(shift.transform.getTranslation().y, reduced ? 0 : greaterThan(0));
      await t.pumpAndSettle();
      expect(completed, 1);
      expect(t.widget<Opacity>(find.byType(Opacity)).opacity, 0);
      expect(t.takeException(), isNull);
    });
  }
}
