-- Pure hive tables and the configuration preamble only. Never runs a workflow,
-- transport wrapper, service, remote, task, or connected-client fixture.
return function(source, types)
    local passed = 0
    local function check(value, message)
        assert(value, message)
        passed += 1
    end
    local function rejects(fn, message)
        check(not pcall(fn), message)
    end
    local body = assert(source:match("local Policy = %(function%(%)%s*(.-)\nend%)%(%)\nlocal required = Policy.starRequirements"),
        "Embedded pure policy boundary changed")
    local progressBody=assert(source:match("local StarProgress = %(function%(%)\n(.-)\nend%)%(%)"))
    local Progress=assert(loadstring(progressBody))()
    local P = assert(loadstring("return function(StarProgress)\n"..body.."\nend"))()(Progress)
    local required = P.starRequirements(types)
    check(#required == 29, "All 29 non-Event/non-Mythic species are required")
    check(table.find(required, "Basic") ~= nil, "Gifted Basic belongs in Star coverage")
    for name, info in pairs(types) do
        local excluded = info.Rarity == "Event" or info.Rarity == "Mythic"
        check((table.find(required, name) == nil) == excluded, "Rarity coverage: " .. name)
    end
    local off = {RollToGifted=false, RollToLegendary=false, RollToMythic=false, RollToMutation=false}
    local function hive()
        local cells = {}
        for i, name in ipairs(required) do
            cells[i] = {x=i, y=1, bee={Type=name, Traits={"Gifted"}}}
        end
        return cells
    end
    check(P.starPreflight(hive(), types, off), "Complete gifted current hive is ready")
    check(P.starPreflight(hive(), types, {}), "Absent false setting defaults match the existing mode synchronizer")
    for i, name in ipairs(required) do
        local cells = hive()
        table.remove(cells, i)
        rejects(function() P.starPreflight(cells, types, off) end, "Missing current gifted " .. name)
        cells = hive()
        cells[i].bee.Traits = {}
        rejects(function() P.starPreflight(cells, types, off) end, "Normal does not satisfy gifted " .. name)
        cells = hive()
        cells[i].bee = nil
        rejects(function() P.starPreflight(cells, types, off) end, "Empty does not satisfy gifted " .. name)
    end
    P.giftedDiscovered = {}
    for _, name in ipairs(required) do P.giftedDiscovered[name] = true end
    rejects(function() P.starPreflight({}, types, off) end, "Discovery history cannot replace current hive coverage")
    local cells = hive()
    cells[2].bee.Type = cells[1].bee.Type
    rejects(function() P.starPreflight(cells, types, off) end, "Duplicate cannot replace another required type")
    for _, flag in ipairs({"RollToGifted", "RollToLegendary", "RollToMythic", "RollToMutation"}) do
        local settings = table.clone(off)
        settings[flag] = true
        rejects(function() P.starPreflight(hive(), types, settings) end, "Active flag blocks Star Egg: " .. flag)
    end
    rejects(function() P.starPreflight(hive(), types, nil) end, "Unknown settings stop before spending")
    cells = hive()
    check(P.starPreflight(cells, types, off), "First egg has full coverage")
    cells[1].bee.Traits = {}
    rejects(function() P.starPreflight(cells, types, off) end, "Second egg rechecks changed coverage")
    local extended = table.clone(types)
    extended.FutureEpic = {Rarity="Epic"}
    check(#P.starRequirements(extended) == 30, "Metadata additions become prerequisites")
    rejects(function() P.starPreflight(hive(), extended, off) end, "New prerequisite cannot be ignored")
    cells = hive()
    cells[#cells + 1] = {x=30, y=1, bee={Type="FutureEpic", Traits={"Gifted"}}}
    check(P.starPreflight(cells, extended, off), "Future complete metadata coverage is accepted")
    local common = table.clone(types)
    common.Basic = {Rarity="Common"}
    check(P.starPreflight(hive(), common, off), "Common rarity spelling includes Basic")
    for _, name in ipairs(required) do
        local incomplete = table.clone(types)
        incomplete[name] = nil
        rejects(function() P.starRequirements(incomplete) end, "Incomplete baseline metadata: " .. name)
    end
    local noBasic = table.clone(extended)
    noBasic.Basic = nil
    rejects(function() P.starRequirements(noBasic) end, "Larger metadata still requires Basic")
    rejects(function() P.starRequirements(nil) end, "Missing metadata stops")
    for _, cell in ipairs(hive()) do
        check(not P.starSafe(cell, hive(), types, required), "Unique gifted prerequisite stays protected: " .. cell.bee.Type)
    end
    cells = hive()
    local spare = {x=30, y=1, bee={Type="Brave", Traits={}}}
    cells[#cells + 1] = spare
    check(P.starSafe(spare, cells, types, required), "Normal unreserved spare remains eligible")
    for _, name in ipairs({"Tabby", "Buoyant"}) do
        local cell = {x=31, y=1, bee={Type=name, Traits={}}}
        check(not P.starSafe(cell, cells, types, required), "Event/Mythic protection: " .. name)
    end
    -- Execute only the preamble ending before its first running-state branch.
    local prefix = assert(source:match("^(.-)if env.AutoGiftedStarRunning then"))
    local function budget(shared, useGetgenv)
        local config = assert(loadstring(prefix .. "\nreturn Config"))
        local scope = setmetatable({_G=shared}, {__index=getfenv(0)})
        scope.getgenv = useGetgenv and function() return shared end or false
        setfenv(config, scope)
        return config().MaxStarEggs
    end
    check(budget({FullHiveStarBudget=1}, true) == 1, "Host budget resolves before Config initialization")
    check(budget({}, true) == 2, "Standalone default budget remains two")
    check(budget({FullHiveStarBudget=0}, true) == 0, "Zero host budget stays zero")
    check(budget({FullHiveStarBudget=1}, false) == 1, "Global fallback honors host budget")
    local itemBody = assert(source:match("local function useItem%(target, item, phase%)(.-)\nlocal function ensureJelly"))
    local freshAt = assert(itemBody:find("refreshStats()", 1, true))
    local scanAt = assert(itemBody:find("local stats, cells = scan()", 1, true))
    local guardAt = assert(itemBody:find("Policy.starPreflight(cells, Types, stats.Settings)", 1, true))
    local requestAt = assert(itemBody:find("invokeServer(remote,", 1, true))
    check(freshAt < scanAt and scanAt < guardAt and guardAt < requestAt, "Fresh per-egg preflight precedes the item request")
    check(itemBody:find('item == "RoyalJelly" and env.FullHiveJellyReady', 1, true) ~= nil,
        "Host Royal Jelly admission hook remains present")
    check(itemBody:find("env.FullHiveJellySpent(remaining)", 1, true) ~= nil,
        "Host Royal Jelly consumption hook remains present")
    return {passed=passed}
end
