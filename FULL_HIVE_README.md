# Full Hive Assist

Run Atlas first, then execute the entire `auto_full_hive_assist.luau` file in **Arceus X Android**. The same bundle remains compatible with Potassium for desktop testing. It contains its policy and the existing Star Egg script, so no local-file support or additional loader is needed.

The assist now waits a fixed **60 seconds** after auto-execution before loading hive modules or requesting player stats. You can auto-execute both scripts together; the assist remains in `startup-delay` during that minute.

The bundle was rebuilt after the previous interrupted build left a three-byte `mak` file. The current generated file starts with `-- Full Hive Assist for Atlas / Arceus X Android / Potassium` and is written atomically by `build_full_hive.ps1`; the builder rejects truncated output below 50,000 characters.

This pass is statically hardened for Arceus X, but it has **not been executed on Arceus X Android** because no Arceus X Android client is currently running. The connected client used during development is Potassium, so Android executor compatibility remains pending a real device test.

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
- Slot 43 low-honey recovery: if the 2,000-jelly refill cannot be afforded and safe non-collector sources remain, the assist buys one 100-jelly pack, rolls one safe non-collector slot at a time, and keeps that coordinate locked through unrelated results. Honey/Exhausted examples are converted toward Bubble, Frosty, Lion, or Ninja collector results; normal 2,000-jelly refills resume when no safe non-collector source remains.
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

