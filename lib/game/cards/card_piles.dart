import '../../core/random/seeded_random.dart';
import '../models/models.dart';

class CardPiles {
  CardPiles(List<CardInstance> deck, this.random) : drawPile = List.of(deck) {
    if (deck.map((c) => c.id).toSet().length != deck.length) {
      throw ArgumentError('Card instance IDs must be unique');
    }
    random.shuffle(drawPile);
  }
  final SeededRandom random;
  final List<CardInstance> drawPile;
  final List<CardInstance> hand = [], discard = [], exhaust = [];

  List<CardInstance> draw(int count, int limit) {
    final drawn = <CardInstance>[];
    for (var i = 0; i < count && hand.length < limit; i++) {
      if (drawPile.isEmpty) {
        drawPile.addAll(discard);
        discard.clear();
        random.shuffle(drawPile);
      }
      if (drawPile.isEmpty) break;
      final card = drawPile.removeLast();
      hand.add(card);
      drawn.add(card);
    }
    return drawn;
  }

  void removeFromHand(CardInstance card, CardDefinition definition) {
    if (!hand.remove(card)) throw StateError('Card not in hand');
    if (definition.keywords.contains(Keyword.temporary)) return;
    (definition.keywords.contains(Keyword.exhaust) ? exhaust : discard).add(
      card,
    );
  }
}
