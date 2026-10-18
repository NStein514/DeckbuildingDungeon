import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deckbound/app/app.dart';
import 'package:deckbound/app/settings.dart';
import 'package:deckbound/core/persistence/save_store.dart';
import 'package:deckbound/core/persistence/run_repository.dart';
import 'package:deckbound/game/progression/run_rules.dart';
import 'package:deckbound/game/dungeon/dungeon.dart';
import 'package:deckbound/game/models/models.dart';
import 'package:deckbound/presentation/screens/battle_screen.dart';
import 'package:deckbound/presentation/widgets/game_card.dart';
import 'test_catalog.dart';

void main() {
  void phone(WidgetTester t) {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
  }

  Future<void> tap(WidgetTester t, String label) async {
    await t.ensureVisible(find.text(label).first);
    await t.tap(find.text(label).first);
    await t.pumpAndSettle();
  }

  testWidgets('new run and reload resume battle entry rather than mid-combat', (
    t,
  ) async {
    phone(t);
    final store = MemorySaveStore(), catalog = loadCatalog();
    await t.pumpWidget(DeckboundApp(catalog: catalog, saveStore: store));
    await t.pumpAndSettle();
    await tap(t, 'New run');
    expect(find.text('Choose your path'), findsOneWidget);
    await tap(t, 'Dungeon Rat');
    expect(find.text('50 / 50 HP  ·  4 block'), findsOneWidget);
    await tap(t, 'End turn');
    expect(find.text('49 / 50 HP  ·  0 block'), findsOneWidget);
    await t.pumpWidget(
      DeckboundApp(
        key: const ValueKey('reload'),
        catalog: catalog,
        saveStore: store,
      ),
    );
    await t.pumpAndSettle();
    await tap(t, 'Continue run');
    await tap(t, 'Resume encounter');
    expect(find.text('TURN 1'), findsOneWidget);
    expect(find.text('50 / 50 HP  ·  4 block'), findsOneWidget);
  });
  testWidgets('reward card confirmation persists once and returns to map', (
    t,
  ) async {
    phone(t);
    final catalog = loadCatalog(), store = MemorySaveStore();
    final rules = RunRules(catalog), repo = RunRepository(store, catalog);
    final r = rules.finishCombat(
      rules.enter(rules.start(514), 'room-0-0'),
      Outcome.victory,
      42,
    );
    await repo.save(r);
    await t.pumpWidget(DeckboundApp(catalog: catalog, saveStore: store));
    await t.pumpAndSettle();
    await tap(t, 'Continue run');
    expect(find.text('Spoils of battle'), findsOneWidget);
    await t.ensureVisible(find.byType(GameCard).first);
    await t.tap(find.byType(GameCard).first);
    await t.pumpAndSettle();
    expect(find.text('Choose your path'), findsOneWidget);
    expect((await repo.load())!.deck, hasLength(13));
    expect((await repo.load())!.gold, r.gold);
  });
  testWidgets('rest upgrade preview permanently changes one instance', (
    t,
  ) async {
    phone(t);
    final catalog = loadCatalog(), store = MemorySaveStore();
    final rules = RunRules(catalog), repo = RunRepository(store, catalog);
    var r = rules.reward(
      rules.finishCombat(
        rules.enter(rules.start(514), 'room-0-0'),
        Outcome.victory,
        42,
      ),
      null,
    );
    r = rules.reward(
      rules.finishCombat(
        rules.enter(r, r.availableRooms.first),
        Outcome.victory,
        30,
      ),
      null,
    );
    r = rules.enter(
      r,
      r.rooms.firstWhere((x) => x.depth == 2 && x.type == RoomType.rest).id,
    );
    await repo.save(r);
    await t.pumpWidget(DeckboundApp(catalog: catalog, saveStore: store));
    await t.pumpAndSettle();
    await tap(t, 'Continue run');
    await tap(t, 'Upgrade a card');
    await t.tap(find.byType(GameCard).first);
    await t.pumpAndSettle();
    expect(find.text('Upgrade preview'), findsOneWidget);
    await tap(t, 'Upgrade');
    expect(find.text('Choose your path'), findsOneWidget);
    expect(
      (await repo.load())!.deck.where((c) => c.upgrade == 1),
      hasLength(1),
    );
    expect((await repo.load())!.health, 30);
  });
  testWidgets(
    'failed battle-result save stays retryable until persistence succeeds',
    (t) async {
      phone(t);
      var attempts = 0;
      final settings = GameSettings();
      addTearDown(settings.dispose);
      await t.pumpWidget(
        MaterialApp(
          home: BattleScreen(
            catalog: loadCatalog(),
            enemyIds: const ['rat'],
            settings: settings,
            seed: 1,
            deck: List.generate(12, (i) => CardInstance('$i', 'strike')),
            onComplete: (result) async {
              expect(result.outcome, Outcome.victory);
              return ++attempts > 1;
            },
          ),
        ),
      );
      await t.pumpAndSettle();
      for (var i = 0; i < 4; i++) {
        if (i == 3) await tap(t, 'End turn');
        await t.ensureVisible(find.byType(GameCard).first);
        await t.tap(find.byType(GameCard).first);
        await t.pumpAndSettle();
        await tap(t, 'Dungeon Rat');
      }
      expect(find.text('Retry save'), findsOneWidget);
      expect(attempts, 1);
      await tap(t, 'Retry save');
      expect(attempts, 2);
      expect(find.text('Continue journey'), findsOneWidget);
    },
  );
}
