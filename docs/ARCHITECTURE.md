# Architecture

## Boundaries

- `game/models`: enums and data objects for cards, effects, fighters, intent patterns, balance, and events. Definitions distinguish logical content IDs from instance IDs. Artwork, tags, rarity, keywords, and effect targeting are data fields. Instance upgrade level is reserved, not an implemented upgrade mechanic.
- `game/data`: JSON decoding into the catalog; starting-deck instance creation. It has no asset-bundle or widget imports. The application loads strings before constructing it.
- `game/cards`: mutable pile ownership and seeded shuffle/draw behavior.
- `game/combat`: command validation, turn orchestration, central effect/status resolution, snapshots, and event ordering. This is a bounded combat aggregate, not a run/dungeon/UI controller.
- `core/random`: explicit 32-bit state with deterministic Fisher–Yates shuffling. The same integer seed produces the same ordering on native and web. Its arithmetic stays within exact JS integer range.
- `presentation`: card selection, target input, rendering, and event feedback. It issues commands, consumes snapshots, and never directly applies damage.
- `assets`: stable logical identifier → image-path lookup with labeled fallback illustrations.
- `core/services`: audio interface with a silent implementation.

## State decision

Use Flutter's built-in StatefulWidget and ChangeNotifier rather than Riverpod for this small, isolated slice. Battle state belongs to the pure Dart engine. Selection/message state belongs to the screen; session settings use ChangeNotifier. No global gameplay singleton or service locator is necessary. Reconsider provider-based dependency injection when run persistence spans screens.

Definition collections loaded from JSON are unmodifiable. Engine internals mutate synchronously under command processing; snapshots copy fighters/status maps and expose unmodifiable lists. Snapshot fighters are detached copies, so presentation cannot mutate the engine. This avoids speculative persistent data structures while keeping command ownership explicit.

## Data flow

Asset strings → GameCatalog → CombatEngine → validated command → ordered effects → outcome check → CombatSnapshot + CombatEvent → UI and audio service.

The engine retains the most recent 200 events for inspection, with monotonically increasing IDs. This is a UI/debug history, not a complete replay archive. A future replay recorder must persist the seed, content version, and commands separately. The UI consumes newly emitted events for feedback, not timers for rules. Health interpolation and card selection animate after resolution. Log entries expose draw, discard, status, healing, damage, and defeat details; bespoke movement/particles are deferred.

## Rendering decision

Flutter alone is appropriate for static tactical layouts. Flame would add a second rendering lifecycle without an immediate benefit. Add it only if future particles, arena effects, or map rendering justify it. Frames, gradients, and icons are interface treatments; final illustration work is a separate asset pipeline.

## Persistence and navigation

No durable saves yet. Returning to camp or closing the application abandons the battle. No Continue Run button implies a nonexistent save. Settings are session-only and clearly labeled. Milestone 2 should add versioned save DTOs, a repository abstraction, atomic file replacement on native, transactional browser storage, and stable boundary commits with reward IDs. Save RNG state, deck instance IDs, current node, health, resources, collection, settings, and content version. Mid-combat continuation remains deferred.

## Platform and build boundaries

Web host files are present. `tool/initialize_platforms.sh` creates native hosts using the installed official Flutter generator in a temporary directory, then copies only missing Android/iOS hosts. Its execution remains blocked by SDK download access in the current environment. No app source or documentation is overwritten by that helper. Native signing and platform SDK installation are external prerequisites.

## Extension seams

New simple cards compose existing typed effects in JSON. New effect kinds require engine implementation and tests. Dungeon generation, rewards, relic triggers, and fusion transactions belong in separate pure Dart modules when implemented. Combo resolution should receive a typed play history and emit ordinary effects/events. Fusion must validate both distinct source instances and recipe compatibility before producing a new deck in one transaction.

No backend, online authentication, paid API, or runtime artwork service is required.
