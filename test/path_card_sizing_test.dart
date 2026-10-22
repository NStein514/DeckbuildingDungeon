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
              ? ['warden']
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
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
        controller.dispose();
        settings.dispose();
      }
    });
  }
}
