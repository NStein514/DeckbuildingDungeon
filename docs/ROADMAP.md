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

## Milestone 3 — tactical combos and permanent fusion

1. Data-driven combo definitions and typed play history with explicit timing.
2. Overload, Shield Bash, and Toxic Flurry with deterministic tests.
3. Fusion recipes, two-distinct-instance validation, atomic deck transaction.
4. Shrine room, outcome preview, once-only confirmation, and saved discovery.
5. UI combo feedback and catalog entries without timing-dependent game logic.

## Milestone 4 — complete act content

Merchant, gold spending, random events, elite encounters, boss phases, broader balance playtesting, cross-run statistics and unlocks.

## Milestone 5 — presentation and accessibility

Approved illustrations and icons, licensed audio, richer event-driven animation, screen-reader and large-text review, physical-device profiling, crash-recovery testing, and native release packaging.

## Milestone 6 — expansion

Additional acts and archetypes, challenge modifiers, legendary recipes and deeper meta-progression once the first act is stable.
