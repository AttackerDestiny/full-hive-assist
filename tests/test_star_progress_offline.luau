-- Pure readiness cases; compile-only validation while fixture execution is blocked.
return function(source)
    local body = assert(source:match("local StarProgress = %(function%(%)\n(.-)\nend%)%(%)"))
    local Progress = assert(loadstring(body))()
    local passed = 0
    local function check(value, message)
        assert(value, message)
        passed += 1
    end
    local function stats(recorded, inventory, completed)
        return {Quests={Completed=completed or {['Seven To Seven']=true, ['Royal Rumble']=true}},
            Eggs={Star=inventory}, Totals={EggUses={Star=recorded}}}
    end
    for _, recorded in ipairs({0, 1}) do
        local progress = Progress.read(stats(recorded, 0))
        check(progress.used == recorded and progress.recordedKnown and not progress.ready,
            "Missing reward inventory cannot become recorded hatches")
    end
    local missing = Progress.read(stats(nil, 0))
    check(missing.used == 0 and not missing.recordedKnown and not missing.ready,
        "Missing use counter cannot authorize rebuilding")
    missing = Progress.read({Quests=stats(0, 0).Quests, Eggs={Star=0}})
    check(not missing.recordedKnown and not missing.ready, "Missing totals are unknown usage")
    for _, invalid in ipairs({-1, 1.5, '2', true, math.huge, 0/0}) do
        local progress = Progress.read(stats(invalid, 0))
        check(progress.used == 0 and not progress.recordedKnown and not progress.ready,
            "Invalid recorded count cannot authorize rebuilding")
    end
    for _, recorded in ipairs({2, 3}) do
        local progress = Progress.read(stats(recorded, 0))
        check(progress.used == recorded and progress.recordedKnown and progress.ready,
            "Confirmed recorded hatches meet the existing two-use condition")
    end
    local remaining = Progress.read(stats(2, 1))
    check(not remaining.ready and remaining.inventory == 1, "Existing empty-inventory condition remains intact")
    local unclaimed = Progress.read(stats(2, 0, {['Seven To Seven']=true}))
    check(not unclaimed.ready and unclaimed.earned == 1, "Recorded hatches do not replace quest conditions")
    local unknown = Progress.read({Eggs={Star=0}, Totals={EggUses={Star=2}}})
    check(not unknown.known and not unknown.ready, "Unknown quest state remains blocked")
    local list = Progress.read(stats(2, 0, {'Seven To Seven', 'Royal Rumble'}))
    check(list.ready, "Existing list-form completed quests remain supported")
    local before = Progress.read(stats(0, 2))
    local after = Progress.read(stats(0, 0))
    check(before.used == after.used and not before.ready and not after.ready,
        "Donation or depletion does not prove hatching")
    return {passed=passed}
end
