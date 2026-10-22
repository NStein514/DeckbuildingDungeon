import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deckbound/app/app.dart';
import 'package:deckbound/core/persistence/run_repository.dart';
import 'package:deckbound/core/persistence/save_store.dart';
import 'package:deckbound/core/random/seeded_random.dart';
import 'package:deckbound/game/combat/combat_engine.dart';
import 'package:deckbound/game/dungeon/difficulty.dart';
import 'package:deckbound/game/dungeon/dungeon.dart';
import 'package:deckbound/game/models/models.dart';
import 'package:deckbound/game/progression/run_rules.dart';
import 'package:deckbound/presentation/widgets/guardian_plan.dart';
import '../test_catalog.dart';
import '../fusion/fusion_test.dart' show shrine;

void main() {
  final catalog = loadCatalog(), rules = RunRules(loadCatalog());
  test(
    'all guardians appear deterministically with a valid saved boss room',
    () async {
      final seen = <String>{};
      final repo = RunRepository(MemorySaveStore(), catalog);
      for (var seed = 0; seed < 200; seed++) {
        final run = rules.start(seed);
        final boss = run.rooms.singleWhere((r) => r.type == RoomType.boss);
        expect(boss.enemies, hasLength(1));
        expect(catalog.enemies[boss.enemies.single]!.boss, true);
        seen.add(boss.enemies.single);
        await repo.save(run);
        expect((await repo.load())!.toJson(), run.toJson());
        expect(rules.start(seed).toJson(), run.toJson());
      }
      expect(seen, {'warden', 'broodmother', 'sentinel'});
    },
  );
  test(
    'version 4 retains the Warden and its original RNG continuation',
    () async {
      final rng = SeededRandom(514);
      final rooms = DungeonGenerator.generate(rng, version: 4);
      final json = rules.start(514).toJson()
        ..['mapVersion'] = 4
        ..['rooms'] = rooms.map((r) => r.toJson()).toList()
        ..['rngState'] = rng.state;
      final store = MemorySaveStore()
        ..contents = jsonEncode({
          'version': 1,
          'contentVersion': 4,
          'run': json,
        });
      final repo = RunRepository(store, catalog);
      final loaded = (await repo.load())!;
      expect(loaded.rooms.last.enemies, ['warden']);
      expect(loaded.toJson(), json);
      await repo.save(loaded);
      expect((await repo.load())!.toJson(), json);
      final modern = DungeonGenerator.generate(SeededRandom(514), version: 5);
      expect(
        modern.take(12).map((r) => r.toJson()),
        rooms.take(12).map((r) => r.toJson()),
      );
    },
  );
  CombatEngine battle(String id) => CombatEngine(
    cards: catalog.cards,
    deck: catalog.createDeck(),
    enemies: [catalog.enemies[id]!],
  );
  test(
    'Broodmother poison, defensive turn and two hits execute and repeat',
    () {
      final e = battle('broodmother');
      expect(e.intent('enemy-0').name, 'Venom bite');
      e.endTurn();
      expect(e.state.player.health, 42);
      expect(e.state.player.stacks(Status.poison), 1);
      expect(e.intent('enemy-0').name, 'Coil');
      e.endTurn();
      expect(e.state.enemies.single.block, 9);
      expect(e.state.player.health, 41);
      expect(e.intent('enemy-0').name, 'Twin fangs');
      e.endTurn();
      expect(e.state.player.health, 29);
      expect(e.state.enemies.single.block, 0);
      expect(e.intent('enemy-0').name, 'Venom bite');
    },
  );
  test('Sentinel offers an opening before burn and heavy attack', () {
    final e = battle('sentinel');
    e.endTurn();
    expect(e.state.enemies.single.block, 8);
    expect(e.state.player.health, 50);
    e.endTurn();
    expect(e.state.player.health, 40);
    expect(e.state.player.stacks(Status.burn), 1);
    e.endTurn();
    expect(e.state.player.health, 24);
    expect(e.intent('enemy-0').name, 'Bank the furnace');
  });
  testWidgets('boss preview is concealed until reveal and survives reload', (
    t,
  ) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final run = advanceToDepth(rules, rules.skipShrine(shrine(rules)), 5);
    final boss = catalog.enemies[run.rooms.last.enemies.single]!;
    final store = MemorySaveStore(),
        repo = RunRepository(MemorySaveStore(), catalog);
    final saved = RunRepository(store, catalog);
    await saved.save(run);
    await t.pumpWidget(DeckboundApp(catalog: catalog, saveStore: store));
    await t.pumpAndSettle();
    Future<void> tap(String label) async {
      if (find.text(label).evaluate().isEmpty) {
        await t.scrollUntilVisible(
          find.text(label),
          250,
          scrollable: find.byType(Scrollable).first,
        );
      }
      await t.ensureVisible(find.text(label).first);
      await t.pumpAndSettle();
      await t.tap(find.text(label).first);
      await t.pumpAndSettle();
    }

    await tap('Continue run');
    expect(find.byType(GuardianPlan), findsNothing);
    expect(find.textContaining(boss.name), findsNothing);
    await t.scrollUntilVisible(
      find.text('Unexplored path 1 · floor 6'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tap('Unexplored path 1 · floor 6');
    await tap('${boss.name} · battle plan');
    expect(find.text('1. ${boss.pattern.first.name}'), findsOneWidget);
    final reveal = (await saved.load())!;
    await repo.save(reveal);
    await t.pumpWidget(
      DeckboundApp(
        key: const ValueKey('reload'),
        catalog: catalog,
        saveStore: store,
      ),
    );
    await t.pumpAndSettle();
    await tap('Continue run');
    expect(find.byType(GuardianPlan), findsOneWidget);
    expect((await saved.load())!.toJson(), reveal.toJson());
    await tap('Enter encounter');
    expect(find.text('TURN 1'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'guardian plan shows scaled multi-hit damage and unchanged poison',
    (t) async {
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GuardianPlan(
              enemy: scaleEnemy(catalog.enemies['broodmother']!, 3),
            ),
          ),
        ),
      );
      await t.tap(find.text('Crypt Broodmother · battle plan'));
      await t.pumpAndSettle();
      expect(find.text('8 damage to you; 2 poison on you'), findsOneWidget);
      expect(find.text('8 damage to you; 8 damage to you'), findsOneWidget);
      expect(find.text('11 block for itself'), findsOneWidget);
    },
  );
}
