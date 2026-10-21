-- Pure progression decisions. The host supplies verified ownership, prices,
-- conditions and coordinates, and revalidates every action before a remote.
local P = {}
P.codes = {"Wax", "Roof", "Nectar", "Crawlers", "Connoisseur", "BopMaster", "BeesBuzz123", "38217"}
P.stages = {
    {gate=0, gear={"Clippers", "Jar", "Canister", "Vacuum", "Basic Boots", "Belt Pocket", "Helmet",
        "Super-Scooper", "Compressor", "Electro-Magnet", "Port-O-Hive", "Honey Dipper", "Propeller Hat",
        "Hiking Boots", "Brave Guard", "Looker Guard", "Bubble Wand"}},
    {gate=25, gear={"Basic Sprinkler", "Candy Planter", "Blue Clay Planter", "Red Clay Planter",
        "Beekeeper's Mask", "Beekeeper's Boots", "Mondo Belt Bag"}},
    {gate=34, gear={"Porcelain Dipper"}},
    {gate=35, gear={"Porcelain Port-O-Hive", "Bubble Mask"}},
    {gate=36, gear={"Silver Soakers", "Cobalt Guard"}},
    {gate=0, gear={"Golden Gushers", "TackyPlanter", "Crimson Guard", "Diamond Drenchers", "Diamond Mask",
        "Petal Belt", "Coconut Canister", "The Supreme Saturator"}},
}
P.bannedCraft = {Gumdrops=true, MoonCharm=true, StarJelly=true}
P.waitOnly = {MoonCharm=true, StarJelly=true, MagicBean=true}
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
    return result
end
local function parallelAction(action)
    action.parallelHive=true
    action.ParallelHive=true
    return action
end
function P.nextGear(facts)
    for stageIndex,stage in ipairs(P.stages) do
        for _,gear in ipairs(stage.gear) do
            local owned=flag(facts.ownedGear,gear,facts.ownedGearKnown)
            if owned==nil then return nil,"unknown-ownership:"..gear end
            if not owned then return {id=gear,stage=stageIndex,gate=stage.gate} end
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
    if item~="RoyalJelly" and item~="Gumdrops" then return nil,"unsupported-pack-item" end
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
        elseif not pack.cost.Honey or pack.cost.Honey==0 or (pack.cost.Ticket or 0)~=0 then
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
        for _,ingredient in ipairs(orderedKeys(recipe.ingredients,recipe.order)) do
            local unit=recipe.ingredients[ingredient]
            if not integer(unit) or unit==0 then return nil,"invalid-recipe-ingredient:"..item end
            local got,why=resolve(ingredient,unit*batches,stack)
            if got==nil then return nil,why end
            if not got then ready=false end
        end
        stack[item]=nil
        crafts[#crafts+1]={kind="craft",item=item,amount=deficit,batches=batches,ready=ready}
        return false
    end
    for _,item in ipairs(orderedKeys(requirements,catalog.materialOrder)) do
        local ok,why=resolve(item,requirements[item],{})
        if ok==nil then return nil,why end
    end
    return {reservedItems=reserved,materialDemand=demand,missingItems=missing,crafts=crafts}
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
    local empty=facts.emptyCell
    if facts.occupied<facts.capacity then
        if type(empty)~="table" or empty.verified~=true or not integer(empty.x) or empty.x==0
            or not integer(empty.y) or empty.y==0 then return {kind="wait",reason="need-verified-empty-cell"} end
        local basic=read("Basic"); if basic==nil then return {kind="wait",reason="unknown-inventory:Basic"} end
        if basic>(reservedItems.Basic or 0) then return {kind="hatch-basic",item="Basic",amount=1,x=empty.x,y=empty.y} end
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
    if type(slot)~="table" or type(egg)~="table" or not validCost(slot.cost) or not validCost(egg.cost) then
        return {kind="wait",reason="unknown-slot-and-egg-cost"}
    end
    local permitted,why=conditionState(slot.conditions,facts)
    if not permitted then return {kind="wait",reason=why or "hive-slot-condition"} end
    local basic=read("Basic");if basic==nil then return {kind="wait",reason="unknown-inventory:Basic"} end
    local total=copy(slot.cost)
    if basic<=(reservedItems.Basic or 0) then
        local eggPermitted,eggCondition=conditionState(egg.conditions,facts)
        if not eggPermitted then return {kind="wait",reason=eggCondition or "basic-egg-condition"} end
        for item,n in pairs(egg.cost) do add(total,item,n) end
    end
    local ok,reason=afford(total,facts.honey,read,reserveHoney,reservedItems)
    if not ok then return {kind="wait",reason=reason} end
    return {kind="buy-hive-slot",amount=1,cost=copy(slot.cost),nextCapacity=facts.capacity+1}
end
function P.plan(facts,catalog)
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
    local nextGear,why=P.nextGear(facts)
    if nextGear==nil then return wait(why,base) end
    local craftAction
    if facts.craft~=nil and facts.craft~=false then
        local craft=facts.craft
        if type(craft)~="table" or type(craft.item)~="string" or not integer(craft.count) or craft.count==0
            or type(craft.ready)~="boolean" then return wait("unknown-blender-state",base) end
        if not craft.ready and craft.speedupEnabled==true then
            if not integer(craft.remainingUnits) or craft.remainingUnits<1 then return wait("unknown-blender-speedup",base) end
            local tickets=craft.tickets
            local perTicket=catalog.blenderSpeedUp and catalog.blenderSpeedUp.perTicket or 1
            if not integer(tickets) or not integer(perTicket) or perTicket<1 then return wait("unknown-blender-tickets",base) end
            local needed=math.ceil(craft.remainingUnits/perTicket)
            if tickets<needed then return wait("waiting-tickets-for-blender",base) end
            craftAction=parallelAction({kind="speedup-blender",item=craft.item,amount=craft.remainingUnits,tickets=needed})
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
    base.reserveHoney=facts.honeyReserve or 0
    local materials,materialError=P.materials(gear.items,facts,catalog)
    if not materials then return wait(materialError,base) end
    base.reservedItems=materials.reservedItems; base.materialDemand=materials.materialDemand; base.missingItems=materials.missingItems
    local costs,costError,complete=P.materialCosts(materials.missingItems,catalog)
    if not costs then return wait(costError,base) end
    base.costReservations=costs;base.costReservationsComplete=complete
    if craftAction then
        if craftAction.parallelHive then base.optionalHiveAllowed=true;base.materialPhase=true end
        base.action=craftAction; return base
    end
    local materialPhase=(next(materials.missingItems)~=nil or #materials.crafts>0)
    if materialPhase then
        base.optionalHiveAllowed=true
        base.materialPhase=true
    end
    local met,condition=conditionState(gear.conditions,facts)
    if met==nil then return wait(condition,base) end
    local read=inventoryReader(facts)
    -- Existing ingredients can be crafted while saving the gear's honey. No
    -- craft action is supplied for banned recipes or future/virtual inputs.
    for _,craft in ipairs(materials.crafts) do
        if craft.ready then
            if facts.craft~=false then return wait("need-verified-idle-blender",base) end
            base.action=parallelAction(copy(craft)); base.action.gear=nextGear.id; return base
        end
    end
    local firstMissing
    for _,item in ipairs(orderedKeys(materials.missingItems,catalog.materialOrder)) do
        firstMissing=firstMissing or item
        local deficit=materials.missingItems[item]
        if P.waitOnly[item] then continue end
        if item~="MagicBean" and (item=="RoyalJelly" or item=="Gumdrops") then
            local pack,packError=P.pack(item,deficit,(catalog.packs or {})[item])
            if not pack then return wait(packError,base) end
            local allowed,packCondition=conditionState(pack.conditions,facts)
            if not allowed then return wait(packCondition or "pack-condition",base) end
            if item=="RoyalJelly" and not complete then return wait("unknown-full-jelly-cost",base) end
            if item=="RoyalJelly" and catalog.royalJellyPricing then
                local quote=P.royalJellyCost(pack.amount,catalog.royalJellyPricing)
                if quote==nil or quote~=pack.cost.Honey then return wait("inconsistent-jelly-price",base) end
            end
            local ok,reason=afford(pack.cost,facts.honey,read,base.reserveHoney,base.reservedItems)
            if ok then base.action=parallelAction({kind="purchase-pack",item=item,amount=pack.amount,packId=pack.id,cost=copy(pack.cost)}); return base end
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
            if not ok then local pending=wait(reason,base);pending.action.parallelHive=true;pending.action.ParallelHive=true;return pending end
            base.action=parallelAction({kind="purchase-material",item=item,amount=1,cost=copy(purchase.cost)}); return base
        end
    end
    if firstMissing then local pending=wait("waiting-material:"..firstMissing,base);pending.action.parallelHive=true;pending.action.ParallelHive=true;return pending end
    if #materials.crafts>0 then local pending=wait("waiting-craft-inputs",base);pending.action.parallelHive=true;pending.action.ParallelHive=true;return pending end
    -- All material deficits are resolved. From this point the gear price is a
    -- hard reservation and optional hive spending must stop.
    base.optionalHiveAllowed=false
    base.materialPhase=false
    base.reserveHoney=gear.honey+(facts.honeyReserve or 0)
    if not met then return wait("waiting-condition:"..tostring(condition),base) end
    if facts.honey<base.reserveHoney then return wait("saving-gear-honey",base) end
    base.action={kind="buy-gear",gear=nextGear.id,honey=gear.honey,items=copy(gear.items)}
    return base
end
return P
