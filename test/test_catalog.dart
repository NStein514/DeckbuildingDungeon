import 'dart:io';
import 'dart:convert';
import 'package:deckbound/game/data/game_catalog.dart';

GameCatalog loadCatalog({List<String>? deck}) => GameCatalog.decode(
  File('assets/data/cards.json').readAsStringSync(),
  File('assets/data/enemies.json').readAsStringSync(),
  deck == null
      ? File('assets/data/balance.json').readAsStringSync()
      : jsonEncode({
          ...jsonDecode(File('assets/data/balance.json').readAsStringSync())
              as Map<String, dynamic>,
          'startingDeck': deck,
        }),
);
