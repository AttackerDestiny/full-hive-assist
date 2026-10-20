# Full Hive Assist

**v1.3.5 refill fix:** Recovery affordability uses only the Royal Jelly still missing from the normal target, including the initial legendary entry target. Buying the first pack of a larger refill no longer switches an affordable top-up into 100-jelly recovery. Active repair still persists until completed; normal admission and saved-leftover rules remain unchanged.

The in-game interface is **Feather**, with a feather sticker, navy/violet styling, live status and inventory badges, and **View hive** beside **Stop assist**. Both the status panel and expanded hive viewer adapt to the screen size. The feather is drawn with native Roblox UI elements, so no asset upload or executor file support is required.

Click **View hive** in the status panel to open the larger live hive view. It shows bee icons in hive order, levels, gifted stars and the active roll slot. Tap a bee for its name/coordinate; **Close** returns to the status panel. The viewer reads the existing client cache and does not pause Atlas or send game requests.

**v1.3.3:** Drag either panel by its header using a mouse or touch. A normal Royal Jelly task starts with **at least** the current refill amount. Its admitted jelly can finish that same task below the threshold, with keep rules and failsafes active. Completing the task closes admission: a new conversion must qualify again. Recovery repairs the wrong slots, then saves its leftovers and waits for the normal refill instead of using them to start gifted conversion. If a normal task genuinely exhausts its jelly, cheap recovery remains available to repair the unfinished slot. Partial refills buy only the missing amount. The script no longer tries to use every leftover jelly.

**v1.3.4 Star Jelly:** At any stage, available Star Jelly is used first on eligible hive targets while any gifted Bumble, Cool, Looker, Bomber, Bubble, Commander, Bucko or Frosty is missing. Each request uses one Star Jelly with all roll-to settings off. Once all eight are present, unused Star Jelly is saved and only Royal Jelly is used. Gifted Basic keeps its separate Basic Egg routine, and gifted legendary bees do not prolong Star Jelly use. Royal Jelly still follows the v1.3.3 refill/keep rules.

A Bee Swarm Simulator hive progression assist that coordinates with Atlas to manage hive rolls, gifted targets, event bees, and progression toward a 50-slot blue hive.

**Main script:** [`auto_full_hive_assist.luau`](auto_full_hive_assist.luau). This generated bundle includes the progression policy and Star Egg workflow; it does not need local source files to run.

## Quick start

1. Join Bee Swarm Simulator and load Atlas.
2. Open [`auto_full_hive_assist.luau`](auto_full_hive_assist.luau), copy the entire file, and execute it in your executor.
3. Allow the **60-second startup delay** before the assist loads game modules and begins working. Atlas and the assist can be placed together in auto-execute.
4. Follow the on-screen status panel. Use its **Stop** button to stop the assist.

The default configuration runs continuously and can spend honey, tickets, stingers, eggs, Star Treats, Star Jelly, and Royal Jelly. The assist pauses Atlas while working and restores roll settings during cleanup.

### Preview without spending

Run this before executing the main script:

```lua
local env = (type(getgenv) == "function" and getgenv()) or _G
env.FullHiveConfig = {DryRun = true}
```

### Run with limits

```lua
local env = (type(getgenv) == "function" and getgenv()) or _G
env.FullHiveConfig = {
    MaxActions = 2,
    MaxRoyalJellies = 10,
    AutoPurchase = false,
}
```

Set options **before** executing the main script. Clear previous overrides with `env.FullHiveConfig = nil` when returning to the default continuous run. Finite action or Royal Jelly limits defer the embedded Star Egg workflow.

### Stop or inspect progress

```lua
local env = (type(getgenv) == "function" and getgenv()) or _G
env.FullHiveStop = true
```

`env.FullHiveReport` contains the current phase, targets, actions, item usage, purchases, and errors.

## Progression

| Hive slots | Main objectives |
| --- | --- |
| 25–39 | Maintain collectors, build Baby/Music/Shy counts, and collect gifted failsafes. |
| 40–43 | Pursue gifted rare/epic targets and convert Bubble/Frosty collectors. |
| 44+ | Enter gifted legendary progression after observing at least 10,000 Royal Jelly. |
| 46–49 | Begin blue progression after two recorded Star Egg uses. |
| 50 | Work toward the final hive targets, including Tadpole/Buoyant caps. |

Gifted Basic, event bees, Star Treats, jelly refills, and Star Eggs have additional resource and progression conditions. See the [detailed guide](FULL_HIVE_README.md) for the complete rules and configuration notes.

## Compatibility and validation

Version 1.1.0 enables 100-jelly collector recovery whenever the normal refill exceeds 100, is unaffordable, and safe non-collector slots remain. Below 20B honey it rolls one jelly at a time with every roll-to setting off; the earlier 20B+ gifted Bubble/Frosty variant is also included. After repairs, the normal stage refill resumes. Unlisted bee types are eligible unless protected or reserved by another rule.

Version 1.1.1 verifies every gifted failsafe and force-result keep during recovery and retains useful crit/red placeholders in mid/late recovery. Kept results end the active coordinate so recovery can continue on another safe slot.

Version 1.0.2 adds recovery from character loss before requests and during movement. It resumes Atlas while waiting for respawn and refreshes/revalidates the hive before continuing. Pending or uncertain requests still stop the assist. See `test_character_recovery.luau` and `tools/test_connected_client.ps1` for regression checks.

The bundle contains compatibility fallbacks for **Arceus X Android** and has been tested with **Potassium** on desktop and the connected **Arceus X** cloudphone. Version 1.0.2 has compile, isolated regression, and live 41-slot startup coverage. Later progression paths still need live coverage. Atlas must also support your executor.

Existing validation includes policy checks and selected live Potassium tests. Later progression paths have not all been exercised with live resources. See the [validation details](FULL_HIVE_README.md#validation-on-october-18-2026) and [test log](FULL_HIVE_TEST_LOG.md) for scope and observations.

## Development

Edit the source modules, then rebuild the standalone script from PowerShell:

```powershell
./build_full_hive.ps1
```

Run the static bundle compatibility check with:

```powershell
./validate_arceus_bundle.ps1
```

| File | Purpose |
| --- | --- |
| [`full_hive_policy.luau`](full_hive_policy.luau) | Hive targets and progression decisions. |
| [`full_hive_runtime.luau`](full_hive_runtime.luau) | Atlas coordination, movement, purchases, and status UI. |
| [`hive_view_ui.luau`](hive_view_ui.luau) | Read-only expandable hive viewer, bundled by the builder. |
| [`feather_theme.luau`](feather_theme.luau) | Shared Feather styling and feather sticker. |
| [`auto_use_star_egg.luau`](auto_use_star_egg.luau) | Star Egg workflow embedded by the builder. |
| [`build_full_hive.ps1`](build_full_hive.ps1) | Generates the standalone bundle atomically. |
| [`test_full_hive_policy.luau`](test_full_hive_policy.luau) | Policy test function. |
| [`run_full_hive_policy_tests.luau`](run_full_hive_policy_tests.luau) | Bundled policy test runner for the game environment. |

Other scripts and reference files are retained in the repository for the related hive workflows.
