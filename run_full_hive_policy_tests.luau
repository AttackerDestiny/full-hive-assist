local P=(function()
-- Pure planner. No Roblox calls; every spending action must revalidate this plan.
local P = {}
P.slotCaps = {Ninja=4, Lion=2}
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
function P.keptGiftedCount(cells,plan,name)
    local count=0
    for _,c in ipairs(cells) do
        if c.bee and c.bee.Type==name and P.gifted(c) and plan.keep[P.key(c)] then count+=1 end
    end
    return count
end
function P.snapshot(stats,types)
    assert(type(stats.Honeycomb)=="table", "Hive snapshot unavailable")
    local purchases=stats.Totals and stats.Totals.Purchases
    assert(type(purchases)=="table", "Hive purchase counters unavailable")
    local bought=purchases.HiveSlots
    if bought==nil then bought=0 end
    assert(type(bought)=="number" and bought>=0 and bought<=25 and bought%1==0,
        "Invalid hive capacity purchase counter")
    local purchasedCapacity=25+bought
    local capacity=stats.UnlockedCells
    if capacity==nil then capacity=purchasedCapacity else
        assert(type(capacity)=="number" and capacity%1==0 and capacity>=purchasedCapacity and capacity<=50,
            "Invalid unlocked hive capacity; refresh before spending")
    end
    local cells,seen={},{}
    for x,col in pairs(stats.Honeycomb) do
        local nx=type(x)=="string" and tonumber(x:match("^x(%d+)$"))
        assert(nx and nx>0 and nx<math.huge and type(col)=="table", "Invalid hive column")
        for y,bee in pairs(col) do
            local ny=type(y)=="string" and tonumber(y:match("^y(%d+)$"))
            assert(ny and ny>0 and ny<math.huge and type(bee)=="table" and types[bee.Type]
                and (bee.Traits==nil or type(bee.Traits)=="table"), "Invalid hive cell")
            local key=nx..","..ny
            assert(not seen[key], "Duplicate normalized hive coordinate")
            seen[key]=true;cells[#cells+1]={x=nx,y=ny,bee=bee}
        end
    end
    assert(#cells<=capacity, "Occupied bees exceed unlocked capacity")
    table.sort(cells,function(a,b) if a.y~=b.y then return a.y<b.y end return a.x<b.x end)
    return cells,capacity
end
-- Capacity is not the number of bees. Acquisition is advisory until the host
-- supplies verified empty-cell and shop interfaces; never guess a spend remote.
function P.growth(cells, capacity, eggs)
    local occupied=#cells
    local empty=math.max(0,capacity-occupied)
    local action=empty>0 and ((eggs and (eggs.Basic or 0)>0) and "hatch-owned-basic" or "acquire-basic-egg")
        or (capacity<50 and "expand-capacity" or "optimize-hive")
    return {Occupied=occupied,Capacity=capacity,Empty=empty,Action=action,
        CanReroll=occupied>=25,AutomaticAcquisition=false}
end
function P.basicSlotSafe(lock, cell, plan)
    return cell and cell.bee and P.key(cell)==P.key(lock)
        and not (plan.protected or {})[P.key(cell)]
        and not (plan.keep or {})[P.key(cell)]
        and not (cell.bee.Type=="Basic" and P.gifted(cell))
end
function P.capacityStatus(cells, keep, needs, capacity)
    local required={}
    for _,c in ipairs(cells) do
        if c.bee and keep[P.key(c)] then required[c.bee.Type]=(required[c.bee.Type] or 0)+1 end
    end
    for _,need in ipairs(needs) do
        local goal=P.count(cells,need.name,need.gifted)+need.amount
        required[need.name]=math.max(required[need.name] or 0,goal)
    end
    local minimum=0
    for _,amount in pairs(required) do minimum+=amount end
    return {Minimum=minimum,Capacity=capacity,Shortfall=math.max(0,minimum-capacity),
        Conflict=minimum>capacity,Required=required}
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
function P.starJellyUpgradeTask(task)
    return task and task.Reason=="convert-flexible"
        and (task.StartedType=="Bubble" or task.StartedType=="Frosty")
end
function P.starJellyUpgrade(plan,task)
    if not plan or plan.reason~="convert-flexible" or not plan.target then return false end
    local target=plan.target
    if (plan.protected or {})[P.key(target)] then return false end
    if P.starJellyUpgradeTask(task) and task.x==target.x and task.y==target.y then
        return true -- Continue this objective through intermediate results.
    end
    return not P.gifted(target) and (target.bee.Type=="Bubble" or target.bee.Type=="Frosty")
end
function P.rollItem(cells,eggs,plan,task)
    if (eggs.StarJelly or 0)>0 and (#P.starJellyMissing(cells)>0
        or P.starJellyUpgrade(plan,task)) then return "StarJelly" end
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
function P.isUsableCollector(cell, cells)
    if not P.isCollectorSection(cell) then return false end
    local cap=P.slotCaps[cell.bee.Type]
    return not cap or P.count(cells,cell.bee.Type)<=cap
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
    -- A newly needed gifted failsafe may replace a normal copy; surplus
    -- normals are then cleaned up. Never finish a roll on another excess copy.
    local slotCap=P.slotCaps[name]
    if slotCap and P.count(cells,name)>slotCap
        and not (gifted and (task.InitialGifted[name] or 0)==0) then return false end
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
        -- Only an explicit Star Egg preparation plan may add all-type keeps.
        if plan.starPrepare and plan.keep[P.key(cell)] and (task.InitialGifted[name] or 0)==0 then
            return true,"star-preparation-result"
        end
        -- Gifted Fire can fill the existing red placeholder group. It is not
        -- an all-type gifted failsafe; a full Shy/Fire group still rejects it.
        if name=="Fire" and plan.keep[P.key(cell)]
            and P.count(cells,name,true)>(task.InitialGifted[name] or 0)
            and P.count(cells,name,true)<=P.keptGiftedCount(cells,plan,name) then
            return true,"placeholder-upgrade"
        end
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
    if P.gifted(cell) and plan.starPrepare and P.count(cells,name,true)>1 then return true end
    if P.gifted(cell) and name=="Fire" and P.count(cells,name,true)>P.keptGiftedCount(cells,plan,name) then return true end
    if P.slotCaps[name] and P.count(cells,name)>P.slotCaps[name] then return true end
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
    -- Ordinary keeps are the configured failsafes/forces only. Historical
    -- preserveUniqueGifted overrides never promote unlisted gifted species.
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
            for _,c in ipairs(cells) do
                if c.bee and P.gifted(c) and keep[P.key(c)] then uniqueGifted[P.key(c)]=true end
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
    local excess = {}
    for name,cap in pairs(P.slotCaps) do
        local ranked={}
        for _,c in ipairs(cells) do if c.bee and c.bee.Type==name then ranked[#ranked+1]=c end end
        table.sort(ranked,function(a,b)
            local ak,bk=keep[P.key(a)]==true,keep[P.key(b)]==true
            if ak~=bk then return ak end
            return P.key(a)<P.key(b)
        end)
        for i=cap+1,#ranked do
            local c=ranked[i]
            if not protected[P.key(c)] then keep[P.key(c)]=nil; excess[P.key(c)]=true end
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
        local ae,be=excess[P.key(a)]==true,excess[P.key(b)]==true
        if ae~=be then return ae end
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
        if not P.isUsableCollector(c,cells) then fallbackCandidates[#fallbackCandidates + 1] = c end
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
    elseif candidates[1] and excess[P.key(candidates[1])] then
        target,mode,reason=candidates[1],stage=="early" and "off" or "gifted","slot-cap"
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
            if excess[P.key(c)] or c.bee.Type == "Baby" or c.bee.Type == "Tadpole" or c.bee.Type == "Buoyant" then cleanupTarget=c; break end
        end
        if #needs == 0 and cleanupTarget then target, mode, reason=cleanupTarget,"gifted","final-surplus" end
    end
    local waitingLate = stage == "late" and not ctx.lateStarted
    -- At 44+, the 10k entry condition gates legendary work, not early repairs.
    if waitingLate and #needs == 0 and reason ~= "convert-flexible" and reason ~= "slot-cap" and not collectorFallback then target = nil end
    local growth=P.growth(cells,ctx.slots,ctx.eggs)
    if ctx.enforceGrowth and not growth.CanReroll then target=nil; reason="hive-growth" end
    local capacityStatus=P.capacityStatus(cells,keep,needs,ctx.slots)
    return {stage=stage, keep=keep, protected=protected, temporary=temporary, needs=needs, candidates=candidates,
        growth=growth,capacityStatus=capacityStatus,starPrepare=ctx.starPrepare==true and not post,
        fallbackCandidates=fallbackCandidates, collectorFallback=collectorFallback and #fallbackCandidates>0,
        recoveryGifted=recoveryMode=="gifted",
        target=target, mode=mode, reason=reason, babyGoal=babyGoal,
        complete=stage == "final" and ctx.slots == 50 and growth.Occupied == 50
            and #needs == 0 and not cleanupTarget and not capacityStatus.Conflict}
end
return P

end)()
local test=(function()
return function(P,T)
    local checked=0
    local function check(v,m) assert(v,m); checked=checked+1 end
    local n=0
    local function cell(t,g) n=n+1; return {x=n,y=1,bee={Type=t,Traits=g and {"Gifted"} or {}}} end
    local function ctx(slots,used,jelly) return {slots=slots,starUsed=used or 0,jelly=jelly or 10000,lateStarted=true} end
    local function hive(list)
        local h={}
        for _,row in ipairs(list) do for _=1,row[2] do h[#h+1]=cell(row[1],row[3]) end end
        return h
    end
    check(P.stage(ctx(39))=="early","39 early")
    check(P.stage(ctx(40))=="mid","40 mid")
    check(P.stage(ctx(44))=="late","44 late")
    check(P.stage(ctx(50,1))=="late","No blue before two eggs")
    check(P.stage(ctx(49,2))=="blue","49 stays blue")
    check(P.stage(ctx(50,2))=="final","50 final")
    for _,slots in ipairs({25,35,40,42,43,44,45,46,47,48,49,50}) do
        local amount,pack=P.refill(slots)
        check(amount%pack==0,"Invalid refill increments")
    end
    for _,bought in ipairs({0,10,74,75,90}) do
        local slow=0
        for i=0,199 do slow=slow+math.min(250000+10000*(bought+i),1000000) end
        check(P.jellyCost(bought,200)==slow,"Jelly ramp formula")
    end
    for _,slots in ipairs({25,35,40,44,46,49,50}) do
        local h={}
        for name,info in pairs(T) do
            if info.Rarity=="Event" or info.Rarity=="Mythic" then
                h[#h+1]=cell(name,false); h[#h+1]=cell(name,true)
            end
        end
        h[#h+1]=cell("Rascal",false)
        local plan=P.plan(h,T,ctx(slots,2))
        for _,c in ipairs(h) do
            if T[c.bee.Type].Rarity=="Event" or T[c.bee.Type].Rarity=="Mythic" then
                check(plan.protected[P.key(c)],"Protected bee released: "..c.bee.Type)
                check(not plan.target or P.key(c)~=P.key(plan.target),"Protected bee targeted")
            end
        end
    end
    local h=hive({{"Bubble",4},{"Frosty",4},{"Ninja",2},{"Lion",1},{"Baby",4},{"Music",4},{"Shy",2}})
    local p=P.plan(h,T,ctx(35))
    check(p.target and p.target.bee.Type=="Lion","Lion replacement priority")
    h[#h+1]=cell("Rascal",false)
    p=P.plan(h,T,ctx(35))
    check(p.target and p.target.bee.Type=="Lion","Lion must precede generic safe bees")
    for _,c in ipairs(h) do if c.bee.Type=="Bubble" or c.bee.Type=="Frosty" or c.bee.Type=="Ninja" then
        check(p.keep[P.key(c)],"Collector minimum released")
    end end
    h=hive({{"Baby",4},{"Music",4},{"Shy",3},{"Bubble",5},{"Frosty",4},{"Ninja",2}})
    p=P.plan(h,T,ctx(35))
    check(not p.target,"Settled early collector hive keeps surplus collectors")
    h=hive({{"Baby",4},{"Music",4},{"Shy",2},{"Bubble",5},{"Frosty",4},{"Ninja",2}})
    p=P.plan(h,T,ctx(35))
    check(p.target and p.target.bee.Type=="Bubble","Surplus Bubble available for Shy")
    h=hive({{"Cool",3,true},{"Looker",3,true},{"Baby",4},{"Music",4},{"Shy",3},{"Bubble",5},{"Frosty",4},{"Ninja",2}})
    p=P.plan(h,T,ctx(40))
    local keptCool,keptLooker=0,0
    for _,c in ipairs(h) do
        if p.keep[P.key(c)] and P.gifted(c) and c.bee.Type=="Cool" then keptCool=keptCool+1 end
        if p.keep[P.key(c)] and P.gifted(c) and c.bee.Type=="Looker" then keptLooker=keptLooker+1 end
    end
    check(keptCool==1,"Failsafe keeps exactly one gifted Cool")
    check(keptLooker==1,"Failsafe keeps exactly one gifted Looker")
    local coolNeed=false
    for _,need in ipairs(p.needs) do if need.name=="Cool" then coolNeed=true end end
    check(not coolNeed,"Existing gifted Cool is skipped as a satisfied failsafe")
    h=hive({{"Baby",4},{"Music",2},{"Looker",1},{"Commander",1},{"Fire",3},{"Bubble",4},{"Frosty",4},{"Ninja",2}})
    p=P.plan(h,T,ctx(35))
    check(p.target and p.target.bee.Type=="Looker","A full placeholder hive must upgrade Looker to Music")
    h=hive({{"Baby",4},{"Music",4},{"Fire",3},{"Bubble",4},{"Frosty",4},{"Ninja",2}})
    p=P.plan(h,T,ctx(35))
    check(p.target and p.target.bee.Type=="Fire","A full placeholder hive must upgrade Fire to Shy")
    h=hive({{"Baby",4},{"Music",2},{"Looker",1,true},{"Commander",1,true},{"Fire",3},{"Bubble",4},{"Frosty",4},{"Ninja",2}})
    p=P.plan(h,T,ctx(35))
    check(p.target and p.target.bee.Type=="Fire","Unique gifted crit failsafes must survive placeholder upgrades")
    h=hive({{"Baby",4},{"Music",4},{"Shy",3},{"Bubble",4},{"Frosty",4}})
    for _,name in ipairs(P.mid) do h[#h+1]=cell(name,true) end
    p=P.plan(h,T,ctx(40))
    check(p.reason=="convert-flexible","Force flexible can convert after fixed gifts")
    check(not P.gifted(p.target),"Conversion targets a normal")
    h=hive({{"Baby",4},{"Music",4},{"Shy",3},{"Bubble",4,true},{"Frosty",4,true},{"Ninja",2}})
    for _,name in ipairs(P.mid) do h[#h+1]=cell(name,true) end
    h[#h+1]=cell("Basic",false)
    p=P.plan(h,T,ctx(40))
    check(p.target and p.target.bee.Type=="Basic" and p.mode=="gifted","New mid-stage cell uses gifted collector rolls")
    h=hive({{"Baby",4},{"Music",4,true},{"Diamond",4,true},{"Tadpole",4,true},{"Tadpole",6},{"Buoyant",17},{"Fuzzy",1,true}})
    p=P.plan(h,T,ctx(50,2))
    check(p.babyGoal==0,"Gifted Tad replaces normal Baby")
    for _,c in ipairs(h) do if c.bee.Type=="Baby" then check(not p.keep[P.key(c)],"Normal baby not released") end end
    h=hive({{"Tadpole",15},{"Buoyant",18},{"Baby",4},{"Music",4}})
    p=P.plan(h,T,ctx(46,2,9000))
    check(P.count(h,"Tadpole")==15,"Fixture")
    local protectedTad,protectedBuoy=0,0
    for _,c in ipairs(h) do if p.protected[P.key(c)] then
        if c.bee.Type=="Tadpole" then protectedTad=protectedTad+1 end
        if c.bee.Type=="Buoyant" then protectedBuoy=protectedBuoy+1 end
    end end
    check(protectedTad==15,"Low-jelly 15th Tad protected from rolling")
    check(protectedBuoy==17,"Buoyant cap")
    p=P.plan(h,T,ctx(46,2,26000)); protectedTad=0
    for _,c in ipairs(h) do if c.bee.Type=="Tadpole" and p.protected[P.key(c)] then protectedTad=protectedTad+1 end end
    check(protectedTad==14,"High-jelly 15th Tad safe")
    h=hive({{"Basic",1,true},{"Bumble",1,true},{"Cool",1,true},{"Looker",1,true},{"Bubble",1,true},
        {"Commander",1,true},{"Bucko",1,true},{"Diamond",4,true},{"Music",1,true},{"Music",3},
        {"Tadpole",4,true},{"Tadpole",6},{"Buoyant",1,true},{"Buoyant",16},{"Fuzzy",1,true},
        {"Tabby",1,true},{"Gummy",1,true},{"Vicious",1,true},{"Puppy",1,true},{"Festive",1,true},
        {"Cobalt",1},{"Frosty",1,true}})
    check(#h==50,"Final hive fixture has 50 bees")
    p=P.plan(h,T,ctx(50,2))
    check(p.complete and not p.target and #p.needs==0,"Final hive must stop rolling when all requirements hold")
    for _,c in ipairs(h) do if c.bee.Type=="Frosty" then c.bee={Type="Baby",Traits={}} end end
    p=P.plan(h,T,ctx(50,2))
    check(not p.complete and p.target and p.target.bee.Type=="Baby","Final surplus Baby must be replaced")
    for _,c in ipairs(h) do if c.bee.Type=="Cool" then c.bee={Type="Hasty",Traits={}} end end
    p=P.plan(h,T,ctx(50,2))
    local needsCool=false
    for _,need in ipairs(p.needs) do if need.name=="Cool" and need.gifted then needsCool=true end end
    check(needsCool and not p.complete,"Final stage must repair missing gifted baseline")
    do
        local base=hive({{"Honey",1},{"Baby",4},{"Music",4},{"Shy",3},{"Bubble",4},{"Frosty",4},{"Ninja",2},{"Cool",1,true}})
        local q=P.plan(base,T,ctx(43))
        local task=P.startRollTask(base[1],base,q)
        local x,y=base[1].x,base[1].y
        task.Rolled=true
        local function result(name,g)
            base[1].bee={Type=name,Traits=g and {"Gifted"} or {}}
            return P.plan(base,T,ctx(43))
        end
        q=result("Exhausted",false)
        check(not P.rollTaskDone(task,base[1],base,T,q),"Honey task continues through Exhausted")
        check(P.rollTaskSafe(task,base[1],base,T,q),"Exhausted remains safe in same task")
        q=result("Cool",true)
        check(q.keep[P.key(base[1])],"Fixture duplicate sorts ahead of old gifted copy")
        check(not P.rollTaskDone(task,base[1],base,T,q),"Duplicate gifted failsafe does not end task")
        check(P.rollTaskSafe(task,base[1],base,T,q),"Duplicate gifted safe despite reordered keep")
        q=result("Baby",false)
        check(not P.rollTaskDone(task,base[1],base,T,q),"Fifth normal Baby does not end task")
        check(P.rollTaskSafe(task,base[1],base,T,q),"Fifth normal Baby stays in active slot")
        q=result("Carpenter",true)
        check(P.rollTaskDone(task,base[1],base,T,q),"First lucky gifted Carpenter ends task")
        base[#base+1]=cell("Carpenter",true)
        q=P.plan(base,T,ctx(43))
        check(not P.rollTaskDone(task,base[1],base,T,q),"Duplicate gifted Carpenter continues")
        q=result("Bumble",true)
        check(P.rollTaskDone(task,base[1],base,T,q),"Missing gifted Bumble satisfies task")
        check(not P.rollTaskSafe(task,base[1],base,T,q),"No reroll after needed gifted result")
        q=result("Tabby",false)
        check(P.rollTaskDone(task,base[1],base,T,q),"Event ends task protected")
        check(not P.rollTaskSafe(task,base[1],base,T,q),"Event never rerolled")
        q=result("Fuzzy",false)
        check(P.rollTaskDone(task,base[1],base,T,q),"Mythic ends task protected")
        q=result("Bubble",false)
        check(not P.rollTaskDone(task,base[1],base,T,q),"Unneeded normal collector does not end gifted task")
        local fallbackTask=P.startRollTask(base[1],base,{stage="mid",reason="collector-fallback",mode="off",needs={}})
        fallbackTask.Rolled=true
        check(P.rollTaskDone(fallbackTask,base[1],base,T,q),"Fallback finishes on a collector result")
        check(task.x==x and task.y==y and task.InitialTotal.Baby==4 and task.InitialGifted.Cool==1,
            "Replanning preserves slot and starting counts")
    end
    do
        local fallbackCtx=ctx(43); fallbackCtx.collectorFallback=true
        local base=hive({{"Honey",1},{"Exhausted",2},{"Baby",4},{"Music",4},{"Shy",3},
            {"Bubble",4},{"Frosty",4},{"Ninja",2},{"Lion",1},{"Tabby",1},{"Fuzzy",1}})
        local q=P.plan(base,T,fallbackCtx)
        check(#q.fallbackCandidates==3,"Honey and Exhausted are three recovery slots")
        check(q.collectorFallback and q.target.bee.Type=="Honey" and q.mode=="off","Recovery chooses noncollector with single rolls")
        check(P.collectorRecovery(43,3,100000000,75,false),"Cannot afford 2k: enter recovery")
        check(not P.collectorRecovery(43,3,2000000000,75,false),"Can afford 2k: normal refill")
        check(P.collectorRecovery(43,3,5000000000,75,true),"Recovery stays until conversion ends")
        check(not P.collectorRecovery(43,0,100000000,75,true),"No noncollector: leave recovery")
        local amount,pack=P.refillFor(43,true)
        check(amount==100 and pack==100,"Recovery buys one 100 pack")
        amount,pack=P.refillFor(43,false)
        check(amount==2000 and pack==1000,"Normal resumes two 1000 packs")
        for i=1,3 do base[i].bee={Type="Bubble",Traits={}} end
        q=P.plan(base,T,fallbackCtx)
        check(not q.collectorFallback and #q.fallbackCandidates==0,"Recovery exits when all safe sources are collectors")
        fallbackCtx.slots=42
        q=P.plan(base,T,fallbackCtx)
        check(not q.collectorFallback,"No recovery at another stage when wrong slots are already repaired")
    end
    -- Exhaustive varied duplicate mixtures: the planner cannot target any kept slot,
    -- except the explicit normal flexible conversion path.
    for i=1,80 do
        h={}
        for j,name in ipairs({"Basic","Bubble","Frosty","Baby","Music","Shy","Ninja","Lion","Tabby","Fuzzy","Tadpole","Buoyant"}) do
            for k=1,(i*j)%6 do h[#h+1]=cell(name,(i+j+k)%3==0) end
        end
        p=P.plan(h,T,ctx(({25,35,40,44,46,50})[i%6+1],2,26000))
        if p.target then
            check(not p.protected[P.key(p.target)],"Fuzz targeted protected slot")
            check(not p.keep[P.key(p.target)] or p.reason=="convert-flexible","Fuzz targeted a force slot")
        end
    end
    -- Species caps count normal and gifted copies together, at every stage.
    for _,spec in ipairs({{"Ninja",4},{"Lion",2}}) do
        local name,cap=spec[1],spec[2]
        check(P.slotCaps[name]==cap,"Configured total cap for "..name)
        for _,slots in ipairs({25,35,41,44,46,50}) do
            local base=hive({{"Baby",4},{"Music",4},{"Shy",3},{"Bubble",4},{"Frosty",4},
                {name,1,true},{name,cap,false},{"Tabby",1},{"Fuzzy",1}})
            local q=P.plan(base,T,ctx(slots,2))
            local kept=0
            for _,c in ipairs(base) do if c.bee.Type==name and q.keep[P.key(c)] then kept+=1 end end
            check(kept<=cap,"Reservations respect total cap at "..slots)
            if slots<46 or (name=="Ninja" and slots<50) then
                check(q.keep[P.key(base[#base-cap-2])],"Existing gifted failsafe retained at "..slots)
            end
            check(q.target and q.target.bee.Type==name and not P.gifted(q.target),"Surplus species selected before other conversion at "..slots)
            local recovery=ctx(slots,2); recovery.collectorFallback=true; recovery.honey=1
            local r=P.plan(base,T,recovery)
            if slots>=35 then
                check(r.collectorFallback and r.target.bee.Type==name,"Over-cap collector enters repair at "..slots)
            end
        end
        for _,existing in ipairs({cap-1,cap}) do
            local base=hive({{"Hasty",1},{name,existing,false}})
            local target=base[1]
            local task=P.startRollTask(target,base,{stage="mid",reason="collector-fallback",mode="off",needs={}})
            task.Rolled=true; target.bee={Type=name,Traits={}}
            local q=P.plan(base,T,{slots=41,starUsed=0,jelly=100,honey=1,collectorFallback=true})
            check(P.rollTaskDone(task,target,base,T,q)==(existing<cap),"Recovery result respects "..name.." cap")
            check(P.rollTaskSafe(task,target,base,T,q)==(existing>=cap),"Excess new result remains on active coordinate")
        end
        local base=hive({{"Hasty",1},{name,cap,false}})
        local task=P.startRollTask(base[1],base,{stage="mid",reason="collector-fallback",mode="off",needs={}})
        task.Rolled=true; base[1].bee={Type=name,Traits={"Gifted"}}
        local q=P.plan(base,T,ctx(41))
        check(P.rollTaskDone(task,base[1],base,T,q),"First gifted failsafe may replace a normal at cap")
        check(q.target and q.target.bee.Type==name and not P.gifted(q.target),"Cap cleanup releases a normal after gifted upgrade")
    end
    return {passed=checked}
end

end)()
local ok,result=pcall(test,P,require(game.ReplicatedStorage.BeeTypes):GetTypes())
getgenv().FullHivePolicyTests={ok=ok,result=result}
