-- Read-only adapter cases against injected tables and fake physical nodes.
-- No game, transport, real services, or executor globals are available here.
return function(factory,Policy)
    local passed=0
    local function check(v,m) assert(v,m);passed+=1 end
    local function node(name,class,list,v)
        local o={Name=name,ClassName=class,Value=v,list=list or {}}
        function o:FindFirstChild(key) for _,c in ipairs(self.list) do if c.Name==key then return c end end end
        function o:GetChildren() return self.list end
        function o:IsA(kind) return self.ClassName==kind or kind=="BasePart" and self.ClassName=="Part" end
        return o
    end
    local function val(name,v) return node(name,"Value",nil,v) end
    local function item(id,category,amount)
        return node(id,"Part",{val("ItemCategory",category),val("ItemType",id),val("ItemAmount",amount or 1)})
    end
    local function shop(name,list)
        return node(name,"Folder",{node("Floor","ObjectValue",nil,node(name.."Floor","Part")),node("Items","Folder",list)})
    end
    local function fixture()
        local packages={}
        function packages.PlayerHas(pack,s) return s.owns[pack.Type]==true end
        function packages.GetCost(pack,s)
            if (pack.Type=="Blue ClayPlanter" or pack.Type=="PesticidePlanter")
                and s.Totals.Purchases.Eggs[pack.Type] then return nil end
            if pack.Category=="HiveSlot" then return {Category="Honey",Amount=3000000} end
            if pack.Type=="Diamond" then return {Category="Eggs",Type="Ticket",Amount=400} end
            if pack.Type=="Ticket"then return {Category="Honey",Amount=Policy.ticketCost(s.Totals.Purchases.Eggs.Ticket or 0,pack.Amount)}end
            if pack.Type=="Gumdrops" then return {Category="Eggs",Type="Ticket",Amount=pack.Amount/3} end
            return {Category="Honey",Amount=pack.Type=="RoyalJelly" and pack.Amount*1000000 or 100}
        end
        function packages.PurchaseRequirements() return {} end
        function packages.CanGive() return true end
        function packages.CanPurchase() return true end
        local top={item("Clippers","Collectors"),item("Porcelain Dipper","Collectors"),item("Bubble Wand","Collectors"),
            item("Jar","Accessories"),item("Porcelain Port-O-Hive","Accessories"),item("Basic Boots","Accessories"),
            item("Beekeeper's Boots","Accessories"),item("Blue ClayPlanter","Eggs"),item("Red ClayPlanter","Eggs"),
            item("CandyPlanter","Eggs"),item("TackyPlanter","Eggs"),item("PesticidePlanter","Eggs"),
            node("Hive Slot","Part",{val("ItemCategory","HiveSlot"),val("ItemType","Hive Slot"),val("ItemAmount",1)})}
        for _,id in ipairs({"Brave Guard","Blue Guard","Elite Blue Guard","Bucko Guard","Cobalt Guard",
            "Looker Guard","Red Guard","Elite Red Guard","Riley Guard","Crimson Guard",
            "Belt Pocket","Belt Bag","Mondo Belt Bag","Honeycomb Belt","Petal Belt"}) do
            top[#top+1]=item(id,"Accessories")
        end
        local shops=node("Shops","Folder",{shop("GearShop",top),shop("EggDispenser",{item("Basic","Eggs")}),
            shop("JellyDispenser",{item("RoyalJelly","Eggs",1),item("RoyalJelly","Eggs",10)}),
            shop("GumdropDispenser",{item("Gumdrops","Eggs",3),item("Gumdrops","Eggs",30),item("Gumdrops","Eggs",300)}),
            shop("TicketShop",{item("Diamond","Eggs")}),shop("TicketDispenser",{item("Ticket","Eggs",1),item("Ticket","Eggs",10),item("Ticket","Eggs",100)})})
        local defs={Oil={Time=300,AutoCompletePerTicket=1,Ingredients={{Category="Eggs",Type="SunflowerSeed",Amount=50},{Category="Eggs",Type="RoyalJelly",Amount=10}},Requirements={}}}
        local cells=node("Cells","Folder",{})
        local deps={Policy=Policy,Packages=packages,Recipes={Get=function(id) return defs[id] end},
            Reqs={Check=function() return true end},Accessories={Get=function(id)
                if id=="Jar" or id=="Porcelain Port-O-Hive" then return {Slot="Container"} end
                if id=="Basic Boots" or id=="Beekeeper's Boots" then return {Slot="Boots"} end
                for _,name in ipairs({"Brave Guard","Blue Guard","Elite Blue Guard","Bucko Guard","Cobalt Guard"}) do
                    if id==name then return {Slot="RightShoulder"} end
                end
                for _,name in ipairs({"Looker Guard","Red Guard","Elite Red Guard","Riley Guard","Crimson Guard"}) do
                    if id==name then return {Slot="LeftShoulder"} end
                end
                for _,name in ipairs({"Belt Pocket","Belt Bag","Mondo Belt Bag","Honeycomb Belt","Petal Belt"}) do
                    if id==name then return {Slot="Belt"} end
                end
            end},CellTools={HasActiveNeighbor=function() return false end},OsTime=function() return 1100 end,
            Shops=shops,Hive=function() return node("Hive","Model",{cells}) end,HoneyReserve=1.2,Uncertain=function() return false end}
        local s={Honey=1000.9,Eggs={},Codes={},Honeycomb={},UnlockedCells=25,owns={},
            Totals={Purchases={Eggs={RoyalJelly=75},HiveSlots=0}},BlenderState=false,PlaytimeAtLoad=500,LoadTime=1000}
        for _,code in ipairs(Policy.codes) do s.Codes[#s.Codes+1]=string.lower(code) end
        return deps,s,cells,defs
    end
    do
        local deps,s=fixture();s.owns["Cobalt Guard"]=true
        local f=factory(deps)(s)
        check(f.ownedGear["Brave Guard"]==true,"Cobalt on verified right shoulder supersedes Brave Guard")
        check(f.ownedGear["Looker Guard"]==false,"Cobalt cannot skip the opposite left Looker Guard")
        check(f.ownedGear["Crimson Guard"]==false,"Owning blue Cobalt never implies red Crimson ownership")
        s.owns["Cobalt Guard"]=false;s.owns["Riley Guard"]=true
        f=factory(deps)(s)
        check(f.ownedGear["Looker Guard"]==true and f.ownedGear["Brave Guard"]==false,"Intermediate Riley Guard supersedes only its verified left shoulder chain")
        s.owns["Riley Guard"]=false;s.owns["Bucko Guard"]=true
        f=factory(deps)(s)
        check(f.ownedGear["Brave Guard"]==true and f.ownedGear["Cobalt Guard"]==false,"Intermediate Bucko ownership skips weaker blue guard without skipping Cobalt")
        s.owns["Belt Bag"]=true
        f=factory(deps)(s)
        check(f.ownedGear["Belt Pocket"]==true and f.ownedGear["Mondo Belt Bag"]==false,"Belt Bag supersedes Pocket but not the later Mondo bag")
    end
    do
        local deps,s=fixture();local f,c=factory(deps)(s)
        check(f.honey==1000 and f.honeyReserve==2,"Honey floors and reserve rounds up conservatively")
        check(f.codesKnown and f.redeemedCodes.Wax and f.redeemedCodes.BeesBuzz123,"Actual lowercase server code array normalizes to requested names")
        check(f.occupied==0 and f.capacity==25 and f.craft==false,"Sparse starter facts stay distinct from capacity")
        check(c.basicEgg.cost.Honey==100 and c.hiveSlot.cost.Honey==3000000,"Verified shop package costs normalize")
        check(c.hiveSlot.package.Category=="HiveSlot" and c.hiveSlot.package.Type=="Hive Slot"
            and c.hiveSlot.package.Amount==1,"Hive-slot package matches the game's shop item metadata")
        check(c.purchases.Diamond.cost.Ticket==400,"Diamond price comes from package metadata")
        check(#c.packs.Ticket==3 and c.ticketPurchased==0,"Only observed fixed ticket options and actual purchase counters are emitted")
        check(c.packs.Ticket[1].shop.Name=="TicketDispenser"and c.packs.Ticket[1].cost.Honey==100000,"Ticket pack binds its physical vendor and current cost")
        check(c.basicEgg.part~=nil,"Shop movement uses a verified vendor floor or terrain part")
        check(#c.packs.Gumdrops==3 and #c.packs.RoyalJelly==2,"Only physical fixed pack options are emitted")
        check(c.recipes.Oil.ingredients.RoyalJelly==10 and c.recipes.Oil.time==300,"Verified recipe ingredients and time normalize")
        check(c.recipes.Glue==false and c.useSuppliedRecipes==false,"Missing live recipe never falls back to supplied guesses")
        check(f.ownedGear.Clippers==false,"Known missing item ownership remains false")
    end
    do
        local deps,s=fixture();s.owns["Porcelain Dipper"]=true;s.owns["Porcelain Port-O-Hive"]=true;s.owns["Beekeeper's Boots"]=true
        s.Totals.Purchases.Eggs["Blue ClayPlanter"]=1
        local f,c=factory(deps)(s)
        check(f.ownedGear["Bubble Wand"] and f.ownedGear.Clippers,"Verified stronger collector skips obsolete collectors")
        check(f.ownedGear.Jar and f.ownedGear["Basic Boots"],"Same accessory slot chain prevents retrograde gear")
        check(f.ownedGear["Blue Clay Planter"] and f.ownedGear["Red Clay Planter"]==false,"Permanent planted planter ownership uses ledger without skipping distinct planter")
        check(c.gear["Blue Clay Planter"]==nil,"Owned one-time planter may legitimately have no remaining purchase cost")
    end
    do
        local deps,s=fixture()
        local planterId
        for _,stage in ipairs(Policy.stages) do for _,id in ipairs(stage.gear) do
            if id=="PesticidePlanter" or id=="Pesticide Planter" then planterId=id end
        end end
        check(planterId~=nil,"Ordered policy includes the Pesticide planter")
        local build=factory(deps)
        local facts,catalog=build(s)
        check(facts.ownedGear[planterId]==false,"Missing Pesticide remains distinct from previous planters")
        check(catalog.gear[planterId] and catalog.gear[planterId].package.Type=="PesticidePlanter",
            "Pesticide display identity resolves to its canonical shop package")
        s.Totals.Purchases.Eggs.PesticidePlanter=1
        facts,catalog=build(s)
        check(facts.ownedGear[planterId]==true and catalog.gear[planterId]==nil,
            "Pesticide ledger proves ownership while inventory is empty and price is unavailable")
        check(facts.ownedGear["Candy Planter"]==false and facts.ownedGear.TackyPlanter==false,
            "Pesticide purchase cannot hide missing Candy or Tacky ownership")
        s.Totals.Purchases.Eggs.PesticidePlanter=0
        s.Totals.Purchases.Eggs.CandyPlanter=1
        s.Totals.Purchases.Eggs["Red ClayPlanter"]=1
        s.Totals.Purchases.Eggs.TackyPlanter=1
        facts=build(s)
        check(facts.ownedGear["Candy Planter"] and facts.ownedGear["Red Clay Planter"]
            and facts.ownedGear.TackyPlanter and facts.ownedGear["Blue Clay Planter"]==false,
            "Backfill ownership reads each permanent planter's own ledger")
        s.Totals.Purchases.Eggs.PesticidePlanter="1"
        check(build(s).ownedGear[planterId]==false,"Malformed Pesticide ledger cannot imply ownership")
    end
    do
        local deps,s,cells=fixture()
        cells.list={node("C1,1","Model",{val("CellX",1),val("CellY",1),val("CellType","Empty"),val("CellLocked",false)}),
            node("C2,2","Model",{val("CellX",2),val("CellY",2),val("CellType","Empty"),val("CellLocked",false)})}
        local f=factory(deps)(s)
        check(f.emptyCell and f.emptyCell.x==1 and f.emptyCell.y==1,"Source-verified bottom row allows first zero-bee hatch")
        s.Honeycomb={x1={y1={Type="Basic",Traits={}}}}
        f=factory(deps)(s)
        check(f.emptyCell==nil,"Cache occupancy overrides stale empty physical label")
        deps.CellTools.HasActiveNeighbor=function() return true end
        f=factory(deps)(s)
        check(f.emptyCell.x==2 and f.emptyCell.y==2,"Other empty rows need verified active neighbor")
    end
    do
        local deps,s=fixture();s.BlenderState={Recipe="Oil",Count=2,StartTime=0}
        local f=factory(deps)(s)
        check(f.craft.ready and f.craft.count==2,"Craft elapsed time uses verified playtime/load clock")
        s.BlenderState.StartTime=1
        f=factory(deps)(s)
        check(not f.craft.ready,"Unfinished craft waits rather than claiming early")
        s.BlenderState.StartTime=0;s.PlaytimeAtLoad=nil
        check(factory(deps)(s).craft and factory(deps)(s).craft.unknown,"Unknown craft clock fails closed")
        s.BlenderState={Recipe="Oil",Count="unknown"}
        check(factory(deps)(s).craft.unknown,"Malformed nonempty Blender state never becomes idle or absent")
        deps.Reqs.Check=function() return false end
        local _,c=factory(deps)(s)
        check(type(c.recipes.Oil)=="table","No recipe conditions does not call unrelated generic requirement checks")
        deps.Recipes.Get("Oil").Requirements={{Type="Earn Badges",Set="Ability",Amount=3}}
        _,c=factory(deps)(s)
        check(type(c.recipes.Oil)=="table"and not c.recipeBlockers.Oil,"False badge checks cannot hide a valid Oil recipe")
        deps.Recipes.Get("Oil").Requirements={{Type="Test game requirement"}}
        deps.Reqs.Description=function()return "Actual game condition"end
        _,c=factory(deps)(s)
        check(c.recipes.Oil==false and c.recipeBlockers.Oil=="Actual game condition","Non-badge recipe conditions remain enforced and described")
        deps.Reqs.Check=function()error("unavailable")end;_,c=factory(deps)(s)
        check(c.recipeBlockers.Oil=="Recipe requirements could not be read","Other-condition read failures remain distinct")
        deps.Recipes.Get("Oil").Requirements=nil;_,c=factory(deps)(s)
        check(type(c.recipes.Oil)=="table","Absent optional requirements cannot disable valid recipe ingredients")
    end
    do
        local deps,s,_,defs=fixture();s.BlenderState={Recipe="Oil",Count=15,StartTime=0}
        defs.Oil.AutoCompletePerTicket=10;s.PlaytimeAtLoad=1400
        local f=factory(deps)(s)
        check(f.craft.completedUnits==5 and f.craft.autoCompletePerTicket==10,"Speedup uses verified recipe units per ticket")
        check(f.craft.startTime==s.BlenderState.StartTime,"Blender facts preserve the server order identity for travel revalidation")
        check(f.craft.remainingUnits==15,"Partial ten-unit ticket block does not underquote two remaining tickets")
        s.PlaytimeAtLoad=2900
        f=factory(deps)(s)
        check(f.craft.completedUnits==10 and f.craft.remainingUnits==5,"Fully elapsed ticket block reduces remaining speedup charge")
    end
    do
        local deps,s=fixture();deps.Uncertain=function() return {Item="RoyalJelly"} end
        check(factory(deps)(s).uncertain,"Unresolved host transaction blocks the pure planner")
        s.Codes=nil
        local starter=factory(deps)(s)
        check(starter.codesKnown and starter.redeemedCodes.Wax==false,"Complete starter snapshot with omitted Codes admits first redemption")
        s.Honeycomb=nil
        check(not factory(deps)(s).codesKnown,"Partial snapshot with omitted Codes stays unknown")
        s.Codes={wax="ambiguous"}
        check(not factory(deps)(s).codesKnown,"Malformed code record cannot be treated as unredeemed")
    end
    do
        local deps,s=fixture();local now=0;local perf={}
        deps.Clock=function() return now end;deps.Performance=perf
        local build=factory(deps)
        local _,first=build(s)
        s.owns.Clippers=true
        local original=deps.Packages.GetCost
        deps.Packages.GetCost=function(pack,stats)
            if pack.Type=="Basic" then return {Category="Honey",Amount=125} end
            return original(pack,stats)
        end
        local second,catalog=build(s)
        check(perf.ShopIndexBuilds==1 and perf.ShopIndexHits==1,"Repeated facts reuse physical shop discovery")
        check(second.ownedGear.Clippers==true,"Ownership remains fresh while the shop index is cached")
        check(first.basicEgg.cost.Honey==100 and catalog.basicEgg.cost.Honey==125,"Costs remain fresh while physical discovery is cached")
        now=6;build(s)
        check(perf.ShopIndexBuilds==2,"Physical shop discovery expires and rebuilds")
    end
    do
        local deps,s=fixture();s.owns.Clippers=true
        local model={};local previews=0
        deps.PreviewModel=function()previews+=1;return model end
        deps.Packages.Icon=function()return "rbxassetid://123"end
        local build=factory(deps)
        local _,ordinary=build(s)
        check(not ordinary.routeGear and not ordinary.gear.Clippers,"Normal planning does not quote owned gear")
        check(previews==0,"Normal planning never clones or requests gear previews")
        local f,c=build(s,true)
        check(f.ownedGear.Clippers and c.routeGear.Clippers.honey==100,"Route view quotes owned gear without changing ownership")
        check(c.routeGear.Jar.honey==100 and c.gear.Jar.honey==100,"Route and planner share fresh unowned quotes")
        check(not c.gear.Clippers,"Read-only owned quote never adds a planner target")
        check(c.routeGear.Clippers.icon=="rbxassetid://123"and c.routeGear.Clippers.model==model,"Route carries cached game art and model references")
    end
    do
        local deps,s=fixture()
        deps.Packages.PurchaseRequirements=function()return {{Type="Earn Badges",Amount=10,Tier=2}}end
        deps.Reqs.Check=function()return false end
        deps.Reqs.Description=function()return "Earn 10 Hotshot Badges"end
        local _,c=factory(deps)(s)
        check(c.gear.Clippers.requirementText=="Earn 10 Hotshot Badges","Catalog preserves game-supplied locked requirement descriptions")
        check(#c.gear.Clippers.unlockConditions==2 and #c.gear.Clippers.conditions==3,"Unlock checks separate badge/grant requirements from affordability")
    end
    do
        local deps,s=fixture();s.owns["Diamond Mask"]=true
        deps.Packages.PlayerHasEquipped=function(pack)return pack.Type=="Diamond Mask"end
        local f=factory(deps)(s)
        check(f.ownedGear["Diamond Mask"]==true and f.equippedGear["Diamond Mask"]==true,"Dependency reads actual Diamond Mask ownership and equipment without relying on shop discovery")
        deps.Packages.PlayerHasEquipped=function()return false end;f=factory(deps)(s)
        check(f.ownedGear["Diamond Mask"]==true and f.equippedGear["Diamond Mask"]==false,"Owned but unequipped mask stays distinct")
        deps.Packages.PlayerHasEquipped=function()error("unavailable")end;f=factory(deps)(s)
        check(f.equippedGear["Diamond Mask"]==nil,"Unknown equipment fails closed")
        s.owns["Diamond Mask"]=false;deps.Packages.PlayerHasEquipped=function()return true end;f=factory(deps)(s)
        check(f.ownedGear["Diamond Mask"]==false,"Equipment alone cannot manufacture ownership or erase a known false ownership")
    end
    do
        local deps,s=fixture();s.BlenderState={Recipe="Oil",Count=2,StartTime=100}
        deps.BlenderGoal=function()return {Gear="Mask",Recipe="Oil",Count=2,StartTime=100}end
        check(factory(deps)(s).craft.goalGear=="Mask","Only the original verified order can retain its gear goal")
        s.BlenderState.StartTime=101
        check(factory(deps)(s).craft.goalGear==nil,"Replacement order cannot inherit an old material goal")
    end
    do
        local deps,s=fixture();s.Honeycomb={x1={}}
        for i,name in ipairs({"Baby","Baby","Baby","Baby","Music","Music","Music","Music","Shy","Shy","Shy"})do
            s.Honeycomb.x1["y"..i]={Type=name,Traits={Gifted=i%2==0}}
        end
        local f=factory(deps)(s)
        check(f.beeCounts.Baby==4 and f.beeCounts.Music==4 and f.beeCounts.Shy==3,"Live hive species counts include normal and gifted force copies")
        s.Honeycomb.x1.y1={Type="Basic"};f=factory(deps)(s)
        check(f.beeCounts.Baby==3,"Fresh species changes immediately update force count")
        s.Honeycomb.x1.y2=false;f=factory(deps)(s)
        check(f.beeCounts==nil,"Malformed hive never supplies partial force counts")
        s.Honeycomb=nil;check(factory(deps)(s).beeCounts==nil,"Absent hive counts remain unknown")
    end
    do
        local deps,s=fixture();local seen
        deps.HiveRetirements=function(snapshot)seen=snapshot;return {Shy=true,Ninja=false}end
        local f=factory(deps)(s)
        check(seen==s and f.questRetired.Shy==true,"Guard facts use retirement evidence for the same fresh stats snapshot")
        deps.HiveRetirements=function()return {Shy="unknown"}end
        check(factory(deps)(s).questRetired.Shy==false,"Nonboolean retirement never qualifies")
        deps.HiveRetirements=function()error("unavailable")end
        check(factory(deps)(s).questRetired==nil,"Failed retirement read stays conservative")
        deps.HiveRetirements=nil
        check(factory(deps)(s).questRetired==nil,"Missing retirement reader retains original force requirements")
    end
    do
        local deps,s=fixture();s.owns["Porcelain Dipper"]=true
        local ownedCategory,equippedCategory,seen
        local has=deps.Packages.PlayerHas
        deps.Packages.PlayerHas=function(pack,snapshot)
            if pack.Type=="Porcelain Dipper"then ownedCategory=pack.Category;seen=snapshot end
            return has(pack,snapshot)
        end
        deps.Packages.PlayerHasEquipped=function(pack,snapshot)
            if pack.Type=="Porcelain Dipper"then equippedCategory=pack.Category;seen=snapshot;return true end
            return false
        end
        local f=factory(deps)(s)
        check(ownedCategory=="Collector"and equippedCategory=="Collector"and seen==s,"Dipper dependency uses real Collector package and same fresh snapshot")
        check(f.ownedGear["Porcelain Dipper"]==true and f.equippedGear["Porcelain Dipper"]==true,"Actual Dipper ownership and equipment normalized")
        deps.Packages.PlayerHasEquipped=function()return false end;f=factory(deps)(s)
        check(f.ownedGear["Porcelain Dipper"]and f.equippedGear["Porcelain Dipper"]==false,"Unequipped owned Dipper stays ineligible")
        deps.Packages.PlayerHasEquipped=function()error("unknown")end;f=factory(deps)(s)
        check(f.equippedGear["Porcelain Dipper"]==nil,"Dipper equipment read errors retain unknown state")
        deps.Shops=nil;deps.Packages.PlayerHasEquipped=function()return true end;f=factory(deps)(s)
        check(f.ownedGear["Porcelain Dipper"]and f.equippedGear["Porcelain Dipper"],"Dependency remains observable before physical shops load")
    end
    return {passed=passed}
end
