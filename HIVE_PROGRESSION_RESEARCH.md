# Hive progression review: zero to fifty bees

Reviewed October 20, 2026 using three research/audit subagents, source inspection, and isolated local Luau fixtures. **No connected-client tests, phone actions, deployment, or live gameplay verification were performed for v1.4.0.** The already running version was left alone.

## Evidence and confidence

The [official experience page](https://www.roblox.com/games/1537690962/Bee-Swarm-Simulator) explains growing the hive and opening mountain areas, but does not prescribe an optimal composition. Exact mechanics below come from community-maintained wiki articles. Composition advice comes from the supplied [Early-game Guide 101](https://docs.google.com/document/d/1MSUCkabnBP2NJ0VE_Au-wfJoSGeRddEmveW5jW2e7gw/edit), not a universal developer-approved recipe. The web search provider failed; the guide was retrieved through its text export and researchers retrieved wiki text through the MediaWiki API.

There is no single optimal hive independent of available bees, gifted coverage, resources, and progression objectives. This update preserves the user's existing blue-hive targets, event priorities, Star Jelly authorization, saved-leftover behavior, and Ninja/Lion caps. It changes safety and planning where evidence supports a concrete improvement.

## Progression decisions

| Occupied bees / capacity | Hive-only priority | Implemented behavior and limits |
| --- | --- | --- |
| 0–24 occupied | Fill empty unlocked cells before expensive rerolls. Use an owned Basic Egg before acquiring another. | `Growth` reports occupied bees, unlocked capacity, empty cells, and the next acquisition step. Runtime waits for Atlas/manual hatching before rerolling a partially filled starter hive. It does not send unverified hatch/purchase calls. |
| Full starter hive, capacity below 35 | Balance useful collectors/support with more occupied slots; avoid presenting fixed legendary quotas as a prerequisite to expansion. | `Growth.Action` reports `expand-capacity`. Existing later force quotas remain; no invented shop interface or automatic slot purchase was added. |
| 35–39 | Keep the first gifted copy of each type while preparing eventual Star Eggs, within available space. Duplicates require a separate justification. | `PreserveUniqueGifted=true` keeps one of each currently owned gifted type in pre-Star-Egg stages, including species formerly treated as unlisted. New needed gifted outcomes end the active task safely; duplicates do not steal existing reservations. |
| 40–43 | Continue the user's gifted Rare/Epic and flexible collector progression; use the separate Gifted Basic workflow when its established gates qualify. | Preserve exact ten separately verified Basic Egg purchases, refill qualification, same-coordinate tasks and saved leftovers. A Basic lock now stops before overwriting a newly kept bee and retains its purchase count for reconciliation. |
| 44+ before two recorded Star Eggs | Assemble current-hive gifted coverage and meet existing Star Egg prerequisites. | Keep the existing embedded Star Egg preparation and rechecks. No egg is spent by this offline task. |
| 46–49 after existing gates | Follow the user's blue progression, respecting protected bees and species caps. | Existing stage transitions/targets remain. Slot count alone is not a general claim of gear/amulet readiness. No farming, quest, equipment, or gear automation was added. |
| 50 | Check the full composition and whether its requirements can coexist in fifty slots. | `CapacityStatus` reports a lower bound on required cells, shortfall, and per-species counts. Capacity conflicts prevent false endgame-complete claims. They are diagnostics, not permission to discard protected bees or change the requested ratios. |

The [Hive Slot article](https://bee-swarm-simulator.fandom.com/wiki/Hive_Slot) documents 25 initial unlocked cells and expansion up to 50. Capacity and occupied count must therefore remain separate. The old runtime always reported at least 25 slots even with zero occupied cells, and could not itself hatch the first bee or buy a new slot. **Autonomous zero-to-fifty acquisition is still not implemented.** Implementing it requires trustworthy empty-cell coordinates, shop price definitions, accepted-response semantics, and reconnect reconciliation. The user forbids real testing, so those interfaces were not guessed or probed.

## Gifted bees, eggs, and spending

- [Gifted Bee](https://bee-swarm-simulator.fandom.com/wiki/Gifted_Bee): duplicate hive bonuses do not stack. Duplicates may still provide useful abilities/tokens; this does not justify removing the requested Baby/Music/Bubble/Frosty/Diamond quantities.
- [Egg](https://bee-swarm-simulator.fandom.com/wiki/Egg#Star_Egg): Star Egg exclusion depends on gifted types **currently in the hive**, including Basic, rather than merely discovered types. Existing embedded preparation already uses current-hive coverage and must recheck per egg.
- [Star Amulet](https://bee-swarm-simulator.fandom.com/wiki/Star_Amulet): discovered gifted types are relevant to amulet unlocks. Do not confuse that with Star Egg coverage or infer readiness from slot count alone.
- [Basic Bee](https://bee-swarm-simulator.fandom.com/wiki/Basic_Bee) and [Basic Egg Shop](https://bee-swarm-simulator.fandom.com/wiki/Basic_Egg_Shop): Basic cannot be obtained from Royal/Star Jelly, so its existing egg workflow remains separate. Price assumptions for a brand-new account should not be borrowed from the established ten-million-honey late workflow.
- [Royal Jelly](https://bee-swarm-simulator.fandom.com/wiki/Royal_Jelly): the documented rarity/gifted odds make targeted outcomes uncertain. An unsuccessful batch is not by itself a defect, and small leftover inventory is not authority to start a fresh underfunded task.
- [Tadpole Bee](https://bee-swarm-simulator.fandom.com/wiki/Tadpole_Bee): gifted Tadpoles supply Baby Love; the existing Baby reduction correctly counts gifted Tadpoles rather than every Tadpole.

### Concrete final-capacity conflict

The existing final requirements need 48 slots before Babies and additional protected species: eight true singles, three more gifted Diamonds, four Music, five named event bees, ten Tadpole, seventeen Buoyant, and one Fuzzy. With one gifted Tadpole, the existing Baby formula still reserves three Babies: **51 required slots**. A retained Cobalt makes that lower bound 52. More gifted Tadpoles can reduce the Baby demand, so this is a conditional conflict, not proof every final configuration is impossible.

The update reports that conflict and refuses to label an over-capacity fixture complete. It does not change the user's final targets or force a new spending priority to resolve it. `CapacityStatus` is a current planner lower bound; it is not a full future optimization solver.

## Reliability changes

1. **Uncertain mutations persist through transport failure.** `FullHiveUncertain` retains a mutation receipt until the corresponding item/purchase response and state checks succeed. A thrown or malformed response cannot silently become permission to retry on the next launch. Receipt fields identify the item and coordinate/amount. Stats-read failures remain distinct. A process crash still erases in-memory receipts, so fresh server reconciliation remains necessary.
2. **Fresh finite-budget check.** After movement and inventory refresh, a bulk Royal Jelly roll that could exceed the remaining finite budget is switched off and deferred before sending a request. This covers inventory growth after the earlier cached check.
3. **Basic lock revalidation.** Existing protected/kept results are checked both at workflow entry and immediately before the mutation. The workflow stops for review while preserving the lock/purchase count; it never blindly resumes an uncertain spend.

## Offline validation and remaining work

The official [Luau CLI release](https://github.com/luau-lang/luau/releases/tag/0.743) ran all five existing isolated suites plus the new progression/safety suite against a fixed rarity fixture and minimal local value shims. These tests have no game, network, or connected-client API. The generated main bundle and embedded Star Egg code compile; the existing 36-marker compatibility check passes. Offline success does not establish executor compatibility or natural live results.

Deferred work is explicit: verified empty-cell hatching and slot acquisition, safe online reconciliation of mutation receipts, configuration-aware final composition resolution, and readiness signals supplied by a future inspected interface. No real test or deployment is authorized by this document.
