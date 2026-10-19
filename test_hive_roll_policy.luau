-- Policy-only tests: no remotes, movement, inventory, or settings changes.
return function(Policy, Types)
    local checked = 0
    local function check(condition, message)
        assert(condition, message)
        checked = checked + 1
    end
    local nextX = 0
    local function cell(name, gifted)
        nextX = nextX + 1
        return {x = nextX, y = 1, bee = name and {Type = name, Traits = gifted and {"Gifted"} or {}} or nil}
    end
    local required, full = {}, {}
    for name, info in pairs(Types) do
        if info.Rarity == "Common" or info.Rarity == "Rare" or info.Rarity == "Epic"
            or info.Rarity == "Legendary" then
            required[#required + 1] = name
            full[#full + 1] = cell(name, true)
        end
    end
    for _, c in ipairs(full) do
        check(not Policy.starSafe(c, full, Types, required), "Star Egg targeted a unique gifted type")
        check(not Policy.prepSafe(c, full, Types), "Prep targeted a unique gifted type")
    end
    local duplicate = cell("Cool", true)
    full[#full + 1] = duplicate
    check(Policy.starSafe(duplicate, full, Types, required), "Duplicate gifted slot rejected")
    local normalExtra = cell("Baby", false)
    full[#full + 1] = normalExtra
    check(Policy.starSafe(normalExtra, full, Types, required), "Normal extra rejected")
    local empty = cell(nil, false)
    full[#full + 1] = empty
    check(Policy.starSafe(empty, full, Types, required), "Unlocked empty slot rejected")
    check(not Policy.prepSafe(empty, full, Types), "Royal Jelly targeted an empty cell")
    check(Policy.choose(full, function(c) return Policy.starSafe(c, full, Types, required) end) == empty,
        "Empty Star Egg slot not preferred")
    local incomplete = {}
    for _, c in ipairs(full) do
        if not c.bee or c.bee.Type ~= "Basic" then incomplete[#incomplete + 1] = c end
    end
    check(not Policy.starSafe(empty, incomplete, Types, required), "Egg allowed without Gifted Basic")
    check(not Policy.starSafe(duplicate, incomplete, Types, required), "Egg allowed with incomplete types")
    local legendDuplicate = cell("Carpenter", true)
    full[#full + 1] = legendDuplicate
    check(Policy.prepSafe(legendDuplicate, full, Types), "Extra gifted Legendary not eligible during preparation")
    check(Policy.starSafe(legendDuplicate, full, Types, required), "Extra gifted Legendary not eligible for Star Egg")
    for _, name in ipairs({"Demon", "Ninja", "Music"}) do
        local copies = name == "Ninja" and 4 or 3
        local list = {}
        for i = 1, copies do list[#list + 1] = cell(name, true) end
        local rolled = 0
        while #list > 1 do
            check(Policy.prepSafe(list[#list], list, Types), "Gifted Legendary duplicate unavailable")
            table.remove(list)
            rolled = rolled + 1
        end
        check(rolled == copies - 1, "Incorrect duplicate budget")
        check(not Policy.prepSafe(list[1], list, Types), "Last gifted Legendary copy was selectable")
    end
    for name, info in pairs(Types) do
        if info.Rarity == "Event" or info.Rarity == "Mythic" then
            for _, gifted in ipairs({false, true}) do
                local c = cell(name, gifted)
                local list = table.clone(full)
                list[#list + 1] = c
                check(not Policy.prepSafe(c, list, Types), "Prep targeted Event/Mythic")
                check(not Policy.starSafe(c, list, Types, required), "Star targeted Event/Mythic")
                check(not Policy.honeySafe(c, list, Types), "Rebuild targeted Event/Mythic")
            end
        end
    end
    local honey = {}
    local singles = {"Basic", "Bomber", "Bumble", "Cool", "Looker", "Bucko", "Commander",
        "Diamond", "Lion", "Shy", "Demon", "Baby", "Music"}
    for _, name in ipairs(singles) do honey[#honey + 1] = cell(name, true) end
    for i = 1, 3 do
        honey[#honey + 1] = cell("Baby", false)
        honey[#honey + 1] = cell("Music", false)
        honey[#honey + 1] = cell("Bubble", true)
        honey[#honey + 1] = cell("Frosty", true)
    end
    check(#Policy.honeyPlan(honey, Types).needs == 0, "Completed honey hive not recognized")
    for _, c in ipairs(honey) do
        check(not Policy.honeySafe(c, honey, Types), "A honey quota bee was selectable")
    end
    local extraBaby, extraMusic = cell("Baby", true), cell("Music", false)
    honey[#honey + 1], honey[#honey + 2] = extraBaby, extraMusic
    check(not Policy.honeySafe(extraBaby, honey, Types), "Additional gifted Baby was not kept")
    check(Policy.honeySafe(extraMusic, honey, Types), "Fourth normal Music was not replaceable")
    local outside = cell("Carpenter", true)
    honey[#honey + 1] = outside
    check(Policy.honeySafe(outside, honey, Types), "Post-egg non-target gifted Legendary not released")
    local plan = Policy.honeyPlan(honey, Types)
    check(#plan.needs == 1 and plan.needs[1].filler and plan.needs[1].amount == 3,
        "Remaining extras not assigned gifted Bubble/Frosty filler")
    -- Newly rolled Mythics become permanently protected immediately.
    local newMythic = cell("Fuzzy", false)
    honey[#honey + 1] = newMythic
    check(not Policy.honeySafe(newMythic, honey, Types), "New normal Mythic was rerollable")
    for _, name in ipairs({"Spicy", "Vector", "Fuzzy", "Precise"}) do
        local normal, gifted = cell(name, false), cell(name, true)
        local list = {normal, gifted}
        check(not Policy.honeySafe(gifted, list, Types), "Optional gifted Mythic not preferred")
        check(Policy.honeySafe(normal, list, Types), "Optional Mythic duplicate unavailable")
        check(not Policy.honeySafe(normal, {normal}, Types), "Last optional normal Mythic selected")
        check(not Policy.prepSafe(normal, list, Types), "Mythic duplicate selected before egg phase")
    end
    for _, name in ipairs({"Baby", "Music"}) do
        for giftedCount = 1, 4 do
            local list, giftedCopies, normalCopies = {}, {}, {}
            for i = 1, giftedCount do
                local c = cell(name, true)
                list[#list + 1], giftedCopies[#giftedCopies + 1] = c, c
            end
            for i = 1, 3 do
                local c = cell(name, false)
                list[#list + 1], normalCopies[#normalCopies + 1] = c, c
            end
            for _, c in ipairs(giftedCopies) do
                check(not Policy.honeySafe(c, list, Types), "Gifted quota replacement not preserved")
            end
            local keptNormals = 0
            for _, c in ipairs(normalCopies) do
                if not Policy.honeySafe(c, list, Types) then keptNormals = keptNormals + 1 end
            end
            check(keptNormals == 4 - giftedCount, "Normal copies did not yield to gifted copies")
        end
    end
    -- Using one duplicate must leave the singleton untouchable for the next egg.
    local afterEgg = {}
    for _, c in ipairs(full) do if c ~= duplicate then afterEgg[#afterEgg + 1] = c end end
    for _, c in ipairs(afterEgg) do
        if c.bee and c.bee.Type == "Cool" then
            check(not Policy.starSafe(c, afterEgg, Types, required), "Second egg could remove last gifted copy")
        end
    end
    return {passed = checked, required = #required}
end
