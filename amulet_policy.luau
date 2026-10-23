-- Pure decisions over verified game amulet packages. No services or spending.
local P={tiers={"Bronze","Silver","Gold","Diamond","Supreme"},requirements={5,10,20,30,40},prices={25000000,50000000,250000000,1000000000,10000000000}}
local function finite(n) return type(n)=="number" and n==n and n>-math.huge and n<math.huge end
function P.read(a)
    if a==nil then return nil end
    if type(a)~="table" or type(a.Type)~="string" or type(a.Mods)~="table" then return nil,"invalid-amulet" end
    local o={type=a.Type,rank=0,convert=0,blue=0,critChance=0,critPower=0,attack=0,capacity=0,pollen=0,honeyPerPollen=0,bond=0,pop=false}
    for i,n in ipairs(P.tiers)do if a.Type:sub(1,#n)==n then o.rank=i end end
    for _,m in ipairs(a.Mods)do
        if type(m)~="table" or not finite(m.Value) or type(m.Type)~="string" then return nil,"invalid-modifier" end
        local p=m.Params or{};if type(p)~="table" then return nil,"invalid-modifier-params" end
        local global=next(p)==nil
        if m.Type=="BaseProductionRate" and global then o.convert+=m.Op=="Mul" and m.Value-1 or m.Value
        elseif m.Type=="PollenBonus" then
            if p.Color=="Blue" and not p.Tag and not p.Zone then o.blue+=m.Value elseif global then o.pollen+=m.Value end
        elseif m.Type=="CriticalChance" and global then o.critChance+=m.Value
        elseif m.Type=="CriticalPower" and global then o.critPower+=m.Value
        elseif m.Type=="BeeAttack" and global then o.attack+=m.Value
        elseif (m.Type=="ContainerSpace" or m.Type=="ContainerSpaceMultiplier") and global then o.capacity=math.max(o.capacity,m.Value)
        elseif m.Type=="PollenValue" and global then o.honeyPerPollen+=m.Value
        elseif m.Type=="TreatBondMultiplier" and global then o.bond+=m.Value
        elseif m.Type=="PlayerAbility" and p.Ability=="Pop Star" and m.Value>0 then o.pop=true end
    end
    return o
end
local function antGood(o)
    local crit=o.rank==1 or ((o.rank==2 or o.rank==3)and(o.critChance>0 or o.critPower>0))
        or(o.rank>=4 and o.critChance>0 and o.critPower>0)
    return o.convert>0 and o.blue>0 and crit and(o.rank<5 or o.attack>=1)
end
function P.starGood(o)
    return o and o.capacity>0 and o.blue>0 and(o.rank==5 and o.pop or o.rank<5 and o.pollen>0)
end
function P.moonGood(o) return o and o.capacity>=250000 and o.honeyPerPollen>0 end
function P.rejectDualPrompt(text) return text=="Spend 500 billion honey to guarantee 2 passive abilities?" end
function P.generated(beforeUses,afterUses,expectedType,candidates)
    if type(beforeUses)~="number"or afterUses~=beforeUses+1 then return false end
    if not expectedType then return true end
    for _,v in ipairs(candidates or{})do
        if v.package and v.package.Type==expectedType and type(v.package.Mods)=="table"then return true end
    end
    return false
end
function P.choose(group,current,offered)
    local n,err=P.read(offered);if not n then return nil,err end
    local old,oldErr=P.read(current);if current~=nil and not old then return nil,oldErr end
    if group=="King Beetle" then
        if not old then return true,"first-king-beetle" end
        if n.attack>=1 and old.attack<1 then return true,"bee-attack-upgrade" end
        return n.convert>old.convert,"convert-rate"
    elseif group=="Ant" then
        if n.rank==0 then return nil,"unknown-ant-tier" end
        if not old then return true,"first-ant" end
        if n.rank<old.rank then return false,"lower-ant-tier" end
        local good,was=antGood(n),antGood(old)
        if good and (not was or n.rank>old.rank) then return true,"required-ant-stats" end
        if was and not good and n.rank==old.rank then return false,"required-ant-stats-lost" end
        if n.rank>old.rank and not good then
            -- Human fallback compares only percentage stats present on both.
            local total=0;local shared=0
            for _,k in ipairs({"blue","critChance","critPower","convert"})do
                if n[k]>0 and old[k]>0 then total+=n[k]-old[k];shared+=1 end
            end
            return shared>0 and total>0,"temporary-ant-shared-percentages"
        end
        for _,k in ipairs({"blue","critChance","critPower","convert"})do if n[k]~=old[k]then return n[k]>old[k],"ant-priority:"..k end end
        return false,"ant-no-improvement"
    elseif group=="Star" then
        if n.rank==0 then return nil,"unknown-star-tier" end
        if old and n.rank<old.rank then return false,"lower-star-tier" end
        return P.starGood(n),"required-star-stats"
    elseif group=="Moon" then
        if not old then return true,"first-moon" end
        if P.moonGood(old) then return false,"moon-goal-already-complete" end
        if P.moonGood(n) then return true,"moon-goal-complete" end
        return n.capacity>old.capacity,"moon-capacity"
    end
    return nil,"unsupported-amulet-group"
end
function P.starTarget(discovered,current)
    if not finite(discovered) or discovered%1~=0 or discovered<0 then return nil,"unknown-gifted-discovery" end
    local rank=0;for i,n in ipairs(P.requirements)do if discovered>=n then rank=i end end
    if rank==0 then return nil,"gifted-types-below-five" end
    local old=P.read(current)
    if old and(old.rank>rank or old.rank==rank and P.starGood(old))then return nil,"star-goal-complete" end
    return {rank=rank,name=P.tiers[rank].." Star Amulet Generator",price=P.prices[rank],gifted=P.requirements[rank]}
end
return P
