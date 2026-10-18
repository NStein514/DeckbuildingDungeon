# Replayability direction

## Reference and goal

The user referenced [Dungeon Raid by 4Cats](https://4cats.itch.io/dungeon-raid), describing a card roguelike about descending through increasingly difficult floors, using found resources, fighting a boss, and surviving hunger. Direct retrieval of the page was blocked by this development environment, so this comparison is based on the user's description, not a hands-on review or verified analysis of that game's systems.

Deckbound should support many distinct runs and a dungeon that continues beyond a single boss. A run may end in defeat; replayability means fresh, meaningful decisions when starting again, not a guarantee that one character can survive forever. Preserve the appeal of readable card encounters, resource tradeoffs, and choosing to push farther. Develop original rules, content, presentation, and identity.

## Deckbound's distinguishing idea: forge the build you descend with

Permanent fusion is the central identity. Combining two useful cards into one stronger, narrower tool changes draw consistency and the range of available tactical combos. For example, fusing Firebolt into Flaming Strike improves a one-card attack but removes that instance from the Firebolt → Spark sequence. The player decides when consistency is worth losing a setup option. Further relics and recipes should deepen this tradeoff.

A proposed future resource is **embers**: opportunities to shape the deck compete with opportunities to recover safely. A sanctuary might offer healing or forging; a dangerous optional room could replenish embers. Prototype this economy before adding a mandatory depletion timer. Hunger is not currently implemented, and the proposed ember system is not in this build.

## Implemented foundation

- Fresh run seeds by default, with explicit seeds for reproducible routes and challenges.
- Six-floor segments with a boss and a choice to descend again, keeping the current build and health.
- Deterministic next-map generation, rising enemy HP/damage/block, continuous floor numbering, bounded active-map storage.
- Three tactical combos, three permanent fusion recipes, shrine preview and confirmation, saved run discoveries.
- Continue/reload at stable checkpoints, including after a boss and on later descents.
- Seeded regular encounters and ambush variants, with visible Hardy/Fierce risk modifiers and bonus gold.
- A merchant with cards, recovery, and removal competing for gold; two optional health/gold bargains.
- A cross-run discovery journal for cards/fusions/relics and personal bests for floors, rooms and bosses.

The current four-enemy catalog and fixed floor roles will repeat. Linear stat scaling supplies increasing pressure, not enough variety by itself. There is no claim of balanced infinite play or an unlimited variety of generated content.

## Next playable milestone

The first encounter pools, risk modifiers, merchants, removal and resource events are implemented. Expand elite/boss behavior and two or three viable build archetypes, then assess the gold economy over repeated descents. More modifiers should change tactics, not only enemy numbers. Keep difficulty previews consistent with actual rules.

Cross-run deepest-floor records and the recipe journal are now implemented. Next, unlock different starting choices, recipes, relics and challenge rules instead of permanently increasing all stats. This preserves meaningful early-floor decisions on repeat runs. The profile is already saved separately from the active journey, with version handling and failed-write tests.

## Acceptance criteria for replayability work

- Different seeds and player choices produce meaningfully different encounter/build paths.
- Several build archetypes can reach later descents in human playtests; no single combo is required.
- Every mandatory floor remains traversable; elite and resource risks are signposted.
- There are viable recovery and deck-management choices, without an effortless infinite sustain loop.
- Continued descents do not grow map history indefinitely or duplicate rewards after reload.
- Tests cover reproducibility, difficulty application, profile persistence and resource invariants; playtests assess tension, variety and run duration. Simulated victories test progression, not balance.

## Unknown dungeon cards

New maps conceal each unexplored path behind a face-down card. Choosing commits the path before revealing its contents, preserving the existing six-floor battle/room rhythm. Interior lane contents shuffle each descent; the final floor remains signposted as a boss. Reloading retains the chosen reveal. This adds uncertainty without replacing tactical combat, fusion builds or the journey journal. Future clues or scouting should introduce deliberate resource decisions; this milestone does not allow free peeking.
