import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:deckbound/app/run_controller.dart';
import 'package:deckbound/core/persistence/profile_repository.dart';
import 'package:deckbound/core/persistence/run_repository.dart';
import 'package:deckbound/core/persistence/save_store.dart';
import 'package:deckbound/game/profile/player_profile.dart';
import 'package:deckbound/game/progression/run_rules.dart';
import 'package:deckbound/game/progression/run_state.dart';
import 'package:deckbound/game/models/models.dart';
import '../test_catalog.dart';
import '../progression/descent_test.dart' show won;
import '../persistence/save_test.dart' show FailingStore;

void main() {
  final catalog = loadCatalog(), rules = RunRules(loadCatalog());
  RunController controller(SaveStore run, SaveStore profile) => RunController(
    RunRepository(run, catalog),
    profileRepository: ProfileRepository(profile, catalog),
  );
  test(
    'records count entered floors and cleared bosses, not unvisited floors',
    () {
      final victory = won(rules);
      final p = PlayerProfile().include(victory);
      expect(p.deepestFloor, 6);
      expect(p.bestRooms, 6);
      expect(p.bestBosses, 1);
      expect(p.cards, contains('flaming_strike'));
      expect(p.relics, contains('ironSigil'));
      final next = rules.descend(victory);
      expect(p.include(next).deepestFloor, 6);
      final entered = rules.enter(next, 'room-0-0');
      expect(p.include(entered).deepestFloor, 7);
      expect(p.include(entered).bestRooms, 6);
      expect(p.include(entered).bestBosses, 1);
      final defeated = rules.finishCombat(entered, Outcome.defeat, 0);
      expect(p.include(defeated).bestBosses, 1);
      expect(p.include(victory).toJson(), p.toJson());
      expect(() => p.cards.add('strike'), throwsUnsupportedError);
    },
  );
  test('new journeys keep discoveries and best records after reload', () async {
    final run = MemorySaveStore(), profile = MemorySaveStore();
    await RunRepository(run, catalog).save(won(rules));
    final c = controller(run, profile);
    await c.load();
    final before = c.profile!.toJson();
    expect(await c.start(2), true);
    expect(c.profile!.toJson(), before);
    expect(c.state!.phase, RunPhase.map);
    c.dispose();
    final reloaded = controller(run, profile);
    await reloaded.load();
    expect(reloaded.profile!.toJson(), before);
    expect(reloaded.state!.seed, 2);
    reloaded.dispose();
  });
  test(
    'legacy current journey imports once without modifying its save',
    () async {
      final run = MemorySaveStore(), profile = MemorySaveStore();
      await RunRepository(run, catalog).save(won(rules));
      final original = run.contents;
      final c = controller(run, profile);
      await c.load();
      expect(run.contents, original);
      final journal = profile.contents;
      await c.load();
      expect(profile.contents, journal);
      expect(c.profile!.bestBosses, 1);
      c.dispose();
    },
  );
  test('run write failure never creates journal progress', () async {
    final run = FailingStore(), profile = MemorySaveStore();
    final c = controller(run, profile);
    await c.load();
    await c.start(1);
    final before = profile.contents;
    run.fail = true;
    expect(await c.enter('room-0-0'), false);
    expect(c.profile!.deepestFloor, 0);
    expect(profile.contents, before);
    c.dispose();
  });
  test(
    'profile write failure retains successful run and blocks replacing its pending records',
    () async {
      final run = MemorySaveStore(), profile = FailingStore();
      final c = controller(run, profile);
      await c.load();
      await c.start(514);
      profile.fail = true;
      expect(await c.enter('room-0-0'), true);
      expect(c.state!.phase, RunPhase.combat);
      expect((await c.repository.load())!.phase, RunPhase.combat);
      expect(c.error, isNull);
      expect(c.profileError, isNotNull);
      expect(c.profile!.deepestFloor, 0);
      final saved = run.contents;
      expect(await c.start(2), false);
      expect(run.contents, saved);
      profile.fail = false;
      await c.retryProfile();
      expect(c.profile!.deepestFloor, 1);
      expect(c.profileError, isNull);
      expect(await c.start(2), true);
      expect(c.profile!.deepestFloor, 1);
      c.dispose();
    },
  );
  test(
    'restart reconciles a crash between run and journal writes exactly once',
    () async {
      final run = MemorySaveStore(), profile = MemorySaveStore();
      await ProfileRepository(profile, catalog).save(PlayerProfile());
      await RunRepository(run, catalog).save(won(rules));
      final c = controller(run, profile);
      await c.load();
      expect(c.profile!.bestBosses, 1);
      final reconciled = profile.contents;
      await c.retryProfile();
      expect(profile.contents, reconciled);
      c.dispose();
    },
  );
  test(
    'corrupt or future journals remain intact while the current run can continue',
    () async {
      for (final bad in [
        '{partial',
        '{"version":9,"contentVersion":1}',
        '{"version":1,"contentVersion":9}',
      ]) {
        final run = MemorySaveStore(),
            profile = MemorySaveStore()..contents = bad;
        await RunRepository(run, catalog).save(rules.start(1));
        final c = controller(run, profile);
        await c.load();
        expect(c.loaded, true);
        expect(c.profile, isNull);
        expect(await c.enter('room-0-0'), true);
        expect(await c.start(2), false);
        await c.retryProfile();
        expect(profile.contents, bad);
        c.dispose();
      }
    },
  );
  test(
    'corrupt run does not hide a valid journal or permit replacement',
    () async {
      final run = MemorySaveStore()..contents = 'bad',
          profile = MemorySaveStore();
      await ProfileRepository(
        profile,
        catalog,
      ).save(PlayerProfile().include(won(rules)));
      final c = controller(run, profile);
      await c.load();
      expect(c.loaded, false);
      expect(c.profile!.bestBosses, 1);
      expect(await c.start(2), false);
      expect(run.contents, 'bad');
      c.dispose();
    },
  );
  test(
    'overlapping input during profile write cannot replace the saved journey',
    () async {
      final run = MemorySaveStore(), profile = FailingStore();
      final c = controller(run, profile);
      await c.load();
      await c.start(1);
      profile.gate = Completer<void>();
      final pending = c.enter('room-0-0');
      expect(await c.start(2), false);
      expect(await c.enter('room-0-0'), false);
      profile.gate!.complete();
      expect(await pending, true);
      expect(c.profile!.deepestFloor, 1);
      expect(c.state!.seed, 1);
      c.dispose();
    },
  );
  test(
    'invalid IDs, duplicate discoveries, inconsistent and negative records are rejected',
    () async {
      final valid = PlayerProfile().include(won(rules)).toJson();
      for (final fields in [
        {
          'cards': ['missing'],
        },
        {
          'cards': ['strike', 'strike'],
        },
        {
          'relics': ['missing'],
        },
        {'deepestFloor': -1},
        {'bestRooms': 7},
        {'bestBosses': 2},
        {'bestRooms': '6'},
      ]) {
        final store = MemorySaveStore()
          ..contents = jsonEncode({
            'version': 1,
            'contentVersion': 1,
            'profile': {...valid, ...fields},
          });
        final before = store.contents;
        await expectLater(
          ProfileRepository(store, catalog).load(),
          throwsFormatException,
        );
        expect(store.contents, before);
      }
    },
  );
}
