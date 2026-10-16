# Deckbound

**Your deck. Your destiny.**

A mobile-first, single-player roguelike deckbuilder set in the Ashen Crypt. Each card is part of your character: a weapon, a ward, a spell, or a tactical opportunity. Build toward a dungeon journey defined by meaningful choices and powerful card combinations.

## Development status

Milestone 1 source implementation: a standalone, seeded combat slice. Start an encounter, select cards, choose enemy targets, spend energy, block attacks, apply statuses, and fight to victory or defeat. Dungeon progression, rewards, fusion, and saved runs are later milestones.

**Validation is pending:** the development environment could not download the Flutter SDK because its artifact host was blocked. The source was syntax-parsed and the content data checked; dependency resolution, Dart formatting, Flutter analysis, tests, and launch have not yet run. See [validation notes](docs/VALIDATION.md).

## Included

- Twenty data-driven cards; twelve unique instances in the starting deck.
- Deterministic shuffling, draw/hand/discard/exhaust piles, retain and temporary-card rules.
- Energy, targeted attacks, defense, healing, and eight status effects.
- Three regular enemies, a boss archetype, and a two-enemy encounter.
- Visible enemy intents, explicit discard choices, and a combat event chronicle.
- Dark fantasy interface, responsive scrolling layouts, reduced motion, and accelerated feedback.
- Card collection, session settings, silent audio abstraction, and replaceable temporary illustrations.
- Domain and widget tests covering combat rules and the playable route.

## Requirements

- Stable Flutter (the environment retrieved framework tag **3.47.7**, whose SDK bootstrap remains unverified).
- Dart 3.8 or newer, below 4.0; use the Dart SDK bundled with Flutter.
- Chrome/Chromium for web development.
- Android SDK and a compatible JDK for Android; macOS and Xcode for iOS.
- No backend, account, or API keys.

## Get started

```sh
flutter pub get
flutter run -d chrome
```

For a headless development machine:

```sh
flutter run -d web-server --web-hostname=0.0.0.0 --web-port=8080
```

Choose an encounter and a seed, then **Enter the crypt**. Tap a card to inspect it. Tap a living enemy for targeted cards, or **Play card** for self-targeted cards. Preparation requires tapping a card to discard before continuing. End turn resolves enemy actions and draws your next hand. The combat log explains individual events.

The battle is deliberately standalone: quitting or reloading loses it. Continue Run is not presented until persistence exists. Audio controls currently affect session preferences only; this build is silent.

## Native platforms

The web host is included. Native host generation could not run in the current environment. On a machine with Flutter installed, generate the official Android/iOS hosts once:

```sh
bash tool/initialize_platforms.sh
flutter pub get
flutter devices
flutter run -d <device-id>
```

The helper creates hosts in a temporary project and copies only `android/` and `ios/`; it refuses to replace existing hosts. It does not overwrite game code or this README. Native builds and device usability remain unverified. Desktop native hosts are deferred; desktop browsers can use the web build.

## Quality checks and builds

```sh
dart format lib test
flutter analyze
flutter test
flutter test --coverage
flutter build web --no-web-resources-cdn
# After generating native hosts:
flutter build apk
# On macOS with signing configured:
flutter build ios
```

`bash tool/validate.sh` runs dependency resolution, formatting, analysis, all tests, and the web build. Commit the generated `pubspec.lock` after the first successful resolution; no lockfile is fabricated in this revision.

## Project organization

```text
lib/
  app/                    App theme and session settings
  assets/                 Logical illustration registry and placeholders
  core/random/            Seeded random source
  core/services/          Audio service boundary
  game/models/            Typed cards, effects, actors, events, rules
  game/cards/             Pile operations
  game/data/              Catalog decoding and starting deck creation
  game/combat/            Synchronous combat engine and snapshots
  presentation/screens/   Menu, battle, results, collection, settings
  presentation/widgets/   Reusable card presentation
assets/data/              Card, enemy, and balance JSON
web/                      Browser host
test/                    Domain and widget tests
tool/                    Native initialization and validation helpers
docs/                    Design, architecture, roadmap, production specs
```

## Roadmap

1. Foundations and playable combat — implemented in source, runtime validation pending.
2. Seeded dungeon paths, rewards, deck upgrades, relics, and versioned local saves.
3. Tactical combos and atomic permanent fusion with preview.
4. Complete Ashen Crypt act, merchants, events, and progression.
5. Production illustrations, audio, animation polish, and device profiling.

Read [game design](docs/GAME_DESIGN.md), [architecture](docs/ARCHITECTURE.md), and the [detailed roadmap](docs/ROADMAP.md).
