import 'dart:convert';
import '../models/models.dart';

class GameCatalog {
  GameCatalog._(this.cards, this.enemies, this.rules, this.startingDeck);
  final Map<String, CardDefinition> cards;
  final Map<String, EnemyDefinition> enemies;
  final CombatRules rules;
  final List<String> startingDeck;
  factory GameCatalog.decode(String cards, String enemies, String balance) {
    final c = (jsonDecode(cards) as List).map((j) => CardDefinition.fromJson(j as Map<String, dynamic>));
    final e = (jsonDecode(enemies) as List).map((j) => EnemyDefinition.fromJson(j as Map<String, dynamic>));
    final b = jsonDecode(balance) as Map<String, dynamic>;
    final cardMap = {for (final card in c) card.id: card};
    final deck = List<String>.from(b['startingDeck'] as List);
    if (deck.length != 12 || deck.any((id) => !cardMap.containsKey(id))) {
      throw const FormatException('Invalid starting deck');
    }
    return GameCatalog._(Map.unmodifiable(cardMap), Map.unmodifiable({for (final enemy in e) enemy.id: enemy}),
      CombatRules(maxHealth:b['maxHealth'] as int, energy:b['energy'] as int, draw:b['draw'] as int, handLimit:b['handLimit'] as int),
      List.unmodifiable(deck));
  }
  List<CardInstance> createDeck() => [for (var i = 0; i < startingDeck.length; i++) CardInstance('starter-$i', startingDeck[i])];
}
