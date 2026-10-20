import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deckbound/app/settings.dart';
import 'package:deckbound/game/combat/combat_engine.dart';
import 'package:deckbound/game/models/models.dart';
import 'package:deckbound/presentation/effects/combat_cue.dart';
import 'package:deckbound/presentation/effects/combat_feedback.dart';
import 'package:deckbound/presentation/screens/battle_screen.dart';
import 'test_catalog.dart';

void main() {
  final catalog = loadCatalog();
  test(
    'typed cues route physical, elemental and support events to recipients',
    () {
      final cues = combatCues([
        const CombatEvent(
          0,
          EventKind.play,
          '',
          cardId: 'firebolt',
          actorId: 'player',
        ),
        const CombatEvent(
          1,
          EventKind.damage,
          '',
          actorId: 'enemy-1',
          amount: 7,
        ),
        const CombatEvent(
          2,
          EventKind.status,
          '',
          actorId: 'enemy-1',
          amount: 2,
          status: Status.burn,
        ),
        const CombatEvent(3, EventKind.block, '', actorId: 'player', amount: 5),
        const CombatEvent(4, EventKind.heal, '', actorId: 'player', amount: 3),
        const CombatEvent(5, EventKind.draw, '', actorId: 'player'),
        const CombatEvent(6, EventKind.draw, '', actorId: 'player'),
        const CombatEvent(7, EventKind.discard, '', actorId: 'player'),
        const CombatEvent(8, EventKind.combo, '', actorId: 'player'),
      ], catalog.cards);
      expect(cues.where((c) => c.actorId == 'enemy-1').map((c) => c.visual), [
        CombatVisual.fire,
        CombatVisual.fire,
      ]);
      expect(
        cues.map((c) => c.label),
        containsAll(['+5 block', '+3 HP', 'Draw 2', 'Discard', 'COMBO!']),
      );
      expect(cues.where((c) => c.label.startsWith('Draw')), hasLength(1));
    },
  );
  test(
    'actual combat supplies card, absorption and periodic status metadata',
    () {
      final e = CombatEngine(
        cards: catalog.cards,
        deck: [const CardInstance('fire', 'firebolt')],
        enemies: [
          const EnemyDefinition('dummy', 'Dummy', 100, [
            EnemyAction('Brace', [
              Effect(EffectKind.block, 10, target: Target.self),
            ]),
          ]),
        ],
      );
      e.endTurn();
      e.play('fire', targetId: 'enemy-0');
      expect(
        e.state.events.lastWhere((e) => e.kind == EventKind.play).cardId,
        'firebolt',
      );
      final damage = e.state.events.lastWhere(
        (e) => e.kind == EventKind.damage,
      );
      expect(damage.blocked, greaterThan(0));
      expect(
        combatCues([damage], catalog.cards).single.visual,
        CombatVisual.shield,
      );
      e.endTurn();
      expect(
        e.state.events.where(
          (e) => e.kind == EventKind.damage && e.status == Status.burn,
        ),
        isNotEmpty,
      );
    },
  );
  test('every playable card emits feedback and invalid commands emit none', () {
    for (final card in catalog.cards.values.where(
      (c) => c.type != CardType.curse,
    )) {
      final e = CombatEngine(
        cards: catalog.cards,
        rules: const CombatRules(energy: 10),
        deck: [CardInstance('card', card.id)],
        enemies: [
          const EnemyDefinition('dummy', 'Dummy', 100, [
            EnemyAction('Wait', []),
          ]),
        ],
      );
      final before = e.state.events.last.sequence;
      expect(e.play('card', targetId: 'enemy-0'), isNull);
      expect(
        combatCues(
          e.state.events.where((e) => e.sequence > before).toList(),
          catalog.cards,
        ),
        isNotEmpty,
        reason: card.id,
      );
      final count = e.state.events.length;
      expect(e.play('missing', targetId: 'enemy-0'), isNotNull);
      expect(e.state.events.length, count);
    }
  });
  for (final reduced in [false, true]) {
    testWidgets(
      'feedback expires, permits input and disposes safely reduced=$reduced',
      (t) async {
        var taps = 0;
        Widget view(int sequence) => MaterialApp(
          home: Scaffold(
            body: CombatFeedback(
              cues: [
                CombatCue(sequence, 'player', CombatVisual.shield, '+5 block'),
              ],
              reducedMotion: reduced,
              fastAnimations: false,
              child: SizedBox(
                width: 300,
                height: 200,
                child: TextButton(
                  onPressed: () => taps++,
                  child: const Text('Act'),
                ),
              ),
            ),
          ),
        );
        await t.pumpWidget(view(1));
        await t.pump(const Duration(milliseconds: 60));
        expect(
          find.byKey(const ValueKey('combat-feedback-label')),
          findsOneWidget,
        );
        if (reduced) expect(find.byType(Image), findsNothing);
        await t.tap(find.text('Act'));
        expect(taps, 1);
        await t.pumpWidget(view(2));
        await t.pump(const Duration(milliseconds: 60));
        expect(
          find.byKey(const ValueKey('combat-feedback-label')),
          findsOneWidget,
        );
        await t.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('combat-feedback-label')),
          findsNothing,
        );
        await t.pumpWidget(view(3));
        await t.pumpWidget(const SizedBox());
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'killing hit resolves immediately, shows impact briefly, then result',
    (t) async {
      var saves = 0;
      await t.pumpWidget(
        MaterialApp(
          home: BattleScreen(
            catalog: catalog,
            enemyIds: const ['rat'],
            settings: GameSettings(),
            seed: 1,
            deck: const [
              CardInstance('hit', 'cinder_maul', upgrade: 1),
              CardInstance('first', 'strike', upgrade: 1),
            ],
            onComplete: (_) async {
              saves++;
              return true;
            },
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Strike +'));
      await t.pump();
      await t.tap(find.text('Dungeon Rat'));
      await t.pumpAndSettle();
      await t.tap(find.text('Cinder Maul +'));
      await t.pump();
      await t.tap(find.text('Dungeon Rat'));
      await t.pump(const Duration(milliseconds: 80));
      expect(saves, 1);
      expect(find.byKey(const ValueKey('combat-feedback-label')), findsWidgets);
      expect(find.text('VICTORY'), findsNothing);
      await t.pumpAndSettle();
      expect(find.text('VICTORY'), findsOneWidget);
      expect(saves, 1);
      expect(t.takeException(), isNull);
    },
  );
  test('fast feedback is shorter and all feedback is under half a second', () {
    expect(
      combatFeedbackDuration(reduced: false, fast: true),
      lessThan(combatFeedbackDuration(reduced: false, fast: false)),
    );
    expect(
      combatFeedbackDuration(reduced: false, fast: false).inMilliseconds,
      lessThan(500),
    );
  });
}
