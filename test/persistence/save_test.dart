import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:deckbound/app/run_controller.dart';
import 'package:deckbound/app/settings.dart';
import 'package:deckbound/core/persistence/save_store.dart';
import 'package:deckbound/core/persistence/store_native.dart';
import 'package:deckbound/core/persistence/run_repository.dart';
import 'package:deckbound/game/progression/run_rules.dart';
import 'package:deckbound/game/progression/run_state.dart';
import 'package:deckbound/game/models/models.dart';
import '../test_catalog.dart';

class FailingStore extends MemorySaveStore {
  bool fail = false;
  Completer<void>? gate;
  @override
  Future<void> write(String contents) async {
    if (gate != null) await gate!.future;
    if (fail) throw const FileSystemException('Simulated failure');
    await super.write(contents);
  }
}

void main() {
  final catalog = loadCatalog(), rules = RunRules(loadCatalog());
  test(
    'versioned pending reward survives reload with no reroll or repeated gold',
    () async {
      final store = MemorySaveStore(),
          repo = RunRepository(MemorySaveStore(), catalog);
      final reward = rules.finishCombat(
        enterRoom(rules, rules.start(514), 'room-0-0'),
        Outcome.victory,
        40,
      );
      await repo.save(reward);
      final loaded = (await repo.load())!;
      expect(loaded.toJson(), reward.toJson());
      final chosen = rules.reward(loaded, loaded.rewards.first);
      await repo.save(chosen);
      expect((await repo.load())!.deck, hasLength(13));
      expect((await repo.load())!.gold, reward.gold);
      await RunRepository(store, catalog).save(rules.start(514));
      expect(store.contents, contains('"version":1'));
    },
  );
  test('corrupt and future saves are not overwritten', () async {
    final store = MemorySaveStore(),
        repo = RunRepository(MemorySaveStore(), catalog);
    for (final text in ['{partial', '{"version":99}']) {
      store.contents = text;
      await expectLater(
        RunRepository(store, catalog).load(),
        throwsFormatException,
      );
      expect(store.contents, text);
    }
    final duplicate = rules.start(1);
    duplicate.deck[1] = duplicate.deck[0];
    await expectLater(repo.save(duplicate), throwsFormatException);
    final badPath = rules.start(1)..completed.add('room-5-0');
    await expectLater(repo.save(badPath), throwsFormatException);
  });
  test('failed save leaves state unchanged and can be retried', () async {
    final store = FailingStore();
    final controller = RunController(RunRepository(store, catalog));
    await controller.load();
    await controller.start(514);
    final before = store.contents;
    store.fail = true;
    expect(await controller.enter('room-0-0'), isFalse);
    expect(controller.state!.phase, RunPhase.map);
    expect(store.contents, before);
    store.fail = false;
    expect(await controller.enter('room-0-0'), isTrue);
    controller.dispose();
  });
  test('overlapping reward confirmations cannot duplicate cards', () async {
    final store = FailingStore();
    final c = RunController(RunRepository(store, catalog));
    await c.load();
    await c.start(514);
    await c.enter('room-0-0');
    await c.continueRoom();
    await c.finish(Outcome.victory, 40);
    final id = c.state!.rewards.first;
    store.gate = Completer<void>();
    final pending = c.reward(id);
    expect(await c.reward(id), isFalse);
    expect(c.state!.deck, hasLength(12));
    store.gate!.complete();
    expect(await pending, isTrue);
    expect(c.state!.deck, hasLength(13));
    c.dispose();
  });
  test('load error prevents destructive replacement', () async {
    final store = MemorySaveStore()..contents = 'invalid';
    final c = RunController(RunRepository(store, catalog));
    await c.load();
    expect(c.loaded, isFalse);
    expect(await c.start(1), isFalse);
    expect(store.contents, 'invalid');
    c.dispose();
  });
  test(
    'abandoned temporary native write does not replace valid save',
    () async {
      final dir = await Directory.systemTemp.createTemp('deckbound-test-');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/run.json');
      final repo = RunRepository(FileSaveStore(file), catalog);
      final run = rules.start(514);
      await repo.save(run);
      await File('${file.path}.tmp').writeAsString('{partial');
      expect((await repo.load())!.toJson(), run.toJson());
      await repo.save(enterRoom(rules, run, 'room-0-0'));
      expect((await repo.load())!.phase, RunPhase.combat);
      expect(await File('${file.path}.tmp').exists(), isFalse);
    },
  );
  test('settings writes serialize and persist latest slider value', () async {
    final store = MemorySaveStore();
    final settings = GameSettings(store: store);
    await settings.load();
    settings.update(reduced: true, fast: true, music: .2, effects: .3);
    settings.update(music: .8);
    await settings.settled;
    final restored = GameSettings(store: store);
    await restored.load();
    expect(restored.reducedMotion, isTrue);
    expect(restored.musicVolume, .8);
    expect(restored.effectsVolume, .3);
    expect(restored.duration, Duration.zero);
    settings.dispose();
    restored.dispose();
  });
  test('future settings are preserved', () async {
    final store = MemorySaveStore()..contents = '{"version":9}';
    final s = GameSettings(store: store);
    await s.load();
    s.update(reduced: true);
    await s.settled;
    expect(store.contents, '{"version":9}');
    expect(s.persistenceError, isNotNull);
    s.dispose();
  });
}
