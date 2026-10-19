# Full Hive Assist

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

The bundle contains compatibility fallbacks for **Arceus X Android** and has been tested with **Potassium** on desktop. Arceus X Android execution remains unverified; static checks do not confirm device compatibility. Atlas must also support your executor.

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
| [`auto_use_star_egg.luau`](auto_use_star_egg.luau) | Star Egg workflow embedded by the builder. |
| [`build_full_hive.ps1`](build_full_hive.ps1) | Generates the standalone bundle atomically. |
| [`test_full_hive_policy.luau`](test_full_hive_policy.luau) | Policy test function. |
| [`run_full_hive_policy_tests.luau`](run_full_hive_policy_tests.luau) | Bundled policy test runner for the game environment. |

Other scripts and reference files are retained in the repository for the related hive workflows.
