-- Pure selection rules; embedded into the standalone combined script.
local Policy = {}
Policy.optionalMythics = {}
-- Early-game fail-safe targets. Bubble/Frosty are quantity-flexible and are
-- handled as permanent species below; Baby/Music are four-slot fallbacks.
local giftedSingles = {"Bomber", "Bumble", "Cool", "Looker", "Bucko",
    "Commander", "Carpenter", "Diamond", "Lion", "Shy", "Demon", "Ninja"}
Policy.giftedSingles = giftedSingles
Policy.stageGifted = false
Policy.stageLegendary = false
Policy.convertFlexible = false
local function isGifted(bee)
    return table.find(bee.Traits or {}, "Gifted") ~= nil
end
local function key(cell) return cell.x .. "," .. cell.y end
function Policy.permanent(cell, types)
    if not cell.bee then return false end
    local info = assert(types[cell.bee.Type], "Unknown bee type")
    return info.Rarity == "Event" or info.Rarity == "Mythic"
end
function Policy.flexible(cell)
    return cell.bee and (cell.bee.Type == "Bubble" or cell.bee.Type == "Frosty")
end
function Policy.countGifted(cells)
    local counts = {}
    for _, cell in ipairs(cells) do
        if cell.bee and isGifted(cell.bee) then
            local name = cell.bee.Type
            counts[name] = (counts[name] or 0) + 1
        end
    end
    return counts
end
function Policy.missing(cells, required)
    local counts = Policy.countGifted(cells)
    local missing = {}
    for _, name in ipairs(required) do
        if not counts[name] then missing[#missing + 1] = name end
    end
    return missing, counts
end
function Policy.stageMissing(cells, types, includeLegendary)
    local missing = {}
    local counts = Policy.countGifted(cells)
    for _, name in ipairs(giftedSingles) do
        local info = types[name]
        if info and (includeLegendary or info.Rarity ~= "Legendary") and not counts[name] then
            missing[#missing + 1] = name
        end
    end
    return missing
end
function Policy.starSafe(cell, cells, types, required)
    if Policy.permanent(cell, types) or Policy.flexible(cell) then return false end
    local missing, counts = Policy.missing(cells, required)
    -- Preserve the four-slot Baby/Music fallback even while gifted targets are
    -- still missing. These slots are only eligible when there is a spare copy.
    if cell.bee and (cell.bee.Type == "Baby" or cell.bee.Type == "Music") then
        local plan = Policy.honeyPlan(cells, types)
        if plan.keep[key(cell)] then return false end
    end
    if not cell.bee then return true end
    if isGifted(cell.bee) then
        return (counts[cell.bee.Type] or 0) > 1
    end
    return true
end
function Policy.prepSafe(cell, cells, types)
    if not cell.bee or Policy.permanent(cell, types) or Policy.flexible(cell) then return false end
    if cell.bee.Type == "Baby" or cell.bee.Type == "Music" then
        if Policy.honeyPlan(cells, types).keep[key(cell)] then return false end
    end
    if not isGifted(cell.bee) then return true end
    return (Policy.countGifted(cells)[cell.bee.Type] or 0) > 1
end
function Policy.honeyPlan(cells, types)
    local keep, needs, candidates = {}, {}, {}
    local reservedGifted = {}
    for _, cell in ipairs(cells) do
        local failSafeGifted = cell.bee and isGifted(cell.bee)
            and table.find(giftedSingles, cell.bee.Type) ~= nil
        if failSafeGifted and not reservedGifted[cell.bee.Type] then
            keep[key(cell)] = true
            reservedGifted[cell.bee.Type] = true
        elseif cell.bee and (Policy.permanent(cell, types) or
            (Policy.flexible(cell) and (isGifted(cell.bee) or not Policy.convertFlexible))) then
            keep[key(cell)] = true
        end
    end
    for _, name in ipairs(giftedSingles) do
        local info = types[name]
        local enabled = Policy.stageGifted and info and
            (Policy.stageLegendary or info.Rarity ~= "Legendary")
        if enabled then
            local found = false
            for _, cell in ipairs(cells) do
                if cell.bee and cell.bee.Type == name and isGifted(cell.bee) then
                    keep[key(cell)] = true
                    found = true
                    break
                end
            end
            if not found then needs[#needs + 1] = {type = name, gifted = true, amount = 1} end
        end
    end
    for _, name in ipairs({"Baby", "Music"}) do
        -- Keep four total copies, preferring gifted copies when available.
        local kept = 0
        for _, cell in ipairs(cells) do
            if cell.bee and cell.bee.Type == name and keep[key(cell)] then
                kept = kept + 1
            end
        end
        for _, giftedPass in ipairs({true, false}) do
            for _, cell in ipairs(cells) do
                if kept < 4 and cell.bee and cell.bee.Type == name
                    and isGifted(cell.bee) == giftedPass and not keep[key(cell)] then
                    keep[key(cell)] = true
                    kept = kept + 1
                end
            end
        end
        if kept < 4 then needs[#needs + 1] = {type = name, gifted = false, amount = 4 - kept} end
    end
    local flexible = {}
    for _, cell in ipairs(cells) do
        if Policy.flexible(cell) then flexible[#flexible + 1] = cell end
    end
    for _, cell in ipairs(cells) do
        -- Do not spend Basic Eggs or hatch unused cells during the rebuild.
        if cell.bee and not keep[key(cell)] and
            (not Policy.flexible(cell) or Policy.convertFlexible) then
            candidates[#candidates + 1] = cell
        end
    end
    local fixedDemand = 0
    for _, need in ipairs(needs) do fixedDemand = fixedDemand + need.amount end
    -- If every replaceable slot is currently Bubble/Frosty, consume normal
    -- flexible slots as a fallback so Baby/Music can still be rolled.
    for _, cell in ipairs(flexible) do
        if #candidates >= fixedDemand then break end
        if keep[key(cell)] then
            keep[key(cell)] = nil
            candidates[#candidates + 1] = cell
        end
    end
    if #candidates < fixedDemand then
        for _, giftedPass in ipairs({false, true}) do
            for _, cell in ipairs(cells) do
                if Policy.flexible(cell) and keep[key(cell)] and isGifted(cell.bee) == giftedPass then
                    keep[key(cell)] = nil
                    candidates[#candidates + 1] = cell
                    if #candidates >= fixedDemand then break end
                end
            end
            if #candidates >= fixedDemand then break end
        end
    end
    if #candidates > fixedDemand then
        needs[#needs + 1] = {type = "Bubble/Frosty", gifted = Policy.convertFlexible,
            amount = #candidates - fixedDemand, filler = true}
    end
    return {keep = keep, needs = needs, candidates = candidates}
end
function Policy.honeySafe(cell, cells, types)
    return cell.bee ~= nil and not Policy.honeyPlan(cells, types).keep[key(cell)]
end
function Policy.choose(cells, predicate)
    -- Prefer empty unlocked cells, then normal extras, then gifted duplicates.
    for _, mode in ipairs({"empty", "normal", "gifted"}) do
        for _, cell in ipairs(cells) do
            local kind = not cell.bee and "empty" or (isGifted(cell.bee) and "gifted" or "normal")
            if kind == mode and predicate(cell) then return cell end
        end
    end
end
return Policy
