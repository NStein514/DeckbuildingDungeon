import 'package:flutter_test/flutter_test.dart';
import 'package:deckbound/core/random/seeded_random.dart';
import 'package:deckbound/game/cards/card_piles.dart';
import 'package:deckbound/game/models/models.dart';

void main() {
  final deck = List.generate(12, (i) => CardInstance('$i', 'strike'));
  test('seeded shuffles are repeatable and preserve every instance', () {
    final a = CardPiles(deck, SeededRandom(514));
    final b = CardPiles(deck, SeededRandom(514));
    expect(a.drawPile.map((c) => c.id), b.drawPile.map((c) => c.id));
    expect(a.drawPile.map((c) => c.id).toSet(), deck.map((c) => c.id).toSet());
  });
  test('draw obeys hand limit without destroying undrawn cards', () {
    final piles = CardPiles(deck, SeededRandom(1));
    expect(piles.draw(20, 10), hasLength(10));
    expect(piles.drawPile, hasLength(2));
    expect(piles.draw(1, 10), isEmpty);
  });
  test('discard reshuffles only when the draw pile runs out', () {
    final piles = CardPiles(deck.take(2).toList(), SeededRandom(1));
    final first = piles.draw(1, 10).single;
    piles.hand.remove(first);
    piles.discard.add(first);
    expect(piles.draw(1, 10).single.id, isNot(first.id));
    expect(piles.discard, hasLength(1));
    expect(piles.draw(1, 10).single.id, first.id);
    expect(piles.discard, isEmpty);
  });
  test('empty piles draw zero cards without looping', () {
    expect(CardPiles([], SeededRandom(0)).draw(5, 10), isEmpty);
  });
  test('duplicate instance IDs are rejected', () {
    expect(() => CardPiles([deck.first, deck.first], SeededRandom(1)), throwsArgumentError);
  });
  test('RNG continuation from saved state matches original', () {
    final rng = SeededRandom(42)..nextInt(100);
    final restored = SeededRandom(rng.state);
    expect(List.generate(20, (_) => rng.nextInt(1000)), List.generate(20, (_) => restored.nextInt(1000)));
  });
}
