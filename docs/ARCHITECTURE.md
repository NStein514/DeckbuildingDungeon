# Architecture

## Domain boundaries

`game/models`, `game/cards`, and `game/combat` implement deterministic combat without Flutter imports. JSON definitions are distinct from card instances. `resolveCard` creates an upgraded definition used by both the engine and UI, so displayed wording and applied effects agree. The engine owns mutation and exposes detached snapshots; rules never depend on animation timing.

`game/dungeon` generates a forward-only graph of ten rooms across six floors. Each room connects to all nodes on the following floor. IDs, depths, encounters, and connections are stable for a seed. Two rest/treasure choice floors and a single boss guarantee a complete path. The shared RNG state is carried into encounter seeds, rewards, and treasure selections.

`game/progression` owns run checkpoints and pure transitions. Each transition validates prerequisites, copies the checkpoint, and returns a new state. No UI mutates the published run. The state contains seed/RNG state, map, visited path, current phase, entry seed, health, gold, deck identities/upgrades, pending rewards, next instance ID, relics, and run-scoped discoveries.

`game/relics` defines four typed passive effects. Combat hooks apply starting block, extra opening draw, first-fire Burn, and increased player Poison. Enemy effects do not inherit player relics. Relic activation flows through the same effect/event processing as cards.

## Application and transactions

`RunController` uses ChangeNotifier and serializes commands by rejecting input while a save is pending. It computes the candidate state, awaits durable-store replacement, then publishes the candidate. Failure leaves both the previous in-memory checkpoint and the existing destination save in place. UI shows an error and permits retry. State snapshots returned by the controller are copies.

A battle is constructed from the saved encounter entry checkpoint. On a terminal result, the battle screen saves the run outcome automatically. It blocks result navigation until that save succeeds, with a retry action on failure. Gold and the three sampled reward IDs are written together. Choosing/skipping the reward is a separate validated transaction. Repeated commands at the wrong phase are rejected.

Returning from or reloading an unfinished battle reconstructs that battle from its entry checkpoint. This is deliberately not a mid-combat save or replay system. Completed battles cannot be replayed after their result checkpoint is saved. A process exit before a successful result save may restart the encounter, but cannot duplicate already committed rewards.

## Persistence

Run saves are envelopes with schema version 1 and content version 1. Loading validates field types, resource bounds, card IDs/upgrades, unique instance identities, the generated map against its seed, the completed path, phase-specific data, and reward structure. Unsupported or corrupt saves are preserved and surfaced; new-run replacement is disabled until a valid load. There is no automatic migration or destructive repair.

Native: `path_provider` locates app support; writes flush a same-directory `.tmp` file and rename it over the destination. Abandoned temporary writes are ignored. This targets Android/iOS file semantics; native app builds still need device verification. Browser: `package:web` performs one synchronous localStorage replacement. Quota/security errors propagate to the controller. Saves are origin-specific; one active game tab is supported. Multi-tab conflict resolution is not implemented.

Settings use a separate versioned document and a serialized write queue to prevent older slider writes overwriting newer settings. Invalid settings remain untouched and the UI explains its session-only fallback. Audio remains silent. Run discoveries and completed-room counts are local to the current journey; cross-run unlocks/statistics are later work.

## Presentation and dependencies

Flutter's built-in state tools are sufficient: local widget state handles selection, ChangeNotifier handles settings/run transactions. Riverpod and Flame add no required capability yet. Gameplay is independent of widget state, frames, and clocks. The event log retains 200 events with increasing sequence IDs, suitable for UI/debug feedback, not a full replay archive.

Art IDs map to replaceable images through an asset registry. Placeholder icons are labeled temporary. Flutter renders frames, numbers, descriptions, and effects. New cards can compose existing typed effects; new effect types require rule tests.

## Future seams

Add tactical combos as a separate sequence-rule resolver emitting ordinary effects/events. Permanent fusion must validate two distinct owned instances and a recipe before creating one new deck transaction. Merchants and events should be room transitions using the same controller/save boundary. Content/schema changes need explicit version handling, especially if map generation or RNG algorithms change.
