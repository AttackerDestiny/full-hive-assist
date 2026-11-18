# Full Hive Assist

**v1.8.4:** Hatch the first bee before starter gear funding. Gear and Star Amulet honey waits allow background hatching and qualified rolls. Ready purchases retain priority, requests remain serialized, and crafting jelly stays protected.

**v1.8.3:** Starter accounts with a complete snapshot and no Codes field can begin code redemption. Redemption receipts accept both supported code-history formats. The feather toggle sits lower below the top HUD.

**v1.8.2:** The **Controls → Assist enabled** switch pauses and resumes Feather in place. Pausing takes effect at a safe checkpoint after the current action or Star Egg workflow settles, releases Atlas, and preserves the active hive task. The hive viewer now uses WindUI's dark palette and Lucide feather icon.

**v1.8.1:** Moves the round Feather toggle to the top center, inside the device's safe area. Fixes a WindUI startup error that caused v1.8.0 to use the native panel.

**v1.8.0:** Feather now uses [WindUI](https://footagesus.github.io/WindUI-Docs/) for its Overview, Progression and Controls tabs. Tap the round feather in the center of the screen to hide or restore the interface without stopping the assist. The read-only **View hive** grid, **Blender tickets** toggle and **Stop assist** remain available. If WindUI cannot start, Feather falls back to the native panel with the same visibility button.

**v1.7.9:** Fixes the observed terminal stop after a player-stats read timeout. It waits for the original read to resolve, resumes Atlas, and replans once without replaying a spend. Pending mutations, uncertain receipts, stuck reads and repeated timeouts remain protected stops.

**v1.7.8:** Completing Star Journey2's5000RedBoost objective now retires the Fire placeholders as well as normal Shy. Ordinary planning retains only one gifted Shy from that group. A sole gifted Fire remains required during actual Star Egg preparation. Cleanup follows the existing resource priorities.

**v1.7.7:** Adds the authorized fallback for Star preparation blocked by Mythics: keep one Fuzzy and reduce Tadpole/Buoyant only when needed, preserving two each where possible and at least one each. Other Mythics give way first; Events and prerequisite gifted bees stay protected. Also funds missing Diamond Eggs with honey through actual fixed ticket packs, followed by the Ticket Tent's one-egg option.

**v1.7.6:** Includes the40% Star requirement and quest-dependent Ninja/Shy retirement. Also fixes the observed exhausted-batch transition where an existing useful Fire placeholder was rejected after normal Shy reservations retired.

**v1.7.5:** After Star Journey1's2500Haste objective, normal Ninja and gifted duplicates become safe replacement slots; Star Journey2's5000RedBoost objective does the same for Shy. Exactly one gifted copy of each stays reserved, including Star Egg preparation. Verified objective progress or completed-quest history is required; unknown progress preserves the prior rules. Includes v1.7.4's40% Gold/Diamond Star minimum.

**v1.7.4:** Gold and Diamond Star Amulets now require at least40% combined Blue Pollen + global Pollen, in addition to their required stats. Below-threshold current amulets resume Star saving; exactly40% qualifies. The background status shows the current total and target while saving.

**v1.7.3:** Recovers once from an unsent movement timeout after cleaning up the tween/noclip and releasing Atlas. Fresh planning preserves the existing hive objective and batch. Pending or uncertain requests block recovery, and a second timeout stops safely.

**v1.7.2:** Adds the requested King Beetle/Ant/Star/Moon amulet decisions and active quest assistance, with gear → Star → hive honey priority. Quest consumables run during savings; field items require standing in a field. Fuzzy is capped at one total copy, and Star Jelly stops after the eight gifted Rare/Epic failsafes. Also fixes the repeated force-slot error after surplus gifted collector results. [Amulet and quest rules](AMULETS_AND_QUESTS.md).

**v1.6.7:** Fixes a false force-slot stop when an unsent fixed-target lease intentionally selected a surplus gifted Bubble/Frosty coordinate. The exact coordinate is allowed only while its fixed gifted goals remain unmet and reserved copies stay protected.

**v1.6.6:** Fixes Blender speedup completion checks for partially elapsed orders. Tickets pay for unfinished units, while collection awards the full order. Queue identity and inventory baselines are preserved through the request, and the explicit ticket-toggle choice survives maintenance.

**v1.6.5:** Empty-cell hatch receipts capture inventory, capacity and bee identities before the server request yields. Response and fresh stats must agree before the receipt closes; natural bee leveling remains allowed. Failed receipts retain their original baseline and response diagnostics. This fixes an evidenced receipt-accounting flaw; the exact failed response from Luneri's v1.6.4 hatch was not recorded, so its old uncertainty is not automatically cleared.

**v1.6.4:** Adds Pesticide Planter after Petal Belt and before Coconut Canister. Accounts with36+ unlocked hive slots first catch up on missing Candy, Red Clay, Blue Clay and Tacky Planters, using permanent purchase records to skip already-owned/deployed planters.

**v1.6.3:** Waits for the full missing crafting-jelly budget before buying any pack, then uses only verified fixed shop options. Reduces repeated metadata/UI discovery, skips unchanged status/viewer updates, and keeps balances and action guards fresh. Validated by3,306 isolated checks per executor; current stopped sessions are preserved until resumed.

**v1.6.2 current:** Counts an affordable gear purchase once, separates material preparation from saving the gear price, and protects jelly being accumulated for the next craft until that craft is queued. Feather displays owned/queued/required material counts. This includes v1.6.1's rotated-pad movement correction. Hive rolling continues during Blender timers; each purchase/craft still requires Atlas paused and a verified nearby destination.

**v1.6.1:** Gear purchase admission counts the gear price once and preserves only the configured safety reserve during that purchase. Material preparation funds the next recipe before unrelated ticket goals, tracks queued output separately, and shows actual material counts. Movement approaches the world top surface of rotated hive/Blender pads. See [AUTO_PROGRESSION.md](AUTO_PROGRESSION.md) for coordination rules and validation limits.

**v1.6.0 auto progression:** The tested bundle coordinates Atlas farming with ordered gear, exact material crafting, verified hive growth, and the existing auto-hive goals. Purchased gear is recognized from the server purchase ledger and skipped. Feather shows the gear target, current action, Blender recipe/count, remaining wait, and a Blender ticket-speedup toggle that is **off by default**. Blender output is collected only after the live recipe timer and fresh output/state checks pass. v1.6.0 passed 3,233 isolated checks per connected executor and is running on RileyCosmicguppydude and Luneri427. See [AUTO_PROGRESSION.md](AUTO_PROGRESSION.md).


**Separate v1.5.2 candidate:** [Final Baby-quota correction](candidates/v1.5.2/README.md) prevents a cleanup roll from stopping on Baby after the final quota has been reduced by gifted Tadpoles. A new regression reproduces the bug on v1.5.1; the candidate passes 3,036 connected isolated checks per executor. It is not deployed and does not replace this repository's default v1.5.1 loader target or Riley's archived v1.5.0.

**v1.5.1 — configured keeps only.** Corrects the blanket first-gifted retention introduced during research. Gifted Hasty, Riley and other unlisted types remain ordinary replacement/repair candidates; they do not prevent 100-jelly collector recovery. Existing failsafes, force/placeholder groups, Event/Mythic protection, caps, admission and saved-leftover rules remain. All-type gifted coverage still applies during explicit Star Egg preparation. The old `PreserveUniqueGifted` option is accepted for compatibility but has no ordinary-mode effect. Connected isolated regressions pass 2,976 checks per executor. This correction is authorized for Luneri; Riley's live runtime stays v1.5.0 pending a separate update instruction.

**Current testing schedule:** the human authorized testing every 30 minutes. Riley remains on v1.5.0; Luneri is authorized for corrected v1.5.1. The existing task is ACTIVE. Healthy instances stay running; older instances may be replaced only after validation and a clean stop. v1.5.0 passed 2,938 checks per executor; v1.5.1 adds 38 configured-keep/recovery checks, for 2,976 checks per executor. Fixture results are separate from natural live spending behavior.

**October 21 authorized execution:** v1.5.0 was executed once on RileyCosmicguppydude at the human's explicit request. Runtime/report/Feather badge v1.5.0 and the 60-second startup delay were verified; it then waited for 600 Royal Jelly with 92 saved, Atlas resumed, and no reported errors or pending requests. This verifies startup/waiting only. Other new spending paths remain unverified, and Luneri427 was not modified. Recurring research remains read-only.

**v1.5.0 — connected research and test build.** The zero-to-fifty review was redone using MCP stats and game definitions from both accounts. It corrects the rarity fixture, validates hive capacity/coordinates before planning, removes an unrelated Royal Jelly startup wait, scopes Basic continuation to its owner/hive/server, and shares Star Egg coverage/budget rules between workflows. Star Eggs are saved when all gifted Mythics are current, with recorded-use and inventory reconciliation after a handoff. Existing targets, caps, refill qualification and saved-leftover rules remain. [Read the review and limits](CONNECTED_HIVE_REVIEW.md). Both accounts now run v1.5.0 after authorized validation. Connected isolated suites pass 2,938 checks each; live coverage includes startup/waiting and Riley's first gifted Riley retention with saved leftovers. Other spending workflows still need natural observation.

**v1.4.4 — offline Star Egg readiness correction, not deployed.** The standalone/embedded Star workflow now requires two valid recorded hatches before its post-egg rebuild. Completed quests and empty inventory no longer imply that eggs were hatched. Existing quest and empty-inventory gates remain; the main stage gate already used recorded hatches. The builder checks that both readiness source copies match. Validation is compilation and static review only; no fixtures or live scripts were executed.

**v1.4.3 — offline completion correction, not deployed.** A qualifying recipe in 50 unlocked slots could previously finish with only 48 occupied bees. Completion now requires 50 occupied bees as well as the existing composition checks. Empty final slots produce a fill-cells advisory; targets and protected bees are unchanged. This correction has static validation only: automatic approval review blocked pure fixture execution, so no fixture pass is claimed.

**v1.4.2 — offline Star Egg safeguards, not deployed.** The embedded workflow now requires all metadata-listed gifted Basic/Common, Rare, Epic and Legendary species in the current hive, replacing its incomplete 12-species list. It rechecks coverage and all roll-to settings before each egg. The host egg budget now initializes correctly, and the builder rejects missing or duplicate integration hooks. **973 selected pure offline checks** pass, with main/embedded compilation and 36 static markers. The full suite was not rerun; live scripts remain untouched.

**v1.4.1 — offline correction, not deployed.** Gifted diversity now defers to existing multi-copy quotas and flexible collector keeps, including reserved Fire placeholders. Planner and runtime also share the same owned-egg growth advisory. The local suite passes **2,923 isolated checks**; running scripts and phone files remain untouched.

**v1.4.0 — offline research build, not deployed.** Adds separate occupied/capacity growth reporting for 0–24 bees, first-gifted retention during pre-Star-Egg progression, final-composition capacity diagnostics, Basic-slot keep revalidation, fresh finite-budget checks, and persistent uncertain-mutation receipts. Existing live scripts were left untouched. See [research, sources, and limitations](HIVE_PROGRESSION_RESEARCH.md).

Zero-to-fifty acquisition is not yet autonomous: Atlas/manual actions still hatch empty cells and buy hive slots. The assist reports the next growth step and waits before rerolling a partially filled starter hive. `FullHiveReport.Growth` and `CapacityStatus` expose these decisions. Ordinary gifted keeps follow the user's configured failsafes and quantities; discovery or a first gifted copy alone is not a keep rule.

**Current development restriction:** connected v1.5.0 testing is authorized as described above. Preserve unresolved requests and existing task/admission state; never force item outcomes or restart healthy instances. Previously rejected fixture commands remain excluded. New application versions may be published as candidates but need separate live-deployment authorization. Publishing a build does not update a running executor.

**v1.3.7 species caps:** Keep at most **4 Ninja** and **2 Lion** bees, counting normal and gifted copies together. These are maximums, not new minimum targets. Surplus slots become eligible for replacement before optional Bubble/Frosty conversions and count as repair candidates when recovery is needed. Recovery does not finish on another over-cap copy. Existing gifted failsafes, stage targets, refill qualification, and saved-leftover rules still apply; cap cleanup runs as resources allow.

**v1.3.6 Star Jelly upgrades:** In addition to missing gifted Rare/Epic failsafes, available Star Jelly can upgrade an eligible normal Bubble/Frosty selected by the existing planner. It can start without the Royal Jelly refill threshold, uses one Star Jelly per request with all roll-to flags off, and stays on that coordinate through intermediate results until the existing keep rules complete it. No new hive targets are introduced. While Star Jelly remains, this unfinished conversion does not become 100-jelly recovery. Once Star Jelly runs out, existing Royal Jelly qualification and repair rules apply. The Royal Jelly completion/save-leftovers rules remain unchanged.

**v1.3.5 refill fix:** Recovery affordability uses only the Royal Jelly still missing from the normal target, including the initial legendary entry target. Buying the first pack of a larger refill no longer switches an affordable top-up into 100-jelly recovery. Active repair still persists until completed; normal admission and saved-leftover rules remain unchanged.

The in-game interface is **Feather**, with a WindUI status window and a matching dark hive viewer. Use the top-center feather icon to hide or restore the UI, or **Assist enabled** in Controls to pause and resume the assist.

Click **View hive** in the status panel to open the larger live hive view. It shows bee icons in hive order, levels, gifted stars and the active roll slot. Tap a bee for its name/coordinate; **Close** returns to the status panel. The viewer reads the existing client cache and does not pause Atlas or send game requests.

**v1.3.3:** Drag either panel by its header using a mouse or touch. A normal Royal Jelly task starts with **at least** the current refill amount. Its admitted jelly can finish that same task below the threshold, with keep rules and failsafes active. Completing the task closes admission: a new conversion must qualify again. Recovery repairs the wrong slots, then saves its leftovers and waits for the normal refill instead of using them to start gifted conversion. If a normal task genuinely exhausts its jelly, cheap recovery remains available to repair the unfinished slot. Partial refills buy only the missing amount. The script no longer tries to use every leftover jelly.

**v1.3.4 Star Jelly:** At any stage, available Star Jelly is used first on eligible hive targets while any gifted Bumble, Cool, Looker, Bomber, Bubble, Commander, Bucko or Frosty is missing. Each request uses one Star Jelly with all roll-to settings off. Once all eight are present, unused Star Jelly is saved and only Royal Jelly is used. Gifted Basic keeps its separate Basic Egg routine, and gifted legendary bees do not prolong Star Jelly use. Royal Jelly still follows the v1.3.3 refill/keep rules.

A Bee Swarm Simulator hive progression assist that coordinates with Atlas to manage hive rolls, gifted targets, event bees, and progression toward a 50-slot blue hive.

**Main script:** [`auto_full_hive_assist.luau`](auto_full_hive_assist.luau). This generated bundle includes the progression policy and Star Egg workflow; it does not need local source files to run.

## Quick start

1. Join Bee Swarm Simulator and load Atlas.
2. Use [`loader.luau`](loader.luau) as described below, or copy the entire [`auto_full_hive_assist.luau`](auto_full_hive_assist.luau) bundle into your executor.
3. Allow the **60-second startup delay** before the assist loads game modules and begins working. Atlas and the assist can be placed together in auto-execute.
4. Follow the on-screen status panel. Use its **Stop** button to stop the assist.

**The repository is currently private.** In your executor, set `env.FullHiveGitHubToken` to a GitHub token with read access to this repository's contents, then paste/run [`loader.luau`](loader.luau). Set the token only in your local executor environment; never put a real token in the loader source or commit it. An executor HTTP request function is required for authenticated loading.

```lua
local env = (type(getgenv) == "function" and getgenv()) or _G
env.FullHiveGitHubToken = "YOUR_CONTENTS_READ_TOKEN"
-- Paste loader.luau below this prelude.
```

If the repository is later made public, the token-free entry point is:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/AttackerDestiny/full-hive-assist/main/loader.luau"))()
```

The loader downloads the current main-branch bundle, preserves your `FullHiveConfig`, and leaves an already-running assist alone. It reports download/compile errors and blocks startup with pending or unresolved hive requests. Atlas is loaded separately. The bundle supplies its own 60-second startup delay. The loader has been statically compiled only; it has not been executed in Roblox. Repository visibility was not changed.

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
| 0–24 occupied | Report owned-egg/empty-cell growth needs; wait for Atlas/manual hatching before rerolling. |
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

Run the isolated suite with the official local Luau CLI:

```powershell
./tools/test_offline.ps1 -LuauPath 'C:\path\to\luau.exe'
```

This runner uses fixed rarity metadata and local stubs, compiles the bundle without executing it, and never contacts Roblox. `tools/test_connected_client.ps1` is retained for historical reference and is prohibited under the current instruction. A non-null `FullHiveUncertain` blocks a later launch until the earlier mutation is reconciled; never clear it as a retry mechanism.

### Connected cloud phones

The current development checkout is `C:\Users\Administrator\Documents\ChatGPT\Auto coding\upstream-full-hive-assist`. Publish updates to this repository's `main` branch. The earlier `full-hive-assist-standalone` repository is inactive.

Use the cloud phone connector for **phone1**, Noka FREE 6 (`free.nokaF`), and the independent **phone2**, Roblox (`com.roblox.client`), with their explicit profiles. Verify the intended account and private server **Alt1** before resuming. The generated bundle is staged at `/sdcard/Arceus X/Workspace/FullHiveAssist/auto_full_hive_assist.luau` on both phones; pasting the entire bundle does not require executor file APIs.

If Roblox tools are absent from the chat, the existing local MCP core can be reached with the repository helper:

```powershell
$env:ROBLOX_MCP_SERVER_ROOT = 'C:\Users\Administrator\Downloads\roblox-executor-mcp-main\roblox-executor-mcp'
node ./tools/call_roblox_mcp.mjs list-clients
node ./tools/call_roblox_mcp.mjs tools/list
```

Use the live schemas and pass an explicit freshly discovered `clientId`. Check account/place/executor, server-backed hive/inventory, pending requests, running version, and actual Atlas state before execution. A missing connection alone does not prove a crash. After a restart, reconcile state before resuming; never blindly replay an uncertain purchase or roll. Load Atlas only when absent, then execute the current bundle once and allow its built-in 60-second delay. Confirm `FullHiveReport.Version`, a fresh `StartedAt`, Feather's version badge, and healthy post-start behavior before reporting deployment. Routine monitoring runs every **10 minutes**, quietly while unchanged.

Commit and push completed changes immediately without routine confirmation:

```powershell
git add --all
git commit -m "Describe the completed change"
git push origin main
```

Keep essential build/regression and safe deployment checks for script changes. Documentation-only updates do not require gameplay tests. See `FULL_HIVE_TEST_LOG.md` and `full_hive_deployment.json` for observations and validation limits.

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
