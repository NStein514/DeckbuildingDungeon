import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deckbound/app/app.dart';
import 'package:deckbound/core/persistence/run_repository.dart';
import 'package:deckbound/core/persistence/save_store.dart';
import 'package:deckbound/game/economy/economy.dart';
import 'package:deckbound/game/dungeon/dungeon.dart';
import 'package:deckbound/game/dungeon/difficulty.dart';
import 'package:deckbound/game/progression/run_rules.dart';
import 'package:deckbound/game/progression/run_state.dart';
import 'package:deckbound/presentation/widgets/game_card.dart';
import 'test_catalog.dart';
import 'economy/economy_test.dart' show reachRoom, reachEvent;
import 'persistence/save_test.dart' show FailingStore;

void main() {
  void phone(WidgetTester t) {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
  }

  Future<void> tap(WidgetTester t, String label) async {
    final f = find.text(label).first;
    await t.ensureVisible(f);
    await t.pumpAndSettle();
    await t.tap(f);
    await t.pumpAndSettle();
  }

  testWidgets(
    'merchant buys, persists sold stock, heals and confirms exact card removal',
    (t) async {
      phone(t);
      final catalog = loadCatalog(), store = MemorySaveStore();
      final repo = RunRepository(store, catalog), rules = RunRules(catalog);
      final r = reachRoom(rules, RoomType.merchant)
        ..gold = 300
        ..health = 30;
      await repo.save(r);
      final id = Merchant.stock(catalog, r.battleSeed).first;
      final price = Merchant.price(catalog.cards[id]!);
      await t.pumpWidget(DeckboundApp(catalog: catalog, saveStore: store));
      await t.pumpAndSettle();
      await tap(t, 'Continue run');
      await tap(t, 'Buy · $price gold');
      expect((await repo.load())!.deck, hasLength(13));
      expect((await repo.load())!.gold, 300 - price);
      await t.pumpWidget(
        DeckboundApp(
          key: const ValueKey('reload'),
          catalog: catalog,
          saveStore: store,
        ),
      );
      await t.pumpAndSettle();
      await tap(t, 'Continue run');
      expect(find.text('Sold'), findsOneWidget);
      await tap(t, 'Heal up to 15 HP · 30 gold');
      expect((await repo.load())!.health, 45);
      await tap(t, 'Remove a card · 40 gold');
      await t.tap(find.byType(GameCard).first);
      await t.pumpAndSettle();
      await tap(t, 'Cancel');
      expect((await repo.load())!.deck, hasLength(13));
      await t.tap(find.byType(GameCard).first);
      await t.pumpAndSettle();
      await tap(t, 'Remove card');
      expect((await repo.load())!.deck, hasLength(12));
      expect((await repo.load())!.gold, 300 - price - 70);
      await tap(t, 'Leave merchant');
      expect((await repo.load())!.phase, RunPhase.map);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('failed merchant save permits retry without spending twice', (
    t,
  ) async {
    phone(t);
    final catalog = loadCatalog(), store = FailingStore();
    final repo = RunRepository(store, catalog),
        r = reachRoom(RunRules(catalog), RoomType.merchant)
          ..gold = 100
          ..health = 30;
    await repo.save(r);
    await t.pumpWidget(DeckboundApp(catalog: catalog, saveStore: store));
    await t.pumpAndSettle();
    await tap(t, 'Continue run');
    store.fail = true;
    await tap(t, 'Heal up to 15 HP · 30 gold');
    expect((await repo.load())!.gold, 100);
    store.fail = false;
    await tap(t, 'Heal up to 15 HP · 30 gold');
    expect((await repo.load())!.gold, 70);
    expect((await repo.load())!.health, 45);
    expect(find.text('Healing purchased'), findsOneWidget);
  });
  testWidgets('event shows explicit bargain and saved choice survives reload', (
    t,
  ) async {
    phone(t);
    final catalog = loadCatalog(), store = MemorySaveStore();
    final repo = RunRepository(store, catalog),
        r = reachEvent(RunRules(catalog), JourneyEvent.bloodAltar)..gold = 100;
    final event = JourneyEvent.fromSeed(r.battleSeed, mapVersion: r.mapVersion);
    await repo.save(r);
    await t.pumpWidget(DeckboundApp(catalog: catalog, saveStore: store));
    await t.pumpAndSettle();
    await tap(t, 'Continue run');
    expect(find.text(event.title), findsOneWidget);
    await tap(
      t,
      event == JourneyEvent.bloodAltar
          ? 'Offer 8 HP · gain 35 gold'
          : 'Pay 20 gold · heal up to 12 HP',
    );
    expect((await repo.load())!.health, r.health + event.health);
    expect((await repo.load())!.gold, r.gold + event.gold);
    await t.pumpWidget(
      DeckboundApp(
        key: const ValueKey('reload'),
        catalog: catalog,
        saveStore: store,
      ),
    );
    await t.pumpAndSettle();
    await tap(t, 'Continue run');
    expect(find.text('Choose your path'), findsOneWidget);
    expect((await repo.load())!.completed, contains(r.currentRoom));
  });
  testWidgets(
    'saved modifier appears in battle and changes actual enemy health',
    (t) async {
      phone(t);
      final catalog = loadCatalog(), store = MemorySaveStore();
      final repo = RunRepository(store, catalog), rules = RunRules(catalog);
      var r = reachRoom(rules, RoomType.combat);
      for (var seed = 0; r.room!.modifier != EncounterModifier.hardy; seed++) {
        r = reachRoom(rules, RoomType.combat, seed: seed);
      }
      await repo.save(r);
      final enemy = scaleEnemy(
        catalog.enemies[r.room!.enemies.single]!,
        1,
        modifier: r.room!.modifier,
      );
      await t.pumpWidget(DeckboundApp(catalog: catalog, saveStore: store));
      await t.pumpAndSettle();
      await tap(t, 'Continue run');
      await tap(t, 'Resume encounter');
      expect(
        find.text('${enemy.health} / ${enemy.health} HP  ·  0 block'),
        findsOneWidget,
      );
      expect(
        find.text('Hardy: ${EncounterModifier.hardy.description}'),
        findsOneWidget,
      );
      expect(t.takeException(), isNull);
    },
  );
}
