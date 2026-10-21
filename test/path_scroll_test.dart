import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deckbound/app/run_controller.dart';
import 'package:deckbound/app/settings.dart';
import 'package:deckbound/core/persistence/run_repository.dart';
import 'package:deckbound/core/persistence/save_store.dart';
import 'package:deckbound/game/models/models.dart';
import 'package:deckbound/presentation/screens/run_screen.dart';
import 'test_catalog.dart';

void main() {
  for (final reduced in [false, true]) {
    testWidgets('ascending path focuses progress and resume (reduced: $reduced)', (
      t,
    ) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final catalog = loadCatalog();
      final c = RunController(RunRepository(MemorySaveStore(), catalog));
      final settings = GameSettings()..reducedMotion = reduced;
      await c.load();
      expect(await c.start(514), true);
      Future<void> show({Key? key}) async {
        await t.pumpWidget(
          MaterialApp(
            home: RunScreen(
              key: key,
              runs: c,
              catalog: catalog,
              settings: settings,
            ),
          ),
        );
        await t.pumpAndSettle();
      }

      ScrollPosition position() =>
          t.state<ScrollableState>(find.byType(Scrollable).first).position;
      void visible(String label) {
        final rect = t.getRect(find.text(label));
        expect(rect.top, greaterThanOrEqualTo(56));
        expect(rect.bottom, lessThanOrEqualTo(844));
      }

      await show();
      expect(position().pixels, position().maxScrollExtent);
      visible('Unexplored path 1 · floor 1');
      expect(
        t.getTopLeft(find.text('FLOOR 6 · BOSS')).dy,
        lessThan(t.getTopLeft(find.text('FLOOR 1')).dy),
      );
      // Browsing older/future floors must not snap back on an unrelated rebuild.
      position().jumpTo(0);
      await show();
      expect(position().pixels, 0);
      await c.enter('room-0-0');
      await t.pumpAndSettle();
      await c.continueRoom();
      await c.finish(Outcome.victory, 40);
      await c.reward(null);
      await t.pumpAndSettle();
      final next = c.state!.rooms.firstWhere(
        (r) => c.state!.availableRooms.contains(r.id),
      );
      visible('Unexplored path ${next.lane + 1} · floor 2');
      expect(position().pixels, greaterThan(0));
      // A fresh screen loaded from the persisted journey also finds this floor.
      await c.load();
      await show(key: const ValueKey('resumed'));
      visible('Unexplored path ${next.lane + 1} · floor 2');
      // A subsequent descent starts back at its lowest floor.
      var r = c.state!;
      while (r.phase.name != 'victory') {
        r = completeRoom(
          c.rules,
          enterRoom(c.rules, r, r.availableRooms.first),
        );
      }
      await c.repository.save(c.rules.descend(r));
      await c.load();
      await t.pumpAndSettle();
      expect(position().pixels, position().maxScrollExtent);
      visible('Unexplored path 1 · floor 7');
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      c.dispose();
      settings.dispose();
    });
  }
}
