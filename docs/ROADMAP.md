# Development roadmap

## Milestone 1 — source implemented, runtime validation blocked

- [x] Flutter package, web host, theme, menus, and battle/result screens
- [x] Typed models, JSON catalog, configurable starting resources
- [x] Seeded pile operations, energy, targeting, attacks, defense, healing
- [x] Status timing, visible predictable enemy intents, multi-enemy resolution
- [x] Retain, exhaust, temporary cards, explicit Preparation discard
- [x] Twenty cards, three regular enemies, one boss archetype
- [x] Unit and widget test sources; production documentation
- [x] Replaceable labeled art placeholders and silent audio interface
- [ ] Download SDK and resolve dependencies; commit real lockfile
- [ ] Run Dart formatter, Flutter analyzer, all tests, and web build
- [ ] Browser smoke test of a full battle; inspect phone and desktop layouts
- [ ] Generate native hosts; Android device and iOS simulator checks

A checked source item is not a claim of passing runtime acceptance. See VALIDATION.md.

## Milestone 2 — deckbuilding and dungeon progression

- Seeded acyclic branching map with guaranteed boss reachability
- Distinct run controller and stable room IDs/completion states
- Card rewards with once-only confirmation and gold
- Deck inspection/filtering, upgrades and removal
- Rest sites and initial passive relic hooks
- Versioned saves and settings with atomic stable-boundary commits
- Resume tests, RNG continuation, reward duplication prevention
- Integrate death/victory into a complete short dungeon route

## Milestone 3 — combinations

- Data-driven sequence tracker and tactical combo rules
- Atomic instance-level permanent fusion, preview and validation
- Discovery state, collection, fusion event feedback
- Comprehensive invalid-transaction and multi-hit tests

## Milestone 4 — Ashen Crypt act

Merchant, events, elite encounters, boss phases, run statistics, unlocks and reward balance. The current boss pattern is an encounter foundation, not a finished act.

## Milestone 5 — presentation and accessibility

Approved illustrations and icons, event-specific draw/play/discard animation, particles, licensed audio, persistent accessibility settings, screen-reader navigation, large-text/device usability testing, profiling. Current feedback consists of real state updates, health interpolation, selected-card transitions, text feedback, and the event log; it is not the final animation suite.

## Milestone 6 — expansion

Additional regions, starting archetypes, challenge modifiers, richer recipes, legendary mechanics, and deeper meta-progression after the first act is stable.
