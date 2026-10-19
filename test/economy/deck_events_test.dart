import 'package:deckbound/game/dungeon/dungeon.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deckbound/app/app.dart';
import 'package:deckbound/app/run_controller.dart';
import 'package:deckbound/core/persistence/run_repository.dart';
import 'package:deckbound/core/persistence/save_store.dart';
import 'package:deckbound/game/economy/economy.dart';
import 'package:deckbound/game/models/models.dart';
import 'package:deckbound/game/progression/run_rules.dart';
import 'package:deckbound/game/progression/run_state.dart';
import 'package:deckbound/presentation/widgets/game_card.dart';
import '../test_catalog.dart';
import '../persistence/save_test.dart' show FailingStore;
import 'economy_test.dart' show reachEvent;

void main() {
  final catalog = loadCatalog(), rules = RunRules(loadCatalog());
  test('forge upgrades only the selected duplicate and requires survival', () {
    final r = reachEvent(rules, JourneyEvent.emberForge);
    final upgraded = rules.resolveEvent(r, accept: true, cardId: 'starter-1');
    expect(upgraded.health, r.health - 6);
    expect(upgraded.gold, r.gold);
    expect(upgraded.deck[1].upgrade, 1);
    expect(upgraded.deck[0].upgrade, 0);
    expect(r.deck[1].upgrade, 0);
    expect(upgraded.phase, RunPhase.map);
    expect(
      () => rules.resolveEvent(upgraded, accept: true, cardId: 'starter-0'),
      throwsStateError,
    );
    expect(() => rules.resolveEvent(r, accept: true), throwsStateError);
    expect(
      () => rules.resolveEvent(r, accept: true, cardId: 'missing'),
      throwsStateError,
    );
    r.deck[1] = CardInstance('starter-1', r.deck[1].definitionId, upgrade: 1);
    expect(
      () => rules.resolveEvent(r, accept: true, cardId: 'starter-1'),
      throwsStateError,
    );
    r.health = 6;
    expect(
      () => rules.resolveEvent(r, accept: true, cardId: 'starter-0'),
      throwsStateError,
    );
    expect(rules.resolveEvent(r, accept: false).health, 6);
    r.health = 7;
    expect(rules.resolveEvent(r, accept: true, cardId: 'starter-0').health, 1);
  });
  test('well charges once, removes exact instance, and retains five cards', () {
    final r = reachEvent(rules, JourneyEvent.memoryWell)..gold = 25;
    final removed = rules.resolveEvent(r, accept: true, cardId: 'starter-1');
    expect(removed.gold, 0);
    expect(removed.health, r.health);
    expect(removed.deck.any((c) => c.id == 'starter-1'), false);
    expect(removed.deck.any((c) => c.id == 'starter-0'), true);
    r.gold = 24;
    expect(
      () => rules.resolveEvent(r, accept: true, cardId: 'starter-1'),
      throwsStateError,
    );
    r.gold = 25;
    r.deck.removeRange(6, r.deck.length);
    expect(
      rules.resolveEvent(r, accept: true, cardId: 'starter-1').deck,
      hasLength(5),
    );
    r.deck.removeLast();
    expect(
      () => rules.resolveEvent(r, accept: true, cardId: 'starter-1'),
      throwsStateError,
    );
    expect(rules.resolveEvent(r, accept: false).gold, 25);
  });
  test(
    'availability permits full-health removal and rejects exhausted upgrade choices',
    () {
      final r = reachEvent(rules, JourneyEvent.emberForge);
      expect(JourneyEvent.memoryWell.canAccept(50, 25, 50, r.deck), true);
      expect(JourneyEvent.wanderingHealer.canAccept(50, 25, 50, r.deck), false);
      final upgraded = [
        for (final c in r.deck) CardInstance(c.id, c.definitionId, upgrade: 1),
      ];
      expect(JourneyEvent.emberForge.canAccept(50, 0, 50, upgraded), false);
    },
  );
  test('version 5 event checkpoint keeps its original offer', () async {
    final legacy = startVersion(rules, 514, 5);
    final room = legacy.rooms.firstWhere((r) => r.type == RoomType.event);
    final r = enterRoom(
      rules,
      advanceToDepth(rules, legacy, room.depth),
      room.id,
    ).toJson();
    final store = MemorySaveStore()
      ..contents = jsonEncode({'version': 1, 'contentVersion': 5, 'run': r});
    final repo = RunRepository(store, catalog);
    final loaded = (await repo.load())!;
    final event = JourneyEvent.fromSeed(
      loaded.battleSeed,
      mapVersion: loaded.mapVersion,
    );
    expect(event.choosesCard, false);
    loaded.gold = 100;
    final accepted = rules.resolveEvent(loaded, accept: true);
    expect(accepted.gold, 100 + event.gold);
    expect(accepted.deck.length, loaded.deck.length);
    await repo.save(loaded);
    expect(
      JourneyEvent.fromSeed((await repo.load())!.battleSeed, mapVersion: 5),
      event,
    );
  });
  for (final event in [JourneyEvent.emberForge, JourneyEvent.memoryWell]) {
    test(
      '${event.name} failed writes and duplicate commands never charge twice',
      () async {
        final store = FailingStore(),
            repo = RunRepository(FailingStore(), catalog);
        await repo.save(reachEvent(rules, event)..gold = 100);
        store.contents = (repo.store as FailingStore).contents;
        final controller = RunController(RunRepository(store, catalog));
        await controller.load();
        final before = controller.state!.toJson();
        store.fail = true;
        expect(await controller.resolveEvent(true, cardId: 'starter-1'), false);
        expect(controller.state!.toJson(), before);
        store.fail = false;
        store.gate = Completer<void>();
        final pending = controller.resolveEvent(true, cardId: 'starter-1');
        expect(await controller.resolveEvent(true, cardId: 'starter-0'), false);
        store.gate!.complete();
        expect(await pending, true);
        store.gate = null;
        expect(
          (await controller.repository.load())!.toJson(),
          controller.state!.toJson(),
        );
        expect(await controller.resolveEvent(true, cardId: 'starter-1'), false);
        controller.dispose();
      },
    );
    testWidgets(
      '${event.name} previews cost, cancels safely and persists a selected card',
      (t) async {
        t.view.physicalSize = const Size(390, 844);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final store = MemorySaveStore(),
            repo = RunRepository(MemorySaveStore(), catalog);
        final r = reachEvent(rules, event)..gold = 100;
        await repo.save(r);
        store.contents = (repo.store as MemorySaveStore).contents;
        final saved = RunRepository(store, catalog);
        await t.pumpWidget(DeckboundApp(catalog: catalog, saveStore: store));
        await t.pumpAndSettle();
        Future<void> tap(String label) async {
          if (find.text(label).evaluate().isEmpty) {
            await t.scrollUntilVisible(find.text(label), 250);
          }
          await t.ensureVisible(find.text(label).first);
          await t.tap(find.text(label).first);
          await t.pumpAndSettle();
        }

        await tap('Continue run');
        await tap(event.actionLabel);
        await t.tap(find.byType(GameCard).first);
        await t.pumpAndSettle();
        expect(
          find.text(
            event == JourneyEvent.emberForge
                ? 'Upgrade this card for 6 HP?'
                : 'Remove this card for 25 gold?',
          ),
          findsOneWidget,
        );
        await tap('Cancel');
        expect((await saved.load())!.toJson(), r.toJson());
        await t.tap(find.byType(GameCard).first);
        await t.pumpAndSettle();
        await tap(event == JourneyEvent.emberForge ? 'Upgrade' : 'Remove card');
        final result = (await saved.load())!;
        expect(result.phase, RunPhase.map);
        expect(result.health, r.health + event.health);
        expect(result.gold, r.gold + event.gold);
        if (event == JourneyEvent.emberForge) {
          expect(result.deck.where((c) => c.upgrade == 1), hasLength(1));
        } else {
          expect(result.deck, hasLength(11));
        }
        expect(t.takeException(), isNull);
      },
    );
  }
}
