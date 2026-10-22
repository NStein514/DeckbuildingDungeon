import 'package:deckbound/assets/asset_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deckbound/app/app.dart';
import 'package:deckbound/core/persistence/run_repository.dart';
import 'package:deckbound/core/persistence/save_store.dart';
import 'package:deckbound/game/progression/run_rules.dart';
import 'package:deckbound/game/progression/run_state.dart';
import 'test_catalog.dart';
import 'fusion/fusion_test.dart' show shrine;
import 'progression/descent_test.dart' show won;
import 'persistence/save_test.dart' show FailingStore;

void main() {
  void phone(WidgetTester t) {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
  }

  Future<void> tap(WidgetTester t, String label) async {
    final target = label == 'Dungeon Rat'
        ? find.text(label).first
        : find.text(label).last;
    if (find.text(label).evaluate().isEmpty) {
      await t.scrollUntilVisible(find.text(label), 250);
    }
    await t.ensureVisible(target);
    await t.pumpAndSettle();
    await t.tap(target);
    await t.pumpAndSettle();
  }

  testWidgets(
    'shrine previews, cancels, retries failed save, and reloads discovery',
    (t) async {
      phone(t);
      final catalog = loadCatalog(), store = FailingStore();
      final repo = RunRepository(store, catalog);
      await repo.save(shrine(RunRules(catalog)));
      await t.pumpWidget(DeckboundApp(catalog: catalog, saveStore: store));
      await t.pumpAndSettle();
      await tap(t, 'Continue run');
      await t.scrollUntilVisible(
        find.byType(DropdownButtonFormField<String>).first.hitTestable(),
        250,
      );
      await t.pumpAndSettle();
      await t.tap(find.byType(DropdownButtonFormField<String>).first);
      await t.pumpAndSettle();
      await tap(t, 'Strike · copy 1');
      await t.scrollUntilVisible(
        find.byType(DropdownButtonFormField<String>).last.hitTestable(),
        250,
      );
      await t.pumpAndSettle();
      await t.tap(find.byType(DropdownButtonFormField<String>).last);
      await t.pumpAndSettle();
      await tap(t, 'Firebolt');
      expect(find.text('Flaming Strike'), findsWidgets);
      await tap(t, 'Fuse cards');
      await tap(t, 'Cancel');
      expect((await repo.load())!.deck, hasLength(12));
      store.fail = true;
      await tap(t, 'Fuse cards');
      await tap(t, 'Confirm fusion');
      await t.scrollUntilVisible(
        find.textContaining('Progress was not saved.'),
        -250,
      );
      expect(find.textContaining('Progress was not saved.'), findsOneWidget);
      expect((await repo.load())!.deck, hasLength(12));
      store.fail = false;
      await tap(t, 'Fuse cards');
      await tap(t, 'Confirm fusion');
      expect(find.text('Choose your path'), findsOneWidget);
      expect((await repo.load())!.deck, hasLength(11));
      expect((await repo.load())!.phase, RunPhase.map);
      await t.pumpWidget(
        DeckboundApp(
          key: const ValueKey('reload'),
          catalog: catalog,
          saveStore: store,
        ),
      );
      await t.pumpAndSettle();
      await tap(t, 'Continue run');
      await t.tap(find.byTooltip('Combos and fusions'));
      await t.pumpAndSettle();
      await t.scrollUntilVisible(find.text('Discovered this journey'), 250);
      expect(find.text('Discovered this journey'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'boss victory offers deeper floors and reload resumes scaled battle',
    (t) async {
      phone(t);
      final catalog = loadCatalog(), store = MemorySaveStore();
      final repo = RunRepository(store, catalog);
      await repo.save(won(RunRules(catalog)));
      await t.pumpWidget(DeckboundApp(catalog: catalog, saveStore: store));
      await t.pumpAndSettle();
      await tap(t, 'Continue run');
      await tap(t, 'Descend deeper');
      expect(find.text('FLOOR 7'), findsOneWidget);
      expect((await repo.load())!.descent, 2);
      // Image decoding uses real asynchronous work, outside the fake test clock.
      await t.runAsync(() async {
        final context = t.element(find.byType(Scaffold).first);
        for (final entry in AssetRegistry.illustrations.entries) {
          if (entry.key.startsWith('enemies/')) {
            await precacheImage(
              ResizeImage(AssetImage(entry.value), width: 768),
              context,
            );
          }
        }
      });
      await tap(t, 'Unexplored path 1 · floor 7');
      await tap(t, 'Enter encounter');
      expect(find.text('27 / 27 HP  ·  0 block'), findsOneWidget);
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
      expect(find.text('27 / 27 HP  ·  0 block'), findsOneWidget);
      expect(find.text('Gnaw  ·  6 damage'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
}
