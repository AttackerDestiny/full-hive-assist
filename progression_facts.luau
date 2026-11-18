-- Read-only normalization. All game interfaces are injected by the host.
-- This module never invokes remotes, moves, touches, equips, or changes Cache.
return function(deps)
    local Policy=assert(deps.Policy,"Progression policy required")
    local aliases={CandyPlanter="CandyPlanter",["Candy Planter"]="CandyPlanter",
        ["Blue Clay Planter"]="Blue ClayPlanter",["Red Clay Planter"]="Red ClayPlanter",
        ["Pesticide Planter"]="PesticidePlanter"}
    for name,id in pairs(deps.ItemAliases or {}) do aliases[name]=id end
    local function integer(n) return type(n)=="number" and n>=0 and n<math.huge and n%1==0 end
    local function finite(n) return type(n)=="number" and n==n and n>-math.huge and n<math.huge end
    local function read(object,name)
        if not object then return nil end
        local ok,child=pcall(function() return object:FindFirstChild(name) end)
        return ok and child or nil
    end
    local function value(object,name)
        local child=read(object,name)
        if not child then return nil end
        local ok,v=pcall(function() return child.Value end)
        if ok then return v end
        return nil
    end
    local function children(object)
        if not object then return {} end
        local ok,list=pcall(function() return object:GetChildren() end)
        return ok and type(list)=="table" and list or {}
    end
    local function part(object)
        if not object then return nil end
        local ok,is=pcall(function() return object:IsA("BasePart") end)
        return ok and is and object or nil
    end
    local function floor(shop)
        local f=read(shop,"Floor") or read(shop,"Terrain")
        if f then
            local ok,is=pcall(function() return f:IsA("ObjectValue") end)
            if ok and is then local got,v=pcall(function() return f.Value end);f=got and v or nil end
        end
        return part(f)
    end
    local function call(module,name,...)
        if type(module)~="table" or type(module[name])~="function" then return nil,false end
        local ok,result=pcall(module[name],...)
        return result,ok
    end
    local function normalizeCost(raw,defaultCurrency)
        if type(raw)~="table" then return nil end
        local rows=raw.Amount~=nil and {raw} or raw
        local honey,items,count=0,{},0
        for key,row in pairs(rows) do
            if type(key)~="number" or type(row)~="table" or not integer(row.Amount) then return nil end
            local currency=row.Category
            if currency==nil then currency=defaultCurrency=="Ticket" and "Eggs" or defaultCurrency end
            if currency=="Honey" then honey+=row.Amount
            elseif currency=="Eggs" then
                local id=row.Type or (defaultCurrency=="Ticket" and "Ticket")
                if type(id)~="string" then return nil end
                items[id]=(items[id] or 0)+row.Amount
            else return nil end
            count+=1
        end
        if count==0 then return nil end
        return {honey=honey,items=items}
    end
    local function currencyCost(cost)
        if not cost then return nil end
        local result={}
        if cost.honey>0 then result.Honey=cost.honey end
        for id,n in pairs(cost.items) do if id~="Ticket" then return nil end;result.Ticket=n end
        if next(result)==nil then result.Honey=0 end
        return result
    end
    local function packageOf(node)
        local category,id=value(node,"ItemCategory"),value(node,"ItemType")
        local amount=value(node,"ItemAmount") or 1
        if type(category)~="string" or type(id)~="string" or not integer(amount) or amount<1 then return nil end
        return {Category=category,Type=id,Amount=amount}
    end
    local shopCache,shopCacheAt,shopRoot
    local clock=deps.Clock or os.clock
    local function catalogShops()
        if shopCache and shopRoot==deps.Shops and clock()-shopCacheAt<5 then
            if deps.Performance then deps.Performance.ShopIndexHits=(deps.Performance.ShopIndexHits or 0)+1 end
            return shopCache.index,shopCache.shops
        end
        local index,shops={},{}
        for _,shop in ipairs(children(deps.Shops)) do
            local name=shop.Name
            shops[name]=shop
            local items=read(shop,"Items")
            for _,node in ipairs(children(items)) do
                local pack=packageOf(node)
                if pack then
                    local entry={package=pack,part=floor(shop) or part(node),shop=shop,shopName=name}
                    index[pack.Type]=index[pack.Type] or {};table.insert(index[pack.Type],entry)
                end
            end
        end
        shopCache={index=index,shops=shops};shopCacheAt=clock();shopRoot=deps.Shops
        if deps.Performance then deps.Performance.ShopIndexBuilds=(deps.Performance.ShopIndexBuilds or 0)+1 end
        return index,shops
    end
    local ownershipMemo={}
    local function knownOwnership(pack,s)
        local key=pack.Category..":"..pack.Type..":"..tostring(pack.Amount)
        local memo=ownershipMemo[key]
        if memo~=nil then return memo end
        local result,ok=call(deps.Packages,"PlayerHas",pack,s)
        if ok and type(result)=="boolean" then ownershipMemo[key]=result;return result end
        return nil
    end
    local function requirements(pack,s,facts,id)
        local reqs,ok=call(deps.Packages,"PurchaseRequirements",pack,s)
        if not ok then return nil end
        if reqs==nil then reqs={} end
        if type(reqs)~="table" then return nil end
        local checked,good=call(deps.Reqs,"Check",s,reqs)
        if not good or type(checked)~="boolean" then return nil end
        local key="purchase:"..id;facts.conditions[key]=checked
        return {key}
    end
    local function descriptor(entry,s,facts,id,currency)
        if not entry or not entry.part then return nil end
        local raw,ok=call(deps.Packages,"GetCost",entry.package,s)
        if not ok then return nil end
        local cost=normalizeCost(raw,currency)
        if not cost then return nil end
        local req=requirements(entry.package,s,facts,id)
        if not req then return nil end
        local canGive,giveKnown=call(deps.Packages,"CanGive",entry.package,s)
        if not giveKnown or type(canGive)~="boolean" then return nil end
        local giveKey="give:"..id;facts.conditions[giveKey]=canGive;req[#req+1]=giveKey
        local purchasable,purchaseKnown=call(deps.Packages,"CanPurchase",entry.package,s)
        if not purchaseKnown or type(purchasable)~="boolean" then return nil end
        local purchaseKey="can-purchase:"..id;facts.conditions[purchaseKey]=purchasable;req[#req+1]=purchaseKey
        return {honey=cost.honey,items=cost.items,conditions=req,
            canPurchase=purchasable,package=entry.package,
            part=entry.part,shop=entry.shop,shopName=entry.shopName}
    end
    -- Only the explicit shared ordered collector path is a lower-bound proof;
    -- alternate endgame collectors all supersede Porcelain without ordering
    -- those distinct endgame tools against each other.
    local collectorRanks={Clippers=1,Magnet=2,Vacuum=3,["Super-Scooper"]=4,Pulsar=5,["Electro-Magnet"]=6,
        ["Honey Dipper"]=7,["Bubble Wand"]=8,Scythe=8,["Golden Rake"]=9,["Spark Staff"]=10,
        ["Porcelain Dipper"]=11,["Petal Wand"]=12,["Tide Popper"]=13,["Dark Scythe"]=13,Gummyballer=13}
    local sprinklerRanks={["Basic Sprinkler"]=1,["Silver Soakers"]=2,["Golden Gushers"]=3,
        ["Diamond Drenchers"]=4,["The Supreme Saturator"]=5}
    local accessoryChains={
        {"Basic Boots","Hiking Boots","Beekeeper's Boots","Coconut Clogs"},
        {"Helmet","Propeller Hat","Beekeeper's Mask","Bubble Mask","Diamond Mask"},
        {"Jar","Canister","Compressor","Port-O-Hive","Porcelain Port-O-Hive","Coconut Canister"},
        {"Belt Pocket","Belt Bag","Mondo Belt Bag","Honeycomb Belt","Petal Belt"},
        -- Read-only Accessories definitions verify Brave is RIGHT/blue and
        -- Looker is LEFT/red. Cross-shoulder ownership proves no upgrade.
        {"Brave Guard","Blue Guard","Elite Blue Guard","Bucko Guard","Cobalt Guard"},
        {"Looker Guard","Red Guard","Elite Red Guard","Riley Guard","Crimson Guard"},
    }
    return function(s)
        -- Ownership/funds/requirements are fresh per snapshot; only immutable
        -- physical shop discovery and repeated reads within this build reuse data.
        ownershipMemo={}
        local facts={honey=finite(s.Honey) and s.Honey>=0 and math.floor(s.Honey) or nil,
            honeyReserve=finite(deps.HoneyReserve or 0) and math.ceil(deps.HoneyReserve or 0) or nil,inventory={},conditions={},ownedGear={},
            redeemedCodes={},inventoryKnown=type(s.Eggs)=="table",codesKnown=type(s.Codes)=="table",craft=nil}
        local catalog={gear={},recipes={},useSuppliedRecipes=false,packs={},purchases={},sources={}}
        if type(s.Eggs)=="table" then for id,n in pairs(s.Eggs) do facts.inventory[id]=n end end
        -- Starter saves omit Codes until their first redemption. Only accept
        -- that omission from a complete player snapshot, never partial data.
        local codes=s.Codes
        if codes==nil and facts.honey~=nil and facts.inventoryKnown and type(s.Honeycomb)=="table" then
            codes={}
        end
        if type(codes)=="table" then
            local redeemed,validCodes={},true
            for key,v in pairs(codes) do
                if type(key)=="number" and integer(key) and key>0 and type(v)=="string" then
                    redeemed[string.lower(v)]=true
                elseif type(key)=="string" and type(v)=="boolean" then
                    if v then redeemed[string.lower(key)]=true end
                else validCodes=false end
            end
            facts.codesKnown=validCodes
            for _,code in ipairs(Policy.codes) do
                local key=string.lower(code)
                if validCodes then facts.redeemedCodes[code]=redeemed[key]==true end
            end
        end
        if deps.Uncertain then
            local ok,state=pcall(deps.Uncertain)
            facts.uncertain=not ok or state~=false and state~=nil
        end
        local cells=0
        if type(s.Honeycomb)=="table" then
            local valid=true
            for _,col in pairs(s.Honeycomb) do
                if type(col)~="table" then valid=false;break end
                for _,bee in pairs(col) do if type(bee)~="table" or type(bee.Type)~="string" then valid=false;break end;cells+=1 end
            end
            if valid then facts.occupied=cells end
        end
        if integer(s.UnlockedCells) and s.UnlockedCells>=25 and s.UnlockedCells<=50 then facts.capacity=s.UnlockedCells end
        local index,shops=catalogShops()
        local entries={}
        local purchases=s.Totals and s.Totals.Purchases and s.Totals.Purchases.Eggs
        for _,stage in ipairs(Policy.stages) do for _,id in ipairs(stage.gear) do
            local internal=aliases[id] or id
            local entry=(index[internal] or {})[1]
            local permanent=internal=="CandyPlanter" or internal=="Blue ClayPlanter"
                or internal=="Red ClayPlanter" or internal=="TackyPlanter" or internal=="PesticidePlanter"
            local bought=permanent and type(purchases)=="table" and purchases[internal]
            if integer(bought) and bought>=1 then facts.ownedGear[id]=true end
            if entry then
                entries[id]=entry
                local owned=knownOwnership(entry.package,s)
                if facts.ownedGear[id]==true then owned=true end
                facts.ownedGear[id]=owned
                if not owned then catalog.gear[id]=descriptor(entry,s,facts,id,"Honey") end
            end
        end end
        local ownedCollectorRank,ownedSprinklerRank=0,0
        for id,rank in pairs(collectorRanks) do
            local entry=(index[aliases[id] or id] or {})[1]
            if entry and knownOwnership(entry.package,s) then ownedCollectorRank=math.max(ownedCollectorRank,rank) end
            if type(s.Collectors)=="table" and s.Collectors[id]==true then ownedCollectorRank=math.max(ownedCollectorRank,rank) end
            if s.EquippedCollector==id then ownedCollectorRank=math.max(ownedCollectorRank,rank) end
        end
        for id,rank in pairs(sprinklerRanks) do
            local entry=(index[id] or {})[1]
            if entry and knownOwnership(entry.package,s) then ownedSprinklerRank=math.max(ownedSprinklerRank,rank) end
        end
        for id,rank in pairs(collectorRanks) do if rank<=ownedCollectorRank then facts.ownedGear[id]=true end end
        for id,rank in pairs(sprinklerRanks) do if rank<=ownedSprinklerRank then facts.ownedGear[id]=true end end
        for _,chain in ipairs(accessoryChains) do
            local slots,highest={},0
            for i,id in ipairs(chain) do
                local internal=aliases[id] or id
                local def,ok=call(deps.Accessories,"Get",internal)
                if ok and type(def)=="table" and type(def.Slot)=="string" then slots[i]=def.Slot end
                local entry=entries[id] or (index[internal] or {})[1]
                if entry and knownOwnership(entry.package,s)==true then highest=math.max(highest,i) end
            end
            if highest>0 and slots[highest] then
                for i=1,highest do if slots[i]==slots[highest] then facts.ownedGear[chain[i]]=true end end
            end
        end
        -- Normalize physical fixed packs; no synthetic custom request amounts.
        for _,spec in ipairs({{"RoyalJelly","JellyDispenser","Honey"},{"Gumdrops","GumdropDispenser","Ticket"},{"Ticket","TicketDispenser","Honey"}}) do
            catalog.packs[spec[1]]={}
            for _,entry in ipairs(index[spec[1]] or {}) do
                if entry.shopName==spec[2] and entry.package.Amount<=1000000 then
                    local d=descriptor(entry,s,facts,spec[1]..":"..entry.package.Amount,spec[3])
                    local cost=d and currencyCost(d)
                    if cost then catalog.packs[spec[1]][#catalog.packs[spec[1]]+1]={id=entry.part.Name,amount=entry.package.Amount,
                        cost=cost,package=entry.package,part=entry.part,shop=entry.shop,conditions=d.conditions} end
                end
            end
        end
        for _,packs in pairs(catalog.packs) do table.sort(packs,function(a,b) return a.amount<b.amount end) end
        if type(purchases)=="table" and (purchases.RoyalJelly==nil or integer(purchases.RoyalJelly)) then
            catalog.royalJellyPricing={purchased=purchases.RoyalJelly or 0,baseHoney=250000,stepHoney=10000,maxHoney=1000000}
        end
        if type(purchases)=="table"and(purchases.Ticket==nil or integer(purchases.Ticket))then catalog.ticketPurchased=purchases.Ticket or 0 end
        for _,spec in ipairs({{"Basic","EggDispenser","basicEgg","Honey"},{"Diamond","TicketShop","Diamond","Ticket"}}) do
            for _,entry in ipairs(index[spec[1]] or {}) do
                if entry.shopName==spec[2] and entry.package.Amount==1 then
                    local d=descriptor(entry,s,facts,spec[1],spec[4]);local cost=d and currencyCost(d)
                    if cost then
                        local descriptorValue={cost=cost,amount=1,package=entry.package,part=entry.part,shop=entry.shop,conditions=d.conditions}
                        if spec[1]=="Basic" then catalog.basicEgg=descriptorValue else catalog.purchases.Diamond=descriptorValue end
                    end
                end
            end
        end
        -- HiveSlot shop metadata may omit ItemType because Category identifies it.
        for _,shop in pairs(shops) do for _,node in ipairs(children(read(shop,"Items"))) do
            if value(node,"ItemCategory")=="HiveSlot" then
                local entry={package={Category="HiveSlot",Amount=1},part=floor(shop) or part(node),shop=shop,shopName=shop.Name}
                local d=descriptor(entry,s,facts,"HiveSlot","Honey");local cost=d and currencyCost(d)
                if cost then catalog.hiveSlot={cost=cost,conditions=d.conditions,package=entry.package,part=entry.part,shop=shop} end
            end
        end end
        for _,item in ipairs(Policy.recipeOrder) do
            local recipe,ok=call(deps.Recipes,"Get",item)
            if ok and type(recipe)=="table" and type(recipe.Ingredients)=="table" and type(recipe.Requirements)=="table" then
                local met,checked=call(deps.Reqs,"Check",s,recipe.Requirements)
                if checked and met==true then
                    local ingredients,order={},{}
                    local valid=true
                    for _,ingredient in ipairs(recipe.Ingredients) do
                        if ingredient.Category~="Eggs" or type(ingredient.Type)~="string" or not integer(ingredient.Amount) then valid=false;break end
                        ingredients[ingredient.Type]=(ingredients[ingredient.Type] or 0)+ingredient.Amount
                        order[#order+1]=ingredient.Type
                    end
                    if valid and #order>0 then catalog.recipes[item]={yield=1,ingredients=ingredients,order=order,time=recipe.Time} end
                end
            end
            if not catalog.recipes[item] then catalog.recipes[item]=false end
        end
        local blender=s.BlenderState
        if blender==nil or blender==false then facts.craft=false
        elseif type(blender)=="table" then
            facts.craft={unknown=true}
            local craftUnknown=true
            if type(blender.Recipe)=="string" and integer(blender.Count) and blender.Count>0
            and finite(blender.StartTime) then
            local recipe,ok=call(deps.Recipes,"Get",blender.Recipe)
            local got,now=pcall(deps.OsTime or function() return nil end)
            local elapsed
            if got and finite(now) and finite(s.PlaytimeAtLoad) and finite(s.LoadTime)
                and finite(s.OfflineProgressTime or 0) then
                elapsed=s.PlaytimeAtLoad+(now-s.LoadTime)+(s.OfflineProgressTime or 0)-blender.StartTime
            end
            if ok and type(recipe)=="table" and finite(recipe.Time) and recipe.Time>0 and elapsed then
                local total=blender.Count*recipe.Time
                local completed=math.floor(math.clamp(elapsed/total,0,1)*blender.Count)
                local perTicket=recipe.AutoCompletePerTicket
                local remainingUnits
                if integer(perTicket) and perTicket>0 then
                    remainingUnits=math.max(0,blender.Count-math.floor(completed/perTicket)*perTicket)
                end
                facts.craft={item=blender.Recipe,count=blender.Count,startTime=blender.StartTime,ready=elapsed>=total,
                    elapsedSeconds=math.max(0,elapsed),totalSeconds=total,
                    remainingSeconds=math.max(0,total-elapsed),completedUnits=completed,
                    remainingUnits=remainingUnits,autoCompletePerTicket=perTicket,
                    tickets=type(s.Eggs)=="table" and s.Eggs.Ticket or nil,
                    speedupEnabled=(type(deps.UseBlenderTickets)=="function" and deps.UseBlenderTickets() or deps.UseBlenderTickets)==true,
                    output=blender.Recipe}
                craftUnknown=false
            end
            if craftUnknown then facts.craft={unknown=true} end
            end
        else facts.craft={unknown=true}
        end
        local ok,h=pcall(deps.Hive or function() return nil end)
        if ok and h then
            local choices={}
            for _,cell in ipairs(children(read(h,"Cells"))) do
                local x,y=value(cell,"CellX"),value(cell,"CellY")
                if value(cell,"CellType")=="Empty" and value(cell,"CellLocked")==false and integer(x) and x>0 and integer(y) and y>0 then
                    local neighbor,known=call(deps.CellTools,"HasActiveNeighbor",deps.CellTools,cell)
                    local occupied=s.Honeycomb and s.Honeycomb["x"..x] and s.Honeycomb["x"..x]["y"..y]
                    if not occupied and (y==1 or known and neighbor==true) then
                        choices[#choices+1]={verified=true,x=x,y=y,part=part(read(cell,"Part")),cell=cell}
                    end
                end
            end
            table.sort(choices,function(a,b) if a.y~=b.y then return a.y<b.y end;return a.x<b.x end)
            facts.emptyCell=choices[1]
            -- Source-verified hatch rule allows the bottom row without an
            -- active neighbor, including the first bee in an empty hive.
        end
        return facts,catalog
    end
end
