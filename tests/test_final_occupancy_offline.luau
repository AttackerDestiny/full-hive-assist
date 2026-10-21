-- Pure table regression cases. Added after fixture execution was blocked;
-- these cases have been statically compiled, not executed or live-verified.
return function(P, types)
    local passed = 0
    local function check(value, message)
        assert(value, message)
        passed += 1
    end
    local cells = {}
    local function add(name, amount, gifted)
        for _ = 1, amount do
            local n = #cells
            cells[n + 1] = {x=n % 5 + 1, y=math.floor(n / 5) + 1,
                bee={Type=name, Traits=gifted and {"Gifted"} or {}}}
        end
    end
    for _, name in ipairs(P.trueSingles) do add(name, 1, true) end
    add("Diamond", 3, true)
    add("Music", 1, true); add("Music", 3, false)
    for _, name in ipairs({"Tabby", "Gummy", "Vicious", "Puppy", "Festive"}) do add(name, 1, true) end
    add("Fuzzy", 1, true)
    add("Tadpole", 4, true); add("Tadpole", 6, false)
    add("Buoyant", 1, true); add("Buoyant", 16, false)
    check(#cells == 48, "Satisfied base recipe has 48 occupied cells")
    local ctx = {slots=50, starUsed=2, jelly=500000, lateStarted=true, enforceGrowth=true}
    local plan = P.plan(cells, types, ctx)
    check(plan.stage == "final" and #plan.needs == 0 and not plan.capacityStatus.Conflict,
        "Final capacity and recipe satisfaction do not imply a full hive")
    check(not plan.complete and plan.growth.Occupied == 48 and plan.growth.Empty == 2,
        "Two empty cells prevent final completion")
    check(plan.target == nil, "Completion guard does not invent replacement targets")
    check(plan.growth.Action == "acquire-basic-egg", "Empty capacity remains an acquisition advisory")
    ctx.eggs = {Basic=1}
    plan = P.plan(cells, types, ctx)
    check(not plan.complete and plan.growth.Action == "hatch-owned-basic", "Owned egg does not count as a bee")
    add("Cobalt", 1, false)
    plan = P.plan(cells, types, ctx)
    check(not plan.complete and plan.growth.Empty == 1, "49 bees do not finish the 50-bee objective")
    add("Frosty", 1, true)
    plan = P.plan(cells, types, ctx)
    check(plan.complete and plan.growth.Empty == 0, "Full qualifying 50-bee hive can finish")
    check(plan.protected[P.key(cells[49])] and cells[50].bee.Type == "Frosty" and P.gifted(cells[50]),
        "Event protection and the input hive remain intact")
    cells[1].bee = {Type="Hasty", Traits={}}
    plan = P.plan(cells, types, ctx)
    check(not plan.complete and #plan.needs > 0, "50 occupied cells still require the specified recipe")
    return {passed=passed}
end
