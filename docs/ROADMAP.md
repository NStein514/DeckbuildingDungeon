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

See VALIDATION.md for current checks and platform limits. An interrupted encounter restarts at its entry checkpoint; this is not mid-turn persistence. Native device testing remains outstanding. Lifetime totals remain outstanding; discovery and best-run records are implemented below.

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

## Milestone 4G — implemented: expanded fusion builds

- Guard + Spark creates Stormguard: block, a lightning hit and Shock setup.
- Heavy Blow + Firebolt creates Cinder Maul: a two-energy heavy hit with Burn.
- Shrine shortcuts list craftable recipes and prefer unupgraded duplicate sources, with preview and confirmation.
- Generated card illustrations, journal discovery, upgrade support, and fusion-only acquisition.

## Milestone 4H — implemented: journal-based starting builds

- Wanderer preserves the original balanced starter deck.
- Discovering any fusion unlocks Stormweaver, trading Heavy Blow and one Strike for Static Lance and Spark.
- Defeating a guardian unlocks Venomblade, trading Heavy Blow and Firebolt for Poison Edge and Quick Slash.
- Camp shows requirements, selection and inspectable decks, including locked previews.
- Unlocks derive from existing journal records; no permanent stat inflation or new save schema.

## Milestone 4I — implemented: tactical regular enemy variety

- Ash Duelist joins solo and ambush encounter pools in new map version 8.
- Guard, weakening strike and heavy lunge cycle; the lunge exposes a one-turn counterattack window.
- Image Generator enemy illustration, existing combat feedback and readable self-targeted status intent.
- Battle-plan previews for every revealed combatant, without exposing hidden paths.
- Exact version-7 layout/RNG compatibility; existing journeys expand their pool on the next descent.

## Milestone 4J — implemented: merchant card upgrades

- Spend 50 gold to upgrade one exact card instance per merchant visit.
- Upgrade preview and explicit cost confirmation, with free cancellation.
- Atomic gold/deck/service persistence, failed-save retry and duplicate-input protection.
- Available in existing merchant checkpoints; map generation remains version 8.

## Milestone 4K — implemented: Last Ember

- New treasure relic grants +1 opening energy when entering combat at half health or less.
- Generated lantern artwork appears in the run inventory and journal.
- Map version 9 expands treasure; earlier maps preserve their original relic pool.

## Milestone 4L — implemented: tactical encounter modifiers

- Rallying enemies gain 1 Strength after each action, increasing later attacks.
- Mending enemies recover 3 health after each action, capped at their maximum.
- New map version 10 samples both alongside Hardy and Fierce in existing risk slots, keeping the opening encounter and guardians unmodified.
- Revealed plans and live intents describe self effects; the existing +10 gold victory bonus applies.
- Earlier maps preserve their exact contents and RNG until the next descent.

## Milestone 4M — implemented: defensive fusion choices

- Guard + Poison Edge → Venom Ward: 1 energy, 7 block and 3 Poison on a chosen enemy.
- Guard + Mend → Bloomguard: 1 energy, 7 block and 4 healing; exhausts for the encounter.
- New painted card artwork, exact-instance shrine previews, upgrade support and persistent journal discovery.
- Seven recipes; fusion results remain excluded from ordinary rewards and merchant stock. Map generation stays version 10.

## Milestone 4N — implemented: specialist starting builds

- Gravewarden unlocks after discovering Glacial Barrier, Stormguard, Venom Ward or Bloomguard; exchanges Quick Slash/Firebolt for Brace/Enfeeble.
- Embercaller unlocks after discovering Flaming Strike or Cinder Maul; exchanges Heavy Blow/Frost Ward for Cinder Storm/a second Firebolt.
- Both preserve twelve base cards, starting resources and the seeded map; unlocks are choices without permanent stat bonuses.
- Locked inspection, journal-derived availability, atomic replacement and exact-deck continuation use existing camp/save flows.
- Image Generator artwork replaces Brace, Enfeeble and Cinder Storm placeholders.

## Milestone 4O — implemented: sanctuary deck choices

- Let go removes one exact card instance instead of healing or upgrading, with no gold cost and a five-card minimum.
- Preview/cancel before committing; the confirmed choice ends the visit and persists across encounters and descents.
- Painted Image Generator sanctuary art replaces the rest-room icon; revealed rest plans describe all three options.
- Removal previews display the correct sanctuary and memory-well costs.

## Milestone 4P — remaining replayability and survival choices

The goal is many distinct runs and a dungeon that can keep generating floors, not a finite campaign expanded only by adding acts. See REPLAYABILITY.md.

1. Varied elite patterns and broader biome/event pools; further guardian tuning through playtesting.
2. Balance prices and resource income across repeated descents; add more meaningful merchant/event options.
3. Prototype an ember resource tied to forging and sanctuary choices; assess whether it creates interesting decisions before making it a mandatory survival meter.
4. More fusion paths and relic tradeoffs, with viable damage, defense, and status builds.
5. Further starting-build and challenge unlocks based on the journal; unlock options rather than permanent stat inflation.
6. Balance repeated descents with automated simulation plus human playtesting; verify multiple builds can progress and increasing difficulty does not create unavoidable losses too early.

## Milestone 5A — implemented: quick combat feedback

- Generated slash, shield, fire, lightning, poison and healing effect atlas.
- Event-driven, target-anchored bursts for card plays, enemy effects, statuses, support and combos.
- Actual damage/block/heal feedback, bounded concurrent effects and nonblocking input.
- Brief killing-hit presentation, immediate state/save resolution, reduced-motion and fast modes.

## Milestone 5B — implemented: distinct combat motion

- Sweeping slash trails, traced shield facets, flying fire and embers, branching lightning, rising poison bubbles, spiraling healing motes and orbiting support cards.
- Each effect changes shape and particle positions over its lifetime; generated fire/healing texture details accompany procedural motion.
- Nonblocking 480 ms effects, 240 ms fast mode and static reduced-motion labels.

## Milestone 5C — implemented: painted combat animation sequences

- Seven Image Generator sprite sheets, eight distinct poses each, reference the existing Cinder Maul and Stormguard artwork.
- Textured steel, bronze/crystal defense, fire/smoke, lightning, liquid venom, golden healing leaves and violet arcane wisps replace procedural outlines.
- Fixed-size, registered frame playback with short cross-dissolves, soft cell edges and bounded shared texture decoding.
- Existing duration, immediate input, result persistence and reduced-motion behavior remain intact.

## Milestone 5D — implemented: floor atmospheres and crafted cards

- Six painted floor backgrounds, repeated by floor position on later descents, with quiet dark gradients beneath cards.
- Matching camp, encounter/result, deck, journal and collection backgrounds; combat uses its room's floor theme.
- Generated bronze-and-leather card face frame and common sun-emblem hidden-path back, preserving color-coded costs and live text.
- Existing card illustrations, flips, tilts and automatic map focus remain in use.

## Milestone 5E — implemented: illustrated starter deck and enemy catalog

- Painted Guard, Quick Slash, Heavy Blow, Mend, Firebolt, Frost Ward, Spark and Preparation illustrations complete the standard starting deck.
- Transparent Dungeon Rat, Skeleton Soldier, Cursed Mage and Dungeon Warden portraits complete the current seven-enemy catalog.
- Logical art IDs replace placeholders across battle, reveal, rewards, shops and collection views without changing gameplay.
- Bounded illustration decoding and content checks for starter/enemy coverage and bundled PNG files.

## Milestone 5F — implemented: path reveals and masked Wayfarers

- Saved path choices flip from their map position and expand into the enemy-style frame; reduced motion and resumed reveals skip the flight.
- One app atmosphere behind the map, without repeated floor image panels.
- Sixteen card paintings share a 1536×1024 canvas; older images were extended/recomposed rather than cropped.
- Taller boss portrait panels and a heroic silver/gold player frame with five masked starter-build portraits.
- Durable hero identity persists independently of upgrades, removals, reloads and descents.

## Milestone 5G — remaining presentation and accessibility

Approved illustrations and icons, licensed audio, richer event-driven animation, screen-reader and large-text review, physical-device profiling, crash-recovery testing, and native release packaging.

## Milestone 6 — expansion

Additional acts and archetypes, challenge modifiers, legendary recipes and deeper meta-progression once the first act is stable.


## Milestone 6A — implemented: archetype support expansion

- Ten fully illustrated collectible cards, two recommendations per starting build.
- Wanderer draw support; Stormweaver Shock setup and paired lightning; Venomblade poison/Weak and retained evasion; Gravewarden limited regeneration and suppression; Embercaller defensive Burn and Vulnerable setup.
- New-run rewards and merchant pools include the additions; existing checkpoints keep their original deterministic pools through further descents.
- Shared upgrades, targeting, exhaust, journal discovery and existing combat effects.
