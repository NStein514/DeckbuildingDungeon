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

See VALIDATION.md for current checks and platform limits. An interrupted encounter restarts at its entry checkpoint; this is not mid-turn persistence. Native device testing remains outstanding. Starting-build unlocks and lifetime totals remain outstanding; discovery and best-run records are implemented below.

## Milestone 3 — implemented: tactical combos, fusion, and descent foundation

1. Data-driven combo definitions and typed play history with explicit timing.
2. Overload, Shield Bash, and Toxic Flurry with deterministic tests.
3. Fusion recipes, two-distinct-instance validation, atomic deck transaction.
4. Shrine room, outcome preview, once-only confirmation, and saved discovery.
5. UI combo feedback and catalog entries without timing-dependent game logic.
6. Repeatable post-boss descents with stronger enemies, persistent builds, fresh seeds, and compatible legacy saves.

## Milestone 4A — implemented: risk and resources

- Seeded regular encounter pools and two ambush compositions.
- Visible Hardy (+25% HP) and Fierce (+2 per damage effect) room modifiers; +10 gold on victory.
- An optional event choice on floor 3 and a merchant option on floor 5 of each new descent.
- Three seeded card offers; once-only healing and exact-instance removal, with confirmation.
- Hungry altar and wandering healer events with explicit costs, survival checks, and free refusal.
- Atomic spending, stock persistence, failed-save retry, duplicate-command rejection, and content-version-1/2 compatibility.
- Phone UI tests and unchanged six-room route length, with maps wrapping to two columns.

## Milestone 4B — implemented: journal and personal records

- A separate versioned profile retains card, fusion and relic discovery across journeys.
- Personal bests: deepest floor entered, most rooms cleared and most bosses defeated in one journey.
- Camp and map journal UI with discovery filtering and card inspection.
- Existing-run import, idempotent recovery after interrupted writes, and practice-battle exclusion.
- Failed journal writes leave the run playable and prevent replacement until reconciliation; invalid/future profiles are preserved.

## Milestone 4C — implemented: unknown dungeon cards

- Face-down path cards conceal room types, enemies and modifiers, including accessibility labels.
- Choosing a card commits and saves the path, then flips it before explicit room entry.
- Seeded lane shuffling prevents fixed merchant/event/shrine positions from spoiling choices.
- Reloads and failed-save retries preserve the reveal and encounter seed; duplicate inputs cannot scout alternatives.
- Reduced-motion and fast-animation settings apply; legacy maps keep their original entry flow until the next descent.

## Milestone 4D — implemented: guardian variety

- Seeded boss selection between the Dungeon Warden, Crypt Broodmother and Ember Sentinel.
- Distinct poison/multi-hit and defensive/burn attack cycles with normal descent scaling.
- Expandable battle-plan previews after reveal, using the same scaled definitions as combat.
- Compatible legacy saves retain their Warden; new journeys and descents use the expanded pool.
- Image Generator illustrations for both new guardians in reveal cards and battles.

## Milestone 4E — implemented: deck-changing events

- Ember Forge trades 6 HP for an exact-instance card upgrade; the offering must be survivable.
- Memory Well trades 25 gold for an exact-instance removal, keeping at least five cards.
- Costed card previews, cancellation, safe exits, durable results and duplicate-command rejection.
- Seeded four-event pool for new maps; existing maps retain their original offers.
- Image Generator artwork for the two events and the Strike card.

## Milestone 4F — implemented: hand continuity and dungeon layout variety

- Unplayed permanent cards carry between turns, with five draws bounded by the ten-card hand limit.
- Fresh encounter hands use the persistent journey deck; upgrades and earned cards remain intact.
- Interior floor bands and lane contents shuffle, preserving two combat and two opportunity floors.
- New high-bit random sampling avoids repetitive low-bit shuffle patterns; legacy layouts remain loadable.
- Small deterministic card tilts preserve click targets and concealment without consuming gameplay RNG.

## Milestone 4G — remaining replayability and survival choices

The goal is many distinct runs and a dungeon that can keep generating floors, not a finite campaign expanded only by adding acts. See REPLAYABILITY.md.

1. Varied elite patterns and broader biome/event pools; further guardian tuning through playtesting.
2. Balance prices and resource income across repeated descents; add more meaningful merchant/event options.
3. Prototype an ember resource tied to forging and sanctuary choices; assess whether it creates interesting decisions before making it a mandatory survival meter.
4. More fusion paths and relic tradeoffs, with viable damage, defense, and status builds.
5. Starting-build and challenge unlocks based on the journal; unlock options rather than permanent stat inflation.
6. Balance repeated descents with automated simulation plus human playtesting; verify multiple builds can progress and increasing difficulty does not create unavoidable losses too early.

## Milestone 5 — presentation and accessibility

Approved illustrations and icons, licensed audio, richer event-driven animation, screen-reader and large-text review, physical-device profiling, crash-recovery testing, and native release packaging.

## Milestone 6 — expansion

Additional acts and archetypes, challenge modifiers, legendary recipes and deeper meta-progression once the first act is stable.
