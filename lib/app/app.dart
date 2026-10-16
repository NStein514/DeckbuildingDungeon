import 'package:flutter/material.dart';
import '../game/data/game_catalog.dart';
import '../presentation/screens/menu_screen.dart';
import 'settings.dart';

class DeckboundApp extends StatefulWidget {
  const DeckboundApp({super.key, required this.catalog});
  final GameCatalog catalog;
  @override
  State<DeckboundApp> createState() => _DeckboundAppState();
}
class _DeckboundAppState extends State<DeckboundApp> {
  final settings = GameSettings();
  @override
  void dispose() { settings.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Deckbound', debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark, useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xff10151c),
      colorScheme: const ColorScheme.dark(primary: Color(0xffd5b87a), secondary: Color(0xff8ebfc8),
        surface: Color(0xff1b232e), onPrimary: Color(0xff10151c)),
      appBarTheme: const AppBarTheme(backgroundColor: Color(0xff10151c), centerTitle: true),
      filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)))),
      outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)))),
      inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder(), isDense: true),
    ),
    home: MenuScreen(catalog: widget.catalog, settings: settings),
  );
}
