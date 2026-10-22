# Deckbound

**Your deck. Your destiny.**

A mobile-first, offline single-player roguelike deckbuilder set in the Ashen Crypt. Your cards are your attacks, wards, spells, and tactical choices.

## Current build: masked heroes and animated path reveals

- Five masked hero portraits follow the selected starting deck; saved identity survives deck changes and deeper descents.
- Chosen paths flip in place, then expand into a framed reveal; all delivered card paintings share a complete 3:2 canvas.
- Repeatable six-floor seeded descents with combat, rest, treasure, fusion shrines, merchants, optional events, and bosses.
- Twenty-seven cards and a twelve-card starting deck; real targeting, energy, statuses, enemy intents, and multiple enemies.
- Three-card battle rewards, gold, persistent deck growth, and one-time card upgrades with previews.
- Three consecutive-play combos and seven permanent fusion recipes with previews and saved discoveries.
- After each boss, descend again with your build intact and stronger enemies; floor numbers keep advancing.
- Seeded encounter variations with revealed Hardy, Fierce, Rallying and Mending modifiers and bonus gold.
- Merchants sell cards, healing, upgrades, and permanent card removal; optional events trade health against gold.
- Five passive relics; every run starts with Iron Sigil.
- New Run, Continue Run, deck inspection with type filtering and cost/rarity sorting, and victory/defeat results.
- A persistent journey journal tracks discovered cards, fusion recipes, relics, and personal bests across new runs.
- Versioned local run saves and persistent settings. An interrupted battle restarts from its entry checkpoint with the same health, deck, and seed.
- Labeled temporary illustrations, silent audio, and reduced-motion preferences.

Biome variety, deeper build progression, additional starting builds, final art, and production audio remain future work. See [roadmap](docs/ROADMAP.md).

## Requirements and launch

Developed and tested with Flutter **3.47.7** / Dart **3.13.5**. Dependencies are locked in `pubspec.lock`. No accounts, backend, credentials, or paid services are needed.

```sh
flutter pub get --enforce-lockfile
flutter run -d chrome
```

For a headless machine:

```sh
flutter run -d web-server --web-hostname=0.0.0.0 --web-port=8080
```

Choose **New run**, then a highlighted room. In combat, tap a card and an enemy, or use **Play card** for self-targeted cards. Preparation requires choosing a discard. After victory, continue to your reward and select one card or skip. Rest sites offer healing, an upgrade, or card removal. The deck icon opens your full deck; long-press a relic for its effect.

Leave the seed blank for a fresh run, or enter a seed to replay the same decisions. After the boss, **Descend deeper** keeps your current health and build; returning to camp preserves the option to continue later. Each descent adds 20% of base enemy HP and 10% of base damage/block, rounded up. This is a repeatable-loop foundation, not yet a balanced endless content pool.

New maps shuffle two combat floors and two opportunity floors between the opening encounter and final boss. Opportunity cards include rest, treasure, events, a merchant and a shrine. Merchant stock is fixed for that visit; each card and service is sold once.

The practice encounter controls launch isolated battles that do not change your saved run. Starting another run requires confirming replacement of the existing save.

## Saving

New journeys present face-down dungeon cards. Flip one to commit your path and reveal its room, then continue into the encounter or opportunity. Hidden room positions shuffle each descent; unchosen cards stay unknown. Reveals persist across reloads, and reduced-motion settings skip the flip animation. Existing journeys keep their original map version and layout until the next descent.

Progress saves on card reveal, room entry, battle results, reward confirmation, rest, treasure, fusion, merchant purchases, event choices, and descent. Reloading during combat restarts the encounter, rather than restoring a partially played turn. Results remain retryable if a save fails. An invalid or newer-version run save is preserved and reported instead of silently replaced.

Native saves use a flushed temporary file and same-directory rename in the application support directory. Browser saves use a single local-storage replacement per document. Settings, active run, and the journey journal use separate documents. Use one active game tab; browsers can clear local storage, and private-browsing storage may be temporary. A stable browser origin/port is necessary to resume the same save.

The **Journey journal** button at camp and trophy icon on the map show your deepest floor entered, most rooms cleared and most bosses defeated in one journey, plus discoveries across journeys. These records survive replacing the active run; practice battles do not count. Existing saves contribute their current journey when first loaded. Earlier overwritten journeys cannot be reconstructed.

A pending journal write shows a retry button. Your run remains playable, but starting a replacement run waits until its records are saved. Invalid journal data is preserved. Records are local to this installation/browser origin, without account sync or stat bonuses.

## Platforms

Web builds and automated tests run in the development environment. Android and iOS host projects are included, generated by Flutter. Native device builds remain unverified: Android requires its SDK/JDK and iOS requires macOS/Xcode and signing. Desktop native hosts are deferred; desktop browsers are supported by the web layout.

```sh
flutter devices
flutter run -d <device-id>
flutter build apk
# On macOS:
flutter build ios
```

## Quality checks

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
python3 tool/check_content.py
flutter build web --no-web-resources-cdn
```

`bash tool/validate.sh` resolves locked dependencies, checks formatting, analyzes, tests, and builds. See [validation evidence and limits](docs/VALIDATION.md).

## Organization

```text
lib/app/                  Application, settings, transactional run controller
lib/core/persistence/     Versioned repository and native/browser stores
lib/core/random/          Seeded random source
lib/core/services/        Audio interface
lib/game/cards/           Piles and resolved upgrades
lib/game/combat/          Pure Dart combat engine and event snapshots
lib/game/dungeon/         Seeded connected rooms
lib/game/progression/     Run checkpoint models and rules
lib/game/relics/           Passive relic definitions
lib/game/data/, models/   Data decoding and typed models
lib/presentation/         Menus, map, rewards, deck, combat, results
lib/assets/               Replaceable illustration registry
assets/data/              Card, enemy, and balance JSON
android/, ios/, web/      Platform hosts
test/                    Domain, persistence, and widget tests
docs/                    Design, architecture, roadmap, art specifications
```

Read [game design](docs/GAME_DESIGN.md), [architecture](docs/ARCHITECTURE.md), and [roadmap](docs/ROADMAP.md). Next: broader build choices, elite/boss variety, and long-run balance. See [replayability direction](docs/REPLAYABILITY.md).

New journeys and descents can end with the Dungeon Warden, Crypt Broodmother or Ember Sentinel. Reveal the boss card to inspect its repeating battle plan before entry. The two new guardians feature generated illustrations. Existing saved maps retain their original guardian.

New-map events now include the Ember Forge (trade 6 HP for a chosen upgrade) and Memory Well (pay 25 gold to remove a chosen card). Both offer previews and a free safe exit. Generated artwork illustrates these events and the Strike card.

Unplayed cards now stay in hand between turns (up to ten cards); played cards still cycle through discard or exhaust. Each encounter draws a fresh hand from your persistent journey deck. New maps shuffle the interior floor order as well as card positions, and dungeon cards have a small stable tilt. Opening encounters and final bosses remain at the ends; use a new run or the next descent to see the new layouts.

Fusion shrines now offer seven recipes, including **Guard + Spark → Stormguard** and **Heavy Blow + Firebolt → Cinder Maul**. Tap an available recipe to preview it; unupgraded copies are selected first and confirmation is required. Both new results have generated card artwork and persistent journal discovery.

Camp now offers journal-unlocked starting builds: Stormweaver after any fusion discovery, and Venomblade after a guardian victory. Expand Starting build to inspect all five decks and select an unlocked option. All start with 12 unupgraded cards, the same resources and Iron Sigil; Continue run keeps its saved deck.

Combat now has brief generated-art effects for attacks, shields, elemental magic, healing and support plays. Each effect plays eight distinct Image Generator painted poses, matched to the card artwork, with smooth transitions between them. Effects last 0.48 seconds (0.24 seconds in fast mode), allow immediate input, and switch to static labels with reduced motion.

New dungeon maps can encounter the Ash Duelist alone or in an ambush. Survive its heavy lunge, then exploit its brief Vulnerable opening. Every revealed enemy now offers an expandable battle plan. Existing layouts stay intact until the next descent; the Duelist is also available in practice.

Merchants now offer one card upgrade per visit for 50 gold. Preview the upgraded card before confirming; cancellation is free, and purchased upgrades persist through encounters and descents.

Last Ember is a new treasure relic: enter combat at half health or less for +1 energy on the opening turn. Earlier saved maps retain their original treasure pool.

New dungeons also feature **Rallying** enemies that gain Strength after acting and **Mending** enemies that heal after acting. Check the revealed battle plan and current intent; defeating either earns the usual 10 extra gold for a risky encounter. Existing saved maps remain unchanged until the next descent.

Two defensive shrine fusions are available: **Guard + Poison Edge → Venom Ward** (7 block, 3 Poison), and **Guard + Mend → Bloomguard** (7 block, heal 4, Exhaust). Both cost 1 energy and include new painted artwork, upgrades and journal discovery.

New starting choices: **Gravewarden** trades Quick Slash and Firebolt for Brace and Enfeeble after discovering any defensive fusion (Glacial Barrier, Stormguard, Venom Ward or Bloomguard). **Embercaller** trades Heavy Blow and Frost Ward for Cinder Storm and a second Firebolt after discovering Flaming Strike or Cinder Maul. Select them in camp under Starting build; existing discoveries count immediately.

Sanctuaries now offer **Let go**: permanently remove one card instead of healing or upgrading. Removal costs no gold, keeps at least five cards, and ends the visit after confirmation. New painted sanctuary artwork accompanies all three choices.

The dungeon path climbs upward: the entrance is at the bottom and the boss is at the top. New descents open at the bottom; completing a room automatically brings the next reachable floor into view. Continuing a saved journey focuses its current choices. Reduced motion makes this repositioning immediate.

Each floor now has a painted atmosphere—threshold, cistern, archive, forge, rooted vault and guardian hall—with subdued gradients around the cards. Matching backgrounds extend through camp, encounters, deck inspection and reference screens. Cards share crafted bronze-and-leather frames and hidden dungeon paths use a painted sun-emblem back.

The standard starting deck now has painted artwork for every card, and all seven enemy types have portraits. This art pass replaces eight starter-card placeholders and four enemy placeholders while keeping existing combat animations and gameplay rules.
