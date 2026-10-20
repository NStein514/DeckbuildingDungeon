import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deckbound/app/app.dart';
import 'package:deckbound/app/run_controller.dart';
import 'package:deckbound/core/persistence/profile_repository.dart';
import 'package:deckbound/core/persistence/run_repository.dart';
import 'package:deckbound/core/persistence/save_store.dart';
import 'package:deckbound/game/profile/player_profile.dart';
import 'package:deckbound/game/progression/run_rules.dart';
import 'package:deckbound/game/progression/starting_build.dart';
import '../test_catalog.dart';
import '../persistence/save_test.dart' show FailingStore;

void main() {
  final catalog = loadCatalog();
  final unlocked = PlayerProfile(
    deepestFloor: 6,
    bestRooms: 6,
    bestBosses: 1,
    cards: ['stormguard'],
  );
  test(
    'unlock conditions use fusion discoveries and guardian records only',
    () {
      expect(StartingBuild.wanderer.unlocked(null), true);
      expect(StartingBuild.stormweaver.unlocked(null), false);
      expect(
        StartingBuild.venomblade.unlocked(PlayerProfile(cards: ['stormguard'])),
        false,
      );
      expect(
        StartingBuild.stormweaver.unlocked(PlayerProfile(cards: ['spark'])),
        false,
      );
      expect(StartingBuild.stormweaver.unlocked(unlocked), true);
      expect(StartingBuild.venomblade.unlocked(unlocked), true);
    },
  );
  test(
    'builds exchange cards, keep resources and leave seeded maps unchanged',
    () {
      final rules = RunRules(catalog);
      final standard = rules.start(514);
      expect(standard.deck.map((c) => c.definitionId), catalog.startingDeck);
      for (final build in StartingBuild.values) {
        final run = rules.start(514, build: build);
        expect(run.deck, hasLength(12));
        expect(run.deck.map((c) => c.id).toSet(), hasLength(12));
        expect(
          run.deck.every(
            (c) => c.upgrade == 0 && catalog.cards.containsKey(c.definitionId),
          ),
          true,
        );
        expect(run.health, standard.health);
        expect(run.gold, standard.gold);
        expect(run.relics, standard.relics);
        expect(run.rngState, standard.rngState);
        expect(
          run.rooms.map((r) => r.toJson()),
          standard.rooms.map((r) => r.toJson()),
        );
      }
      expect(
        StartingBuild.stormweaver
            .deck(catalog)
            .where((c) => c.definitionId == 'spark'),
        hasLength(2),
      );
      expect(
        StartingBuild.venomblade.deck(catalog).map((c) => c.definitionId),
        contains('poison_edge'),
      );
      expect(
        StartingBuild.venomblade.deck(catalog).map((c) => c.definitionId),
        isNot(contains('firebolt')),
      );
    },
  );
  test('locked controller command cannot replace an existing save', () async {
    final store = MemorySaveStore();
    final c = RunController(
      RunRepository(store, catalog),
      profileRepository: ProfileRepository(MemorySaveStore(), catalog),
    );
    await c.load();
    await c.start(514);
    final before = store.contents;
    expect(await c.start(12, build: StartingBuild.stormweaver), false);
    expect(store.contents, before);
    expect(c.state!.seed, 514);
    c.dispose();
  });
  test(
    'failed build replacement retains the old run and retries safely',
    () async {
      final store = FailingStore(), journal = MemorySaveStore();
      final profile = ProfileRepository(journal, catalog);
      await profile.save(unlocked);
      final c = RunController(
        RunRepository(store, catalog),
        profileRepository: profile,
      );
      await c.load();
      await c.start(514);
      final before = store.contents;
      store.fail = true;
      expect(await c.start(12, build: StartingBuild.venomblade), false);
      expect(store.contents, before);
      expect(c.state!.seed, 514);
      store.fail = false;
      expect(await c.start(12, build: StartingBuild.venomblade), true);
      expect(c.state!.deck.map((c) => c.definitionId), contains('poison_edge'));
      c.dispose();
    },
  );
  for (final build in StartingBuild.values) {
    test(
      '${build.name} saves exact deck and survives controller reload',
      () async {
        final store = MemorySaveStore(), journal = MemorySaveStore();
        final profile = ProfileRepository(journal, catalog);
        await profile.save(unlocked);
        final c = RunController(
          RunRepository(store, catalog),
          profileRepository: profile,
        );
        await c.load();
        expect(await c.start(514, build: build), true);
        await c.load();
        expect(
          c.state!.deck.map((c) => c.definitionId),
          build.deck(catalog).map((c) => c.definitionId),
        );
        expect(build.unlocked(c.profile), true);
        c.dispose();
      },
    );
  }
  testWidgets(
    'phone camp shows locks, previews decks and selects an unlocked build',
    (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final store = MemorySaveStore(), journal = MemorySaveStore();
      await ProfileRepository(
        journal,
        catalog,
      ).save(PlayerProfile(cards: ['stormguard']));
      await t.pumpWidget(
        DeckboundApp(catalog: catalog, saveStore: store, profileStore: journal),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Starting build · Wanderer'));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Venomblade'));
      await t.pumpAndSettle();
      await t.tap(find.text('Venomblade'));
      await t.pumpAndSettle();
      expect(find.text('Starting build · Wanderer'), findsOneWidget);
      await t.ensureVisible(find.byTooltip('Inspect Stormweaver deck'));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Inspect Stormweaver deck'));
      await t.pumpAndSettle();
      expect(find.text('Your deck · 12'), findsOneWidget);
      await t.pageBack();
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Stormweaver'));
      await t.pumpAndSettle();
      await t.tap(find.text('Stormweaver'));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('New run'));
      await t.pumpAndSettle();
      await t.tap(find.text('New run'));
      await t.pumpAndSettle();
      expect(
        (await RunRepository(
          store,
          catalog,
        ).load())!.deck.map((c) => c.definitionId),
        StartingBuild.stormweaver.deck(catalog).map((c) => c.definitionId),
      );
      expect(t.takeException(), isNull);
    },
  );
}
