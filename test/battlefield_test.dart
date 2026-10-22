import 'package:deckbound/app/settings.dart';
import 'package:deckbound/presentation/screens/battle_screen.dart';
import 'package:deckbound/presentation/widgets/battlefield.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'test_catalog.dart';

void main() {
  for (final count in [1, 2]) {
    testWidgets('$count enemies occupy upper right opposite the hero', (
      t,
    ) async {
      t.view.physicalSize = const Size(1280, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Battlefield(
              player: const SizedBox(key: ValueKey('hero'), height: 140),
              enemyHeight: 320,
              enemies: List.generate(
                count,
                (i) => SizedBox(key: ValueKey('enemy$i')),
              ),
            ),
          ),
        ),
      );
      final hero = t.getRect(find.byKey(const ValueKey('hero')));
      final enemy = t.getRect(find.byKey(const ValueKey('enemy0')));
      expect(hero.size, enemy.size);
      expect(hero.right, lessThan(enemy.left));
      expect(hero.bottom, greaterThan(enemy.bottom));
      expect(hero.top, greaterThan(enemy.top));
      if (count == 2) {
        final second = t.getRect(find.byKey(const ValueKey('enemy1')));
        expect(second.left, greaterThan(enemy.right));
        expect(second.top, enemy.top);
      }
      expect(t.takeException(), isNull);
    });
  }

  for (final width in [320.0, 360.0, 600.0, 792.0, 820.0, 1024.0]) {
    for (final scale in [1.0, 1.6]) {
      testWidgets('two enemies fit width $width at text scale $scale', (
        t,
      ) async {
        t.view.physicalSize = Size(width, 844);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final settings = GameSettings()..reducedMotion = true;
        addTearDown(settings.dispose);
        await t.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: BattleScreen(
              catalog: loadCatalog(),
              settings: settings,
              enemyIds: const ['skeleton', 'mage'],
              seed: 5,
            ),
          ),
        );
        await t.pumpAndSettle();
        expect(find.text('End turn').hitTestable(), findsOneWidget);
        expect(find.text('Skeleton Soldier'), findsOneWidget);
        expect(find.text('Cursed Mage'), findsOneWidget);
        expect(t.takeException(), isNull);
      });
    }
  }
}
