# Architecture

## Domain boundaries

`game/models`, `game/cards`, and `game/combat` implement deterministic combat without Flutter imports. JSON definitions are distinct from card instances. `resolveCard` creates an upgraded definition used by both the engine and UI, so displayed wording and applied effects agree. The engine owns mutation and exposes detached snapshots; rules never depend on animation timing.

`game/dungeon` generates a forward-only graph of thirteen rooms across six floors (ten or eleven for legacy maps). Each room connects to all nodes on the following floor. IDs, depths, encounters, and connections are stable for a seed. Two choice floors and a single boss guarantee a complete path. Version 3 maps add an event on floor three and a merchant alongside rest/treasure/shrine on floor five. Version 1/2 maps retain their original rooms and RNG sequence. Each cleared boss offers another descent. The root seed stays fixed; each descent has its own map seed and deterministic RNG continuation. Only the active map/path is stored; total cleared rooms derives from the descent count. The shared RNG state is carried into encounter seeds, rewards, and treasure selections.

`game/progression` owns run checkpoints and pure transitions. Each transition validates prerequisites, copies the checkpoint, and returns a new state. No UI mutates the published run. The state contains seed/RNG state, map, visited path, current phase, entry seed, health, gold, deck identities/upgrades, pending rewards, next instance ID, relics, and run-scoped discoveries.

`game/relics` defines four typed passive effects. Combat hooks apply starting block, extra opening draw, first-fire Burn, and increased player Poison. Enemy effects do not inherit player relics. Relic activation flows through the same effect/event processing as cards.

## Application and transactions

`RunController` uses ChangeNotifier and serializes commands by rejecting input while a save is pending. It computes the candidate state, awaits durable-store replacement, then publishes the candidate. Failure leaves both the previous in-memory checkpoint and the existing destination save in place. UI shows an error and permits retry. State snapshots returned by the controller are copies.

A battle is constructed from the saved encounter entry checkpoint. On a terminal result, the battle screen saves the run outcome automatically. It blocks result navigation until that save succeeds, with a retry action on failure. Gold and the three sampled reward IDs are written together. Choosing/skipping the reward is a separate validated transaction. Repeated commands at the wrong phase are rejected.

Returning from or reloading an unfinished battle reconstructs that battle from its entry checkpoint. This is deliberately not a mid-combat save or replay system. Completed battles cannot be replayed after their result checkpoint is saved. A process exit before a successful result save may restart the encounter, but cannot duplicate already committed rewards.

## Persistence

Run saves are envelopes with schema version 1 and content version 3. Content versions 1 and 2 remain readable: absent mapVersion defaults to 1, mapSeed to seed, and descent to 1. Old maps are validated with their original generator; their next descent uses map version 3. Missing purchases defaults to an empty list. New saves are intentionally unreadable by the older apps. Loading validates field types, resource bounds, card IDs/upgrades, unique instance identities, the generated map against its map seed and generator version, the completed path, phase-specific data, and reward structure. Unsupported or corrupt saves are preserved and surfaced; new-run replacement is disabled until a valid load. There is no automatic migration or destructive repair.

Native: `path_provider` locates app support; writes flush a same-directory `.tmp` file and rename it over the destination. Abandoned temporary writes are ignored. This targets Android/iOS file semantics; native app builds still need device verification. Browser: `package:web` performs one synchronous localStorage replacement. Quota/security errors propagate to the controller. Saves are origin-specific; one active game tab is supported. Multi-tab conflict resolution is not implemented.

Settings use a separate versioned document and a serialized write queue to prevent older slider writes overwriting newer settings. Invalid settings remain untouched and the UI explains its session-only fallback. Audio remains silent. Run discoveries and completed-room counts are local to the current journey; starting-build unlocks and lifetime totals are later work.

## Presentation and dependencies

Flutter's built-in state tools are sufficient: local widget state handles selection, ChangeNotifier handles settings/run transactions. Riverpod and Flame add no required capability yet. Gameplay is independent of widget state, frames, and clocks. The event log retains 200 events with increasing sequence IDs, suitable for UI/debug feedback, not a full replay archive.

Art IDs map to replaceable images through an asset registry. Placeholder icons are labeled temporary. Flutter renders frames, numbers, descriptions, and effects. New cards can compose existing typed effects; new effect types require rule tests.

## Combos, fusion, and difficulty

`game/combos` contains typed, structured definitions and successful-play records. The engine resolves base card effects, relic effects, then a matching combo on a surviving target. Consecutive pairs must belong to the same turn; elemental pairs require the same target. Rejected commands do not enter history. History resets at turn start. Bonus damage is ordinary blockable damage, without attack or lightning modifiers; bonus Poison uses the existing status/relic resolver. Events drive feedback; frames do not govern rules.

`game/fusion` holds unordered two-source recipes. The run rule validates two distinct owned instances and an active shrine, removes those instances, creates a new base result, records discovery, and completes the shrine in a single copied-state transaction. Source upgrades are consumed. Failure to persist leaves sources intact. Fusion-only cards are excluded from battle rewards. The UI preserves its selections across loading/error rebuilds and supports preview, cancellation, and retry.

`game/dungeon/difficulty.dart` derives encounter definitions from the saved descent. It scales authored health by +20% and damage/block by +10% per completed descent, rounded up, preserving status amounts and original definitions. Battle construction and intent previews share these definitions, including after reload. Practice battles stay at descent 1 without room modifiers. Hardy multiplies the already-scaled HP by 1.25, rounded up; Fierce adds 2 to each scaled damage effect. The map stores each modifier and validates it against its generator version and seed. The battle UI and engine use the same modified definitions.

`game/economy` defines prices, stock generation and event costs. Merchant stock is three non-fusion, non-curse definitions shuffled from sorted IDs using the saved room entry seed. Purchases store unique tokens (`card:<id>`, `heal`, `remove`) only while the merchant is active. Every purchase validates phase, funds, availability and service conditions, copies the state, then commits wallet and benefit together. Leaving clears visit tokens and completes the room. Removal selects an exact instance and requires at least five remaining cards.

Events derive their offer from the saved room entry seed. Accept validates health/gold and writes both costs and benefits with room completion; declining completes the room without resource changes. No event rerolls on reload. Future stock/catalog or RNG changes require content-version handling.

Future survival resources should use the same controller/save boundary. `profile_repository` stores a separate profile envelope (schema/content version 1), using the same flushed-file or browser replacement stores. Native uses `deckbound-profile.json`; browser uses `deckbound.profile.v1`. Run content version stays 3.

`PlayerProfile` is immutable. Discoveries merge by set union; records merge by maximum. Deepest floor counts entered rooms, not an unvisited next descent; bosses defeated derive from completed descents plus an active victory checkpoint. These are per-journey bests, not cumulative totals. Reconciliation is idempotent and uses bounded catalog sets and three numbers, without storing every journey.

`RunController` loads the profile separately even when the run is corrupt. For each gameplay transition it first saves/publishes the run checkpoint, then attempts to update the journal. Profile failure returns success for the already-saved gameplay action, preventing duplicate rewards or costs; a separate warning offers retry. Load/retry reconciles the profile from the current run. Run discovery and depth records are monotonic within a journey, so later checkpoints retain pending information. Before replacing a journey the controller must successfully reconcile its journal. Corrupt/future profiles remain untouched and block new-run replacement while allowing the existing run to continue. Multi-tab/multi-device merges are not supported.

Practice battles have no run-controller completion callback, so they never contribute records. Existing current runs are imported on first profile load; earlier overwritten runs cannot be recovered. No account sync, unlocks, or permanent combat bonuses are introduced. Content/schema changes require explicit version handling.
