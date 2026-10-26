import 'dart:convert';
import '../../game/data/game_catalog.dart';
import '../../game/profile/player_profile.dart';
import '../../game/relics/relic.dart';
import 'save_store.dart';

class ProfileRepository {
  ProfileRepository(this.store, this.catalog);
  final SaveStore store;
  final GameCatalog catalog;
  Future<PlayerProfile> load() async {
    final text = await store.read();
    if (text == null) return PlayerProfile();
    try {
      final j = jsonDecode(text) as Map<String, dynamic>;
      if (j['version'] != 1 ||
          ![1, 2, 3, 4, 5, 6].contains(j['contentVersion'])) {
        throw const FormatException(
          'Unsupported journal version; original preserved.',
        );
      }
      final p = j['profile'] as Map<String, dynamic>;
      final cards = List<String>.from(p['cards'] as List);
      final relics = List<String>.from(p['relics'] as List);
      if (cards.toSet().length != cards.length ||
          relics.toSet().length != relics.length) {
        throw const FormatException('Duplicate journal entries.');
      }
      final profile = PlayerProfile(
        deepestFloor: p['deepestFloor'] as int,
        bestRooms: p['bestRooms'] as int,
        bestBosses: p['bestBosses'] as int,
        cards: cards,
        relics: relics,
      );
      _validate(profile);
      return profile;
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('Invalid journal; original preserved.');
    }
  }

  Future<void> save(PlayerProfile profile) async {
    _validate(profile);
    await store.write(
      jsonEncode({
        'version': 1,
        'contentVersion': 6,
        'profile': profile.toJson(),
      }),
    );
  }

  void _validate(PlayerProfile p) {
    if (p.deepestFloor < 0 ||
        p.bestRooms < 0 ||
        p.bestBosses < 0 ||
        p.bestRooms > p.deepestFloor ||
        p.bestBosses * 6 > p.bestRooms ||
        !p.cards.every(catalog.cards.containsKey) ||
        !p.relics.every((id) => Relic.values.any((r) => r.name == id))) {
      throw const FormatException(
        'Invalid journal records; original preserved.',
      );
    }
  }
}
