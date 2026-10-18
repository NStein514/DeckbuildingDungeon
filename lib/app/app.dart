import 'package:flutter/material.dart';
import '../game/data/game_catalog.dart';
import '../presentation/screens/menu_screen.dart';
import 'settings.dart';
import 'run_controller.dart';
import '../core/persistence/run_repository.dart';
import '../core/persistence/profile_repository.dart';
import '../core/persistence/save_store.dart';

class DeckboundApp extends StatefulWidget {
  const DeckboundApp({
    super.key,
    required this.catalog,
    this.saveStore,
    this.settingsStore,
    this.profileStore,
  });
  final GameCatalog catalog;
  final SaveStore? saveStore, settingsStore, profileStore;
  @override
  State<DeckboundApp> createState() => _DeckboundAppState();
}

class _DeckboundAppState extends State<DeckboundApp> {
  late final GameSettings settings;
  late final RunController runs;
  @override
  void initState() {
    super.initState();
    settings = GameSettings(store: widget.settingsStore);
    settings.load();
    runs = RunController(
      RunRepository(widget.saveStore ?? MemorySaveStore(), widget.catalog),
      profileRepository: ProfileRepository(
        widget.profileStore ?? MemorySaveStore(),
        widget.catalog,
      ),
    );
    runs.load();
  }

  @override
  void dispose() {
    settings.dispose();
    runs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Deckbound',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xff10151c),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xffd5b87a),
        secondary: Color(0xff8ebfc8),
        surface: Color(0xff1b232e),
        onPrimary: Color(0xff10151c),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xff10151c),
        centerTitle: true,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        isDense: true,
      ),
    ),
    home: MenuScreen(catalog: widget.catalog, settings: settings, runs: runs),
  );
}
