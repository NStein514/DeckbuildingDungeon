import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:deckbound/core/persistence/profile_repository.dart';
import 'package:deckbound/core/persistence/run_repository.dart';
import 'package:deckbound/core/persistence/save_store.dart';
import 'package:deckbound/game/combat/combat_engine.dart';
import 'package:deckbound/game/dungeon/dungeon.dart';
import 'package:deckbound/game/models/models.dart';
import 'package:deckbound/game/profile/player_profile.dart';
import 'package:deckbound/game/progression/run_rules.dart';
import 'package:deckbound/game/relics/relic.dart';
import 'test_catalog.dart';

void main() {
  final catalog = loadCatalog(), rules = RunRules(loadCatalog());
  CombatEngine battle(
    int hp, {
    int max = 50,
    Set<Relic> relics = const {Relic.lastEmber},
  }) => CombatEngine(
    cards: catalog.cards,
    deck: const [CardInstance('mend', 'mend')],
    enemies: const [
      EnemyDefinition('dummy', 'Dummy', 100, [EnemyAction('Wait', [])]),
    ],
    initialHealth: hp,
    rules: CombatRules(maxHealth: max),
    relics: relics,
  );
  test('Last Ember grants energy at half health only on opening turn', () {
    for (final hp in [1, 25, 26, 50]) {
      final e = battle(hp);
      expect(e.state.energy, hp <= 25 ? 4 : 3);
      e.endTurn();
      expect(e.state.energy, 3);
    }
    expect(battle(25, relics: {}).state.energy, 3);
    expect(battle(25, max: 51).state.energy, 4);
    expect(battle(26, max: 51).state.energy, 3);
  });
  test('opening bonus survives healing and combines with opening relics', () {
    final e = battle(
      25,
      relics: {Relic.lastEmber, Relic.ironSigil, Relic.quickdrawCharm},
    );
    expect(e.state.player.block, 4);
    expect(e.play('mend'), isNull);
    expect(e.state.player.health, greaterThan(25));
    expect(e.state.energy, 4 - catalog.cards['mend']!.cost);
    e.endTurn();
    expect(e.state.energy, 3);
    expect(
      e.state.events.where((e) => e.message.contains('Last Ember')),
      hasLength(1),
    );
  });
  test(
    'new treasure awards Last Ember once; legacy treasure stays unchanged',
    () {
      for (final version in [8, 9]) {
        var r = startVersion(rules, 514, version);
        final room = r.rooms.firstWhere((r) => r.type == RoomType.treasure);
        r = advanceToDepth(rules, r, room.depth);
        r = enterRoom(rules, r, room.id);
        r.relics
          ..clear()
          ..addAll(Relic.treasurePool(8));
        final after = rules.treasure(r);
        expect(after.gold, r.gold + 25);
        expect(after.relics.contains(Relic.lastEmber), version == 9);
        expect(() => rules.treasure(after), throwsStateError);
      }
    },
  );
  test('map 9 preserves map 8 layouts and RNG continuation', () {
    for (var seed = 1; seed <= 100; seed++) {
      final old = startVersion(rules, seed, 8),
          fresh = startVersion(rules, seed, 9);
      expect(
        fresh.rooms.map((r) => r.toJson()).toList(),
        old.rooms.map((r) => r.toJson()).toList(),
      );
      expect(fresh.rngState, old.rngState);
    }
  });
  test(
    'legacy run and journal load; new relic persists in current envelopes',
    () async {
      final store = MemorySaveStore()
        ..contents = jsonEncode({
          'version': 1,
          'contentVersion': 10,
          'run': startVersion(rules, 514, 8).toJson(),
        });
      final repo = RunRepository(store, catalog);
      final run = (await repo.load())!;
      run.relics.add(Relic.lastEmber);
      await repo.save(run);
      expect(jsonDecode(store.contents!)['contentVersion'], 14);
      expect((await repo.load())!.relics, contains(Relic.lastEmber));
      final journal = MemorySaveStore()
        ..contents = jsonEncode({
          'version': 1,
          'contentVersion': 1,
          'profile': PlayerProfile().toJson(),
        });
      final profiles = ProfileRepository(journal, catalog);
      await profiles.save((await profiles.load()).include(run));
      expect(jsonDecode(journal.contents!)['contentVersion'], 4);
      expect((await profiles.load()).relics, contains('lastEmber'));
    },
  );
}
