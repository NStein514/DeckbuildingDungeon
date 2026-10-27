import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deckbound/app/app.dart';
import 'package:deckbound/app/run_controller.dart';
import 'package:deckbound/core/persistence/run_repository.dart';
import 'package:deckbound/core/persistence/save_store.dart';
import 'package:deckbound/game/dungeon/dungeon.dart';
import 'package:deckbound/game/models/models.dart';
import 'package:deckbound/game/progression/run_rules.dart';
import 'package:deckbound/game/progression/run_state.dart';
import 'package:deckbound/presentation/widgets/game_card.dart';
import '../test_catalog.dart';
import '../persistence/save_test.dart' show FailingStore;

RunState sanctuary(RunRules rules) {
  final r = beforeType(rules, RoomType.rest);
  return enterRoom(
      rules,
      r,
      r.rooms.firstWhere((r) => r.type == RoomType.rest).id,
    )
    ..health = 23
    ..gold = 17;
}

void main() {
  final catalog = loadCatalog(), rules = RunRules(loadCatalog());
  test(
    'sanctuary removes exact upgraded duplicate without healing or spending',
    () {
      final r = sanctuary(rules);
      r.deck[1] = const CardInstance('starter-1', 'strike', upgrade: 1);
      final before = r.toJson();
      final result = rules.rest(r, removeId: 'starter-1');
      expect(
        result.deck.map((c) => c.id),
        r.deck.where((c) => c.id != 'starter-1').map((c) => c.id),
      );
      expect(result.deck.first.id, 'starter-0');
      expect(result.health, 23);
      expect(result.gold, 17);
      expect(result.rngState, r.rngState);
      expect(result.phase, RunPhase.map);
      expect(result.completed.length, r.completed.length + 1);
      expect(r.toJson(), before);
      expect(() => rules.rest(result), throwsStateError);
      expect(
        () => rules.rest(result, upgradeId: 'starter-0'),
        throwsStateError,
      );
      expect(() => rules.rest(result, removeId: 'starter-0'), throwsStateError);
    },
  );
  test(
    'invalid and combined choices cannot consume a visit; removal retains five',
    () {
      final r = sanctuary(rules);
      final before = r.toJson();
      expect(() => rules.rest(r, removeId: 'missing'), throwsStateError);
      expect(
        () => rules.rest(r, upgradeId: 'starter-0', removeId: 'starter-1'),
        throwsStateError,
      );
      expect(r.toJson(), before);
      r.deck.removeRange(6, r.deck.length);
      expect(rules.rest(r, removeId: 'starter-1').deck, hasLength(5));
      r.deck.removeLast();
      expect(() => rules.rest(r, removeId: 'starter-1'), throwsStateError);
      expect(rules.rest(r).health, 38);
      expect(rules.rest(r, upgradeId: 'starter-1').deck[1].upgrade, 1);
    },
  );
  test(
    'removal survives failed save retry, overlapping commands, reload and descent',
    () async {
      final store = FailingStore(),
          repo = RunRepository(FailingStore(), catalog);
      await repo.save(sanctuary(rules));
      store.contents = (repo.store as FailingStore).contents;
      final c = RunController(RunRepository(store, catalog));
      await c.load();
      final before = c.state!.toJson(), bytes = store.contents;
      store.fail = true;
      expect(await c.rest(removeId: 'starter-1'), false);
      expect(c.state!.toJson(), before);
      expect(store.contents, bytes);
      store.fail = false;
      store.gate = Completer<void>();
      final pending = c.rest(removeId: 'starter-1');
      expect(await c.rest(), false);
      store.gate!.complete();
      expect(await pending, true);
      store.gate = null;
      await c.load();
      expect(c.state!.deck.any((c) => c.id == 'starter-1'), false);
      expect(await c.rest(removeId: 'starter-0'), false);
      var r = c.state!;
      while (r.phase != RunPhase.victory) {
        r = completeRoom(rules, enterRoom(rules, r, r.availableRooms.first));
      }
      r = rules.descend(r);
      expect(r.deck.any((c) => c.id == 'starter-1'), false);
      expect(r.deck, hasLength(11));
      c.dispose();
    },
  );
  testWidgets('phone sanctuary previews and cancels before consuming removal', (
    t,
  ) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final store = MemorySaveStore(),
        repo = RunRepository(MemorySaveStore(), catalog);
    final r = sanctuary(rules);
    await repo.save(r);
    store.contents = (repo.store as MemorySaveStore).contents;
    final saved = RunRepository(store, catalog);
    await t.pumpWidget(DeckboundApp(catalog: catalog, saveStore: store));
    await t.pumpAndSettle();
    Future<void> tap(String label) async {
      if (find.text(label).evaluate().isEmpty) {
        await t.scrollUntilVisible(find.text(label), 200);
      }
      await t.ensureVisible(find.text(label).first);
      await t.pumpAndSettle();
      await t.tap(find.text(label).first);
      await t.pumpAndSettle();
    }

    await tap('Continue run');
    await tap('Let go · remove a card');
    expect(find.textContaining('Cost: 40 gold'), findsNothing);
    await t.tap(find.byType(GameCard).first);
    await t.pumpAndSettle();
    expect(
      find.text('Remove this card and end the sanctuary visit?'),
      findsOneWidget,
    );
    await tap('Cancel');
    expect((await saved.load())!.toJson(), r.toJson());
    await t.pageBack();
    await t.pumpAndSettle();
    expect(find.text('A moment by the embers'), findsOneWidget);
    await tap('Let go · remove a card');
    await t.tap(find.byType(GameCard).first);
    await t.pumpAndSettle();
    await tap('Remove card');
    final result = (await saved.load())!;
    expect(result.deck, hasLength(11));
    expect(result.health, r.health);
    expect(result.gold, r.gold);
    expect(result.phase, RunPhase.map);
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'five-card sanctuary disables removal and keeps recovery available',
    (t) async {
      final store = MemorySaveStore(), repo = RunRepository(store, catalog);
      final r = sanctuary(rules)..deck.removeRange(5, 12);
      await repo.save(r);
      await t.pumpWidget(DeckboundApp(catalog: catalog, saveStore: store));
      await t.pumpAndSettle();
      await t.tap(find.text('Continue run'));
      await t.pumpAndSettle();
      await t.scrollUntilVisible(find.text('Let go · remove a card'), 200);
      final button = find.widgetWithText(
        OutlinedButton,
        'Let go · remove a card',
      );
      expect(t.widget<OutlinedButton>(button).onPressed, isNull);
      expect(
        t
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Rest · heal up to 15 HP'),
            )
            .onPressed,
        isNotNull,
      );
    },
  );
}
