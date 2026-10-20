-- Pure planner. No Roblox calls; every spending action must revalidate this plan.
local P = {}
P.mid = {"Bumble", "Cool", "Looker", "Bomber", "Bubble", "Commander", "Bucko", "Frosty"}
P.legendary = {"Baby", "Carpenter", "Demon", "Lion", "Diamond", "Music", "Ninja", "Shy"}
P.singles = {"Basic", "Bumble", "Cool", "Looker", "Bomber", "Bubble", "Commander", "Bucko", "Frosty", "Carpenter", "Demon", "Lion", "Diamond", "Ninja", "Shy"}
P.trueSingles = {"Basic", "Bumble", "Cool", "Looker", "Bubble", "Commander", "Bucko", "Diamond"}
P.exactGifted = {Basic=true, Bumble=true, Cool=true, Looker=true, Bomber=true,
    Commander=true, Bucko=true, Carpenter=true, Demon=true, Lion=true,
    Diamond=true, Ninja=true, Shy=true}
function P.gifted(c) return c.bee and table.find(c.bee.Traits or {}, "Gifted") ~= nil end
function P.key(c) return c.x .. "," .. c.y end
function P.count(cells, name, giftedOnly)
    local n = 0
    for _, c in ipairs(cells) do
        if c.bee and c.bee.Type == name and (not giftedOnly or P.gifted(c)) then n = n + 1 end
    end
    return n
end
function P.starJellyMissing(cells)
    local missing={}
    -- These eight Rare/Epic failsafes are obtainable from Star Jelly.
    -- Basic keeps its separate egg routine; legendary gifts are not required.
    for _,name in ipairs(P.mid) do
        if P.count(cells,name,true)==0 then missing[#missing+1]=name end
    end
    return missing
end
function P.rollItem(cells,eggs)
    if (eggs.StarJelly or 0)>0 and #P.starJellyMissing(cells)>0 then return "StarJelly" end
    return "RoyalJelly"
end
function P.isCollectorSection(cell)
    if not cell or not cell.bee then return false end
    local name = cell.bee.Type
    return name == "Bubble" or name == "Frosty" or name == "Lion" or name == "Ninja"
end
function P.isRecoveryTask(task)
    return task and (task.Reason=="collector-fallback" or task.Reason=="gifted-collector-fallback")
end
function P.recoveryMode(honey)
    if (honey or 0)>=20000000000 then return "gifted","gifted-collector-fallback" end
    return "off","collector-fallback"
end
function P.giftedLimit(name, stage)
    if name == "Baby" or name == "Music" then return 4 end
    if name == "Diamond" and stage == "final" then return 4 end
    return P.exactGifted[name] and 1 or nil
end
function P.startRollTask(target, cells, plan)
    local task = {Version=2,x=target.x,y=target.y,Stage=plan.stage,Reason=plan.reason,
        Mode=plan.mode,StartedType=target.bee.Type,Rolled=false,
        InitialTotal={},InitialGifted={},Goals={},
        InitialFingerprint=target.bee.Type..":"..tostring(P.gifted(target))}
    for _,c in ipairs(cells) do
        if c.bee then
            local name=c.bee.Type
            task.InitialTotal[name]=(task.InitialTotal[name] or 0)+1
            if P.gifted(c) then task.InitialGifted[name]=(task.InitialGifted[name] or 0)+1 end
        end
    end
    for _,need in ipairs(plan.needs or {}) do
        local before=(need.gifted and task.InitialGifted or task.InitialTotal)[need.name] or 0
        task.Goals[#task.Goals+1]={name=need.name,gifted=need.gifted,before=before,target=before+need.amount}
    end
    return task
end
-- The task belongs to one coordinate. Candidate sorting never ends a task.
function P.rollTaskDone(task, cell, cells, types, plan)
    if not cell or not cell.bee then return true, "slot-unavailable" end
    if (plan.protected or {})[P.key(cell)] then return true, "protected-result" end
    if not task.Rolled then return false end
    local name = cell.bee.Type
    local gifted = P.gifted(cell)
    local limit = P.giftedLimit(name, plan.stage)
    -- Do not let a new duplicate win a reservation merely because its
    -- coordinate sorts before the existing gifted copy.
    if gifted and limit and P.count(cells, name, true) > limit then return false end
    if (task.Reason == "collector-fallback" or task.Reason == "collector")
        and P.isCollectorSection(cell) then return true, "collector-result" end
    if task.Reason=="gifted-collector-fallback" and gifted and (name=="Bubble" or name=="Frosty") then
        return true,"gifted-collector-result"
    end
    if task.Reason=="gifted-collector-fallback" and not gifted and P.isCollectorSection(cell) then return false end
    if task.Reason == "convert-flexible" then
        if gifted and (name == "Bubble" or name == "Frosty") then return true, "gifted-collector-result" end
        if not gifted and (name == "Bubble" or name == "Frosty") then return false end
    end
    for _,goal in ipairs(task.Goals or {}) do
        if name==goal.name and (not goal.gifted or gifted) and goal.before<goal.target then
            local count=P.count(cells,name,goal.gifted)
            if count>goal.before and count<=goal.target then return true, "needed-result" end
        end
    end
    if gifted then
        if not task.Goals or #task.Goals==0 then
            if name=="Bubble" or name=="Frosty" then return true, "gifted-collector-result" end
        end
        if limit and (task.InitialGifted[name] or 0)<limit then return true, "failsafe-result" end
    end
    -- A needed normal force bee is useful; a fifth Baby or a surplus normal
    -- collector never steals an old force slot just by sorting first.
    local normalCaps={Baby=4,Music=4,Shy=3,Bubble=4,Frosty=4,Ninja=2}
    local cap=normalCaps[name]
    if (not task.Goals or #task.Goals==0) and cap and (task.InitialTotal[name] or 0)<cap and P.count(cells,name)<=cap then
        return true, "force-quota-result"
    end
    if not gifted and (plan.stage=="early" or (P.isRecoveryTask(task) and (plan.stage=="mid" or plan.stage=="late")))
        and (name=="Looker" or name=="Commander" or name=="Fire") then
        local initial=task.InitialTotal
        local better=name=="Looker" and (initial.Music or 0)+(initial.Commander or 0)
            or name=="Commander" and (initial.Music or 0) or (initial.Shy or 0)
        local capForGroup=name=="Fire" and 3 or 4
        if better+(initial[name] or 0)<capForGroup and plan.keep[P.key(cell)] then
            return true,"placeholder-upgrade"
        end
    end
    return false
end
function P.rollTaskSafe(task, cell, cells, types, plan)
    if not cell or not cell.bee or plan.protected[P.key(cell)] then return false end
    local done = P.rollTaskDone(task, cell, cells, types, plan)
    if done then return false end
    local name = cell.bee.Type
    local limit = P.giftedLimit(name, plan.stage)
    if P.gifted(cell) and limit and P.count(cells, name, true) > limit then return true end
    if P.gifted(cell) and (limit or name=="Bubble" or name=="Frosty") then return false end
    if task.Reason == "convert-flexible" and not P.gifted(cell)
        and (name == "Bubble" or name == "Frosty") then return true end
    if task.Reason=="gifted-collector-fallback" and not P.gifted(cell) and P.isCollectorSection(cell) then return true end
    local normalCaps={Baby=4,Music=4,Shy=3,Bubble=4,Frosty=4,Ninja=2}
    if normalCaps[name] and not P.gifted(cell) and P.count(cells,name)>normalCaps[name] then return true end
    if not task.Rolled and task.InitialFingerprint==name..":"..tostring(P.gifted(cell)) then
        -- The planner selected this slot, including an explicitly released
        -- placeholder. Recheck no permanent protected bee has appeared above.
        return true
    end
    return not plan.keep[P.key(cell)]
end
function P.stage(ctx)
    if ctx.slots >= 50 and ctx.starUsed >= 2 then return "final" end
    if ctx.slots >= 46 and ctx.starUsed >= 2 then return "blue" end
    if ctx.slots >= 44 then return "late" end
    if ctx.slots >= 40 then return "mid" end
    return "early"
end
function P.refill(slots)
    if slots >= 50 then return 500000, 100000 end
    if slots >= 48 then return 400000, 100000 end
    if slots >= 47 then return 200000, 100000 end
    if slots >= 46 then return 100000, 100000 end
    if slots >= 45 then return 10000, 10000 end
    if slots >= 44 then return 4000, 1000 end
    if slots >= 43 then return 2000, 1000 end
    if slots >= 42 then return 1000, 1000 end
    if slots >= 40 then return 600, 100 end
    if slots >= 35 then return 200, 100 end
    return 100, 100
end
function P.jellyCost(bought, amount)
    local discounted = math.min(amount, math.max(0, 75 - bought))
    return discounted * (250000 + 10000 * bought)
        + 10000 * discounted * (discounted - 1) / 2 + (amount - discounted) * 1000000
end
function P.collectorRecovery(slots, safeNonCollector, honey, bought, active, inventory, target)
    local base=P.refill(slots)
    local missing=math.max(0,(target or base)-(inventory or 0))
    return base>100 and safeNonCollector>0 and (active==true or honey<P.jellyCost(bought,missing))
end
function P.refillFor(slots, collectorFallback)
    if collectorFallback and P.refill(slots)>100 then return 100,100 end
    return P.refill(slots)
end
function P.plan(cells, types, ctx)
    local stage = P.stage(ctx)
    local collectorFallback=P.refill(ctx.slots)>100 and ctx.collectorFallback==true
    local recoveryMode,recoveryReason=P.recoveryMode(ctx.honey)
    local post = stage == "blue" or stage == "final"
    local keep, needs, protected, temporary = {}, {}, {}, {}
    local function reserve(name, amount, giftedOnly)
        local kept = 0
        for _, pass in ipairs({true, false}) do
            for _, c in ipairs(cells) do
                if kept < amount and c.bee and c.bee.Type == name and P.gifted(c) == pass
                    and (not giftedOnly or pass) then
                    keep[P.key(c)] = true
                    kept = kept + 1
                end
            end
        end
        return kept
    end
    local function need(name, amount, giftedOnly)
        local n = P.count(cells, name, giftedOnly)
        if n < amount then needs[#needs + 1] = {name=name, amount=amount-n, gifted=giftedOnly == true} end
    end
    local function reserveNormal(name, amount)
        local kept = 0
        for _, c in ipairs(cells) do
            if keep[P.key(c)] and c.bee and c.bee.Type == name then kept = kept + 1 end
        end
        for _, c in ipairs(cells) do
            if kept < amount and c.bee and c.bee.Type == name and not P.gifted(c)
                and not keep[P.key(c)] then
                keep[P.key(c)] = true
                kept = kept + 1
            end
        end
        return kept
    end
    for _, c in ipairs(cells) do
        if c.bee then
            local rarity = assert(types[c.bee.Type], "Unknown bee " .. c.bee.Type).Rarity
            if rarity == "Event" or rarity == "Mythic" then
                keep[P.key(c)], protected[P.key(c)] = true, true
            end
        end
    end
    for _, name in ipairs(post and P.trueSingles or P.singles) do reserve(name, 1, true) end
    local uniqueGifted = {}
    for k,v in pairs(keep) do uniqueGifted[k] = v end
    local babyGoal = stage == "final" and math.max(0, 4 - P.count(cells, "Tadpole", true)) or 4
    if stage == "final" and ctx.replaceGiftedBabyOnly then
        babyGoal = math.max(babyGoal, P.count(cells, "Baby") - P.count(cells, "Baby", true))
    end
    reserve("Baby", babyGoal, false)
    reserve("Music", 4, false)
    if not post then
        -- Cheap crit/red placeholders compete by rank; gifted failsafes are additional keeps.
        local crit, red = 0, 0
        for _, c in ipairs(cells) do
            if keep[P.key(c)] and c.bee then
                if c.bee.Type == "Music" or c.bee.Type == "Commander" or c.bee.Type == "Looker" then
                    crit = crit + 1
                elseif c.bee.Type == "Shy" or c.bee.Type == "Fire" then
                    red = red + 1
                end
            end
        end
        for _, name in ipairs({"Music", "Commander", "Looker"}) do
            for _, pass in ipairs({true, false}) do
                for _, c in ipairs(cells) do
                    local exactDuplicate = pass and P.exactGifted[name] and P.count(cells, name, true) >= 1
                    if crit < 4 and c.bee and c.bee.Type == name and P.gifted(c) == pass
                        and not keep[P.key(c)] and not exactDuplicate then
                        keep[P.key(c)], crit = true, crit + 1
                    end
                end
            end
        end
        for _, name in ipairs({"Shy", "Fire"}) do
            for _, pass in ipairs({true, false}) do
                for _, c in ipairs(cells) do
                    local exactDuplicate = pass and P.exactGifted[name] and P.count(cells, name, true) >= 1
                    if red < 3 and c.bee and c.bee.Type == name and P.gifted(c) == pass
                        and not keep[P.key(c)] and not exactDuplicate then
                        keep[P.key(c)], red = true, red + 1
                    end
                end
            end
        end
        reserve("Bubble", 4, false); reserve("Frosty", 4, false)
        -- Ninja has two collector force slots, but only one gifted Ninja is a
        -- failsafe copy. Fill the second force slot with a normal Ninja when
        -- possible, leaving any extra gifted copy eligible for reroll.
        reserve("Ninja", 1, true); reserveNormal("Ninja", 2)
        -- Only opportunistically keep collectors. They can be consumed for fixed targets.
        need("Baby", 4, false); need("Music", 4, false); need("Shy", 3, false)
        if stage ~= "early" then
            for _, name in ipairs(P.mid) do need(name, 1, true) end
        end
        if stage == "late" and ctx.lateStarted then
            for _, name in ipairs(P.legendary) do need(name, 1, true) end
        end
        if ctx.starPrepare then
            for name, info in pairs(types) do
                if info.Rarity ~= "Event" and info.Rarity ~= "Mythic" and name ~= "Basic" then
                    reserve(name, 1, true); need(name, 1, true)
                end
            end
        end
    else
        for _,name in ipairs(P.trueSingles) do need(name, 1, true) end
        if stage == "blue" then reserve("Ninja", 1, true); reserve("Shy", 1, true) end
        need("Baby", babyGoal, false); need("Music", 4, false)
        if stage == "final" then
            reserve("Diamond", 4, true); need("Diamond", 4, true)
            need("Fuzzy", 1, true)
            need("Music", 1, true)
            if babyGoal > 0 then need("Baby", 1, true) end
            for _,name in ipairs({"Tabby", "Gummy", "Vicious", "Puppy", "Festive"}) do need(name, 1, true) end
        end
        local tadGoal = stage == "final" and 10 or 10
        local buoyGoal = stage == "final" and 17 or 15
        need("Tadpole", tadGoal, false); need("Buoyant", buoyGoal, false)
        if stage == "final" then need("Tadpole", 1, true); need("Buoyant", 1, true) end
        local tadCap, buoyCap = stage == "final" and 10 or 14, 17
        for _, spec in ipairs({{"Tadpole", tadCap}, {"Buoyant", buoyCap}}) do
            local ranked = {}
            for _, c in ipairs(cells) do if c.bee and c.bee.Type == spec[1] then ranked[#ranked+1] = c end end
            table.sort(ranked, function(a,b)
                if P.gifted(a) ~= P.gifted(b) then return P.gifted(a) end
                return P.key(a) < P.key(b)
            end)
            for i = spec[2]+1, #ranked do
                local c = ranked[i]
                local release = stage == "final" or spec[1] == "Buoyant" or ctx.jelly >= 25000 or ctx.canRefill30k
                if release then keep[P.key(c)], protected[P.key(c)] = nil, nil end
                if not release and spec[1] == "Tadpole" and ctx.jelly < 10000 then temporary[P.key(c)] = true end
            end
        end
    end
    local candidates, conversion = {}, {}
    for _, c in ipairs(cells) do
        if c.bee and not keep[P.key(c)] then candidates[#candidates+1] = c end
        if not post and stage ~= "early" and c.bee and not P.gifted(c)
            and (c.bee.Type == "Bubble" or c.bee.Type == "Frosty") then conversion[#conversion+1] = c end
    end
    local function priority(c)
        if c.bee.Type == "Lion" then return 1 end
        if c.bee.Type == "Ninja" then return 2 end
        if c.bee.Type == "Bubble" or c.bee.Type == "Frosty" then return 3 end
        return 4
    end
    table.sort(candidates, function(a,b)
        if priority(a) ~= priority(b) then return priority(a) < priority(b) end
        return P.key(a) < P.key(b)
    end)
    -- Temporary crit/red placeholders must eventually yield to Music/Shy. When
    -- collector extras are exhausted, release one lowest-ranked placeholder;
    -- retain the unique gifted failsafes reserved above.
    if not post and #candidates == 0 then
        local upgrades = {}
        if P.count(cells, "Music") < 4 then
            upgrades[#upgrades+1] = "Looker"; upgrades[#upgrades+1] = "Commander"
        end
        if P.count(cells, "Shy") < 3 then upgrades[#upgrades+1] = "Fire" end
        for _, name in ipairs(upgrades) do
            for _, c in ipairs(cells) do
                if c.bee and c.bee.Type == name and not uniqueGifted[P.key(c)] then
                    keep[P.key(c)] = nil
                    candidates[1] = c
                    break
                end
            end
            if candidates[1] then break end
        end
    end
    local fallbackCandidates = {}
    for _, c in ipairs(candidates) do
        if not P.isCollectorSection(c) then fallbackCandidates[#fallbackCandidates + 1] = c end
    end
    local target, mode, reason = nil, "off", nil
    local royalNeeds = false
    for _,n in ipairs(needs) do
        if types[n.name].Rarity ~= "Event" and n.name ~= "Basic" then royalNeeds = true end
    end
    if collectorFallback and #fallbackCandidates > 0 then
        -- Repair safe noncollectors before returning to the normal stage refill.
        target, mode, reason = fallbackCandidates[1], recoveryMode, recoveryReason
    elseif #needs > 0 and royalNeeds then
        target, reason = candidates[1], "fixed-targets"
        local normalNeed = false
        for _, n in ipairs(needs) do if not n.gifted then normalNeed = true end end
        mode = normalNeed and (ctx.slots >= 35 and not post and "legendary" or "off") or "gifted"
        if post then mode = "gifted" end
    elseif not post and stage ~= "early" and #conversion > 0 then
        -- Surplus normals first; once exhausted release one of the four force copies.
        table.sort(conversion, function(a,b)
            local ak, bk = keep[P.key(a)] == true, keep[P.key(b)] == true
            if ak ~= bk then return not ak end
            if ctx.nextFlexible and a.bee.Type ~= b.bee.Type then return a.bee.Type == ctx.nextFlexible end
            return P.key(a) < P.key(b)
        end)
        target, mode, reason = conversion[1], "gifted", "convert-flexible"
    elseif not post then
        for _, c in ipairs(candidates) do
            local t = c.bee.Type
            if t ~= "Bubble" and t ~= "Frosty" and (stage ~= "early" or (t ~= "Lion" and t ~= "Ninja")) then
                target, reason = c, stage == "early" and "collector" or "gifted-collector"
                mode = stage == "early" and "off" or "gifted"
                break
            end
        end
    elseif stage == "blue" and #candidates > 0 then target, mode, reason = candidates[1], "gifted", "blue-fill" end
    local cleanupTarget
    if stage == "final" then
        for _,c in ipairs(candidates) do
            if c.bee.Type == "Baby" or c.bee.Type == "Tadpole" or c.bee.Type == "Buoyant" then cleanupTarget=c; break end
        end
        if #needs == 0 and cleanupTarget then target, mode, reason=cleanupTarget,"gifted","final-surplus" end
    end
    local waitingLate = stage == "late" and not ctx.lateStarted
    -- At 44+, the 10k entry condition gates legendary work, not early repairs.
    if waitingLate and #needs == 0 and reason ~= "convert-flexible" and not collectorFallback then target = nil end
    return {stage=stage, keep=keep, protected=protected, temporary=temporary, needs=needs, candidates=candidates,
        fallbackCandidates=fallbackCandidates, collectorFallback=collectorFallback and #fallbackCandidates>0,
        recoveryGifted=recoveryMode=="gifted",
        target=target, mode=mode, reason=reason, babyGoal=babyGoal,
        complete=stage == "final" and #needs == 0 and not cleanupTarget}
end
return P
