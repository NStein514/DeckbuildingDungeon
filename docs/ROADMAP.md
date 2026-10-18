# Roadmap

## Milestones 1 and 2 — implemented

- Typed pure-Dart combat, deterministic piles, statuses, targeting, multiple enemies, outcomes.
- Twenty cards, three regular enemies, Warden, responsive combat UI and event log.
- Seeded six-floor branching dungeon with guaranteed boss reachability.
- Three-card rewards, gold, deck growth, rest healing, per-instance upgrades and previews.
- Four passive relics, treasure rooms, and deck sorting/filtering.
- Versioned native/browser saves, Continue Run, serialized settings persistence.
- Failed-save retry, duplicate-command protection, corrupt-save preservation.
- Complete real-combat seeded-run test, persistence and widget tests.
- Flutter dependency lockfile and Android/iOS/web hosts.

See VALIDATION.md for current checks and platform limits. An interrupted encounter restarts at its entry checkpoint; this is not mid-turn persistence. Native device testing remains outstanding. Gold spending, global discovery/unlocks and run statistics are not part of this implementation.

## Milestone 3 — implemented: tactical combos, fusion, and descent foundation

1. Data-driven combo definitions and typed play history with explicit timing.
2. Overload, Shield Bash, and Toxic Flurry with deterministic tests.
3. Fusion recipes, two-distinct-instance validation, atomic deck transaction.
4. Shrine room, outcome preview, once-only confirmation, and saved discovery.
5. UI combo feedback and catalog entries without timing-dependent game logic.
6. Repeatable post-boss descents with stronger enemies, persistent builds, fresh seeds, and compatible legacy saves.

## Milestone 4 — replayability and meaningful survival choices

The goal is many distinct runs and a dungeon that can keep generating floors, not a finite campaign expanded only by adding acts. See REPLAYABILITY.md.

1. Encounter pools and seeded floor modifiers; varied elites and boss patterns with clear previews.
2. Merchant spending, deck removal, and resource events that create competing uses for gold.
3. Prototype an ember resource tied to forging and sanctuary choices; assess whether it creates interesting decisions before making it a mandatory survival meter.
4. More fusion paths and relic tradeoffs, with viable damage, defense, and status builds.
5. Cross-run discovery journal and deepest-floor statistics; unlock options rather than permanent stat inflation.
6. Balance repeated descents with automated simulation plus human playtesting; verify multiple builds can progress and increasing difficulty does not create unavoidable losses too early.

## Milestone 5 — presentation and accessibility

Approved illustrations and icons, licensed audio, richer event-driven animation, screen-reader and large-text review, physical-device profiling, crash-recovery testing, and native release packaging.

## Milestone 6 — expansion

Additional acts and archetypes, challenge modifiers, legendary recipes and deeper meta-progression once the first act is stable.
