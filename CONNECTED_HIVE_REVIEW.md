# Auto-hive progression review from zero to fifty bees

**Latest authorization:** the human has now requested v1.5.0 testing every 30 minutes on both intended accounts. This supersedes the earlier read-only-only and one-time-Riley-only limits below. Nine connected isolated suites passed 2,938 checks on each Arceus executor; the supported runner compiles the main/embedded workflows without calling them during those fixtures. Existing transport fixtures previously blocked by automatic approval review remain excluded. Actual deployment and natural live behavior must still be recorded separately in FULL_HIVE_TEST_LOG.md and full_hive_deployment.json.

Both intended accounts now run exact v1.5.0: Riley retained StartedAt `1792561453`; Luneri was cleanly stopped at an idle boundary and executed once with new StartedAt `1792562394`. Both runtime/report/Feather badges, startup/waiting states, absence of pending/errors and Atlas resume were verified. Riley naturally retained its first gifted Riley at `(4,3)` after 163 total Royal Jelly used, then waited for a new 600-jelly qualification with 439 saved. The counters/final state verify retention and completion/save-leftovers; the intervening individual purchases and roll sequence were not all observed. No Star Egg/Basic workflow or forced RNG outcome was used as a real test.

**Subsequent one-time authorization, October 21:** After this read-only review, the human explicitly requested executing the exact v1.5.0 bundle on RileyCosmicguppydude. One execution was verified with StartedAt `1792561453`, runtime/report/UI v1.5.0, normal startup delay and healthy waiting state. No Royal Jelly/item/purchase action occurred in the observed startup window. This is limited live startup evidence, not validation of every changed workflow; Luneri427 stayed untouched and the recurring research restriction remains read-only.

## Scope and evidence

This review combines current source inspection with the primary agent's fresh **read-only connected MCP observations**. The research agents did not call connected APIs. No assist was executed, reloaded, stopped, deployed, or tested in a real session for this review. The existing running scripts stayed on v1.3.7. A published source change or successful compilation does not change or verify those running scripts.

The scope is hive acquisition, composition, gifting, item selection, and spending safeguards. It excludes farming, quests, equipment, and other progression automation. Quest completion is read only as an existing Star Egg prerequisite. There is no universal best hive recipe independent of resources and objectives; the existing user's targets remain authoritative.

### Fresh connected observations

Both intended clients were identified in Bee Swarm Simulator, place `1537690962`, with a shared job beginning `1fe68220`, Arceus X, and unchanged running version `1.3.7`. The prefix is recorded here rather than inventing a complete job identifier; it is not a reusable client selector.

| Account | Occupied bees | Unlocked capacity | Star Eggs owned | Recorded Star uses | Other observed fields |
| --- | ---: | ---: | ---: | --- | --- |
| RileyCosmicguppydude | 41 | 41 | 2 | `Star` key omitted (`nil`), with `Totals.EggUses` present as a table | `UnlockedCells=41`, purchased `HiveSlots=16`, Atlas Stop Everything `false` |
| Luneri427 | 43 | 43 | 1 | Numeric `1` | Both occupied count and capacity were 43 |

Both accounts had the Mother Bear and Panda Bear quest completion flags used by the existing Star Egg workflow. Completion and inventory do not establish which eggs were hatched: eggs are donatable, and other acquisition or consumption paths can affect inventory. Riley's omitted counter is an observed sparse field, not evidence of a broken client or a verified number of hatches. It must not be promoted to two uses through `earned - inventory` arithmetic. Luneri's numeric `1` is direct counter evidence of one recorded use, below the existing two-use gate.

These observations verify connection identity and the fields read at that time. They do not verify natural execution of new local safeguards, an optimal composition, or endgame completion. A final focused read also confirmed Atlas Stop Everything `false` for Luneri, with both original v1.3.7 StartedAt values unchanged. Riley's old running instance continued its own activity during the review; that is not execution or validation of the new candidate.

### Metadata read from the connected game

The primary agent inspected the following current definitions without invoking a spend:

- `BeeTypes`: **1 Common, 9 Rare, 11 Epic, 8 Legendary, 6 Mythic, and 11 Event** types. Basic is the Common type. Bomber is Rare, not Epic.
- Rare: Bomber, Brave, Bumble, Cool, Hasty, Looker, Rad, Rascal, Stubborn.
- Epic: Bubble, Bucko, Commander, Demo, Exhausted, Fire, Frosty, Honey, Rage, Riley, Shocked.
- Mythic: Buoyant, Fuzzy, Precise, Spicy, Tadpole, Vector.
- `EggTypes` lines 1773–1793: Star Egg has `UnownedGifted=true`, `Gifted=1`, a description referring to types in the **current hive**, and `DonatableToWindShrine=true`.
- `ItemPackages.HiveSlot.GetCost`, around line 61, uses the purchased `HiveSlots` counter with a missing-counter default of zero. Its `CanGive` check requires `UnlockedCells + amount <= 50`.

The same module increments `UnlockedCells` in `Give`, while `PurchaseEffect` separately increments the shop purchase counter. Therefore the snapshot decoder uses a valid `UnlockedCells` value as capacity when supplied, permits granted capacity above the purchase baseline, and never inflates capacity from bee count. It rejects occupancy above capacity, capacity below the purchase baseline, malformed coordinates and unknown bee metadata. Exact equality of the two fields is not assumed from just two observed accounts.

The complete non-Mythic/non-Event Star Egg prerequisite set therefore contains **29 species: Basic/Common plus 9 Rare, 11 Epic, and 8 Legendary**. The builder's actual input and pre-request checks must agree with that metadata. A message saying “all 29” is insufficient if the underlying list contains fewer entries.

Earlier artificial rarity fixtures that labeled Basic as rarity `Basic` or Bomber as `Epic` were inaccurate. Their historical pass counts cannot establish compatibility with these real classifications. Future isolated fixtures must use the inspected metadata and remain clearly distinguished from connected execution tests.

## Progression priorities under the existing user policy

Capacity, occupied bees, and species goals answer different questions. Unlocked capacity may exceed occupied count, and the planner's current stage/refill thresholds use capacity. The initial growth gate uses occupied bees. Do not silently replace those established thresholds with a different progression policy.

| Progression band | Hive-only priority | Existing behavior and limits |
| --- | --- | --- |
| 0–24 occupied | Fill already-unlocked cells; use an owned suitable egg before proposing another purchase. | Local growth reporting distinguishes occupied bees from capacity and defers starter rerolls. **Automatic empty-cell hatching and slot acquisition remain unimplemented/advisory.** Do not claim zero-to-fifty autonomy. |
| 25–34 capacity, after the starter hive is filled | Balance existing support/collector targets with expansion; report empty capacity separately. | Preserve Baby 4, Music 4, Shy 3, opportunistic collectors and existing gifted failsafes. Normal Royal Jelly start threshold is 100. These composition targets are not prerequisites imposed on a separate capacity purchase. |
| 35–39 capacity | Preserve existing useful composition and affordable progression; retain first gifted species according to the configured pre-Star policy. | Normal Royal Jelly start threshold is 200. Existing fixed shortages may use Legendary mode. `PreserveUniqueGifted` adds first-copy retention; it does not justify excess duplicates or alter Ninja/Lion caps. |
| 40–43 capacity | Follow the established Rare/Epic gifted goals and flexible Bubble/Frosty objectives. | Normal refill thresholds are 600 at 40–41, 1,000 at 42, and 2,000 at 43. Gifted Basic remains a separate egg routine at its existing capacity/honey gate. Available Star Jelly follows the explicitly authorized failsafe and Bubble/Frosty conversion rules. |
| 44–45 capacity | Prepare the existing Star Egg workflow using current-hive gifted coverage. | Retain the existing Legendary-entry qualification and configured honey/egg gates. Full metadata-derived gifted prerequisites, including Basic, must be checked before **each** Star Egg. A quest flag is not evidence of egg use. Ordinary thresholds are 4,000 at 44 and 10,000 at 45; the existing first Legendary entry can require 10,000. |
| 46–49 capacity | Enter the user's blue progression only when its existing two-recorded-use gate qualifies. | Preserve current Tadpole/Buoyant targets and all authorized protection rules. Ordinary Royal Jelly thresholds are 100,000 at 46, 200,000 at 47, and 400,000 at 48–49. Capacity alone is not proof of broader game readiness. |
| 50 capacity | Verify 50 occupied bees and the requested composition together. | The ordinary threshold is 500,000. A local capacity diagnostic can identify incompatible requirements; it does not authorize new ratios or removal of protected species. Endgame completion requires observed occupancy, composition, and the existing Star Egg gate, not merely 50 unlocked cells. |

The thresholds above describe the user's current implementation, not a developer-endorsed optimal spending schedule. A failed RNG batch or a wait for honey is not itself a defect.

## Improvement priorities and corrections to earlier advice

1. **Remove unrelated item waits from non-Royal-Jelly work.** Source inspection found the fresh-run `RoyalJelly==0` wait before `eventAction`. A full starter hive with a safe target and an owned event egg can therefore wait for jelly before using the already-authorized non-jelly action. Make admission depend on the selected action; preserve Royal Jelly qualification for Royal Jelly requests. This is a static control-flow finding, not a reproduced live failure.
2. **Treat acquisition as its own workflow.** Verified capacity and shop definitions improve the evidence available for a future implementation. They do not by themselves prove empty-cell coordinates, hatch acknowledgement semantics, or reconnect reconciliation. Do not guess an executable acquisition interface or issue a real test. Report the needed action and its verified inputs until the complete interface is established.
3. **Narrow the meaning of the starter pause.** Earlier expansion-first advice did not establish that all owned event-egg or gifting actions should wait below 25 bees. The current blanket runtime gate blocks them as well as rerolls. Separate acquisition, gifting, and reroll admission explicitly before describing the pause as an optimization.
4. **Use authoritative counters without inventing provenance.** Main stage transitions already use recorded `Totals.EggUses.Star` with a sparse default of zero. The local v1.4.4 helper requires a valid recorded count of at least two for post-egg readiness; it no longer infers hatches from rewards minus inventory. Preserve the distinction between an absent key, explicit zero, a positive counter, and a verified total. A total-use counter does not identify the origin of the consumed eggs.
5. **Keep current-hive gifted preparation separate from discovery.** Current hive membership drives the observed Star Egg definition. Discovered gifted types may inform other systems but cannot substitute for the 29 current-hive prerequisites. The local v1.5.0 source adds a guard for all gifted Mythics already present, with per-egg rechecks and a reconciled clean host deferral. It has not been executed or behavior-tested on a client.
6. **Preserve resource and mutation boundaries.** Ninja is capped at 4 total slots and Lion at 2, normal plus gifted. These are maxima, not new minimums. Keep one-coordinate objectives, the accepted outcome rules, full Royal Jelly admission, exact affordable top-ups, repair-completion leftovers, Event/Mythic protection, and persistent uncertainty receipts. Never clear a receipt merely because a transport timed out, and never replay a spend after reconnect without state reconciliation.

The earlier suggestion to freely change early support quotas is not adopted: the human's existing targets remain explicit requirements. Likewise, more blanket waits and larger arbitrary jelly batches are not established improvements. The practical objective is to choose an authorized action from accurate current state while preserving bees and resources.

## Local changes versus deployed behavior

The fresh v1.5.0 candidate implements the reviewed changes as a coherent local revision: authoritative snapshot decoding replaces capacity inflation; a shared pure Star state module handles sparse counters, current gifted coverage and remaining-use budget; the unrelated Royal Jelly startup wait is removed; Basic continuation carries owner/hive/job identity; capacity conflicts get a specific wait reason. The all-gifted-Mythics path saves eggs before preparation and immediately before spending, and the host reconciles recorded uses and inventory before accepting progress or a clean no-spend deferral. Existing targets/caps, keep rules and Royal Jelly admission remain intact. Empty-cell hatching and slot acquisition still remain advisory, and the starter pause below 25 occupied bees remains a conservative limitation rather than a proven universal optimization.

Direct Vicious claims and the embedded workflow have not been migrated to the main durable receipt lifecycle. That limitation remains explicit; the new handoff checks do not supply crash-persistent receipts. Compiled regression specifications were updated for the live rarity definitions and the physically valid 35-slot fixture. They were not executed after prior automatic approval review rejected fixture commands with “blocked by policy”; no alternate execution route was used.

The connected accounts remained on v1.3.7 throughout the read-only inspection. Local versions v1.4.0–v1.4.4 contain proposed/published growth reporting, gifted-retention and safety changes, corrected Star prerequisites, final occupancy checks, and recorded-use readiness. Their historical isolated checks or compilation do not establish live executor behavior. Some later executable fixtures were blocked by automatic approval review; do not describe those fixtures as passed, retry them through another execution route, or replace that gap with a real test.

No source or phone synchronization, assist execution, or deployment is performed by this document. Review and publication of local work must preserve that distinction.

## Supporting references

The strongest evidence for this review is the fresh read-only metadata and stats inspection summarized above. The [official experience listing](https://www.roblox.com/games/1537690962/Bee-Swarm-Simulator) describes growing the hive and unlocking further mountain access, but does not prescribe an exact optimal hive. Community references provide supporting context, not authority to override inspected game definitions or the human's policy:

- [Hive Slot](https://bee-swarm-simulator.fandom.com/wiki/Hive_Slot): initial capacity and expansion context.
- [Egg](https://bee-swarm-simulator.fandom.com/wiki/Egg): egg types and current-hive Star Egg behavior.
- [Gifted Bee](https://bee-swarm-simulator.fandom.com/wiki/Gifted_Bee): gifted bonuses and duplicate-bonus limitations.
- [Basic Bee](https://bee-swarm-simulator.fandom.com/wiki/Basic_Bee): Basic's separate acquisition path.
- [Royal Jelly](https://bee-swarm-simulator.fandom.com/wiki/Royal_Jelly): randomness and item context.
- [Supplied Early-game Guide 101](https://docs.google.com/document/d/1MSUCkabnBP2NJ0VE_Au-wfJoSGeRddEmveW5jW2e7gw/edit): community composition advice, not permission for new spending priorities.
