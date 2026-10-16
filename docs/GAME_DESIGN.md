# Deckbound — game design

## Identity and scope

Your deck is your character. Tactical clarity, build creativity, short responsive turns, replayable paths, and a cohesive dark fantasy identity guide the project. The long-term loop is explore → fight → earn rewards → reshape the deck → descend → confront the boss.

Milestone 1 implements the fight in isolation. The menu is an encounter harness, not a dungeon map. Victory and defeat are real engine outcomes; rewards, persistence, and progression are intentionally absent.

## Combat economy

Balance lives in `assets/data/balance.json`: 50 maximum HP, 3 energy each turn, 5 draws each turn, hand limit 10. A retained card does not reduce the next turn's five draws; the hand cap still applies. The starting deck is Strike ×3, Guard ×2, Quick Slash, Heavy Blow, Mend, Firebolt, Frost Ward, Spark, and Preparation. Duplicates have separate instance IDs.

Cards pay their cost only after validation. Targeted cards require a living enemy; self effects apply to their source. Defense and healing on mixed cards such as Frost Ward still require a valid enemy target for the full transaction. Curse cards cannot be played. A selected card may be inspected even if unaffordable.

Played cards leave the hand before their effects, then enter discard. An in-flight card cannot draw itself. Retain prevents end-turn discard; Exhaust removes a card only when played; Temporary removes a card on play or discard. Exhausted and temporary cards cannot recycle. Empty draw piles reshuffle discards using the seeded random source. Empty piles and full hands are valid states.

Mend, Focus, Battle Cry, and Preparation exhaust in this slice, avoiding unlimited healing, strength, and zero-cost draw loops in very small decks. Preparation draws first, then requires an explicit discard choice, bounded by the available hand. It blocks playing cards and ending the turn until resolved.

## Resolution order

1. At the owner's turn start, clear old block.
2. Tick Burn, then Poison (both bypass block); stop if the owner dies.
3. If alive, heal Regeneration. Reduce each ticking status by one.
4. On player turns, replenish energy and draw five, bounded by the hand limit.
5. Resolve each card's ordered effects, checking terminal outcomes after each effect.
6. End player turn: discard non-retained cards, expire player action-duration effects.
7. Each living enemy takes its start phase, then its visible action, then duration expiration.
8. Only if combat remains active, begin the next player turn.

Enemies act in displayed order. A dead target is never struck again by later hits. Player death takes precedence over victory if both conditions ever coincide. Combat ends immediately on a terminal result; later actions do not execute. There is no animation wait in the rules.

## Status contract

All applications add stacks. Zero stacks are removed. Negative stacks are not content-supported.

| Status | Meaning | Lifetime |
| --- | --- | --- |
| Strength | Add stacks to Attack-card and enemy attack damage | Entire battle |
| Weak | Multiply outgoing attack damage by 0.75, floor | Lose one at owner's action end |
| Vulnerable | Multiply incoming attack damage by 1.5, floor | Lose one at owner's action end |
| Burn | Lose stacks HP at owner's turn start, bypass block | Lose one after tick |
| Poison | Lose stacks HP after Burn at owner's turn start, bypass block | Lose one after tick |
| Chill | Subtract 2 per stack from each attack in next action phase | Clear at owner's action end |
| Shock | Next lightning hit gains damage equal to stacks | Entire battle until consumed |
| Regeneration | Heal stacks at owner's start, after damage-over-time | Lose one after healing |
| Block | Absorb damage point-for-point before HP | Clear at owner's next turn start |

Attack arithmetic: max(0, base + Strength − 2×Chill), then Weak floor, then Vulnerable floor, then block absorption, then HP loss. Spell damage ignores attack modifiers. Lightning adds and consumes Shock before block absorption. Damage-over-time ignores block and attack modifiers. HP is clamped to [0, maximum]; healing never revives. Intent previews account for current attack modifiers but display incoming damage before block absorption.

Burn and Poison deliberately share timing in this milestone; their identities can diverge through future relics/combos without changing the underlying phase contract. Vulnerable may expire at an enemy's turn end even if the player did not exploit it. New timing changes require tests and wording updates.

## Enemies

Dungeon Rat teaches basic attacks. Skeleton alternates attacks and defense. Cursed Mage applies Weak and Burn. Dungeon Warden escalates through repeatable Strength buffs and heavy attacks; phase transitions are deferred. The ambush pits a rat and skeleton together. All patterns are predictable; the seed changes card order, not enemy intent randomness.

## Future systems

Milestone 2 adds branching dungeon nodes, one-of-three rewards, gold, rest, upgrades, relics, and stable-boundary saves. Milestone 3 adds sequence history with structured combo rules and atomic two-instance fusion. Neither is represented as working UI today. Fusion recipes and relic interactions will be data-driven additions, not card-name checks in widgets.
