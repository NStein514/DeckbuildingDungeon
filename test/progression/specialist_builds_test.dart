import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deckbound/app/app.dart';
import 'package:deckbound/app/run_controller.dart';
import 'package:deckbound/core/persistence/profile_repository.dart';
import 'package:deckbound/core/persistence/run_repository.dart';
import 'package:deckbound/core/persistence/save_store.dart';
import 'package:deckbound/game/models/models.dart';
import 'package:deckbound/game/combat/combat_engine.dart';
import 'package:deckbound/game/profile/player_profile.dart';
import 'package:deckbound/game/progression/run_rules.dart';
import 'package:deckbound/game/progression/starting_build.dart';
import '../test_catalog.dart';
import '../fusion/fusion_test.dart' show shrine;
import '../persistence/save_test.dart' show FailingStore;

void main() {
  final catalog = loadCatalog(), rules = RunRules(loadCatalog());
  test('specialist unlocks require a related fusion discovery', () {
    for (final id in [
      'glacial_barrier',
      'stormguard',
      'venom_ward',
      'bloomguard',
    ]) {
      final p = PlayerProfile(cards: [id]);
      expect(StartingBuild.gravewarden.unlocked(p), true);
      expect(StartingBuild.embercaller.unlocked(p), false);
    }
    for (final id in ['flaming_strike', 'cinder_maul']) {
      final p = PlayerProfile(cards: [id]);
      expect(StartingBuild.embercaller.unlocked(p), true);
      expect(StartingBuild.gravewarden.unlocked(p), false);
    }
    for (final build in [
      StartingBuild.gravewarden,
      StartingBuild.embercaller,
    ]) {
      expect(build.unlocked(null), false);
      expect(
        build.unlocked(
          PlayerProfile(
            bestBosses: 10,
            cards: [
              'brace',
              'enfeeble',
              'firebolt',
              'cinder_storm',
              'venom_flurry',
            ],
          ),
        ),
        false,
      );
    }
  });
  test(
    'new starter trades are exact and grant no fusion cards or upgrades',
    () {
      final grave = StartingBuild.gravewarden
          .deck(catalog)
          .map((c) => c.definitionId)
          .toList();
      final ember = StartingBuild.embercaller
          .deck(catalog)
          .map((c) => c.definitionId)
          .toList();
      expect(
        grave,
        [...catalog.startingDeck]
          ..[5] = 'brace'
          ..[8] = 'enfeeble',
      );
      expect(
        ember,
        [...catalog.startingDeck]
          ..[6] = 'cinder_storm'
          ..[9] = 'firebolt',
      );
      expect(ember.where((id) => id == 'firebolt'), hasLength(2));
      for (final build in [
        StartingBuild.gravewarden,
        StartingBuild.embercaller,
      ]) {
        expect(
          build
              .deck(catalog)
              .any(
                (c) =>
                    catalog.cards[c.definitionId]!.tags.contains('fusion') ||
                    c.upgrade != 0,
              ),
          false,
        );
      }
    },
  );
  test(
    'both specialist starters can finish the opening fight with real commands',
    () {
      for (final build in [
        StartingBuild.gravewarden,
        StartingBuild.embercaller,
      ]) {
        for (var seed = 0; seed < 40; seed++) {
          final run = enterRoom(
            rules,
            rules.start(seed, build: build),
            'room-0-0',
          );
          final e = CombatEngine(
            cards: catalog.cards,
            deck: run.deck,
            enemies: [catalog.enemies['rat']!],
            seed: run.battleSeed,
            relics: run.relics.toSet(),
          );
          for (
            var turn = 0;
            turn < 20 && e.state.outcome == Outcome.active;
            turn++
          ) {
            for (final card in List<CardInstance>.of(e.state.hand)) {
              if (e.state.outcome != Outcome.active) break;
              if (card.definitionId == 'preparation') continue;
              if (catalog.cards[card.definitionId]!.cost <= e.state.energy) {
                expect(e.play(card.id, targetId: 'enemy-0'), isNull);
              }
            }
            if (e.state.outcome == Outcome.active) e.endTurn();
          }
          expect(
            e.state.outcome,
            Outcome.victory,
            reason: '${build.name} seed $seed',
          );
        }
      }
    },
  );
  for (final build in [StartingBuild.gravewarden, StartingBuild.embercaller]) {
    final defensive = build == StartingBuild.gravewarden;
    test(
      '${build.name} unlocks through actual fusion, survives replacement and failed saves',
      () async {
        final store = FailingStore(), journal = MemorySaveStore();
        final repo = RunRepository(store, catalog);
        await repo.save(shrine(rules));
        final c = RunController(
          repo,
          profileRepository: ProfileRepository(journal, catalog),
        );
        await c.load();
        final before = store.contents;
        expect(await c.start(22, build: build), false);
        expect(store.contents, before);
        expect(
          await c.fuse(
            defensive ? 'starter-3' : 'starter-0',
            defensive ? 'starter-7' : 'starter-8',
          ),
          true,
        );
        expect(build.unlocked(c.profile), true);
        final fused = store.contents;
        store.fail = true;
        expect(await c.start(22, build: build), false);
        expect(store.contents, fused);
        store.fail = false;
        expect(await c.start(22, build: build), true);
        await c.load();
        expect(
          c.state!.deck.map((c) => c.definitionId),
          build.deck(catalog).map((c) => c.definitionId),
        );
        expect(build.unlocked(c.profile), true);
        expect(c.state!.mapVersion, 10);
        expect(c.state!.relics, rules.start(22).relics);
        c.dispose();
      },
    );
    testWidgets(
      '${build.name} locked preview is inspectable; unlocked selection starts exact deck',
      (t) async {
        t.view.physicalSize = const Size(390, 844);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final store = MemorySaveStore(), journal = MemorySaveStore();
        Future<void> showCamp() async {
          await t.pumpWidget(const SizedBox());
          await t.pumpWidget(
            DeckboundApp(
              catalog: catalog,
              saveStore: store,
              profileStore: journal,
            ),
          );
          await t.pumpAndSettle();
          await t.tap(find.text('Starting build · Wanderer'));
          await t.pumpAndSettle();
        }

        Future<void> tap(Finder f) async {
          await t.ensureVisible(f);
          await t.pumpAndSettle();
          await t.tap(f);
          await t.pumpAndSettle();
        }

        await showCamp();
        final tile = find.widgetWithText(ListTile, build.title);
        expect(t.widget<ListTile>(tile).onTap, isNull);
        await tap(find.byTooltip('Inspect ${build.title} deck'));
        expect(find.text('Your deck · 12'), findsOneWidget);
        await t.pageBack();
        await t.pumpAndSettle();
        await ProfileRepository(journal, catalog).save(
          PlayerProfile(cards: [defensive ? 'bloomguard' : 'cinder_maul']),
        );
        await showCamp();
        await tap(find.text(build.title));
        expect(find.text('Starting build · ${build.title}'), findsOneWidget);
        await tap(find.text('New run'));
        expect(
          (await RunRepository(
            store,
            catalog,
          ).load())!.deck.map((c) => c.definitionId),
          build.deck(catalog).map((c) => c.definitionId),
        );
        expect(t.takeException(), isNull);
      },
    );
  }
}
