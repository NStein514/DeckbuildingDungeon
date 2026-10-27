# Deckbound — game design

## Identity and scope

Your deck is your character. Tactical clarity, build creativity, short responsive turns, replayable paths, and a cohesive dark fantasy identity guide the project. The long-term loop is explore → fight → earn rewards → reshape the deck → descend → confront the boss.

Milestones 1–3 implement combat, fusion, and repeatable dungeon descents. The menu offers saved runs and separate practice battles. Victory, defeat, rewards, deck progression, and stable-boundary saves are functional.

## Combat economy

Balance lives in `assets/data/balance.json`: 50 maximum HP, 3 energy each turn, 5 draws each turn, hand limit 10. An unplayed permanent card stays in hand and does not reduce the next turn's five draws; the hand cap still applies. The starting deck is Strike ×3, Guard ×2, Quick Slash, Heavy Blow, Mend, Firebolt, Frost Ward, Spark, and Preparation. Duplicates have separate instance IDs.

Cards pay their cost only after validation. Targeted cards require a living enemy; self effects apply to their source. Defense and healing on mixed cards such as Frost Ward still require a valid enemy target for the full transaction. Curse cards cannot be played. A selected card may be inspected even if unaffordable.

Played cards leave the hand before their effects, then enter discard. An in-flight card cannot draw itself. All unplayed permanent cards stay in hand at turn end (the legacy Retain keyword is redundant); Exhaust removes a card only when played; Temporary removes a card on play, explicit discard, or turn end. Exhausted and temporary cards cannot recycle. Empty draw piles reshuffle discards using the seeded random source. Empty piles and full hands are valid states.

Mend, Focus, Battle Cry, and Preparation exhaust in this slice, avoiding unlimited healing, strength, and zero-cost draw loops in very small decks. Preparation draws first, then requires an explicit discard choice, bounded by the available hand. It blocks playing cards and ending the turn until resolved.

## Resolution order

1. At the owner's turn start, clear old block.
2. Tick Burn, then Poison (both bypass block); stop if the owner dies.
3. If alive, heal Regeneration. Reduce each ticking status by one.
4. On player turns, replenish energy and draw five, bounded by the hand limit.
5. Resolve each card's ordered effects, checking terminal outcomes after each effect.
6. End player turn: remove unplayed Temporary cards, keep other cards in hand, and expire player action-duration effects.
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

## Tactical combos and permanent fusion

Play the pair consecutively in the same turn. Invalid commands do not break the sequence; another successful play does. After base and relic effects, if the target survives:

- Firebolt → Spark on the same enemy: consume 2 Burn and deal 6 blockable bonus damage.
- Guard → Heavy Blow: deal bonus damage equal to current player block, retaining that block.
- Poison Edge → Quick Slash on the same enemy: apply 3 extra Poison, modified by Venom Fang.

Bonus damage ignores Strength, Weak, Vulnerable and Shock. Combos never redirect after a target dies. Feedback appears in the action message and combat chronicle, with a guide accessible from combat and the map.

At a shrine, select two distinct owned instances in either recipe order. Preview and confirm one fusion, or leave. Strike + Firebolt produces Flaming Strike (1 energy, 8 damage, 3 Burn); Guard + Frost Ward produces Glacial Barrier (1 energy, 9 block, 1 Chill); Quick Slash + Poison Edge produces Venom Flurry (1 energy, two 3-damage hits, 3 Poison). Source upgrades are consumed; results are unupgraded and can later be upgraded normally. Only fusion grants these cards. Discoveries persist for this journey.

## Repeatable descent foundation

A boss victory offers a new six-floor descent without discarding health, cards, upgrades, relics, gold, or discoveries. The new map and encounters use deterministic RNG continuation; floors keep numbering upward. Every further descent adds 20% of authored enemy HP and 10% of authored damage/block, rounded up. Status stacks are unchanged. There is no authored final descent. Returning to camp preserves the victory checkpoint so the player can continue later.

New runs use a fresh seed unless the player enters one. Repeating a seed reproduces the same sequence given the same choices. The current encounter pool is small and higher-floor balance is provisional; procedural continuation alone does not establish lasting replay value. REPLAYABILITY.md defines the next work.

## Milestone 2: implemented dungeon loop

New Run creates six floors: an introductory rat, four shuffled interior floors (two combat bands and two opportunity bands), and a seeded guardian. Opportunity bands offer rest/treasure/event or rest/treasure/shrine/merchant cards. All next-floor nodes are connected and a boss route always exists. Each run starts with Iron Sigil. Practice encounters remain available separately.

Winning regular combat grants 15–25 seeded gold and three distinct sampled card options. Choose one or skip. The next card instance ID, deck mutation, and room completion are committed once. Gold funds merchant purchases and event bargains. Modified encounters grant 10 additional gold.

Rest offers one choice: restore 30% of maximum HP (capped at maximum), upgrade one unupgraded card, or remove one card while keeping at least five. Upgrades preserve the instance ID, add 2 to damage/block/heal effects and 1 to status/draw effects, leave discard and energy cost unchanged, and retain keywords. Only one upgrade is permitted; previews use the same resolved definition as combat.

Treasure grants 25 gold and one unowned relic. If all relics are owned, it grants gold only. Iron Sigil grants 4 opening block; Quickdraw Charm adds one opening draw; Ember Heart adds 2 Burn on the first Fire play per combat; Venom Fang adds 1 stack to player Poison applications. Passive effects are reset appropriately for each new encounter.

The run carries health, deck, upgrades, relics, gold, discoveries, room completion, and RNG state. Saves occur at stable boundaries. Restarting mid-combat recreates the entry encounter. Settings persist separately; final audio and art remain pending. Starting-build unlocks and boss phase changes remain future work.


## Risk and resources (Milestone 4A)

New descents contain 13 room nodes but still visit six rooms. Introductory rats and bosses retain normal stats. One combat band offers an unmodified single enemy versus a Hardy or Fierce single enemy. The other offers a modified single enemy versus a seeded rat/mage or rat/skeleton ambush. Version-7 maps randomize their depths. Version-8 maps expand single enemies to four regular definitions and add the Duelist as an ambush companion. Hardy adds 25% HP after descent scaling, rounded up; Fierce adds 2 per direct damage effect after scaling, leaving status stacks unchanged. Both grant 10 bonus gold. Maps and combat display the modifier before actions.

The merchant competes with free rest, treasure, and fusion. Stock consists of three distinct seeded cards, excluding fusion and curse cards. Prices are 40 common, 60 uncommon, 90 rare, 120 legendary. Each offer can be purchased once per visit. Healing costs 30 gold for up to 15 HP, once; full-health characters cannot buy it. Removal costs 40 gold for one exact instance, once; a confirmation previews the card and the deck must retain at least five cards. Purchases leave the shop open; leaving completes it permanently for this descent. Removing a discovered card does not erase its discovery.

The event is one seeded bargain: the hungry altar trades 8 HP for 35 gold (requires at least 9 HP); the wandering healer trades 20 gold for up to 12 HP (unavailable at full health). Either can be declined for free. A resolved event cannot be repeated. Each bargain describes its exact cost before acceptance.

Prices and modifier balance are provisional. No passive hunger or ember depletion has been added. Starting-build unlocks, more enemy/boss content, and human long-run balance testing remain the next priorities.


## Journey journal (Milestone 4B)

Saved journeys contribute card and relic discoveries to a persistent journal; fusion discoveries derive from the fusion-result card IDs. Seeing a card in a reward offer or archive does not discover it: acquiring it through the starting deck, a reward, merchant, or fusion does. Removal never erases discovery. Starting a new run keeps the journal; practice encounters do not contribute.

Personal records are the deepest floor actually entered, most rooms cleared in a single journey, and most bosses defeated in a single journey. Descending after a boss does not count the next floor until its first room is entered. Reloading cannot inflate these values. A separate journal save lets the active run be replaced while preserving discoveries and records. No lifetime win/defeat totals, character-stat increases, or unlocked starting builds are claimed in this milestone.

## Guardian variety

Version-5 maps select one of three guardians from the saved map seed. Repeats across descents are possible. The Warden remains unchanged. The Crypt Broodmother has 74 base HP: Venom bite (6 damage, 2 poison), Coil (9 block), Twin fangs (two 6-damage hits). The Ember Sentinel has 86 base HP: Bank the furnace (8 block), Scorch (8 damage, 2 burn), Furnace strike (15 damage). Cycles repeat and use standard descent scaling. The boss reveal offers an optional full-cycle preview before entry without exposing unopened cards. Boss rewards and descent rules remain unchanged. These starting values require human balance feedback.

## Deck-changing event bargains

New maps can reveal the Ember Forge (6 HP for one unupgraded card upgrade; at least 7 HP required) or Memory Well (25 gold for removing a chosen card; at least six cards before removal). Existing altar/healer events remain in the pool. Each event offers a free safe exit. Costs are confirmed with the selected card preview, and only a successfully saved choice completes the room. Repeat descents create fresh offers; balance is provisional.

## Shuffled floor order and hand carryover

Map version 7 shuffles the four interior floor bands and their lane contents using high-bit rejection-sampled random indices. Every route still visits two interior combat floors and two opportunity floors; each opportunity floor retains a rest option. The opening Rat and final guardian stay at the ends. Identical seeds replay identically and saves never reroll. Existing versions 1–6 keep their layout until the next descent. Small deterministic tilts (at most 1.5 degrees) are cosmetic only.

Unplayed permanent cards persist between turns. Each turn draws up to five more cards, bounded by the ten-card hand limit. Played cards discard or exhaust normally. Each encounter starts with fresh piles drawn from the current journey deck, including earned/fused cards and upgrades; exhaustion is encounter-local. Hand contents do not carry between encounters.

## Expanded fusion builds

Guard + Spark → Stormguard (1 energy): gain 6 block, deal 2 lightning damage, then apply 2 Shock. The damage consumes existing Shock before the new stacks are applied; its defense-card damage does not gain attack-only Strength bonuses. An upgrade grants 8 block, 4 damage and 3 Shock. Heavy Blow + Firebolt → Cinder Maul (2 energy): deal 15 attack damage and apply 4 Burn; upgraded, 17 damage and 5 Burn. Fire tagging triggers Ember Heart as normal. Both results are shrine-only, consume two exact source cards and their upgrades, and begin unupgraded. These recipes compete for Guard/Firebolt sources with existing fusions. Balance remains provisional.

## Starting builds

Wanderer uses the original starter deck. Stormweaver replaces Heavy Blow and one Strike with Static Lance and Spark, emphasizing Shock and lightning at the expense of direct heavy damage. Venomblade replaces Heavy Blow and Firebolt with Poison Edge and Quick Slash, emphasizing poison and repeated cheap attacks while giving up fire fusion sources. All retain 12 unupgraded cards, 50 HP, zero gold and Iron Sigil. Any journal fusion discovery unlocks Stormweaver; one recorded guardian victory unlocks Venomblade. Locked decks can be inspected at camp. These are provisional sidegrades, not proven equally balanced builds. Practice continues to use Wanderer.

## Quick combat feedback

Physical attacks produce a slash; fire, lightning and poison use their own bursts. Block gains and fully absorbed hits show shield ripples. Healing has rising motes, while buffs, card draw, discard and other support plays receive arcane feedback. Damage numbers show actual HP lost plus any absorbed amount. Status applications and periodic damage retain their element; combos get a short additional cue. The effects overlap rather than making players wait through a sequence. Normal feedback lasts 0.48 seconds, fast feedback 0.24 seconds, and reduced motion uses static labels. A killing blow displays its final impact before the result screen while the result save proceeds immediately.

## Ash Duelist

A 34-HP regular enemy available solo or beside a Rat. Its repeating cycle is Measured guard (7 block), Ash feint (4 damage and 1 Weak on the player), then Reckless lunge (11 damage and 2 Vulnerable on itself). Enemy end-phase expiry immediately reduces that Vulnerable to 1, leaving one player turn to exploit the opening before it guards again. Normal descent, Hardy and Fierce scaling apply. Battle plans show authored/scaled applications; live status counters show remaining stacks. This encounter is provisional pending human balance testing, especially Fierce ambushes.

## Merchant upgrade service

Each merchant visit offers one card upgrade for 50 gold, competing with healing, removal and new cards. Choose any owned unupgraded card, including fusion results, inspect its upgraded effects and confirm the cost. The exact copy is upgraded; deck size and instance identity stay unchanged. Canceling spends nothing. The service cannot be bought twice during the visit, including after reload. Pricing is provisional pending repeated-descent playtesting.

Last Ember grants one additional energy on the first turn when starting combat at half maximum health or less (rounded down). It stacks with other opening relics, never retriggers within an encounter, and remains owned between encounters. New maps use the five-relic treasure pool; maps through version 8 retain the original four.

Combat effects use eight-pose painted sequences: a steel crescent disperses into sparks; bronze and crystal assemble into a defensive ward and scatter; fire travels, blooms and dissipates as smoke; lightning branches and leaves residual arcs; venom splashes into mist; golden healing leaves spiral and unfurl; violet arcane wisps coil and unravel. The material treatment references existing card illustrations. Frame cross-dissolves smooth playback without zooming a still image. Effects do not change combat timing or RNG.

### Tactical encounters

New dungeons can reveal Rallying or Mending enemies in the same risk slots used by Hardy and Fierce. Rallying adds 1 Strength after each completed action, including defensive actions; each point increases subsequent damage effects. It applies once per action, including multi-hit actions, and resets with the encounter. Mending restores 3 HP after each action, never above maximum and never reviving a defeated enemy. Both bonuses remain fixed across descents; authored HP and damage/block still scale normally. Their victory reward includes the existing 10 bonus gold.

Rallying encourages ending or controlling fights before pressure accumulates. Mending rewards focused damage instead of spreading damage across targets. The opening encounter and guardians remain unmodified. Hidden cards conceal the modifier until path commitment; revealed battle plans and live intents show the added effects. Combat entry reloads reset temporary Strength and enemy health like other encounter state.

### Defensive fusion choices

Guard + Poison Edge produces Venom Ward (1 energy): gain 7 block and apply 3 Poison to one enemy. The card requires an enemy target, works with Venom Fang, and upgrades to 9 block/4 Poison. It trades direct attack damage and the Poison Edge combo setup for repeatable protection and poison pressure.

Guard + Mend produces Bloomguard (1 energy): gain 7 block and restore 4 HP, then Exhaust. The upgrade grants 9 block/6 HP; healing caps at maximum. It remains usable at full health for block. Exhaust removes it only for this encounter, so it returns in the next encounter's fresh deck. Fusing away Guard sacrifices that copy's repeatable defense and Shield Bash setup for a compact recovery play.

Both recipes consume two exact instances and their upgrades, create one base card, and follow the existing once-per-shrine saved confirmation. They are fusion-only and enter the persistent discovery journal when acquired. Balance values are provisional pending playtesting.

### Specialist starting builds

Gravewarden unlocks when the journal contains Glacial Barrier, Stormguard, Venom Ward or Bloomguard. It replaces Quick Slash with Brace and Firebolt with Enfeeble, sacrificing free damage and Burn/Overload setup for reliable block and Weak. Heavy Blow and the original Guard copies remain available for Shield Bash.

Embercaller unlocks after a Flaming Strike or Cinder Maul discovery. It replaces Heavy Blow with Cinder Storm and Frost Ward with another Firebolt, sacrificing a heavy direct hit and Chill/block for sustained Burn. Spark remains available for Overload, while future fusion competes for the Firebolt copies.

Both start with twelve unupgraded, non-fusion cards, 50 HP, zero gold and Iron Sigil. Acquiring a qualifying fusion unlocks a starting option for future journeys; it does not change the active deck. Existing journal discoveries qualify automatically. Camp allows inspection while locked; actual new-run selection and replacement are validated by the controller. Continue keeps the saved deck regardless of the current camp selection.

## Sanctuary: let go

At a rest site, choose exactly one action: heal 30% of maximum health, upgrade one card, or permanently remove one card. Let go costs no gold and requires more than five cards before removal. Any card instance, including an upgraded or fused card, may be removed after a preview and confirmation. Canceling or returning from the picker preserves the visit. Removal gives neither healing nor an upgrade; it trades immediate recovery or card power for more consistent future draws. Existing paid removal remains available at merchants and memory wells without consuming a rest opportunity.
