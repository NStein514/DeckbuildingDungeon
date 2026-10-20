import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deckbound/app/app.dart';
import 'package:deckbound/app/run_controller.dart';
import 'package:deckbound/core/persistence/profile_repository.dart';
import 'package:deckbound/core/persistence/run_repository.dart';
import 'package:deckbound/core/persistence/save_store.dart';
import 'package:deckbound/game/cards/upgrades.dart';
import 'package:deckbound/game/combat/combat_engine.dart';
import 'package:deckbound/game/economy/economy.dart';
import 'package:deckbound/game/models/models.dart';
import 'package:deckbound/game/progression/run_rules.dart';
import 'package:deckbound/game/relics/relic.dart';
import '../test_catalog.dart';
import 'fusion_test.dart' show shrine;

void main() {
  final catalog = loadCatalog(), rules = RunRules(loadCatalog());
  CombatEngine battle(
    String id, {
    bool upgraded = false,
    Set<Relic> relics = const {},
  }) => CombatEngine(
    cards: catalog.cards,
    deck: [
      CardInstance('fused', id, upgrade: upgraded ? 1 : 0),
      const CardInstance('lance', 'static_lance'),
    ],
    enemies: [
      const EnemyDefinition('dummy', 'Dummy', 100, [
        EnemyAction('Hit', [Effect(EffectKind.damage, 5)]),
      ]),
    ],
    relics: relics,
  );
  test('Stormguard blocks, applies Shock and feeds the next lightning hit', () {
    final e = battle('stormguard');
    expect(e.play('fused'), isNotNull);
    expect(e.state.energy, 3);
    expect(e.play('fused', targetId: 'enemy-0'), isNull);
    expect(e.state.player.block, 6);
    expect(e.state.enemies.single.health, 98);
    expect(e.state.enemies.single.stacks(Status.shock), 2);
    e.play('lance', targetId: 'enemy-0');
    expect(e.state.enemies.single.health, 89);
    expect(e.state.enemies.single.stacks(Status.shock), 0);
    e.endTurn();
    expect(e.state.player.health, 50);
  });
  test('upgraded Stormguard and Cinder Maul match resolved previews', () {
    final storm = battle('stormguard', upgraded: true);
    storm.play('fused', targetId: 'enemy-0');
    expect(storm.state.player.block, 8);
    expect(storm.state.enemies.single.health, 96);
    expect(storm.state.enemies.single.stacks(Status.shock), 3);
    final maul = battle('cinder_maul', upgraded: true);
    maul.play('fused', targetId: 'enemy-0');
    expect(maul.state.enemies.single.health, 83);
    expect(maul.state.enemies.single.stacks(Status.burn), 5);
    final preview = resolveCard(
      catalog.cards['cinder_maul']!,
      const CardInstance('f', 'cinder_maul', upgrade: 1),
    );
    expect(preview.description, contains('17 damage'));
    expect(preview.description, contains('5 burn'));
  });
  test(
    'Cinder Maul spends two energy and triggers Ember Heart once per encounter',
    () {
      final e = battle('cinder_maul', relics: {Relic.emberHeart});
      e.play('fused', targetId: 'enemy-0');
      expect(e.state.energy, 1);
      expect(e.state.enemies.single.health, 85);
      expect(e.state.enemies.single.stacks(Status.burn), 6);
      e.endTurn();
      expect(e.state.enemies.single.health, 79);
      e.play('fused', targetId: 'enemy-0');
      expect(e.state.enemies.single.stacks(Status.burn), 9);
    },
  );
  test('fusion-only cards stay out of rewards and merchant stock', () {
    for (var seed = 0; seed < 100; seed++) {
      final reward = rules.finishCombat(
        enterRoom(rules, rules.start(seed), 'room-0-0'),
        Outcome.victory,
        40,
      );
      for (final id in ['stormguard', 'cinder_maul']) {
        expect(reward.rewards, isNot(contains(id)));
        expect(Merchant.stock(catalog, seed), isNot(contains(id)));
      }
    }
  });
  test(
    'content 7 remains readable and expanded results persist in run and journal',
    () async {
      for (final pair in [
        ['starter-3', 'starter-10', 'stormguard'],
        ['starter-6', 'starter-8', 'cinder_maul'],
      ]) {
        final store = MemorySaveStore()
          ..contents = jsonEncode({
            'version': 1,
            'contentVersion': 7,
            'run': shrine(rules).toJson(),
          });
        final profile = ProfileRepository(MemorySaveStore(), catalog);
        final c = RunController(
          RunRepository(store, catalog),
          profileRepository: profile,
        );
        await c.load();
        expect(await c.fuse(pair[0], pair[1]), true);
        expect((await c.repository.load())!.deck.last.definitionId, pair[2]);
        expect((await profile.load()).cards, contains(pair[2]));
        expect(jsonDecode(store.contents!)['contentVersion'], 11);
        await c.start(12);
        expect(c.profile!.cards, contains(pair[2]));
        c.dispose();
      }
    },
  );
  for (final name in ['Stormguard', 'Cinder Maul']) {
    testWidgets('$name shortcut previews exact sources and confirms once', (
      t,
    ) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final store = MemorySaveStore(),
          repo = RunRepository(MemorySaveStore(), catalog);
      final r = shrine(rules);
      r.deck[3] = const CardInstance('starter-3', 'guard', upgrade: 1);
      await repo.save(r);
      store.contents = (repo.store as MemorySaveStore).contents;
      await t.pumpWidget(DeckboundApp(catalog: catalog, saveStore: store));
      await t.pumpAndSettle();
      Future<void> tap(String label) async {
        if (find.text(label).evaluate().isEmpty) {
          await t.scrollUntilVisible(find.text(label), 250);
        }
        await t.ensureVisible(find.text(label).last);
        await t.pumpAndSettle();
        await t.tap(find.text(label).last);
        await t.pumpAndSettle();
      }

      await tap('Continue run');
      final chip = find.widgetWithText(ActionChip, name);
      await t.scrollUntilVisible(chip.hitTestable(), 250);
      await t.pumpAndSettle();
      await t.tap(chip);
      await t.pumpAndSettle();
      if (name == 'Stormguard') {
        expect(find.text('Guard · copy 2'), findsWidgets);
      }
      await tap('Fuse cards');
      await tap('Cancel');
      expect((await RunRepository(store, catalog).load())!.deck, hasLength(12));
      await tap('Fuse cards');
      await tap('Confirm fusion');
      final saved = (await RunRepository(store, catalog).load())!;
      expect(saved.deck, hasLength(11));
      expect(
        saved.deck.last.definitionId,
        name == 'Stormguard' ? 'stormguard' : 'cinder_maul',
      );
      expect(saved.deck.firstWhere((c) => c.id == 'starter-3').upgrade, 1);
      expect(t.takeException(), isNull);
    });
  }
}
