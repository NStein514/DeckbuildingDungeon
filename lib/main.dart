import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app/app.dart';
import 'game/data/game_catalog.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final data = await Future.wait(['cards', 'enemies', 'balance'].map((name) => rootBundle.loadString('assets/data/$name.json')));
    runApp(DeckboundApp(catalog: GameCatalog.decode(data[0], data[1], data[2])));
  } catch (error, stack) {
    debugPrint('Unable to load game data: $error\n$stack');
    runApp(const MaterialApp(home: Scaffold(body: Center(child: Padding(padding: EdgeInsets.all(24),
      child: Text('The crypt could not be loaded. Restart the game or check the asset installation.'))))));
  }
}
