import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deckbound/app/app.dart';
import 'package:deckbound/core/persistence/profile_repository.dart';
import 'package:deckbound/core/persistence/run_repository.dart';
import 'package:deckbound/core/persistence/save_store.dart';
import 'package:deckbound/game/progression/run_rules.dart';
import 'test_catalog.dart';
import 'progression/descent_test.dart' show won;
import 'persistence/save_test.dart' show FailingStore;

void main() {
  void phone(WidgetTester t) {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
  }

  Future<void> tap(WidgetTester t, String text) async {
    await t.ensureVisible(find.text(text).first);
    await t.pumpAndSettle();
    await t.tap(find.text(text).first);
    await t.pumpAndSettle();
  }

  testWidgets(
    'journal retains fusion and records after new run and app reload',
    (t) async {
      phone(t);
      final catalog = loadCatalog(),
          run = MemorySaveStore(),
          profile = MemorySaveStore();
      await RunRepository(run, catalog).save(won(RunRules(catalog)));
      await t.pumpWidget(
        DeckboundApp(catalog: catalog, saveStore: run, profileStore: profile),
      );
      await t.pumpAndSettle();
      await tap(t, 'New run');
      await tap(t, 'New journey');
      await t.tap(find.byTooltip('Journey journal'));
      await t.pumpAndSettle();
      expect(find.text('Deepest floor entered'), findsOneWidget);
      expect(find.text('Fusion discoveries · 1 / 17'), findsOneWidget);
      await t.scrollUntilVisible(
        find.textContaining('Discovered across your journeys'),
        250,
      );
      expect(
        find.textContaining('Discovered across your journeys'),
        findsOneWidget,
      );
      await t.pumpWidget(
        DeckboundApp(
          key: const ValueKey('reload'),
          catalog: catalog,
          saveStore: run,
          profileStore: profile,
        ),
      );
      await t.pumpAndSettle();
      await tap(t, 'Journey journal');
      expect(find.text('Fusion discoveries · 1 / 17'), findsOneWidget);
      expect((await ProfileRepository(profile, catalog).load()).bestBosses, 1);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'pending journal has retry and disables replacement, then recovers',
    (t) async {
      phone(t);
      final catalog = loadCatalog(),
          run = MemorySaveStore(),
          profile = FailingStore()..fail = true;
      await RunRepository(run, catalog).save(won(RunRules(catalog)));
      await t.pumpWidget(
        DeckboundApp(catalog: catalog, saveStore: run, profileStore: profile),
      );
      await t.pumpAndSettle();
      expect(find.textContaining('journal update is pending'), findsOneWidget);
      expect(
        t
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'New run'))
            .onPressed,
        isNull,
      );
      final before = run.contents;
      profile.fail = false;
      await tap(t, 'Retry journal update');
      expect(run.contents, before);
      expect(
        t
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'New run'))
            .onPressed,
        isNotNull,
      );
      expect(
        (await ProfileRepository(profile, catalog).load()).cards,
        contains('flaming_strike'),
      );
    },
  );
  testWidgets('practice battles never write the journal', (t) async {
    phone(t);
    final profile = MemorySaveStore();
    await t.pumpWidget(
      DeckboundApp(catalog: loadCatalog(), profileStore: profile),
    );
    await t.pumpAndSettle();
    await tap(t, 'Enter the crypt');
    await tap(t, 'End turn');
    expect(profile.contents, isNull);
    expect(t.takeException(), isNull);
  });
}
