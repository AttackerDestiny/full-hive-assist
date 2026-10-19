$source = Get-Content -Raw auto_claim_gifted_star.pre_rebuild.luau
$source = $source.Replace('-- Auto-claim by walking and prepare gifted types. Star Egg use is disabled.', '-- Walk/claim, collect Star Egg requirements, use up to two eggs, then rebuild the honey hive.')
$source = $source.Replace('    MaxStarEggs = 0, -- Preparation only: do not use Star Eggs.', "    MaxStarEggs = 0, -- Early assist does not use Star Eggs.`n    MaxStarJellies = math.huge, -- Use Star Jelly first when inventory has any.`n    RebuildHoney = true, -- Continue Royal Jelly assist after the Star Jelly phase.")
$source = $source.Replace('    RebuildHoney = true, -- Starts after the egg phase finishes (or no eggs exist).', "    RebuildHoney = true, -- Starts after the egg phase finishes (or no eggs exist).`n    GiftedJellyThreshold = 5000,")
$oldRequired = @'
local required = {}
for name, info in pairs(Types) do
    if info.Rarity == "Common" or info.Rarity == "Rare"
        or info.Rarity == "Epic" or info.Rarity == "Legendary" then
        required[#required + 1] = name
    end
end
table.sort(required)
assert(#required >= 29, "Unexpected bee metadata; stopping")
'@
$newRequired = @'
local required = {"Bomber", "Bumble", "Cool", "Looker", "Bucko", "Commander", "Carpenter", "Diamond", "Lion", "Shy", "Demon", "Ninja"}
for _, name in ipairs(required) do assert(Types[name], "Missing fail-safe bee metadata: " .. name) end
'@
$source = $source.Replace($oldRequired, $newRequired)
$policy = Get-Content -Raw hive_roll_policy.luau
$source = $source.Replace('local function gifted(bee)', "local Policy = (function()`n" + $policy + "`nend)()`nlocal function gifted(bee)")
$start = $source.IndexOf('    table.sort(cells, function(a, b)')
$end = $source.IndexOf('    local missing = {}', $start)
$newSort = @'
    -- Empty unlocked cells are eligible for Star Eggs only, never Royal Jelly.
    local hiveRef = player:FindFirstChild("Honeycomb")
    local hive = hiveRef and hiveRef.Value
    if not hive then
        for _, candidate in ipairs(workspace.Honeycombs:GetChildren()) do
            if candidate.Owner.Value == player then hive = candidate break end
        end
    end
    if hive and hive:FindFirstChild("Cells") then
        for _, cell in ipairs(hive.Cells:GetChildren()) do
            local cellType, locked = cell:FindFirstChild("CellType"), cell:FindFirstChild("CellLocked")
            if cellType and cellType.Value == "Empty" and locked and not locked.Value then
                cells[#cells + 1] = {x = cell.CellX.Value, y = cell.CellY.Value}
            end
        end
    end
    table.sort(cells, function(a, b)
        if a.y ~= b.y then return a.y < b.y end
        return a.x < b.x
    end)

'@
$source = $source.Substring(0,$start) + $newSort + $source.Substring($end)
$start = $source.IndexOf('local function safe(cell, counts)')
$end = $source.IndexOf('local function ownsHive()', $start)
$source = $source.Substring(0,$start) + $source.Substring($end)
$start = $source.IndexOf('if not Config.DryRun then', $source.IndexOf('local usedJelly, usedEggs'))
$end = $source.IndexOf('local function refreshStats()', $start)
$source = $source.Substring(0,$start) + $source.Substring($end)
$start = $source.IndexOf('local function useItem(cell, item)')
$source = $source.Substring(0,$start)
$workflow = Get-Content -Raw hive_workflow_tail.luau
$suffix = @'
end
local ok, err = xpcall(run, function(message) return tostring(message) end)
env.AutoGiftedStarRunning = false
if not ok then
    env.AutoGiftedStarError = err
    if env.AutoGiftedStarReport then env.AutoGiftedStarReport.Error = err end
    warn("[Hive] " .. err)
end
'@
$combined = $source + $workflow + "`n" + $suffix
$combined = $combined.Replace('local env = getgenv()', 'local env = (type(getgenv) == "function" and getgenv()) or _G')
$combined = $combined.Replace('getgenv().', 'env.')
$portability = Get-Content -Raw hive_portability.luau
$combined = $combined.Replace('local function run()', "local function run()`n" + $portability)
$combined = $combined.Replace('require(ReplicatedStorage.ClientStatCache)', 'loadModule(ReplicatedStorage.ClientStatCache)')
$combined = $combined.Replace('require(ReplicatedStorage.BeeTypes)', 'loadModule(ReplicatedStorage.BeeTypes)')
$combined = $combined.Replace('fences and fences:QueryDescendants("BasePart") or {}', 'fencePartsUnder(fences)')
$resilience = Get-Content -Raw hive_resilience.luau
$combined = $combined.Replace('local function run()', "local function run()`n" + $resilience)
$ui = Get-Content -Raw hive_status_ui.luau
$combined = $combined.Replace('local function run()', "local function run()`nenv.AutoGiftedStarReport = {Phase = 'starting'}`n" + $ui)
$combined = $combined.Replace('    walkToPart(floor)', "    if env.AutoGiftedStarReport then env.AutoGiftedStarReport.Activity = 'Walking to jelly dispenser' end`n    walkToPart(floor)")
$combined = $combined.Replace('    local packsBought = 0', "    if env.AutoGiftedStarReport then env.AutoGiftedStarReport.Activity = 'Buying 10,000-jelly packs' end`n    local packsBought = 0")
$combined = $combined.Replace('            walkToPart(Vector3.new(-113, 3, 271), true, false)', "            if env.AutoGiftedStarReport then env.AutoGiftedStarReport.Activity = 'Returning to hive' end`n            walkToPart(Vector3.new(-113, 3, 271), true, false)")
$combined = [regex]::Replace($combined, '([A-Za-z0-9_.]+):InvokeServer\(', 'invokeServer($1, ')
# Keep the wrapper's own call direct.
$combined = $combined.Replace('invokeServer(target, table.unpack(args, 1, args.n))', 'target:InvokeServer(table.unpack(args, 1, args.n))')
$combined = [regex]::Replace($combined, ',\s*\)', ')')
$combined = $combined.Replace('os.clock() - lastProgress > 3', 'os.clock() - lastProgress > 8')
$combined = $combined.Replace('os.clock() - progressTime > 3', 'os.clock() - progressTime > 8')
$combined = $combined.Replace('local deadline = os.clock() + 120', 'local deadline = os.clock() + 240')
$combined = $combined.Replace('local deadline = os.clock() + 90', 'local deadline = os.clock() + 240')
# The auto-claim movement function calls its Humanoid "hum".
$claimEnd = $combined.IndexOf('local ReplicatedStorage = game:GetService("ReplicatedStorage")')
$claimPrefix = $combined.Substring(0, $claimEnd).Replace('humanoid.WalkSpeed', 'hum.WalkSpeed')
$combined = $claimPrefix + $combined.Substring($claimEnd)
# Hold a native movement target between rendered frames, then refine direction.
$combined = $combined.Replace('local progressTime = os.clock()', "local progressTime = os.clock()`n        local previousFrame = os.clock()")
$combined = $combined.Replace('            if near(root, part) then return true end', "            local now = os.clock()`n            local gap = now - previousFrame`n            previousFrame = now`n            if gap > 0.4 then progressTime = progressTime + gap deadline = deadline + math.min(gap, 30) end`n            if near(root, part) then return true end")
$combined = $combined.Replace('local lastRecoveryJump = 0', "local lastRecoveryJump = 0`n            local previousFrame = os.clock()")
$combined = $combined.Replace('                local goal = root.Position - destination', "                local now = os.clock()`n                local gap = now - previousFrame`n                previousFrame = now`n                if gap > 0.4 then lastProgress = lastProgress + gap deadline = deadline + math.min(gap, 30) end`n                local goal = root.Position - destination")
Set-Content -LiteralPath auto_early_hive_assist.luau -Value $combined
