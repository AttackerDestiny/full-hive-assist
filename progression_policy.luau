-- Pure progression decisions. The host supplies verified ownership, prices,
-- conditions and coordinates, and revalidates every action before a remote.
local P = {}
P.codes = {"Wax", "Roof", "Nectar", "Crawlers", "Connoisseur", "BopMaster", "BeesBuzz123", "38217"}
P.stages = {
    {gate=0, gear={"Clippers", "Jar", "Canister", "Vacuum", "Basic Boots", "Belt Pocket", "Helmet",
        "Super-Scooper", "Compressor", "Electro-Magnet", "Port-O-Hive", "Honey Dipper", "Propeller Hat",
        "Hiking Boots", "Brave Guard", "Looker Guard", "Bubble Wand"}},
    {gate=0, gear={"Basic Sprinkler", "Candy Planter", "Blue Port-O-Hive", "Beekeeper's Mask", "Beekeeper's Boots",
        "Mondo Belt Bag", "Blue Clay Planter", "Red Clay Planter"}},
    {gate=0, gear={"Porcelain Dipper"}},
    {gate=35, gear={"Porcelain Port-O-Hive", "Bubble Mask"}},
    {gate=36, gear={"Silver Soakers", "Cobalt Guard"}},
    {gate=0, gear={"Golden Gushers", "TackyPlanter", "Crimson Guard", "Diamond Drenchers", "Diamond Mask",
        "Petal Belt", "Coconut Canister", "The Supreme Saturator", "Pesticide Planter"}},
}
-- Latest human priority for existing 36+-slot accounts. The original route
-- stays intact below that capacity; this catch-up intentionally puts Red
-- before Blue in the order given by the newer instruction.
P.planterCatchup={"Candy Planter","Red Clay Planter","Blue Clay Planter","TackyPlanter"}
P.bannedCraft = {Gumdrops=true, MoonCharm=true, StarJelly=true, SoftWax=true, HardWax=true}
P.waitOnly = {MoonCharm=true, StarJelly=true, MagicBean=true, SoftWax=true, HardWax=true}
P.recipeOrder = {"BlueExtract", "RedExtract", "Enzymes", "Oil", "Glue", "TropicalDrink", "Glitter",
    "PurplePotion", "SoftWax", "HardWax", "SwirledWax", "CausticWax"}
-- These are the human's supplied recipes, not inferred game interfaces.
-- Verified catalog.recipes entries override them, including output yield.
P.recipes = {
    BlueExtract={yield=1, ingredients={Blueberry=50, RoyalJelly=10}},
    RedExtract={yield=1, ingredients={Strawberry=50, RoyalJelly=10}},
    Enzymes={yield=1, ingredients={Pineapple=50, RoyalJelly=10}},
    Oil={yield=1, ingredients={SunflowerSeed=50, RoyalJelly=10}},
    Glue={yield=1, ingredients={Gumdrops=50, RoyalJelly=10}},
    TropicalDrink={yield=1, ingredients={Coconut=10, Enzymes=2, Oil=2}},
    Glitter={yield=1, ingredients={MoonCharm=25, MagicBean=1}},
    PurplePotion={yield=1, ingredients={RedExtract=3, BlueExtract=3, Glue=3, Neonberry=3}},
    SoftWax={yield=1, ingredients={Honeysuckle=5, Oil=1, Enzymes=1, RoyalJelly=10}},
    HardWax={yield=1, ingredients={SoftWax=3, Enzymes=3, Bitterberry=33, RoyalJelly=33}},
    SwirledWax={yield=1, ingredients={HardWax=3, SoftWax=9, PurplePotion=6, RoyalJelly=3333}},
    CausticWax={yield=1, ingredients={HardWax=5, Enzymes=5, Neonberry=25, RoyalJelly=5252}},
}
local function integer(n) return type(n)=="number" and n>=0 and n<math.huge and n%1==0 end
local function add(map,key,n) map[key]=(map[key] or 0)+n end
local function copy(t) local out={}; for k,v in pairs(t or {}) do out[k]=v end; return out end
local function orderedKeys(t,order)
    local keys,seen={},{}
    for _,k in ipairs(order or P.recipeOrder) do if t[k]~=nil and not seen[k] then keys[#keys+1]=k; seen[k]=true end end
    local rest={}; for k in pairs(t) do if not seen[k] then rest[#rest+1]=k end end
    table.sort(rest); for _,k in ipairs(rest) do keys[#keys+1]=k end
    return keys
end
local function flag(map,key,known)
    if type(map)~="table" then return nil end
    local value=map[key]
    if value==nil and known==true then return false end
    if type(value)=="boolean" then return value end
    return nil
end
local function conditionState(required,facts)
    if required~=nil and type(required)~="table" then return nil,"invalid-condition-list" end
    local count=0
    for key,name in pairs(required or {}) do
        if not integer(key) or key<1 or type(name)~="string" then return nil,"invalid-condition-list" end
        count+=1
    end
    if count~=#(required or {}) then return nil,"invalid-condition-list" end
    local blocked
    for _,name in ipairs(required or {}) do
        local value=flag(facts.conditions,name,false)
        if value==nil then return nil,"unknown-condition:"..name end
        if not value then blocked=blocked or name end
    end
    return blocked==nil,blocked
end
local function inventoryReader(facts)
    if type(facts.inventory)~="table" then return nil,"unknown-inventory" end
    for key,value in pairs(facts.inventory) do
        if type(key)~="string" or not integer(value) then return nil,"invalid-inventory" end
    end
    return function(item)
        local value=facts.inventory[item]
        if value==nil and facts.inventoryKnown==true then return 0 end
        if not integer(value) then return nil end
        return value
    end
end
local function wait(reason,base)
    local result=copy(base); result.action={kind="wait",reason=reason}; result.reason=reason
    result.optionalHiveAllowed=base.optionalHiveAllowed==true
    if result.optionalHiveAllowed then result.action.parallelHive=true;result.action.ParallelHive=true end
    return result
end
local function parallelAction(action)
    action.parallelHive=true
    action.ParallelHive=true
    return action
end
function P.nextGear(facts,deferred)
    if integer(facts.capacity) and facts.capacity>=36 then
        for _,gear in ipairs(P.planterCatchup) do
            local owned=flag(facts.ownedGear,gear,facts.ownedGearKnown)
            if owned==nil then return nil,"unknown-ownership:"..gear end
            if not owned and not (deferred and deferred[gear]) then
                local stageIndex
                for i,stage in ipairs(P.stages) do for _,name in ipairs(stage.gear) do
                    if name==gear then stageIndex=i;break end
                end;if stageIndex then break end end
                return {id=gear,stage=stageIndex,gate=0,catchup=true}
            end
        end
    end
    for stageIndex,stage in ipairs(P.stages) do
        for _,gear in ipairs(stage.gear) do
            local owned=flag(facts.ownedGear,gear,facts.ownedGearKnown)
            if owned==nil then return nil,"unknown-ownership:"..gear end
            if not owned and not (deferred and deferred[gear]) then
                return {id=gear,stage=stageIndex,gate=stage.gate}
            end
        end
    end
    return false
end
local function validCost(cost)
    if type(cost)~="table" or next(cost)==nil then return false end
    for item,amount in pairs(cost) do
        if (item~="Honey" and item~="Ticket") or not integer(amount) then return false end
    end
    return true
end
local function afford(cost,honey,read,reserveHoney,reservedItems)
    for item,amount in pairs(cost) do
        local owned=item=="Honey" and honey or read(item)
        local reserve=item=="Honey" and reserveHoney or (reservedItems[item] or 0)
        if owned==nil then return false,"unknown-currency:"..item end
        if owned-reserve<amount then return false,"waiting-currency:"..item end
    end
    return true
end
-- Fixed pack selection uses only host-verified catalog options. A minimum pack
-- may exceed a deficit (for example 3 Gumdrops for 1 missing); no custom amount.
function P.pack(item,deficit,packs)
    if not integer(deficit) or deficit==0 then return nil,"invalid-pack-deficit" end
    if item~="RoyalJelly" and item~="Gumdrops" and item~="Ticket"then return nil,"unsupported-pack-item" end
    if type(packs)~="table" or #packs==0 then return nil,"unknown-packs:"..item end
    local below,above
    for _,pack in ipairs(packs) do
        if type(pack)~="table" or not integer(pack.amount) or pack.amount==0 or not validCost(pack.cost) then
            return nil,"invalid-pack:"..item
        end
        if item=="Gumdrops" then
            local tickets=({[3]=1,[30]=10,[300]=100})[pack.amount]
            if not tickets or pack.cost.Ticket~=tickets or (pack.cost.Honey or 0)~=0 then
                return nil,"invalid-gumdrop-pack"
            end
        elseif item=="Ticket"then
            if not({[1]=true,[10]=true,[100]=true,[500]=true})[pack.amount]
                or not pack.cost.Honey or pack.cost.Honey<=0 or(pack.cost.Ticket or 0)~=0 then return nil,"invalid-ticket-pack"end
        elseif not pack.cost.Honey or pack.cost.Honey==0 or (pack.cost.Ticket or 0)~=0 then
            return nil,"invalid-jelly-dispenser-pack"
        elseif not ({[1]=true,[10]=true,[100]=true,[1000]=true,[10000]=true,[100000]=true,[1000000]=true})[pack.amount] then
            return nil,"invalid-jelly-dispenser-pack"
        end
        if pack.amount<=deficit then
            if not below or pack.amount>below.amount then below=pack end
        elseif not above or pack.amount<above.amount then above=pack end
    end
    return below or above
end
function P.royalJellyCost(amount,pricing)
    if not integer(amount) or type(pricing)~="table" or not integer(pricing.purchased)
        or not integer(pricing.baseHoney) or not integer(pricing.stepHoney)
        or not integer(pricing.maxHoney) or pricing.maxHoney<pricing.baseHoney then return nil end
    local initial=math.min(pricing.maxHoney,pricing.baseHoney+pricing.stepHoney*pricing.purchased)
    if pricing.stepHoney==0 then return initial*amount end
    local rising=math.min(amount,math.max(0,math.ceil((pricing.maxHoney-initial)/pricing.stepHoney)))
    return initial*rising+pricing.stepHoney*rising*(rising-1)/2+(amount-rising)*pricing.maxHoney
end
function P.craftingJellyCost(amount,catalog)
    if not integer(amount) then return nil,"invalid-crafting-jelly-deficit" end
    if amount==0 then return 0 end
    if catalog.royalJellyPricing~=nil then
        local total=P.royalJellyCost(amount,catalog.royalJellyPricing)
        return total,total==nil and "unknown-full-jelly-cost" or nil
    end
    local unit
    for _,pack in ipairs((catalog.packs or {}).RoyalJelly or {}) do
        local valid=P.pack("RoyalJelly",amount,{pack})
        if not valid then return nil,"invalid-jelly-dispenser-pack" end
        local quote=pack.cost.Honey/pack.amount
        if not integer(quote) or quote==0 or unit and quote~=unit then return nil,"unknown-full-jelly-cost" end
        unit=quote
    end
    if unit==nil then return nil,"unknown-full-jelly-cost" end
    return amount*unit
end
-- Reserve all calculable purchase costs for the complete leaf deficit. Current
-- RJ quotes alone cannot price later packs during the escalating-price phase.
function P.materialCosts(missing,catalog)
    local costs,complete={},true
    for item,deficit in pairs(missing) do
        if item=="RoyalJelly" or item=="Gumdrops" then
            local left,units,tickets,first=deficit,0,0,nil
            while left>0 do
                local pack,err=P.pack(item,left,(catalog.packs or {})[item])
                if not pack then return nil,err end
                first=first or pack
                local count=math.max(1,math.floor(left/pack.amount))
                units+=pack.amount*count;tickets+=(pack.cost.Ticket or 0)*count
                left=math.max(0,left-pack.amount*count)
            end
            if item=="Gumdrops" then add(costs,"Ticket",tickets) else
                local total=P.royalJellyCost(units,catalog.royalJellyPricing)
                if total==nil then
                    if units==first.amount then total=first.cost.Honey else complete=false end
                end
                if total then add(costs,"Honey",total) end
            end
        elseif item=="Diamond" then
            local purchase=(catalog.purchases or {})[item]
            if type(purchase)~="table" or purchase.amount~=1 or not validCost(purchase.cost) then
                complete=false
            else for currency,n in pairs(purchase.cost) do add(costs,currency,n*deficit) end end
        end
    end
    return costs,nil,complete
end
-- Verified ItemPackages.Eggs.GetCost curve. Compare every actual fixed-pack
-- quote with this model before admission; unknown/changed prices fail closed.
function P.ticketCost(purchased,amount)
    if not integer(purchased)or not integer(amount)or amount>400 or purchased+amount>100000 then return nil end
    local total=0
    for i=purchased+1,purchased+amount do
        total+=i>50000 and math.floor((i-50000)^1.85)*10000000+100000000000
            or math.floor((i-1)^(i<500 and 1.2 or 1.7))*1000+100000
    end
    return total
end
-- Recursive reservation consumes each owned unit once across ALL next-gear
-- requirements. Missing outputs do not become virtual owned inventory. Only a
-- recipe whose inputs are already owned is ready to craft in this snapshot.
function P.materials(requirements,facts,catalog)
    if type(requirements)~="table" then return nil,"unknown-gear-materials" end
    catalog=catalog or {}
    for item,quantity in pairs(requirements) do
        if type(item)~="string" or not integer(quantity) then return nil,"invalid-material-demand" end
    end
    local read,err=inventoryReader(facts); if not read then return nil,err end
    local available,reserved,demand,missing,crafts={},{},{},{},{}
    local queued,queuedAllocated={},{}
    if type(facts.craft)=="table" and type(facts.craft.item)=="string" and integer(facts.craft.count)
        and facts.craft.count>0 and type(facts.craft.ready)=="boolean" then
        queued[facts.craft.item]=facts.craft.count
    end
    local function resolve(item,quantity,stack)
        if type(item)~="string" or not integer(quantity) then return nil,"invalid-material-demand" end
        if quantity==0 then return true end
        add(demand,item,quantity)
        if available[item]==nil then
            available[item]=read(item)
            if available[item]==nil then return nil,"unknown-inventory:"..item end
        end
        local held=math.min(quantity,available[item]); available[item]-=held; add(reserved,item,held)
        local deficit=quantity-held; if deficit==0 then return true end
        local queuedHeld=math.min(deficit,queued[item] or 0)
        if queuedHeld>0 then
            queued[item]-=queuedHeld;add(queuedAllocated,item,queuedHeld);deficit-=queuedHeld
            -- Queued output satisfies future demand, but is never treated as
            -- an immediately consumable input or permission to buy gear.
            if deficit==0 then return false end
        end
        if stack[item] then return nil,"cyclic-recipe:"..item end
        local recipe=(catalog.recipes or {})[item]
        if recipe==nil and catalog.useSuppliedRecipes~=false then recipe=P.recipes[item] end
        if P.bannedCraft[item] or item=="MagicBean" or recipe==false then recipe=nil end
        if recipe==nil then add(missing,item,deficit); return false end
        if type(recipe)~="table" or not integer(recipe.yield) or recipe.yield==0
            or type(recipe.ingredients)~="table" or next(recipe.ingredients)==nil then return nil,"invalid-recipe:"..item end
        -- Exact deficit crafting only: do not round an unknown multi-output
        -- recipe into extra production without a separate human instruction.
        if deficit%recipe.yield~=0 then return nil,"nonexact-recipe-yield:"..item end
        local batches=deficit/recipe.yield
        for ingredient,unit in pairs(recipe.ingredients) do
            if type(ingredient)~="string" or not integer(unit) or unit==0 then return nil,"invalid-recipe-ingredient:"..item end
        end
        stack[item]=true
        local ready=true
        local missingInputs,inputs={},{}
        for _,ingredient in ipairs(orderedKeys(recipe.ingredients,recipe.order)) do
            local unit=recipe.ingredients[ingredient]
            if not integer(unit) or unit==0 then return nil,"invalid-recipe-ingredient:"..item end
            local required=unit*batches
            local heldInput=available[ingredient]
            if heldInput==nil then heldInput=read(ingredient) end
            if heldInput==nil then return nil,"unknown-inventory:"..ingredient end
            inputs[ingredient]=required
            if heldInput<required then missingInputs[ingredient]=required-heldInput end
            local got,why=resolve(ingredient,unit*batches,stack)
            if got==nil then return nil,why end
            if not got then ready=false end
        end
        stack[item]=nil
        crafts[#crafts+1]={kind="craft",item=item,amount=deficit,batches=batches,ready=ready,
            ingredients=inputs,missingInputs=missingInputs}
        return false
    end
    for _,item in ipairs(orderedKeys(requirements,catalog.materialOrder)) do
        local ok,why=resolve(item,requirements[item],{})
        if ok==nil then return nil,why end
    end
    return {reservedItems=reserved,materialDemand=demand,missingItems=missing,crafts=crafts,
        queuedItems=queuedAllocated,nextCraft=crafts[1]}
end
-- Growth is allowed only at a required gate; outside a gate the host retains
-- its established auto-hive scheduling and can request this advisory separately.
function P.growth(facts,catalog,target,reserveHoney,reservedItems)
    reservedItems=reservedItems or {};reserveHoney=reserveHoney or 0
    local read,err=inventoryReader(facts); if not read then return {kind="wait",reason=err} end
    if not integer(facts.capacity) or not integer(facts.occupied) or facts.capacity<25
        or facts.capacity>50 or facts.occupied>facts.capacity or not integer(target) or target>50 then
        return {kind="wait",reason="unknown-hive-growth"}
    end
    if not integer(facts.honey) then return {kind="wait",reason="unknown-honey"} end
    if facts.occupied>=target and facts.capacity>=target then return {kind="gate-ready"} end
    local ownedEgg
    for _,item in ipairs({"Basic","Silver","Gold"}) do
        local amount=read(item)
        if amount==nil then return {kind="wait",reason="unknown-inventory:"..item} end
        local reserve=(reservedItems[item] or 0)
        if item=="Gold" then reserve=math.max(reserve,facts.questGoldReserve or 0) end
        if amount>reserve then ownedEgg=item;break end
    end
    local empty=facts.emptyCell
    if facts.occupied<facts.capacity then
        if type(empty)~="table" or empty.verified~=true or not integer(empty.x) or empty.x==0
            or not integer(empty.y) or empty.y==0 then return {kind="wait",reason="need-verified-empty-cell"} end
        if ownedEgg then return {kind=ownedEgg=="Basic" and "hatch-basic" or "hatch-egg",
            item=ownedEgg,amount=1,x=empty.x,y=empty.y} end
        local price=catalog.basicEgg
        if type(price)~="table" or not validCost(price.cost) then return {kind="wait",reason="unknown-basic-egg-cost"} end
        local permitted,condition=conditionState(price.conditions,facts)
        if not permitted then return {kind="wait",reason=condition or "basic-egg-condition"} end
        local ok,why=afford(price.cost,facts.honey,read,reserveHoney,reservedItems)
        if not ok then return {kind="wait",reason=why} end
        return {kind="buy-basic-egg",item="Basic",amount=1,cost=copy(price.cost)}
    end
    local slot,egg=catalog.hiveSlot,catalog.basicEgg
    if facts.capacity>=50 then return {kind="wait",reason="hive-capacity-limit"} end
    if type(slot)~="table" or not validCost(slot.cost)
        or (not ownedEgg and (type(egg)~="table" or not validCost(egg.cost))) then
        return {kind="wait",reason="unknown-slot-and-egg-cost"}
    end
    local permitted,why=conditionState(slot.conditions,facts)
    if not permitted then return {kind="wait",reason=why or "hive-slot-condition"} end
    local total=copy(slot.cost)
    if not ownedEgg then
        local eggPermitted,eggCondition=conditionState(egg.conditions,facts)
        if not eggPermitted then return {kind="wait",reason=eggCondition or "basic-egg-condition"} end
        for item,n in pairs(egg.cost) do add(total,item,n) end
    end
    local ok,reason=afford(total,facts.honey,read,reserveHoney,reservedItems)
    if not ok then return {kind="wait",reason=reason} end
    return {kind="buy-hive-slot",amount=1,cost=copy(slot.cost),nextCapacity=facts.capacity+1}
end
-- Quote one additional occupied cell, including capacity when the hive is full.
function P.growthHoneyCost(facts,catalog,reservedItems)
    local read=inventoryReader(facts)
    if not read then return nil end
    local owned=false
    for _,item in ipairs({"Basic","Silver","Gold"}) do
        local amount=read(item)
        if amount==nil then return nil end
        local reserve=(reservedItems or {})[item] or 0
        if item=="Gold" then reserve=math.max(reserve,facts.questGoldReserve or 0) end
        if amount>reserve then owned=true end
    end
    local cost=0
    if facts.occupied==facts.capacity then
        if facts.capacity>=50 then return nil end
        local slot=catalog.hiveSlot
        if type(slot)~="table" or not validCost(slot.cost) or not integer(slot.cost.Honey) then return nil end
        cost=slot.cost.Honey
    end
    if not owned or facts.occupied<facts.capacity then
        local egg=catalog.basicEgg
        if type(egg)~="table" or not validCost(egg.cost) or not integer(egg.cost.Honey) then return nil end
        cost+=egg.cost.Honey
    end
    return cost
end
local function onlyJellyMissing(materials)
    if not materials then return false end
    for item in pairs(materials.missingItems) do
        if item~="RoyalJelly" then return false end
    end
    return true
end
local function plan(facts,catalog,selectedGear,selectedMaterials)
    local base={optionalHiveAllowed=false,reserveHoney=0,reservedItems={},materialDemand={},missingItems={},costReservations={}}
    if type(facts)~="table" or type(catalog)~="table" then return wait("unknown-progression-facts",base) end
    for _,key in ipairs({"gear","recipes","packs","purchases","sources"}) do
        if catalog[key]~=nil and type(catalog[key])~="table" then return wait("invalid-catalog:"..key,base) end
    end
    if not integer(facts.honey) or not integer(facts.honeyReserve or 0) then return wait("unknown-honey",base) end
    if facts.pending or facts.uncertain then return wait("unresolved-progression-request",base) end
    for _,code in ipairs(P.codes) do
        local redeemed=flag(facts.redeemedCodes,code,facts.codesKnown)
        if redeemed==nil then return wait("unknown-code-state:"..code,base) end
        if not redeemed then base.action={kind="redeem-code",code=code}; return base end
    end
    if not integer(facts.occupied) or not integer(facts.capacity) or facts.capacity<25 or facts.capacity>50
        or facts.occupied>facts.capacity then return wait("unknown-hive-counts",base) end
    local inventory,inventoryError=inventoryReader(facts)
    if not inventory then return wait(inventoryError,base) end
    local nextGear,why=selectedGear
    if not nextGear then nextGear,why=P.nextGear(facts) end
    if nextGear==nil then return wait(why,base) end
    local craftAction
    if facts.craft~=nil and facts.craft~=false then
        local craft=facts.craft
        if type(craft)~="table" or type(craft.item)~="string" or not integer(craft.count) or craft.count==0
            or type(craft.ready)~="boolean" then return wait("unknown-blender-state",base) end
        if not craft.ready and craft.speedupEnabled==true then
            if not integer(craft.remainingUnits) or craft.remainingUnits<1 or craft.remainingUnits>craft.count
                or type(craft.startTime)~="number" or craft.startTime~=craft.startTime
                or craft.startTime<=-math.huge or craft.startTime>=math.huge then return wait("unknown-blender-speedup",base) end
            local tickets=craft.tickets
            local perTicket=craft.autoCompletePerTicket or (catalog.blenderSpeedUp and catalog.blenderSpeedUp.perTicket) or 1
            if not integer(tickets) or not integer(perTicket) or perTicket<1 then return wait("unknown-blender-tickets",base) end
            local needed=math.ceil(craft.remainingUnits/perTicket)
            if tickets<needed then craftAction=parallelAction({kind="wait",reason="waiting-tickets-for-blender"})
            else craftAction=parallelAction({kind="speedup-blender",item=craft.item,amount=craft.count,
                remainingUnits=craft.remainingUnits,orderStartTime=craft.startTime,orderCount=craft.count,tickets=needed}) end
        elseif not craft.ready then
            craftAction=parallelAction({kind="wait",reason="blender-busy"})
        end
        if craft.ready then craftAction={kind="collect-craft",item=craft.item,amount=craft.count} end
    end
    if not nextGear then
        if craftAction then
            if craftAction.parallelHive then base.optionalHiveAllowed=true;base.materialPhase=true end
            base.action=craftAction; return base
        end
        base.optionalHiveAllowed=true; base.reserveHoney=facts.honeyReserve or 0
        base.action={kind="hive",reason="ordered-gear-complete"}; return base
    end
    base.gear=nextGear.id; base.stage=nextGear.stage; base.requiredHive=nextGear.gate
    base.planterCatchup=nextGear.catchup==true
    -- The ordered list explicitly waits for these hive gates BEFORE the next
    -- gear stage. Its future gear price must not block buying the gate itself.
    if facts.occupied<nextGear.gate or facts.capacity<nextGear.gate then
        base.reserveHoney=facts.honeyReserve or 0
        base.action=P.growth(facts,catalog,nextGear.gate,base.reserveHoney,{})
        return base
    end
    local gear=(catalog.gear or {})[nextGear.id]
    if type(gear)~="table" or not integer(gear.honey) or type(gear.items)~="table" then
        return wait("unknown-gear-cost:"..nextGear.id,base)
    end
    -- Material acquisition may proceed in parallel with hive farming. Reserve
    -- only the user's safety reserve until every material/craft deficit clears.
    base.reserveHoney=(facts.honeyReserve or 0)+(selectedGear and not selectedGear.queueSelected and gear.honey or 0)
    local materials,materialError=selectedMaterials
    if not materials then materials,materialError=P.materials(gear.items,facts,catalog) end
    if not materials then return wait(materialError,base) end
    base.reservedItems=materials.reservedItems; base.materialDemand=materials.materialDemand; base.missingItems=materials.missingItems
    base.queuedItems=materials.queuedItems
    base.nextCraft=materials.nextCraft
    base.gearItems=copy(gear.items)
    base.saveCraftingJelly=onlyJellyMissing(materials) and (materials.materialDemand.RoyalJelly or 0)>0
    local gearBudget=gear.honey+(facts.honeyReserve or 0)
    if not next(materials.missingItems) and #materials.crafts==0 and not next(materials.queuedItems)
        and facts.honey<gearBudget then
        base.savingGearHoney=true
        base.reserveHoney=gearBudget
    end
    local costs,costError,complete=P.materialCosts(materials.missingItems,catalog)
    -- Whole-gear cost estimates are diagnostics. An unknown future quote must
    -- never hide a ready collection or the next recipe's actionable deficit.
    base.costReservations=costs or {};base.costReservationsComplete=complete==true
    base.costReservationReason=costError
    if craftAction then
        if craftAction.parallelHive then
            base.optionalHiveAllowed=true
            base.materialPhase=true
        end
        base.action=craftAction; return base
    end
    local materialPhase=(next(materials.missingItems)~=nil or #materials.crafts>0 or next(materials.queuedItems)~=nil)
    if materialPhase then
        base.optionalHiveAllowed=true
        base.materialPhase=true
    end
    local met,condition=conditionState(gear.conditions,facts)
    if met==nil then return wait(condition,base) end
    local read=inventoryReader(facts)
    -- Existing ingredients can be crafted while saving the gear's honey. No
    -- craft action is supplied for banned recipes or future/virtual inputs.
    local jellyDeficit=materials.missingItems.RoyalJelly or 0
    if selectedGear and base.saveCraftingJelly and jellyDeficit==0 and facts.honey<base.reserveHoney then
        base.optionalHiveAllowed=false
        return wait("saving-gear-honey",base)
    end
    local jellyCraft
    for _,craft in ipairs(materials.crafts) do
        if craft.ready then
            if facts.craft~=false then return wait("need-verified-idle-blender",base) end
            base.nextCraft=craft
            base.action=parallelAction(copy(craft)); base.action.gear=nextGear.id; return base
        end
        if (craft.missingInputs.RoyalJelly or 0)>0
            and next(craft.missingInputs)=="RoyalJelly" and next(craft.missingInputs,"RoyalJelly")==nil then
            jellyCraft=craft
            break
        end
    end
    local diamond=(catalog.sources or {}).Diamond
    if (materials.missingItems.Diamond or 0)>0 and diamond and diamond.kind=="claim-token"
        and type(diamond.id)=="string" and type(diamond.readyCondition)=="string"
        and flag(facts.conditions,diamond.readyCondition,false) then
        base.action={kind="acquire-material",item="Diamond",sourceId=diamond.id,sourceKind=diamond.kind,amount=1}
        return base
    end
    -- A complete recipe can be prepared independently of other gear inputs.
    local fundingRecipeJelly=jellyCraft~=nil and facts.craft==false
    if fundingRecipeJelly then base.nextCraft=jellyCraft end
    local inventoryRequired
    for _,item in ipairs(orderedKeys(materials.missingItems,catalog.materialOrder)) do
        if P.waitOnly[item] or (gear.items[item] and item~="RoyalJelly" and item~="Gumdrops"
            and not (catalog.purchases or {})[item] and not (catalog.sources or {})[item]) then
            inventoryRequired=item
            break
        end
    end
    local firstMissing=inventoryRequired
    local actionableMissing=fundingRecipeJelly and jellyCraft.missingInputs
        or materials.nextCraft and materials.nextCraft.missingInputs or materials.missingItems
    if fundingRecipeJelly then
        -- The next recipe has every non-jelly input. Protect its accumulated
        -- jelly while funding the remaining deficit, until that craft queues.
        base.optionalHiveAllowed=false
        base.craftingJellyRequired=jellyCraft.ingredients.RoyalJelly
        base.craftingJellyDeficit=actionableMissing.RoyalJelly
    end
    for _,item in ipairs(orderedKeys(actionableMissing,catalog.materialOrder)) do
        if item=="RoyalJelly" and not fundingRecipeJelly then continue end
        firstMissing=firstMissing or item
        local deficit=actionableMissing[item]
        if P.waitOnly[item] then continue end
        if item~="MagicBean" and (item=="RoyalJelly" or item=="Gumdrops") then
            if item=="RoyalJelly" then
                -- Admission is for the entire fresh remaining recipe deficit,
                -- never merely the next pack. Fixed packs are sent only after
                -- this gate and the deficit is repriced after every purchase.
                base.optionalHiveAllowed=false
                base.saveCraftingJelly=true
                base.requiredRJ=jellyCraft.ingredients.RoyalJelly
                base.missingRJ=deficit
                local fullCost,pricingError=P.craftingJellyCost(deficit,catalog)
                if fullCost==nil then return wait(pricingError,base) end
                base.fundsRequired=fullCost+base.reserveHoney
                if facts.honey<base.fundsRequired then
                    local pending=wait("saving-crafting-jelly",base)
                    pending.action.parallelHive=false;pending.action.ParallelHive=false
                    pending.action.fundsRequired=base.fundsRequired;pending.action.requiredRJ=base.requiredRJ;pending.action.missingRJ=deficit
                    return pending
                end
            end
            local pack,packError
            if item=="RoyalJelly" and catalog.customRoyalJelly then
                pack=catalog.customRoyalJelly(deficit)
                packError="custom-jelly-quote-unavailable"
            else
                pack,packError=P.pack(item,deficit,(catalog.packs or {})[item])
            end
            if not pack then return wait(packError,base) end
            if item=="RoyalJelly" and pack.amount>deficit then return wait("no-exact-fixed-jelly-pack",base) end
            local allowed,packCondition=conditionState(pack.conditions,facts)
            if not allowed then return wait(packCondition or "pack-condition",base) end
            if item=="RoyalJelly" and catalog.royalJellyPricing then
                local quote=P.royalJellyCost(pack.amount,catalog.royalJellyPricing)
                if quote==nil or quote~=pack.cost.Honey then return wait("inconsistent-jelly-price",base) end
            end
            local ok,reason=afford(pack.cost,facts.honey,read,base.reserveHoney,base.reservedItems)
            if not ok and item~="RoyalJelly" then
                -- Fund the current recipe with supported smaller packs when a
                -- larger fixed pack is unaffordable; never form a custom pack.
                local best
                for _,candidate in ipairs((catalog.packs or {})[item] or {}) do
                    local valid=P.pack(item,deficit,{candidate})
                    local permitted=valid and conditionState(candidate.conditions,facts)
                    if permitted and candidate.amount<=deficit and afford(candidate.cost,facts.honey,read,base.reserveHoney,base.reservedItems)
                        and (not best or candidate.amount>best.amount) then best=candidate end
                end
                if best then pack=best;ok=true end
            end
            if ok and item=="RoyalJelly" and catalog.royalJellyPricing then
                local quote=P.royalJellyCost(pack.amount,catalog.royalJellyPricing)
                if quote==nil or quote~=pack.cost.Honey then return wait("inconsistent-jelly-price",base) end
            end
            if ok then
                base.action={kind="purchase-pack",item=item,amount=pack.amount,packId=pack.id,cost=copy(pack.cost)}
                if item~="RoyalJelly" then parallelAction(base.action) end
                return base
            end
            if item=="RoyalJelly" and reason=="waiting-currency:Honey" then
                local pending=wait("saving-crafting-jelly",base)
                pending.action.parallelHive=false;pending.action.ParallelHive=false
                return pending
            end
            local pending=wait(reason,base);pending.action.parallelHive=true;pending.action.ParallelHive=true;return pending
        end
        -- Prefer a specifically verified available token/condenser source over
        -- a purchase of the same missing material; never invent a source.
        local source=(catalog.sources or {})[item]
        if type(source)=="table"
            and type(source.id)=="string" and type(source.readyCondition)=="string"
            and ((source.kind=="claim-token" and item=="Diamond") or source.kind=="nectar-vial") then
            local ready=flag(facts.conditions,source.readyCondition,false)
            if ready then base.action={kind="acquire-material",item=item,sourceId=source.id,sourceKind=source.kind,amount=1}; return base end
        end
        local purchase=(catalog.purchases or {})[item]
        if item=="Diamond" and purchase then
            if type(purchase)~="table" or purchase.amount~=1 or not validCost(purchase.cost) then return wait("unknown-diamond-egg-cost",base) end
            local allowed,purchaseCondition=conditionState(purchase.conditions,facts)
            if not allowed then return wait(purchaseCondition or "diamond-egg-condition",base) end
            local ok,reason=afford(purchase.cost,facts.honey,read,base.reserveHoney,base.reservedItems)
            if not ok and reason=="waiting-currency:Ticket"and catalog.packs and catalog.packs.Ticket
                and #catalog.packs.Ticket>0 then
                local needed=(purchase.cost.Ticket or 0)+(base.reservedItems.Ticket or 0)-(read("Ticket")or 0)
                local bought=catalog.ticketPurchased
                local cost=P.ticketCost(bought,needed)
                if cost==nil then return wait("unknown-ticket-funding-cost",base)end
                base.optionalHiveAllowed=false;base.requiredTickets=needed;base.fundsRequired=cost+base.reserveHoney
                local pack,why=P.pack("Ticket",needed,catalog.packs.Ticket)
                if not pack or pack.amount>needed then return wait(why or"no-exact-fixed-ticket-pack",base)end
                -- A smaller verified pack is required near the final deficit.
                local permitted,condition=conditionState(pack.conditions,facts)
                if not permitted then return wait(condition or"ticket-pack-condition",base)end
                if P.ticketCost(bought,pack.amount)~=pack.cost.Honey then return wait("inconsistent-ticket-price",base)end
                if facts.honey<base.fundsRequired then return wait("saving-diamond-tickets",base)end
                base.action={kind="purchase-pack",item="Ticket",amount=pack.amount,packId=pack.id,cost=copy(pack.cost),forItem="Diamond"}
                return base
            end
            if not ok then local pending=wait(reason,base);pending.action.parallelHive=true;pending.action.ParallelHive=true;return pending end
            base.action=parallelAction({kind="purchase-material",item=item,amount=1,cost=copy(purchase.cost)}); return base
        end
    end
    if firstMissing then local pending=wait("waiting-material:"..firstMissing,base);pending.action.parallelHive=true;pending.action.ParallelHive=true;return pending end
    if #materials.crafts>0 then local pending=wait("waiting-craft-inputs",base);pending.action.parallelHive=true;pending.action.ParallelHive=true;return pending end
    -- Reserve the planned gear before optional hive purchases or rolling.
    -- Already-owned eggs may still hatch through the growth worker.
    base.optionalHiveAllowed=false
    base.materialPhase=false
    base.reserveHoney=gear.honey+(facts.honeyReserve or 0)
    if gear.shopAccess==false then
        base.optionalHiveAllowed=true
        local pending=wait("waiting-shop-access:"..gear.shopName,base)
        parallelAction(pending.action);return pending
    end
    if not met then return wait("waiting-condition:"..tostring(condition),base) end
    -- Early gear yields to a cheaper occupied cell. A full hive includes the
    -- next slot and an egg unless a usable owned egg can fill it.
    local growthHoney=P.growthHoneyCost(facts,catalog,base.reservedItems)
    if nextGear.stage<=4 and not nextGear.catchup and not selectedGear
        and growthHoney~=nil and growthHoney<gear.honey then
        base.reserveHoney=facts.honeyReserve or 0
        base.savingGearHoney=false
        base.optionalHiveAllowed=true
        base.eggBeforeGear=true
        base.growthHoney=growthHoney
        base.action=P.growth(facts,catalog,math.min(50,facts.capacity+(facts.occupied==facts.capacity and 1 or 0)),base.reserveHoney,base.reservedItems)
        return base
    end
    if facts.honey<base.reserveHoney then
        base.optionalHiveAllowed=true
        local pending=wait("saving-gear-honey",base)
        parallelAction(pending.action);return pending
    end
    base.action={kind="buy-gear",gear=nextGear.id,honey=gear.honey,items=copy(gear.items)}
    return base
end
-- Product-facing status uses separate actual and queued output counts. It does
-- not call a queued Blender result inventory or label missing materials as a
-- honey-saving phase.
function P.describe(result,facts,catalog)
    local action=result.action or {kind="wait",reason="unknown-action"}
    local phase=result.materialPhase and "materials" or action.kind=="buy-gear" and "gear-ready"
        or action.reason=="saving-gear-honey" and "saving-gear-honey" or action.kind
    local labels={['buy-gear']='Buying gear',craft='Crafting materials',['collect-craft']='Collecting materials',
        ['purchase-pack']='Buying crafting supplies',['purchase-material']='Buying gear materials',
        ['speedup-blender']='Completing Blender order',['redeem-code']='Redeeming code',hive='Hive progression'}
    local reason=action.reason or result.reason
    local label=labels[action.kind] or (reason=="blender-busy" and "Blender running; hive continues")
        or (reason=="saving-crafting-jelly" and "Saving honey for crafting jelly")
        or (reason=="saving-diamond-tickets"and"Saving honey for Diamond Egg tickets")
        or (phase=="saving-gear-honey" and "Saving honey for gear") or "Waiting for materials or requirements"
    local gear=result.gear and (catalog and catalog.gear or {})[result.gear]
    if type(gear)~="table" then gear=nil end
    local items=gear and gear.items or result.gearItems
    local rows={}
    local materialsKnown=type(items)=="table"
    for _,item in ipairs(orderedKeys(materialsKnown and items or {})) do
        local required=items[item]
        if type(item)~="string" or not integer(required) then materialsKnown=false;continue end
        local actual=type(facts.inventory)=="table" and facts.inventory[item] or nil
        if not integer(actual) then actual=nil end
        if actual==nil and facts.inventoryKnown then actual=0 end
        local queued=(result.queuedItems or {})[item] or 0
        rows[#rows+1]={item=item,required=required,actual=actual,queued=queued,
            deficit=actual and math.max(0,required-actual-queued) or nil}
    end
    return {phase=phase,label=label,reason=reason,targetGear=result.gear,reserveHoney=result.reserveHoney or 0,
        gearHoney=gear and integer(gear.honey) and gear.honey or nil,gearMaterialsKnown=materialsKnown,
        parallelHive=action.parallelHive==true,materials=rows,nextCraft=result.nextCraft,
        fundsRequired=result.fundsRequired,requiredRJ=result.requiredRJ,missingRJ=result.missingRJ,requiredTickets=result.requiredTickets}
end
local function canPrepareLaterGear(facts,catalog,gear,materials)
    if not onlyJellyMissing(materials) then return false end
    if (materials.materialDemand.RoyalJelly or 0)==0 and facts.honey<gear.honey+(facts.honeyReserve or 0) then
        return false
    end
    local remaining=materials.missingItems.RoyalJelly or 0
    if remaining==0 then return true end
    local cost=P.craftingJellyCost(remaining,catalog)
    if not cost then return false end
    if catalog.customRoyalJelly then return true end
    local packs={}
    for _,pack in ipairs((catalog.packs or {}).RoyalJelly or {}) do
        if type(pack)=="table" and conditionState(pack.conditions,facts)==true then packs[#packs+1]=pack end
    end
    while remaining>0 do
        local pack=P.pack("RoyalJelly",remaining,packs)
        if not pack or pack.amount>remaining then return false end
        remaining%=pack.amount
    end
    return true
end

local function laterGear(facts,catalog,primary)
    local deferred={[primary.gear]=true}
    local available=copy(facts)
    available.inventory=copy(facts.inventory)
    for item,held in pairs(primary.reservedItems) do
        available.inventory[item]=math.max(0,(available.inventory[item] or 0)-held)
    end
    while true do
        local candidate=P.nextGear(facts,deferred)
        if not candidate then return nil end
        deferred[candidate.id]=true
        local gear=(catalog.gear or {})[candidate.id]
        if candidate.gate>facts.occupied or candidate.gate>facts.capacity or type(gear)~="table"
            or gear.shopAccess==false or not integer(gear.honey) or type(gear.items)~="table"
            or conditionState(gear.conditions,facts)~=true then continue end
        local candidateFacts=available
        local materials=P.materials(gear.items,candidateFacts,catalog)
        if materials and not next(materials.missingItems) and #materials.crafts==0 and not next(materials.queuedItems)
            and canPrepareLaterGear(available,catalog,gear,materials) then
            return {gear=candidate.id,stage=candidate.stage,deferredGear=primary.gear,gearItems=copy(gear.items),
                reservedItems=copy(primary.reservedItems),reserveHoney=gear.honey+(facts.honeyReserve or 0),
                optionalHiveAllowed=false,action={kind="buy-gear",gear=candidate.id,honey=gear.honey,items=copy(gear.items)}}
        end
        if not canPrepareLaterGear(candidateFacts,catalog,gear,materials) then
            -- A deferred gear item may share recipe inputs with the active one.
            -- Keep its holdings for direct gear costs, but allow shared ingredients.
            candidateFacts=copy(facts)
            candidateFacts.inventory=copy(facts.inventory)
            for item in pairs(gear.items) do candidateFacts.inventory[item]=available.inventory[item] end
            materials=P.materials(gear.items,candidateFacts,catalog)
            if not materials or #materials.crafts==0 or not canPrepareLaterGear(candidateFacts,catalog,gear,materials) then continue end
        end
        local result=plan(candidateFacts,catalog,candidate,materials)
        local action=result.action
        if action.kind~="craft" and not (action.kind=="wait" and result.saveCraftingJelly)
            and not (action.kind=="purchase-pack" and action.item=="RoyalJelly") then continue end
        result.deferredGear=primary.gear
        action.gear=candidate.id
        for item,held in pairs(primary.reservedItems) do
            local unreserved=(facts.inventory[item] or 0)-(result.reservedItems[item] or 0)
            add(result.reservedItems,item,math.min(held,unreserved))
        end
        return result
    end
end

local function queuePlan(facts,catalog,primary)
    if not facts.gearQueues or not primary.gear or facts.pending or facts.uncertain
        or primary.action.kind=="redeem-code" then return nil end
    local queues={A={},B={}}
    local deferred={}
    for _=1,100 do
        local candidate=P.nextGear(facts,deferred)
        if not candidate then break end
        deferred[candidate.id]=true
        local gear=(catalog.gear or {})[candidate.id]
        -- Unknown quotes stay on the established fail-closed planner path.
        if type(gear)~="table" or not integer(gear.honey) or type(gear.items)~="table" then
            if candidate.id==primary.gear then return nil end
            continue
        end
        local kind=next(gear.items) and "B" or "A"
        if #queues[kind]<3 then
            candidate.queueSelected=true;candidate.honey=gear.honey;candidate.order=#queues.A+#queues.B+1
            queues[kind][#queues[kind]+1]=candidate
        end
        if #queues.A==3 and #queues.B==3 then break end
    end
    for _,queue in ipairs({queues.A,queues.B}) do
        table.sort(queue,function(a,b) return a.honey<b.honey or a.honey==b.honey and a.order<b.order end)
        for priority,candidate in ipairs(queue) do candidate.priority=priority end
    end
    local function decide(candidate,f)
        return candidate and plan(f or facts,catalog,candidate) or nil
    end
    local priorityMaterial=decide(queues.B[1])
    local material=priorityMaterial
    local aggregate,requirements,aggregateError
    if facts.discoveryPreparation then
        requirements={}
        for _,candidate in ipairs(queues.B) do
            for item,count in pairs(catalog.gear[candidate.id].items) do add(requirements,item,count) end
        end
        aggregate,aggregateError=P.materials(requirements,facts,catalog)
        if not aggregate then return wait(aggregateError,primary) end
        if queues.B[1] then material=plan(facts,catalog,queues.B[1],aggregate) end
    end
    local held=material and material.reservedItems or {}
    local function finish(result)
        if not result then return nil end
        result.gearQueues=queues
        result.discoveryPreparation=facts.discoveryPreparation==true
        result.queueMaterialRequirements=requirements
        result.queueMaterialsReady=aggregate~=nil and not next(aggregate.missingItems) and #aggregate.crafts==0 and not next(aggregate.queuedItems)
        result.queueMaterialMissing=aggregate and aggregate.missingItems
        result.farmMissing=material and material.missingItems or {}
        if material and material.requiredHive and (facts.occupied<material.requiredHive or facts.capacity<material.requiredHive) then
            result.farmMissing={}
        end
        result.materialFarmGear=facts.discoveryPreparation and "Combined material queue" or queues.B[1] and queues.B[1].id
        if result.action.kind~="buy-gear" then
            for item,count in pairs(held) do result.reservedItems[item]=math.max(result.reservedItems[item] or 0,count) end
        end
        return result
    end
    local function readyPurchase(candidate)
        local gear=catalog.gear[candidate.id]
        if candidate.gate>facts.occupied or candidate.gate>facts.capacity or gear.shopAccess==false
            or conditionState(gear.conditions,facts)~=true then return nil end
        local read=inventoryReader(facts)
        for item,count in pairs(gear.items) do
            if type(item)~="string" or item=="Honey" or not integer(count) then return nil end
        end
        local cost=copy(gear.items);cost.Honey=gear.honey
        if not read or not afford(cost,facts.honey,read,facts.honeyReserve or 0,{}) then return nil end
        -- A fully ready purchase precedes blocked material targets and Blender
        -- work. Its actual spend is revalidated by the host after travel.
        return {gear=candidate.id,stage=candidate.stage,requiredHive=candidate.gate,
            gearItems=copy(gear.items),reservedItems=copy(gear.items),materialDemand={},missingItems={},queuedItems={},
            reserveHoney=gear.honey+(facts.honeyReserve or 0),optionalHiveAllowed=false,
            action={kind="buy-gear",gear=candidate.id,honey=gear.honey,items=copy(gear.items)}}
    end
    -- Ready honey gear is independent of material collection and never invokes
    -- the superseded egg-price diversion. One action is still sent per turn.
    for _,candidate in ipairs(queues.A) do
        local result=readyPurchase(candidate)
        if result then return finish(result) end
    end
    for _,candidate in ipairs(queues.B) do
        local result=readyPurchase(candidate)
        if result then return finish(result) end
    end
    if material then return finish(material) end
    return finish(decide(queues.A[1]))
end
function P.plan(facts,catalog)
    local result=plan(facts,catalog)
    local queued=type(facts)=="table" and type(catalog)=="table" and queuePlan(facts,catalog,result)
    if queued then result=queued
    elseif result.gear and result.action.kind=="wait" and not result.craftingJellyDeficit and result.materialDemand
        and next(result.materialDemand) and (next(result.missingItems) or next(result.queuedItems or {})) then
        result=laterGear(facts,catalog,result) or result
    end
    if facts and facts.discoveryPreparation and not result.gear and result.action.kind=="hive" then
        result.discoveryPreparation=true;result.queueMaterialsReady=true;result.queueMaterialRequirements={}
    end
    result.status=P.describe(result,type(facts)=="table" and facts or {},type(catalog)=="table" and catalog or {})
    return result
end
return P
