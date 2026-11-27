# Feather — project and GPT handoff

Feather is a Luau Roblox executor application that coordinates Bee Swarm Simulator hive progression, gear, crafting, quests and amulets with Atlas farming. This is an existing working project; continue its implementation rather than replacing it with a new script.

Repository: https://github.com/AttackerDestiny/full-hive-assist (branch `main`). Bee Swarm Simulator place: `1537690962`.

## Start here in a new chat or on a new device

1. Read this README, then **[AGENTS.md](AGENTS.md)** for detailed rules and latest human overrides.
2. Read the newest entries at the END of **[FULL_HIVE_TEST_LOG.md](FULL_HIVE_TEST_LOG.md)**. Historical entries are not current authorization or proof of current state.
3. Read `latestDeployment` in **[full_hive_deployment.json](full_hive_deployment.json)** for the last observed versions, hashes and StartedAt values. Rediscover live clients; saved IDs and account/device mappings expire.
4. Inspect the current branch, local changes and relevant modules before editing. Preserve unrelated work and immutable release bundles.
5. Use the connected Roblox MCP to verify identity and actual behavior. If unavailable, state that live verification is unavailable; do not invent it.

A new device does not automatically inherit this computer's MCP servers, executor connections, filesystem or credentials. Clone the repository and configure the required integrations locally. Reading this repository does not create a Roblox connection.

Suggested prompt for the next GPT:

> Read README.md, AGENTS.md, the latest FULL_HIVE_TEST_LOG.md entries and full_hive_deployment.json in AttackerDestiny/full-hive-assist. Continue the existing Feather project. Work in the primary agent only. Rediscover Roblox clients and verify account/place/job/executor before calls. Respect user stop/pause, preserve pending and uncertain receipts, and never replay uncertain spends. Explain what is actually connected before claiming a live fix. Test, version, rebuild, safely re-execute authorized application changes, verify them live and commit/push to main. Ignore QuackTest02 unless I explicitly change that instruction.

## Public loader and source of truth

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/AttackerDestiny/full-hive-assist/main/start.luau?reload="..os.time(),true))()
```

`start.luau` downloads and compiles `core.luau`, then hands off safely. Its own loader version is separate from the application version. The application version is `SCRIPT_VERSION` in `full_hive_runtime.luau`, exposed as `getgenv().FullHiveVersion`, `FullHiveReport.Version` and the UI version.

**Edit source modules, then build `core.luau`.** Do not fix only the generated bundle. Older notes naming `auto_full_hive_assist.luau` refer to historical layouts; the current public payload is `core.luau`. Do not restore old releases over current code.

## Code map

| File | Responsibility |
|---|---|
| `full_hive_policy.luau` | Pure hive targets, keeps, safe slots, stage/roll policy and task reconciliation |
| `full_hive_runtime.luau` | Main loop, serialized requests, Atlas coordination, movement, batch admission and runtime reports |
| `progression_policy.luau` | Gear route, five-item honey/material queues, recipes, funding, eligibility and hive growth decisions |
| `progression_facts.luau` | Read-only normalization of fresh stats and actual game shop/recipe metadata |
| `progression_runtime.luau` | Travel, last-moment revalidation, guarded purchases/crafts and receipts |
| `progression_funds.luau` | Funds/reservation checks |
| `progression_hatch_receipt.luau`, `progression_blender_receipt.luau` | Reconciliation of hatching and Blender mutations |
| `background_runtime.luau`, `quest_assist_policy.luau` | Active quests, verified force retirements and background assistance |
| `amulet_policy.luau` | Offer decisions and amulet requirements |
| `star_progress.luau`, bundled Star sources | Quest/egg history, coverage and Star workflow |
| `material_farm.luau` | Supported crafting-fruit field switching and confirmed status |
| `atlas_progression_control.luau`, `atlas_callback_values.luau` | Atlas controls and wrapped callback discovery |
| `atlas_switch_control.luau` | Verified Atlas Coconut Crab setter, config/UI confirmation and detached-tab binding |
| `feather_wind_ui.luau`, `hive_view_ui.luau`, `route_dashboard.luau`, `feather_theme.luau` | WindUI interface, hive viewer and animated route display |
| `feather_restart.luau`, `feather_settings.luau` | Safe re-execution and persistent user settings |
| `build_full_hive.ps1`, `validate_arceus_bundle.ps1` | Bundle generation and compatibility validation |

See [FULL_HIVE_README.md](FULL_HIVE_README.md) for additional operational details. When older prose conflicts with current source and latest human instructions, investigate the conflict; do not silently restore obsolete behavior.

## Roblox MCP

Prefer the installed `roblox-mcp` skill and native executor tools. On the original computer the skill is at `C:/Users/admin/.agents/skills/roblox-mcp/SKILL.md`; that is a local installation path, not a portable repository dependency.

### Connection workflow

- Call `list-clients` at the start of live work. Client IDs can change within seconds.
- Use an explicit current `clientId` for every account operation. Verify `LocalPlayer.Name`, `game.PlaceId`, `game.JobId` and `identifyexecutor()` in the returned data. Never assume two executor sessions behave identically.
- Prefer scoped `search-instances`, `get-descendants-tree`, `script-grep` and focused script reads. Use small `get-data-by-code` probes for values; return raw Luau tables, not JSON strings or entire game trees.
- `execute-file` schedules execution. It does not prove completion. Follow with a focused runtime/result read.
- Do not use broad GC scans when a scoped search or `filtergc` will work. Do not dump tokens, full private configuration or enormous source into chat.

Minimal read-only identity/health probe:

```lua
local e=getgenv()
local r=e.FullHiveReport or {}
return {
    account=game.Players.LocalPlayer.Name, place=game.PlaceId,
    job=game.JobId, executor=identifyexecutor(),
    version=e.FullHiveVersion, reportVersion=r.Version, started=r.StartedAt,
    running=e.FullHiveRunning, stop=e.FullHiveStop, pause=r.PauseRequested,
    pending=e.FullHivePending, autoPending=e.AutoHivePendingRequest,
    uncertain=e.FullHiveUncertain, autoUncertain=e.AutoHiveUncertain,
    error=r.Error
}
```

Also inspect fresh server-backed inventory/hive, relevant settings, current task, admission and actual Atlas switch state. Cache data is useful for focused observation, but a final spend must use the implementation's fresh revalidation and receipt workflow. A runtime report alone is not proof of the game's actual switch state.

### Existing local MCP bridge fallback

`tools/call_roblox_mcp.mjs` uses an installed MCP SDK and the existing core at `http://127.0.0.1:16384/mcp`. It does not start a server. Point `ROBLOX_MCP_SERVER_ROOT` at the real installed executor-server directory containing its SDK dependency; historical paths under admin/Administrator/Downloads may have moved.

```powershell
$env:ROBLOX_MCP_SERVER_ROOT = 'C:\path\to\installed\roblox-executor-mcp'
node tools/call_roblox_mcp.mjs tools/list
node tools/call_roblox_mcp.mjs list-clients
# Save arguments as a real UTF-8 JSON file, then:
node tools/call_roblox_mcp.mjs get-data-by-code C:\path\to\probe-arguments.json
```

Discover current schemas rather than guessing tool names/arguments. The helper can resolve an exact account name to a unique client, but explicit rediscovery and returned identity checks are still necessary. Do not start duplicate servers to work around a missing connection.

## Cloudphone MCP

Cloudphone tools control Android foreground apps, screenshots and input. Roblox MCP inspects the in-game executor; these are separate connections. Missing Roblox MCP alone does NOT prove an app crash.

Native connections encountered include `mcp__cloudphone_phone2`, `phone4` and `phone5`. Each controls only its named profile. Read its current tool descriptions, check `cloudphone_status`, then obtain a fresh screenshot BEFORE input/launch actions. Do not guess coordinates from old screenshots. A remote desktop containing multiple app windows is not proof of a particular account/profile mapping.

Historical verified profiles (rediscover before acting):

| Profile | Historical account/app | Package |
|---|---|---|
| original `cloudphone` | RileyCosmicguppydude / Noka FREE 6 | `free.nokaF` |
| `phone2` | Luneri427 / Roblox | `com.roblox.client` |

Later Quack/Spiderman/Glen sessions must be identified live, not mapped to these devices by guesswork. Never swap profiles or use another profile as fallback.

Local bridge installations used `cloudphone_control_mcp.py`; profile-specific private connection files live outside this repo (for example `.cloudphone-control/profiles/phone2/connection.json`). Import/configure the installed controller only according to its own tool definitions. Paths and Python locations vary; use `Python -X utf8` when needed. **Never commit or print connection tokens, private connection JSON, GitHub authorization codes or credentials.**

For authorized disconnect recovery, corroborate discovery with foreground/screen state. Distinguish respawn/loading/connector failure from a real app disconnect. Rejoin only the authorized private server **Alt1**, confirmed in UI or through a previously verified link. Do not substitute a public server. Login or unavailable Alt1 needs user attention. Reconcile actual inventory/hive and known pre-disconnect receipts before any resume; a crash clearing executor flags does not prove the server rejected the last request.

## Core invariants for safe coding

- Never clear unresolved request/uncertain flags, seed arbitrary batches or replay an uncertain spend. Mutation receipts preserve their copied pre-request baseline.
- No target means no roll. Unsafe active coordinates wait without spending; preserve the task and admission, release Atlas and revalidate later.
- Keep Event/Mythic protection, exact duplicate/failsafe/force rules and the explicitly authorized exceptions. RNG, slow honey growth and waiting for funds are not bugs.
- Requests are serialized even when features run in the background. Movement uses the existing AlignPosition tween/noclip implementation with nearby checks; do not introduce unverified remotes or alternate teleport routes.
- Release Atlas before waits/exits after owned work. Batch rolling can retain its Atlas lease until that work is done. Respect actual user pause/stop; maintenance is a distinct controlled handoff.
- Pure policy tests cannot prove a real purchase, field switch or RNG result. Label isolated coverage, live configuration verification and naturally observed actions separately.
- No subagents. Do not alter the existing recurring schedule unless asked. No duplicate automation.

## Current rules to preserve (v1.8.127 candidate snapshot)

This section is a handoff snapshot; consult later log entries and AGENTS.md for subsequent changes.

- Both gear queues contain up to five eligible entries. Honey queue sorts by honey price; material queue sorts by remaining leaf ingredients after owned stock and queued output, then honey and route order. Ready purchases/crafts can bypass blocked targets. Passive drops must not monopolize active material farming.
- Crimson Guard follows Coconut Canister in the route, before Supreme Saturator. Route order is not an additional ownership prerequisite.
- BOTH Cobalt and Crimson require Baby4/Music4/Shy3. Once verified Star Journey2 Red Boost5000/completed quest evidence retires Shy, require Baby4/Music4 only. Music3 was a corrected typo and is NOT valid.
- After completed The Family Final and no active Mother Bear quest, feed owned Treats to Vicious up to level12 without buying more or overspending the bond deficit. Once fresh level12 is verified, enable Atlas Auto Kill Coconut Crab through its own Set API and confirm config plus UI; preserve other combat settings and intentional stops.
- Atlas protected UI lookups and activation use scoped executor identity8, restoring the caller after callbacks and errors. A low-identity thread must not cause a Plugin capability failure while discovering Stop Everything.
- Normal early/mid force filling uses one Royal Jelly per request, roll-to off and50 refill. Completion restores normal stage refill. Preserve starter <33 inventory-only rolling and explicit late/Star/post-Star workflows.
- Ordinary gifted failsafe hunting requires the existing force quotas and Bubble Mask. Keep incidental gifted results under existing keep rules.
- Coconut Canister needs Diamond Mask owned AND equipped for queue admission. Pesticide Planter needs Diamond Mask owned and45 unlocked hive slots. Petal Belt needs one actual Spirit Petal in inventory.
- Ignore Blender Earn Badges recipe metadata as a craft gate; retain actual validated ingredients and other conditions. Do not auto-craft banned wax recipes.
- Craft whole remaining recipe deficits when inputs permit; protect crafting jelly, fund its complete deficit before buying and preserve queued output separately from actual inventory. Unrelated active Blender cancellation requires exact order revalidation and reconciled refunds/output.
- Normal Royal Jelly admission uses inventory >= refill. An admitted unfinished objective can continue below it; completion closes admission and saves leftovers. Never reseed saved leftovers to bypass qualification.
- The46-slot normal threshold/refill is10000 Royal Jelly (human correction126);47+ thresholds retain their existing values. Candidate127 records copied roll baselines and preserves the existing exact-task surplus-Fuzzy exception during response protection.
- Planner reservations honor existing configured gifted roll shields at every stage; incidental gifted Bomber cannot become a later-stage repair target. This adds no gifted hunting goals. Reserved stale leases retire through guarded reconciliation; unfinished unsafe leases and unresolved receipts retain admission. Repair completion restores normal stage qualification.
- Supported material fruit routes: Strawberry → Strawberry Field; Blueberry → Pine Tree Forest; SunflowerSeed → Sunflower Field; Pineapple → Pineapple Patch, subject to real entry access. Return field is Blue Flower below5 bees, Bamboo from5, Pine Tree from15. Only bind Atlas's main Farming selector, not quest field selectors.
- Star Egg paths use actual Seven To Seven / Royal Rumble completion, current Star inventory and use counters. Six path targets gifted Music/Baby/Shy/Diamond/Lion/Demon. Never infer history solely from current hive composition.

Full route and all nuanced amulet, quest, Star, keep and spending rules remain in source and AGENTS.md; this README is not permission to simplify them.

## Build, test, deploy and publish

Run from the repository root in PowerShell:

```powershell
./build_full_hive.ps1
./tools/test_offline.ps1 -LuauPath 'C:\path\to\luau.exe'
./validate_arceus_bundle.ps1
./tools/test_connected_client.ps1 -ClientId ACCOUNT -TestFilePath "$env:TEMP/feather-regression.luau"
```

The offline runner uses the official Luau CLI. The connected runner command above **generates a fixture only**. Execute that exact fixture using the intended live client's `execute-file`, then verify `FullHiveRegressionResult.allPassed` and the affected check counts. Give final candidate fixtures unique markers when earlier drafts have the same application version, so stale passing results cannot masquerade as final verification.

Application changes:

1. Diagnose from current evidence and relevant game/source scripts. Bump `SCRIPT_VERSION`, rebuild and run relevant regressions. Do not change immutable releases.
2. Rediscover intended accounts, confirm identity and stop/pause state, inspect both pending flags and uncertainty. Compile/download the exact new payload before stopping anything.
3. Use the existing loader/restart helper to stop cleanly, wait for `FullHiveRunning=false`, preserve task/admission/settings and execute the new bundle once. Do not manually pre-set Stop: the helper preserves human pauses and could interpret that as one. Do not replay a scheduled bundle merely because its completion is delayed.
4. Verify NEW StartedAt, matching runtime/report/UI version, post-start running/error state, request flags, actual Atlas control and the affected live path where feasible. Preserve honest limitations when natural triggers have not happened.
5. Record hashes (raw generated bytes and normalized LF payload when different), actual accounts, executor/job, StartedAt, test results and observed behavior in FULL_HIVE_TEST_LOG.md and full_hive_deployment.json.
6. Fetch first, preserve unrelated work, then `git add` explicit completed files, `git commit`, `git push origin main`. Verify the remote branch contains the commit. Never force-push. Keep the local commit and report an actual push failure.

Documentation-only updates do not require version bumps, game spending or live re-execution. A healthy unchanged application should stay running.

Latest live deployment: **v1.8.126** on **SpidermanXD56**. Its10000 threshold and actual7440 top-up/rolling were verified, but subsequent rolling stopped on a protection-check error with an unresolved receipt. **v1.8.127 is a tested candidate and has not been deployed** there because that old receipt lacks its original pre-roll snapshot. Do not report Spiderman as healthy or replay/clear the receipt to resume. xd_Glen09 remains on124 with its Atlas UI fix previously verified. Other accounts except QuackTest02 remain in scope for requested work. See the deployment JSON and latest log for hashes, tests and observations.
