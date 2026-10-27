import 'package:deckbound/assets/asset_registry.dart';
import 'package:deckbound/presentation/widgets/room_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deckbound/app/run_controller.dart';
import 'package:deckbound/app/settings.dart';
import 'package:deckbound/core/persistence/run_repository.dart';
import 'package:deckbound/core/persistence/save_store.dart';
import 'package:deckbound/game/dungeon/dungeon.dart';
import 'package:deckbound/game/progression/run_rules.dart';
import 'package:deckbound/game/progression/run_state.dart';
import 'package:deckbound/presentation/screens/run_screen.dart';
import 'package:deckbound/presentation/widgets/path_reveal.dart';
import 'test_catalog.dart';

class PreviewController extends RunController {
  PreviewController(this.preview)
    : super(RunRepository(MemorySaveStore(), loadCatalog()));
  final RunState preview;
  @override
  RunState get state => preview;
}

void main() {
  for (final width in [390.0, 1280.0]) {
    testWidgets('every revealed room keeps card proportions at width $width', (
      t,
    ) async {
      t.view.physicalSize = Size(width, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final catalog = loadCatalog();
      Size? firstSize;
      for (final type in RoomType.values) {
        final run = RunRules(catalog).start(514);
        final original = run.rooms.first;
        run.rooms[0] = DungeonRoom(
          original.id,
          0,
          0,
          type,
          original.next,
          type == RoomType.combat
              ? ['rat', 'skeleton']
              : type == RoomType.boss
              ? ['warden', 'sentinel']
              : [],
        );
        run.currentRoom = original.id;
        run.phase = RunPhase.reveal;
        final controller = PreviewController(run);
        final settings = GameSettings()..reducedMotion = true;
        await t.pumpWidget(
          MaterialApp(
            home: RunScreen(
              key: ValueKey(type),
              runs: controller,
              catalog: catalog,
              settings: settings,
            ),
          ),
        );
        await t.pumpAndSettle();
        final size = t.getSize(find.byType(PathReveal));
        expect(size.width / size.height, closeTo(150 / 217, .001));
        firstSize ??= size;
        expect(
          size,
          firstSize,
          reason: '${type.name} must not resize the card',
        );
        if (type == RoomType.treasure || type == RoomType.merchant) {
          final face = find.byType(PathReveal);
          final card = find.descendant(
            of: face,
            matching: find.byType(RoomCard),
          );
          final art = find.descendant(
            of: card,
            matching: find.byType(GameIllustration),
          );
          expect(card, findsOneWidget);
          expect(art, findsOneWidget);
          expect(t.getCenter(art).dx, closeTo(t.getCenter(face).dx, 1));
          final artRect = t.getRect(art), faceRect = t.getRect(face);
          expect(artRect.width / artRect.height, closeTo(1.5, .001));
          expect(faceRect.contains(artRect.topLeft), isTrue);
          expect(faceRect.contains(artRect.bottomRight), isTrue);
          expect(
            find.descendant(of: card, matching: find.byType(Icon)),
            findsNothing,
          );
        }
        if (type == RoomType.combat || type == RoomType.boss) {
          final secretName = type == RoomType.boss
              ? 'Ember Sentinel'
              : 'Skeleton Soldier';
          expect(find.textContaining(secretName), findsNothing);
          final next = find.text('Reveal next opponent');
          await t.ensureVisible(next);
          await t.tap(next);
          await t.pumpAndSettle();
          expect(find.textContaining(secretName), findsWidgets);
          expect(find.byType(PathReveal), findsNWidgets(2));
          final cards = find.byType(PathReveal);
          expect(t.getSize(cards.first), size);
          expect(t.getSize(cards.last), size);
          expect(t.getTopLeft(cards.last).dx, greaterThanOrEqualTo(0));
          expect(t.getTopRight(cards.last).dx, lessThanOrEqualTo(width));
          expect(t.getTopLeft(cards.first).dy, t.getTopLeft(cards.last).dy);
          expect(
            t.getTopLeft(cards.last).dx,
            greaterThan(t.getTopRight(cards.first).dx),
          );
        }
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
        controller.dispose();
        settings.dispose();
      }
    });
  }
}
