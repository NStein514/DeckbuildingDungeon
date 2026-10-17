import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deckbound/app/app.dart';
import 'package:deckbound/presentation/widgets/game_card.dart';
import 'test_catalog.dart';

void main() {
  testWidgets('menu starts a real battle and end turn resolves enemy damage', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(DeckboundApp(catalog: loadCatalog()));
    await tester.ensureVisible(find.text('Enter the crypt'));
    await tester.tap(find.text('Enter the crypt'));
    await tester.pumpAndSettle();
    expect(find.text('TURN 1'), findsOneWidget);
    expect(find.byType(GameCard), findsWidgets);
    await tester.ensureVisible(find.text('End turn'));
    await tester.tap(find.text('End turn'));
    await tester.pumpAndSettle();
    expect(find.text('TURN 2'), findsOneWidget);
    expect(find.text('45 / 50 HP  ·  0 block'), findsOneWidget);
  });
  testWidgets('collection displays actual card definitions', (tester) async {
    await tester.pumpWidget(DeckboundApp(catalog: loadCatalog()));
    await tester.ensureVisible(find.text('Collection'));
    await tester.tap(find.text('Collection'));
    await tester.pumpAndSettle();
    expect(find.text('The card archive'), findsOneWidget);
    expect(find.text('Strike'), findsOneWidget);
    expect(find.text('Deal 6 damage.'), findsOneWidget);
  });
  testWidgets(
    'selecting an attack and enemy spends energy and deals real damage',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        DeckboundApp(catalog: loadCatalog(deck: List.filled(12, 'strike'))),
      );
      await tester.ensureVisible(find.text('Enter the crypt'));
      await tester.tap(find.text('Enter the crypt'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(GameCard).first);
      await tester.tap(find.byType(GameCard).first);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Dungeon Rat'));
      await tester.tap(find.text('Dungeon Rat'));
      await tester.pumpAndSettle();
      expect(find.text('16 / 22 HP  ·  0 block'), findsOneWidget);
      expect(find.text('YOUR HAND · 4'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    },
  );
}
