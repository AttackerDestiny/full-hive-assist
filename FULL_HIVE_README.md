# Full Hive Assist

**v1.4.4 offline correction:** Standalone Star Egg rebuild readiness uses a valid recorded hatch count, never quest rewards minus current inventory. Two recorded hatches are required alongside the existing quest/inventory conditions. This source-only correction has not been fixture-tested or deployed.

**v1.4.3 offline correction:** Completion requires 50 occupied bees, not just 50 unlocked cells and satisfied composition targets. Empty final cells remain an Atlas/manual hatching advisory. This version is statically reviewed only; fixture execution was rejected by automatic approval review. No real tests or deployment were performed.

**v1.4.0 offline build:** The current research task prohibits live testing or deployment. See [the zero-to-fifty hive review](HIVE_PROGRESSION_RESEARCH.md) for new growth/diversity/capacity diagnostics, mutation safeguards, evidence, and acquisition limitations. Historical live instructions and observations below are not authorization to run this new build on a connected client.

**v1.3.7 user caps:** Ninja has a maximum of 4 total hive slots and Lion a maximum of 2, including normal and gifted copies. A cap does not add a minimum quota. The planner prioritizes surplus slots before optional flexible conversion, and excess copies remain eligible during collector recovery instead of being retained as collector outcomes. Existing unique gifted failsafes may replace a normal copy; subsequent cleanup releases the normal surplus. Permanent protection, later stage goals, same-coordinate objectives, refill thresholds, and completion/save-leftovers rules are preserved. Existing excess bees are replaced only through the regular resource-qualified workflow.

**v1.3.6 Star Jelly upgrades:** In addition to missing gifted Rare/Epic failsafes, available Star Jelly can upgrade an eligible normal Bubble/Frosty selected by the existing planner. It can start without the Royal Jelly refill threshold, uses one Star Jelly per request with all roll-to flags off, and stays on that coordinate through intermediate results until the existing keep rules complete it. No new hive targets are introduced. While Star Jelly remains, this unfinished conversion does not become 100-jelly recovery. Once Star Jelly runs out, existing Royal Jelly qualification and repair rules apply. The Royal Jelly completion/save-leftovers rules remain unchanged.

**v1.3.5 refill fix:** Recovery affordability uses only the Royal Jelly still missing from the normal target, including the initial legendary entry target. Buying the first pack of a larger refill no longer switches an affordable top-up into 100-jelly recovery. Active repair still persists until completed; normal admission and saved-leftover rules remain unchanged.

**v1.3.4** removes the 40-slot Star Jelly cutoff. Item selection checks the eight existing gifted Rare/Epic failsafes (Bumble, Cool, Looker, Bomber, Bubble, Commander, Bucko, Frosty) at every stage. If any is missing and Star Jelly is available, use it first, one at a time, on the planner's eligible target with all roll-to flags off. Recheck inventory and the goal immediately before spending. All eight present means Royal Jelly only, even if Gifted Basic or gifted legendaries are missing; Basic retains its own egg routine. With no Star Jelly, continue Royal Jelly normally. Star Jelly does not require a Royal Jelly batch or advance its consumption budget. Existing stage targets, keep/protection rules and the v1.3.3 save-leftovers behavior remain in effect. `FullHiveReport.StarJelly` and `StarJellyMissing` expose the inventory/goal.

**v1.3.3** supersedes the v1.3.2 use-all rule. Admission now ends when a normal coordinate finishes or recovery repairs all wrong slots. Remaining inventory is saved; a new normal conversion must meet the normal >=refill threshold again. Thus, a good hive with200 RJ and a2000 target waits/tops up before converting another normal Bubble/Frosty. An unfinished normal task still uses its admitted batch on the same coordinate without being downgraded by intermediate results. If that batch actually exhausts, low-cost recovery may repair the wrong slot, then stops at a safe hive rather than immediately starting another gifted conversion. Genuine recovery may use the remainder across multiple wrong slots until repaired. Basic/Star workflow completion also closes its admission. Existing safety and keep rules remain unchanged.

**v1.3.2** keeps an admitted Royal Jelly batch usable until it reaches zero, across slot completion and refill/recovery changes. Identity/hive/server checks still apply. The start threshold remains inventory >= current refill; a later small gift cannot restart an exhausted batch. Gifts during an active batch remain usable. A normal batch takes precedence over an unaffordable future refill, so a temporary noncollector result cannot downgrade the active task into 100-jelly recovery. Fresh full normal inventory also prevents recovery entry. Genuine recovery retains its keep rules until repaired, then its remaining jelly can continue in normal mode. This supersedes the older rule that reset admission on refill/mode changes. All existing target safety checks remain; completion/protection takes precedence over spending.

**v1.3.1 clarification:** The user confirmed the batch start rule is **inventory >= current refill amount**, rather than exact equality. Luneri427's Potassium client had 2,299 Royal Jelly with a 2,000 target; the planner correctly selected normal Frosty for gifted conversion, but v1.3.0's strict equality blocked it. Inventory above the target now opens a batch without buying more. Inventory below the target still requires a full refill, and admission still clears at zero or a refill/recovery-mode change. This supersedes the equality/excess-inventory rule in the historical v1.3.0 notes below. Both PC Potassium and Android Arceus X use the same gate. The UI appears after the fixed 60-second delay; Atlas loading does not gate UI creation.

**v1.3.0** requires an exact inventory/refill match to admit each Royal Jelly batch. An admitted batch can continue below its starting amount until exhausted; its state is scoped to the player, hive, server, refill amount and recovery mode. Zero inventory clears admission immediately, so a later +1 gift cannot restart Until Gifted. A partial inventory is topped up to the exact target only when the full missing amount is affordable; ordinary pack sizes are retained, with supported smaller packs for the remainder. Excess inventory is held without rolling or further buying. Restoring a normal refill after 100-jelly recovery requires fresh admission at that normal amount. The legendary entry batch displays and requires at least a 10,000 target, then normal stage refills resume once that entry batch is exhausted. Main rolls, Gifted Basic and the embedded Star Egg workflow share the gate, with a final check before each Royal Jelly remote. `FullHiveJellyBatch` and `FullHiveReport.JellyBatch` expose admitted batches. This supersedes the older zero-only refill rule below. All 1,590 connected regression checks pass, including 304 batch checks.

Both Feather panels now support mouse/touch dragging from the header, with screen bounds, single-finger tracking and signal cleanup. The buttons, bee cards and scrolling remain interactive. The live UI smoke test passed 10 mouse/touch/scale/bounds checks.

**v1.2.1 — Feather.** The status UI is branded **Feather** with a native feather sticker after the name, a navy/blue/violet gradient, version badge, clear phase/activity text, slots/jelly/refill badges, and rounded **View hive** / **Stop assist** controls. The expanded hive tab uses the same theme. `feather_theme.luau` provides the shared style; the builder embeds it before the hive-view module. The name and appearance changes do not alter hive progression rules.

**v1.2.0** adds **View hive** beside Stop assist. It opens a responsive larger panel with the normal/gifted game icons, levels, gifted stars and live hive coordinates in the same bottom-up order as the game. Tap a bee for its name/level/coordinate, and use **Close** to return. The current roll slot has a blue outline. The viewer updates once per second while open from `ClientStatCache` only; opening, closing and selecting cards do not invoke remotes or change farming/hive settings. Its source is `hive_view_ui.luau`, embedded in the standalone bundle by `build_full_hive.ps1`.

**v1.1.1** explicitly validates the existing keep rules during 100-jelly recovery. A needed gifted failsafe or Baby/Music/Shy ends that slot's recovery and is kept; excess copies remain eligible according to the existing limits. A gifted Baby/Music upgrades a normal copy rather than creating an extra force slot. Useful normal Commander/Looker/Fire placeholders are also retained during mid/late recovery when the crit/red force group is short. Event/Mythic protection and stage-specific reservations still apply. The connected regression runner now passes 1,286 checks (696 policy, 46 character recovery, 544 collector recovery).

**v1.1.0** generalizes collector recovery to every stage whose normal refill is above 100. If that refill is unaffordable and safe non-collector slots remain, buy one 100-jelly pack at a time and repair those slots. Below 20 billion honey, all roll-to settings stay off and every hive request consumes one Royal Jelly; Bubble, Frosty, Lion or Ninja completes a collector slot. At 20 billion honey or more, recovery uses Until Gifted for gifted Bubble/Frosty. Needed force bees and gifted failsafes are retained when obtained. Recovery persists until the safe wrong slots are repaired, then restores the normal stage refill (for example, 100 back to 1,000); existing jelly is used before another refill. `FullHiveReport.RefillAmount`, `NormalRefillAmount`, `CollectorFallback`, and `SafeNonCollector` expose this state.

Any game bee not reserved by the written rules is eligible, including normal Brave/Bumble and unlisted gifted types. Event/Mythic protection, explicit cap exceptions, force quantities, and gifted failsafe reservations still take precedence. An old active task on a wrong slot adopts recovery mode at the same coordinate; an existing collector is held while other wrong slots are repaired.

The user's supplied original specification is retained in `base_prompt.reference.txt`; the v1.1.0 clarification above extends its refill behavior. The initial collector suite added 350 checks for generalized entry, collector outcomes, the 20B boundary, default-safe types, protection and restoration of the original refill; v1.1.0 passed 1,092 checks in total. The v1.1.1 totals and extra keep-rule coverage are recorded above.

**v1.0.2** recovers from character loss before a request or during movement. It cleans up movement, resumes Atlas, waits for a living character and root, then refreshes server stats and revalidates the active slot. Action counters and the coordinate lease survive recovery. Uncertain requests, unrelated failures, and failures caught inside the embedded Star Egg workflow still stop the assist. `FullHiveReport.RespawnRecoveries` counts recovered interruptions. The current monitor runs without subagents.

Regression checks for the connected client can be run with `./tools/test_connected_client.ps1 -ClientId <id>`. These compile the bundle and embedded Star Egg source and exercise the policy and character recovery in isolation; they do not execute the bundle or spend inventory.

The first numbered release is **v1.0.0**. The status panel, `getgenv().FullHiveVersion`, and `getgenv().FullHiveReport.Version` show the running version. Rebuilding a file does not replace an already running instance: after each approved update, stop the old assist cleanly, wait for pending requests to resolve, execute the rebuilt bundle once, and verify its version and new `StartedAt`. The 30-minute monitor follows this deployment rule.

Run Atlas first, then execute the entire `auto_full_hive_assist.luau` file in **Arceus X Android**. The same bundle remains compatible with Potassium for desktop testing. It contains its policy and the existing Star Egg script, so no local-file support or additional loader is needed.

The assist now waits a fixed **60 seconds** after auto-execution before loading hive modules or requesting player stats. You can auto-execute both scripts together; the assist remains in `startup-delay` during that minute.

The bundle was rebuilt after the previous interrupted build left a three-byte `mak` file. The current generated file starts with `-- Full Hive Assist for Atlas / Arceus X Android / Potassium` and is written atomically by `build_full_hive.ps1`; the builder rejects truncated output below 50,000 characters.

The initial compatibility pass was validated statically and on Potassium. Subsequent tests connected the Arceus X cloudphone; v1.0.2 compiles there and has live 41-slot startup coverage. Its recovery checks run the real helpers and movement code against isolated test doubles. Later progression and a naturally occurring respawn after this fix still require live observation.

Arceus compatibility changes include:

- `getgenv` fallback to `_G`, guarded `loadstring`/`load`, `table.pack`/`table.unpack` fallbacks, and identity-aware module loading.
- `QueryDescendants` fallbacks using bounded descendant traversal for Atlas discovery and movement collision handling.
- Atlas control discovery that accepts `getconnections` plus either `debug.getupvalues` or global `getupvalues`, with `firesignal`, direct handler, and `GuiButton:Activate()` fallbacks.
- A configurable `AtlasInitiallyStopped` flag for executors that expose the Atlas button but no callback/upvalue inspection. Leave it `false` when Atlas starts with Stop Everything off; set it `true` when it starts on.
- Android touch handling through `GuiButton.Activated`, a high-display-order status panel, and a mobile-safe top position.
- `WaitForChild`/identity-aware loading for slow Android joins, fixed 60-second startup delay, atomic bundle generation, and a one-argument compile fallback for mobile `loadstring` wrappers.

Use the following optional prelude before executing the bundle when Arceus does not expose `getgenv` (the bundle itself also falls back to `_G`):

```lua
getgenv = getgenv or function() return _G end
```

For an Arceus build where Atlas exposes the Stop Everything button but callback introspection is unavailable, configure the known initial state before running:

```lua
getgenv().FullHiveConfig = {AtlasInitiallyStopped = false}
```

Do not set this to `true` unless Atlas is visibly already stopped. The assist cannot safely infer a hidden switch state without callback/upvalue APIs.

Atlas itself is an obfuscated third-party loader with its own executor gate (`getthreadidentity() >= 8`, `loadstring`, `buffer`, and `string.pack`). If Atlas displays “Your executor is not supported,” the assist cannot bypass that gate; Atlas must be loaded by an Arceus build that satisfies its requirements, or the Atlas loader must be replaced.

The default run is continuous and can spend honey, tickets, stingers, eggs, Star Treats, Star Jelly, and Royal Jelly according to the progression rules. It pauses Atlas through its verified **Stop Everything** control while working, restores the original roll settings, and turns Stop Everything off while waiting or after stopping. Cleanup retries Atlas release even if the local lease flag was lost, and the status panel surfaces cleanup errors. A status panel includes a Stop button.

Stop from the executor with:

```lua
getgenv().FullHiveStop = true
```

Optional settings must be assigned **before** executing the bundle. Remove old test overrides with `getgenv().FullHiveConfig = nil` for the normal continuous run.

```lua
-- Preview only: no movement, setting changes, purchases, or item use.
getgenv().FullHiveConfig = {DryRun = true}
```

```lua
-- A bounded test. Finite jelly limits use individual rolls when necessary
-- so server auto-jelly cannot exceed the remaining budget.
getgenv().FullHiveConfig = {
    MaxActions = 2,
    MaxRoyalJellies = 10,
    AutoPurchase = false,
}
```

`getgenv().FullHiveReport` exposes the stage, needs, next target, item consumption, purchases, errors, and Atlas pause state. Limits count item requests and purchase requests; a normal unlimited auto-jelly request can consume many jellies.

## Stage decisions

- Slots 25–39: collector floors, ranked crit/red placeholders, four Baby, four Music, three Shy, and opportunistic gifted failsafes. Single-count gifted failsafes are exact: once one gifted Cool, Looker, Bumble, Bomber, Commander, Bucko, Carpenter, Demon, Lion, Diamond, Ninja, Shy, or Basic exists, that target is satisfied; duplicate gifted copies remain eligible for reroll. Bubble/Frosty keep their quantity-flexible rules. Star Jelly is used before Royal Jelly. Legendary mode becomes available at 35 slots for the fixed legendary shortages.
- Slots 40–43: gifted rare/epic targets, then conversion of normal Bubble/Frosty, using surplus normals before releasing one collector force slot. Conversion follows the last gifted Bubble/Frosty result when choosing the next force species.
- Collector recovery at any stage with a normal refill above 100: if the stage refill cannot be afforded and safe non-collector sources remain, buy one 100-jelly pack and keep the same coordinate through unrelated results. Below 20B honey, single rolls target Bubble/Frosty/Lion/Ninja with all roll-to settings off; at 20B+, Until Gifted targets gifted Bubble/Frosty. Restore the normal stage refill after all safe non-collector sources are repaired.
- Slots 44+: the gifted legendary phase starts after observing at least 10,000 Royal Jelly. This entry state persists for the session. If needed and affordable, the assist buys the stage refill in its prescribed packs until the entry amount is reached; normal subsequent refills begin only when jelly runs out.
- Gifted Basic: enabled from 40 slots at 3 billion honey. A persistent slot lock buys a batch of **ten separate Basic Egg purchases**, each request using `Amount = 1`, while staying at the Basic Egg shop. Only after all ten purchases are verified does it return to the hive and alternate one Basic Egg with one Royal Jelly. A partial batch count persists across a stop and resumes without retrying an uncertain purchase. A new Event/Mythic in that slot stops the process rather than overriding permanent protection.
- Star Eggs: at 100 billion honey with the eight specified gifted legendary species present, the assist hands control to the existing `auto_use_star_egg.luau` workflow. The existing source file is not modified. Integration hooks add nearby movement, stage refill coordination, stop propagation, and a remaining two-egg budget. Its own preparation and outcome checks remain in control.
- Slots 46–49: blue progression starts only after the server records two Star Egg uses. Tadpole/Buoyant caps are explicit exceptions to Mythic protection. A fifteenth Tadpole below 10,000 jelly can be used only for an event hatch; at 10,000–24,999 it remains protected unless 30,000 jelly can be refilled.
- Slot 50: the final targets activate. Each gifted Tadpole releases one Baby of either kind, up to four Babies. Final Tadpole/Buoyant caps are 10/17; gifted Diamond demand is four. Cobalt remains protected even though it is absent from the written final ratio.

Event eggs already owned are hatched without buying another. Vicious can be skipped while stingers are insufficient. Star Treats already owned are fed to normal event bees in the requested order, with Gummy after that list. New Star Treat purchases follow the event purchase priorities. The assist waits for Atlas to hatch new unlocked slots.

Movement uses a tweened AlignPosition constraint and temporary noclip. Collision properties and movement objects are restored after movement or interruption. Purchases and hive item requests require a nearby character. Uncertain responses stop the script without retrying a potentially completed purchase or roll.

Roll tasks are coordinate leases. A selected slot stays active until its objective is satisfied, a needed failsafe or valid collector result is obtained, or permanent protection makes further rolling invalid. The status panel reports the active coordinate and recovery mode. Startup waits a fixed 60 seconds before loading hive modules or retrieving stats, then uses the visible Atlas control with executor fallbacks.

## Validation on October 18, 2026

Connected client: Potassium, Bee Swarm Simulator, 38 occupied slots.

- 696 pure policy checks passed against live BeeTypes metadata, including exact gifted failsafe counts, same-slot roll objectives, low-honey slot-43 recovery, stage boundaries, Event/Mythic protection, collector minimums, replacement priorities, jelly price ramps, cap exceptions, placeholder upgrades, and final completion.
- Live preview selected a replaceable slot without changing Atlas or inventory.
- Live roll test consumed one Star Jelly and 54 Royal Jelly over two item requests. Protected bees remained intact; roll settings were restored and Atlas resumed.
- Live event test bought Cobalt for 250 tickets and hatched it into a normal Bucko slot. Atlas resumed afterward.
- A separate finite-budget test consumed exactly one Royal Jelly and verified that movement objects were removed and roll settings restored.
- The earlier bundle and embedded Star Egg source compiled in Potassium. The current Arceus pass is validated statically and still requires a real Arceus X Android run for executor-level confirmation.

Mid, late, Gifted Basic, Star Egg, and final hive spending paths have policy/compile coverage, but the Arceus-specific paths have not been exercised with live resources. The supplied existing Star Egg workflow is reused; its guarantee and later-stage outcomes have not been revalidated in this session.

A subsequent continuous run reached 4 Baby, 4 Music, and 3 Shy at 38 slots. The updated assist is running, and an hourly heartbeat follows its progress toward the final 50-slot hive. See `FULL_HIVE_TEST_LOG.md` for the live observations. A finite action or Royal Jelly budget now defers the existing Star Egg handoff so its internal preparation cannot exceed the outer test budget.

## Editing and rebuilding

Edit `full_hive_policy.luau` or `full_hive_runtime.luau`, then run `./build_full_hive.ps1`. This rebuilds the standalone bundle using the current `auto_use_star_egg.luau` source. `test_full_hive_policy.luau` exports the policy test function.

