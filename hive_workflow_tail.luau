local Report = {
    Phase = "inspect", DryRun = Config.DryRun, JelliesUsed = 0, StarJelliesUsed = 0, StarEggsUsed = 0,
    Purchases = 0, RequiredTypes = #required,
}
env.AutoGiftedStarReport = Report
local function updateReport()
    local stats, cells, counts, missing = scan()
    Report.Missing = missing
    Report.RoyalJelly = stats.Eggs.RoyalJelly or 0
    Report.StarEggs = stats.Eggs.Star or 0
    Report.StarJellies = stats.Eggs.StarJelly or 0
    Report.Honey = stats.Honey or 0
    local plan = Policy.honeyPlan(cells, Types)
    Report.HoneyNeeds = plan.needs
    Report.HoneyExtraSlots = #plan.candidates
    return stats, cells, counts, missing, plan
end
local function configureMode(mode)
    assert(mode == "gifted" or mode == "legendary" or mode == "off", "Unknown roll mode")
    local desired = {
        RollToGifted = mode == "gifted", RollToLegendary = mode == "legendary",
        RollToMythic = false, RollToMutation = false,
    }
    local current = Cache:Get().Settings or {}
    for setting, value in pairs(desired) do
        if (current[setting] == true) ~= value then
            ReplicatedStorage.Events.PlayerSettingsEvent:FireServer(setting, value)
        end
    end
    local deadline = os.clock() + 15
    local matched = false
    repeat
        task.wait(0.35)
        local fresh = refreshStats()
        matched = true
        for setting, value in pairs(desired) do
            if (fresh.Settings[setting] == true) ~= value then matched = false end
        end
    until matched or os.clock() >= deadline or env.AutoGiftedStarStop
    assert(matched, "Roll settings did not synchronize; stopping before spending")
    Report.RollMode = mode
end
local usedStarJellies = 0
local function stopped()
    assert(not env.AutoGiftedStarStop, "Stopped by user")
end
local function fingerprint(bee)
    return bee.Type .. ":" .. tostring(table.find(bee.Traits or {}, "Gifted") ~= nil)
end
local permanentBaseline = {}
local optionalBaselineKeys = {}
local rebuilding = false
local function capturePermanents(cells)
    for _, cell in ipairs(cells) do
        if Policy.permanent(cell, Types) then
            local key = cell.x .. "," .. cell.y
            local optional = Policy.optionalMythics[cell.bee.Type]
            if not rebuilding or not optional then
                permanentBaseline[key] = fingerprint(cell.bee)
                if optional then optionalBaselineKeys[key] = true end
            end
        end
    end
end
local function verifyPermanents(cells)
    local byKey = {}
    for _, cell in ipairs(cells) do byKey[cell.x .. "," .. cell.y] = cell end
    for key, expected in pairs(permanentBaseline) do
        local cell = byKey[key]
        assert(cell and cell.bee and fingerprint(cell.bee) == expected,
            "Protected Event/Mythic changed; stopping")
    end
    capturePermanents(cells)
end
local function isSafe(cell, cells, phase)
    if phase == "prepare" then return Policy.prepSafe(cell, cells, Types) end
    if phase == "star-jelly" then return Policy.prepSafe(cell, cells, Types) end
    if phase == "eggs" then return Policy.starSafe(cell, cells, Types, required) end
    if phase == "rebuild" then return Policy.honeySafe(cell, cells, Types) end
    return false
end
local function useItem(target, item, phase)
    stopped()
    Report.Activity = item == "StarJelly" and "Using Star Jelly on a verified extra slot"
        or item == "Star" and "Using Star Egg on a verified extra slot" or "Rolling Royal Jelly"
    assert(ownsHive(), "No claimed hive")
    refreshStats()
    local stats, cells = scan()
    if item == "RoyalJelly" then
        local settings = stats.Settings or {}
        assert((settings.RollToGifted == true) == (Report.RollMode == "gifted")
            and (settings.RollToLegendary == true) == (Report.RollMode == "legendary")
            and not settings.RollToMythic and not settings.RollToMutation,
            "Roll settings changed; stopping before spending")
    end
    verifyPermanents(cells)
    local current
    for _, cell in ipairs(cells) do
        if cell.x == target.x and cell.y == target.y then current = cell break end
    end
    assert(current and isSafe(current, cells, phase), "Target became protected; stopping")
    assert((item == "Star" and phase == "eggs") or (item == "StarJelly" and phase == "star-jelly")
        or (item == "RoyalJelly" and phase ~= "eggs" and phase ~= "star-jelly"),
        "Item/phase mismatch")
    local before = stats.Eggs[item] or 0
    assert(before > 0, "Item inventory empty")
    local remaining, accepted, honeycomb, discovered, eggUses =
        remote:InvokeServer(current.x, current.y, item, 1, false)
    assert(accepted and type(honeycomb) == "table" and type(remaining) == "number",
        "Server rejected request or returned an unknown result; no automatic retry")
    Cache:Set({"Eggs", item}, remaining)
    Cache:Set("Honeycomb", honeycomb)
    if discovered then Cache:Set("DiscoveredBees", discovered) end
    if eggUses then Cache:Set({"Totals", "EggUses"}, eggUses) end
    local consumed = before - remaining
    assert(consumed >= 1 and consumed <= before, "Invalid item consumption")
    if item == "Star" then
        assert(consumed == 1, "Unexpected Star Egg consumption")
        usedEggs = usedEggs + consumed
    elseif item == "StarJelly" then
        usedStarJellies = usedStarJellies + consumed
    else
        usedJelly = usedJelly + consumed
    end
    local bee = honeycomb["x" .. current.x] and honeycomb["x" .. current.x]["y" .. current.y]
    assert(bee and Types[bee.Type], "Updated bee unavailable")
    local _, afterCells = scan()
    verifyPermanents(afterCells)
    if phase == "eggs" then
        local afterMissing = Policy.missing(afterCells, required)
        assert(#afterMissing == 0, "Star Egg requirements were lost; stopping")
        assert(gifted(bee) and Types[bee.Type].Rarity == "Mythic", "Unexpected Star Egg result; stopping")
    end
    Report.JelliesUsed, Report.StarJelliesUsed, Report.StarEggsUsed = usedJelly, usedStarJellies, usedEggs
    Report.LastResult = {X = current.x, Y = current.y, Type = bee.Type,
        Gifted = gifted(bee), Item = item, Consumed = consumed}
    print(string.format("[Hive] %s: %s%s (%d,%d), %d %s used", phase,
        gifted(bee) and "Gifted " or "", bee.Type, current.x, current.y, consumed, item))
    updateReport()
    task.wait(Config.RollDelay)
end
local function ensureJelly()
    stopped()
    assert(usedJelly < Config.MaxRoyalJellies, "Per-run Royal Jelly limit reached")
    local stats = Cache:Get()
    if (stats.Eggs.RoyalJelly or 0) > Config.JellyReserve then return true end
    if not Config.AutoRefill then return false end
    local success = refill()
    if success then Report.Purchases = Report.Purchases + 1 end
    Report.Activity = nil
    return success
end
refreshStats()
local stats, cells, counts, missing, plan = updateReport()
capturePermanents(cells)
local eggBudget = math.min(Config.MaxStarEggs, stats.Eggs.Star or 0)
local starJellyBudget = math.min(Config.MaxStarJellies or 0, stats.Eggs.StarJelly or 0)
Report.StarJellyBudget = starJellyBudget
Report.EggBudget = eggBudget
Report.NextStarTarget = Policy.choose(cells, function(cell)
    return Policy.starSafe(cell, cells, Types, required)
end)
-- Avoid putting an entire bee record into the status report.
if Report.NextStarTarget then
    local cell = Report.NextStarTarget
    Report.NextStarTarget = {X = cell.x, Y = cell.y, Type = cell.bee and cell.bee.Type or "Empty"}
end
if Config.DryRun then
    Report.Phase = "dry-run"
    print("[Hive] Dry run only: no settings, movement, items or purchases changed")
    return
end

-- Star Jelly is the first phase. If the account has zero Star Jelly, this
-- phase is skipped and Royal Jelly continues normally.
while usedStarJellies < starJellyBudget do
    stopped()
    stats, cells, counts, missing = updateReport()
    local stageMissing = Policy.stageMissing(cells, Types, false)
    if #stageMissing == 0 then break end
    local target = Policy.choose(cells, function(cell)
        return Policy.prepSafe(cell, cells, Types)
    end)
    if not target then break end
    useItem(target, "StarJelly", "star-jelly")
end

if eggBudget > 0 then
    Report.Phase = "prepare"
    while true do
        stopped()
        stats, cells, counts, missing = updateReport()
        if #missing == 0 then break end -- Do not clean up duplicate bees here.
        assert(counts.Basic, "Gifted Basic is missing; Royal Jelly cannot supply it")
        local target = Policy.choose(cells, function(cell) return Policy.prepSafe(cell, cells, Types) end)
        assert(target, "No safe Royal Jelly slot remains")
        configureMode("gifted")
        assert(ensureJelly(), "Cannot refill jelly; Star Eggs preserved")
        useItem(target, "RoyalJelly", "prepare")
    end
    Report.Phase = "eggs"
    configureMode("off")
    while usedEggs < eggBudget do
        stopped()
        refreshStats()
        stats, cells, counts, missing = updateReport()
        assert(#missing == 0, "All 29 gifted types must be in the current hive before each egg")
        -- Early-game mode only spends Star Eggs while a named fail-safe gifted
        -- target is missing. Event/Mythic bees are never an implicit target.
        break
    end
end

-- Only the post-egg phase may release non-target gifted Legendaries.
Report.Phase = "rebuild"
rebuilding = true
-- Release only the optional species from the per-slot baseline; the policy
-- still protects one copy, while all other Event/Mythic slots stay immutable.
for key in pairs(optionalBaselineKeys) do permanentBaseline[key] = nil end
while Config.RebuildHoney do
    stopped()
    stats, cells, counts, missing, plan = updateReport()
    local jelly = stats.Eggs.RoyalJelly or 0
    Policy.stageGifted = jelly >= 5000
    Policy.stageLegendary = jelly >= 20000
    Policy.convertFlexible = Policy.stageGifted
    stats, cells, counts, missing, plan = updateReport()
    if #plan.needs == 0 then
        Report.Phase = "complete"
        print("[Hive] Honey targets reached; every remaining replaceable slot is gifted Bubble/Frosty")
        return
    end
    for _, need in ipairs(plan.needs) do
        assert(not (need.type == "Basic" and need.gifted), "Gifted Basic missing; cannot recover it with jelly")
    end
    local remainingDemand = 0
    for _, need in ipairs(plan.needs) do remainingDemand = remainingDemand + need.amount end
    assert(#plan.candidates >= remainingDemand,
        "Not enough unprotected slots for honey targets; protected bees kept")
    local needGifted, needNormal = false, false
    for _, need in ipairs(plan.needs) do
        if need.gifted and not need.filler then needGifted = true end
        if not need.gifted then needNormal = true end
    end
    -- Fixed gifted types first, then three normal Baby/Music each, then filler.
    if not needNormal then needGifted = true end
    local target = Policy.choose(cells, function(cell) return Policy.honeySafe(cell, cells, Types) end)
    assert(target, "No safe honey rebuild slot")
    if needGifted then
        assert((stats.Eggs.RoyalJelly or 0) >= Config.GiftedJellyThreshold,
            "Royal Jelly below 5,000; gifted-target phase is deferred")
        configureMode("gifted")
    else
        -- Baby/Music fallback rolls must run with both stop settings off.
        configureMode("off")
    end
    assert(ensureJelly(), "Cannot refill Royal Jelly; stopping rebuild")
    useItem(target, "RoyalJelly", "rebuild")
end
Report.Phase = "complete"
