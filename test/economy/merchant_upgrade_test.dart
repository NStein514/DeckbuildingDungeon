import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deckbound/app/app.dart';
import 'package:deckbound/app/run_controller.dart';
import 'package:deckbound/core/persistence/run_repository.dart';
import 'package:deckbound/core/persistence/save_store.dart';
import 'package:deckbound/game/dungeon/dungeon.dart';
import 'package:deckbound/game/models/models.dart';
import 'package:deckbound/game/progression/run_rules.dart';
import 'package:deckbound/presentation/widgets/game_card.dart';
import '../test_catalog.dart';
import '../persistence/save_test.dart' show FailingStore;
import 'economy_test.dart' show reachRoom;

void main() {
  final catalog = loadCatalog(), rules = RunRules(loadCatalog());
  shop() => reachRoom(rules, RoomType.merchant)..gold = 100;
  test('merchant upgrades one exact duplicate at a cost, once per visit', () {
    final before = shop();
    final after = rules.merchantUpgrade(before, 'starter-1');
    expect(after.gold, 50);
    expect(before.gold, 100);
    expect(after.deck, hasLength(12));
    expect(after.deck.where((c) => c.upgrade == 1).single.id, 'starter-1');
    expect(after.deck.firstWhere((c) => c.id == 'starter-0').upgrade, 0);
    expect(after.nextCardId, before.nextCardId);
    expect(() => rules.merchantUpgrade(after, 'starter-0'), throwsStateError);
    final left = rules.leaveMerchant(after);
    expect(left.purchases, isEmpty);
    expect(left.deck.firstWhere((c) => c.id == 'starter-1').upgrade, 1);
  });
  test('invalid upgrade choices never spend gold or alter the source run', () {
    final poor = shop()..gold = 49;
    expect(() => rules.merchantUpgrade(poor, 'starter-0'), throwsStateError);
    expect(poor.gold, 49);
    final r = shop();
    r.deck[0] = const CardInstance('starter-0', 'strike', upgrade: 1);
    expect(() => rules.merchantUpgrade(r, 'starter-0'), throwsStateError);
    expect(() => rules.merchantUpgrade(r, 'missing'), throwsStateError);
    expect(
      () => rules.merchantUpgrade(rules.start(1), 'starter-0'),
      throwsStateError,
    );
    expect(r.gold, 100);
  });
  test(
    'content 9 merchant accepts upgrade and retains sold service after reload',
    () async {
      final store = MemorySaveStore()
        ..contents = jsonEncode({
          'version': 1,
          'contentVersion': 9,
          'run': shop().toJson(),
        });
      final c = RunController(RunRepository(store, catalog));
      await c.load();
      expect(await c.merchantUpgrade('starter-0'), true);
      expect(jsonDecode(store.contents!)['contentVersion'], 16);
      await c.load();
      expect(c.state!.gold, 50);
      expect(c.state!.purchases, contains('upgrade'));
      expect(await c.merchantUpgrade('starter-1'), false);
      expect(c.state!.gold, 50);
      c.dispose();
    },
  );
  test('failed writes and overlapping upgrades never charge twice', () async {
    final store = FailingStore(), repo = RunRepository(FailingStore(), catalog);
    await repo.save(shop());
    store.contents = (repo.store as FailingStore).contents;
    final c = RunController(RunRepository(store, catalog));
    await c.load();
    store.fail = true;
    expect(await c.merchantUpgrade('starter-0'), false);
    expect(c.state!.gold, 100);
    expect(c.state!.deck.every((c) => c.upgrade == 0), true);
    store.fail = false;
    store.gate = Completer<void>();
    final first = c.merchantUpgrade('starter-0');
    expect(await c.merchantUpgrade('starter-1'), false);
    store.gate!.complete();
    expect(await first, true);
    expect(c.state!.gold, 50);
    expect(c.state!.deck.where((c) => c.upgrade == 1), hasLength(1));
    c.dispose();
  });
  testWidgets(
    'phone upgrade preview cancels freely and confirms a durable purchase',
    (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final store = MemorySaveStore(),
          repo = RunRepository(MemorySaveStore(), catalog);
      await repo.save(shop());
      store.contents = (repo.store as MemorySaveStore).contents;
      await t.pumpWidget(DeckboundApp(catalog: catalog, saveStore: store));
      await t.pumpAndSettle();
      Future<void> tap(String label) async {
        await t.ensureVisible(find.text(label).first);
        await t.pumpAndSettle();
        await t.tap(find.text(label).first);
        await t.pumpAndSettle();
      }

      await tap('Continue run');
      await tap('Upgrade a card · 50 gold');
      await t.tap(find.byType(GameCard).first);
      await t.pumpAndSettle();
      expect(find.text('Upgrade this card for 50 gold?'), findsOneWidget);
      await tap('Cancel');
      expect((await RunRepository(store, catalog).load())!.gold, 100);
      await t.tap(find.byType(GameCard).first);
      await t.pumpAndSettle();
      await tap('Upgrade');
      final saved = (await RunRepository(store, catalog).load())!;
      expect(saved.gold, 50);
      expect(saved.deck.where((c) => c.upgrade == 1), hasLength(1));
      expect(find.text('Card upgrade purchased'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
}
