-- Pure tables only. The caller supplies the planner; this file contains no
-- transport, game services, movement, or live executor access.
return function(P)
    local passed=0
    local function check(value,message) assert(value,message);passed+=1 end
    local function copy(t) local r={};for k,v in pairs(t) do r[k]=type(v)=="table" and copy(v) or v end;return r end
    local function facts()
        local f={honey=1e12,honeyReserve=0,inventory={},inventoryKnown=true,
            ownedGear={},ownedGearKnown=true,redeemedCodes={},codesKnown=true,
            conditions={},occupied=25,capacity=25,craft=false}
        for _,code in ipairs(P.codes) do f.redeemedCodes[code]=true end
        return f
    end
    local function ownedThrough(f,last)
        for _,stage in ipairs(P.stages) do for _,name in ipairs(stage.gear) do
            if name==last then return end;f.ownedGear[name]=true
        end end
    end
    local function catalog(name,honey,items)
        return {gear={[name]={honey=honey or 0,items=items or {}}}}
    end
    do
        local f=facts();f.occupied=0;f.honey=0;f.inventory.Basic=1;f.emptyCell={x=1,y=1,verified=true}
        local c=catalog("Clippers",100,{})
        local r=P.plan(f,c)
        check(r.action.reason=="saving-gear-honey" and r.optionalHiveAllowed and r.reserveHoney==100,"Gear funding keeps its reservation while allowing inventory-only hive work")
        check(P.growth(f,c,1,r.reserveHoney,r.reservedItems).kind=="hatch-basic","Owned egg can hatch without spending gear funds")
        f.inventory.Basic=0;f.honey=100;c.basicEgg={cost={Honey=1000}}
        check(P.plan(f,c).action.kind=="buy-gear","Affordable gear precedes a more expensive next egg")
        f.honey=99;r=P.plan(f,c)
        check(P.growth(f,c,1,r.reserveHoney,r.reservedItems).kind=="wait","Egg cannot consume planned gear savings")
        f.honey=1099
        check(P.growth(f,c,1,100,{}).kind=="wait","Egg purchase needs full cost above the gear reservation")
        f.honey=1100
        check(P.growth(f,c,1,100,{}).kind=="buy-basic-egg","Egg may use funds above the full gear reservation")
        f.emptyCell=nil
        check(P.growth(f,c,1,100,{}).reason=="need-verified-empty-cell","Hatching still requires a verified empty coordinate")
    end
    do
        local f=facts();f.redeemedCodes.Wax=false
        local r=P.plan(f,{})
        check(r.action.kind=="redeem-code" and r.action.code=="Wax","Codes precede purchases")
        f.redeemedCodes.Wax=true;f.redeemedCodes.Roof=false
        check(P.plan(f,{}).action.code=="Roof","Redeemed code is skipped")
        f.redeemedCodes.Roof=nil;f.codesKnown=false
        check(P.plan(f,{}).action.kind=="wait","Unknown code state cannot be redeemed blindly")
    end
    for stageIndex,stage in ipairs(P.stages) do
        for _,name in ipairs(stage.gear) do
            local f=facts();ownedThrough(f,name);f.occupied=50;f.capacity=50
            -- Isolate normal route order; 36+ catch-up has its own cases below.
            for _,planter in ipairs(P.planterCatchup) do f.ownedGear[planter]=true end
            f.ownedGear[name]=false
            local r=P.plan(f,catalog(name,100,{}))
            check(r.gear==name and r.stage==stageIndex and r.action.kind=="buy-gear","Exact ordered next gear: "..name)
            check(not r.optionalHiveAllowed and r.reserveHoney==100,"Gear reserves honey before optional hive spending")
        end
    end
    do
        local f=facts();f.capacity=35;f.occupied=35
        check(P.nextGear(f).id=="Clippers","35-slot account retains the original route before catch-up threshold")
        f.capacity=36;f.occupied=25
        for _,expected in ipairs({"Candy Planter","Red Clay Planter","Blue Clay Planter","TackyPlanter"}) do
            local next=P.nextGear(f)
            check(next.id==expected and next.catchup and next.gate==0,"36-slot catch-up follows the latest planter priority without requiring 36 occupied bees")
            local r=P.plan(f,catalog(expected,100,{}))
            check(r.gear==expected and r.planterCatchup and r.action.kind=="buy-gear","Missing earlier ordinary gear cannot block planter catch-up")
            f.ownedGear[expected]=true
        end
        check(P.nextGear(f).id=="Clippers","Completed catch-up returns to the original next unowned gear once")
        for _,capacity in ipairs({37,50}) do
            f=facts();f.capacity=capacity;f.occupied=25
            for _,name in ipairs({"Candy Planter","Red Clay Planter","Blue Clay Planter"}) do f.ownedGear[name]=true end
            check(P.nextGear(f).id=="TackyPlanter","Prefarmed 37/50-slot account skips already-owned planters and aims for Tacky")
        end
        f=facts();f.capacity=36;f.ownedGearKnown=false
        check(P.nextGear(f)==nil,"Unknown catch-up ownership cannot be treated as missing or skipped")
        local route=P.stages[6].gear
        local at=table.find(route,"Petal Belt")
        check(route[at+1]=="Pesticide Planter" and route[at+2]=="Coconut Canister","Pesticide Planter follows Petal Belt before Coconut Canister")
    end
    do
        local f=facts()
        -- The host has verified stronger same-slot equipment and normalized
        -- obsolete earlier entries as owned; the pure policy never equips it.
        for _,name in ipairs(P.stages[1].gear) do f.ownedGear[name]=true end
        f.ownedGear["Porcelain Dipper"]=true;f.ownedGear["Porcelain Port-O-Hive"]=true
        local r=P.plan(f,catalog("Basic Sprinkler",100,{}))
        check(r.gear=="Basic Sprinkler" and r.action.kind=="buy-gear","Normalized stronger gear never triggers Jar/Boots/Bubble Wand retrograde purchases")
    end
    for _,gate in ipairs({25,34,35,36}) do
        local name
        for _,stage in ipairs(P.stages) do if stage.gate==gate then name=stage.gear[1];break end end
        local f=facts();ownedThrough(f,name);f.occupied=gate-1;f.capacity=math.max(25,gate)
        if gate>=36 then for _,planter in ipairs(P.planterCatchup) do f.ownedGear[planter]=true end end
        f.inventory.Basic=1;f.emptyCell={verified=true,x=5,y=5}
        local r=P.plan(f,catalog(name,100,{}))
        check(r.action.kind=="hatch-basic","Occupied gate cannot be satisfied by capacity alone")
        f.occupied=gate;f.capacity=gate
        check(P.plan(f,catalog(name,100,{})).action.kind=="buy-gear","Both gate counts satisfy exact boundary")
    end
    do
        local f=facts();ownedThrough(f,"Porcelain Dipper")
        f.occupied=33;f.capacity=33;f.honeyReserve=7;f.honey=117
        local c=catalog("Porcelain Dipper",150000000,{})
        c.hiveSlot={cost={Honey=100}};c.basicEgg={cost={Honey=10}}
        local r=P.plan(f,c)
        check(r.action.kind=="buy-hive-slot" and r.reserveHoney==7,"Unmet hive gate reserves user honey only, not future gear price")
        f.capacity=34;f.emptyCell={verified=true,x=4,y=7};f.honey=17
        check(P.plan(f,c).action.kind=="buy-basic-egg","Fill gate cell before reserving future Porcelain cost")
    end
    do
        local f=facts();f.honey=50;f.inventory.Blueberry=100;f.inventory.RoyalJelly=20
        local r=P.plan(f,catalog("Clippers",100,{BlueExtract=2}))
        check(r.action.kind=="craft" and r.action.item=="BlueExtract" and r.action.amount==2 and r.optionalHiveAllowed==true,"Craft existing inputs while allowing parallel hive")
        check(r.reserveHoney==0 and r.reservedItems.RoyalJelly==20,"Material phase reserves only the safety reserve")
        f.inventory.BlueExtract=1
        r=P.plan(f,catalog("Clippers",100,{BlueExtract=2}))
        check(r.action.amount==1 and r.reservedItems.Blueberry==50,"Existing output reduces exact craft deficit")
        f.craft={item="Oil",count=7,ready=false}
        check(P.plan(f,catalog("Clippers",100,{BlueExtract=2})).action.reason=="blender-busy" and P.plan(f,catalog("Clippers",100,{BlueExtract=2})).action.parallelHive,"Existing craft is not replaced and farming remains parallel")
        f.craft.ready=true
        local collected=P.plan(f,catalog("Clippers",100,{BlueExtract=2}))
        check(collected.action.kind=="collect-craft" and collected.action.amount==7,"Collect a ready existing craft before starting another")
        f.craft=nil
        check(P.plan(f,catalog("Clippers",100,{BlueExtract=2})).action.kind=="wait","A new craft needs verified idle blender state")
        f.craft=false
        f.inventory.Blueberry=0
        local waiting=P.plan(f,catalog("Clippers",100,{BlueExtract=2}))
        check(waiting.action.parallelHive==true and waiting.optionalHiveAllowed==true,"Missing material currency waits while hive remains optional")
        f.inventory.Blueberry=100;f.inventory.RoyalJelly=20
        local ready=P.plan(f,catalog("Clippers",100,{BlueExtract=2}))
        check(ready.action.kind=="craft" and ready.action.parallelHive==true and ready.optionalHiveAllowed==true,"Material craft phase remains parallel")
        f.inventory.BlueExtract=2
        local gear=P.plan(f,catalog("Clippers",100,{BlueExtract=2}))
        check(gear.action.kind=="wait" and gear.action.reason=="saving-gear-honey" and gear.optionalHiveAllowed==true and gear.action.parallelHive and gear.reserveHoney==100,"Gear savings permit existing jelly while retaining honey reservation")
        f.craft={item="Oil",count=7,ready=false,speedupEnabled=false,remainingUnits=2,tickets=20,startTime=500}
        local disabled=P.plan(f,catalog("Clippers",100,{BlueExtract=2}))
        check(disabled.action.kind=="wait" and disabled.action.reason=="blender-busy","Blender ticket speedup is disabled by default")
        f.craft.speedupEnabled=true
        local sped=P.plan(f,setmetatable({blenderSpeedUp={perTicket=1}},{__index=catalog("Clippers",100,{BlueExtract=2})}))
        check(sped.action.kind=="speedup-blender" and sped.action.amount==7 and sped.action.remainingUnits==2 and sped.action.tickets==2,
            "Explicit speedup separates full output from exact ticket-billed remaining units")
        f.craft.tickets=1
        check(P.plan(f,setmetatable({blenderSpeedUp={perTicket=1}},{__index=catalog("Clippers",100,{BlueExtract=2})})).action.reason=="waiting-tickets-for-blender","Insufficient tickets waits without speedup")
    end
    do
        local f=facts();local c=catalog("Clippers",100,{BlueExtract=250})
        f.craft={item="BlueExtract",count=231,ready=false,speedupEnabled=true,remainingUnits=118,
            autoCompletePerTicket=1,tickets=118,startTime=1000.5}
        local r=P.plan(f,c)
        check(r.action.kind=="speedup-blender" and r.action.amount==231 and r.action.remainingUnits==118
            and r.action.tickets==118,"231-output order with 118 billable units expects full 231 output")
        check(r.action.orderStartTime==1000.5 and r.action.orderCount==231,"Speedup action binds the exact order start and count")
        f.craft={item="BlueExtract",count=15,ready=false,speedupEnabled=true,remainingUnits=15,
            autoCompletePerTicket=10,tickets=2,startTime=2000}
        r=P.plan(f,c)
        check(r.action.amount==15 and r.action.remainingUnits==15 and r.action.tickets==2,"Partial ten-unit ticket block preserves full output and rounds ticket quote up")
        f.craft.remainingUnits=5;f.craft.tickets=1;r=P.plan(f,c)
        check(r.action.amount==15 and r.action.tickets==1,"Elapsed ten-unit block reduces ticket charge without reducing output")
        f.craft.remainingUnits=16
        check(P.plan(f,c).action.reason=="unknown-blender-speedup","Remaining billable units cannot exceed the original order")
        f.craft.remainingUnits=5;f.craft.startTime=nil
        check(P.plan(f,c).action.reason=="unknown-blender-speedup","Enabled speedup requires source order identity")
        f.craft.startTime=math.huge
        check(P.plan(f,c).action.reason=="unknown-blender-speedup","Nonfinite order start cannot authorize speedup")
        f.craft.speedupEnabled=false
        check(P.plan(f,c).action.reason=="blender-busy","Disabled speedup ignores optional quote identity and remains a parallel timer wait")
        f.craft.ready=true;r=P.plan(f,c)
        check(r.action.kind=="collect-craft" and r.action.amount==15,"Ready collection continues to expect the full order output")
    end
    do
        local f=facts();f.inventory.Oil=10;f.inventory.SunflowerSeed=7000;f.inventory.RoyalJelly=1400
        local r=P.plan(f,catalog("Clippers",0,{Oil=150}))
        check(r.action.kind=="craft" and r.action.amount==140,"150 oil target with 10 owned crafts 140")
        f.inventory.Oil=150
        check(P.plan(f,catalog("Clippers",0,{Oil=150})).action.kind=="buy-gear","Already owned material is not crafted")
    end
    do
        local f=facts();f.inventory.Oil=1;f.inventory.Enzymes=1;f.inventory.SunflowerSeed=50
        f.inventory.Pineapple=50;f.inventory.RoyalJelly=20;f.inventory.Coconut=10
        local r=P.plan(f,catalog("Clippers",0,{TropicalDrink=1}))
        check(r.action.kind=="craft" and r.action.item~="TropicalDrink","Child material must exist before parent craft")
        check(r.reservedItems.RoyalJelly==20,"Recursive siblings share exact Royal Jelly reservation")
    end
    do
        local f=facts();f.inventory.RoyalJelly=10;f.inventory.Blueberry=50;f.inventory.SunflowerSeed=50
        local m=assert(P.materials({BlueExtract=1,Oil=1},f,{}))
        check(m.reservedItems.RoyalJelly==10 and m.missingItems.RoyalJelly==10,"Shared inventory cannot fund two recipes twice")
        check(#m.crafts==2 and m.crafts[1].ready and not m.crafts[2].ready,"Only actually funded recipe is ready")
    end
    for _,item in ipairs({"Gumdrops","MoonCharm","StarJelly","MagicBean"}) do
        local f=facts();local c=catalog("Clippers",0,{[item]=1})
        c.recipes={[item]={yield=1,ingredients={Pineapple=1}}};f.inventory.Pineapple=100
        local r=P.plan(f,c)
        check(r.action.kind=="wait" and r.action.item~=item,"Banned/wait-only material is never crafted: "..item)
        if P.waitOnly[item] then
            c.sources={[item]={id="forbidden-source",kind="nectar-vial",readyCondition="ready"}}
            f.conditions.ready=true
            check(P.plan(f,c).action.kind=="wait","Wait-only material cannot be acquired from an alternate source: "..item)
        end
    end
    do
        local pack=assert(P.pack("Gumdrops",1,{{id="one",amount=3,cost={Ticket=1}},{id="ten",amount=30,cost={Ticket=10}}}))
        check(pack.amount==3,"Minimum verified Gumdrop pack handles sub-pack deficit")
        check(P.pack("Gumdrops",10,{{amount=10,cost={Ticket=4}}})==nil,"Custom Gumdrop amount is forbidden")
        check(P.pack("RoyalJelly",99,{{amount=1,cost={Honey=1}},{amount=10,cost={Honey=10}},{amount=100,cost={Honey=100}}}).amount==10,
            "Royal Jelly selects an existing pack rather than custom 99")
    end
    do
        local f=facts();f.honey=5;f.inventory.Blueberry=50
        local c=catalog("Clippers",100,{BlueExtract=1});c.packs={RoyalJelly={{id="ten",amount=10,cost={Honey=10}}}}
        local r=P.plan(f,c)
        check(r.action.kind=="wait" and r.action.reason=="saving-crafting-jelly" and not r.optionalHiveAllowed and r.reserveHoney==0,"Current recipe jelly funding blocks hive without reserving gear honey")
        f.honey=10;r=P.plan(f,c)
        check(r.action.kind=="purchase-pack" and r.action.amount==10,"Fixed jelly pack is affordable above full gear reserve")
        c.packs.RoyalJelly[1].conditions={"unknown-pack-unlock"}
        check(P.plan(f,c).action.kind=="wait","Unknown pack requirements block purchase")
        c.packs.RoyalJelly[1].conditions=nil
        f.pending=true
        check(P.plan(f,c).action.kind=="wait","Pending transaction blocks every next action")
    end
    do
        local pricing={purchased=0,baseHoney=250000,stepHoney=10000,maxHoney=1000000}
        check(P.royalJellyCost(2,pricing)==510000,"Verified escalating Royal Jelly cost covers each purchased unit")
        pricing.purchased=75
        check(P.royalJellyCost(20,pricing)==20000000,"Royal Jelly capped prices remain exact")
        local costs,err,complete=P.materialCosts({RoyalJelly=11,Gumdrops=31},
            {royalJellyPricing=pricing,packs={RoyalJelly={{amount=10,cost={Honey=10000000}},{amount=1,cost={Honey=1000000}}},
                Gumdrops={{amount=3,cost={Ticket=1}},{amount=30,cost={Ticket=10}},{amount=300,cost={Ticket=100}}}}})
        check(not err and complete and costs.Honey==11000000 and costs.Ticket==11,"Reserve complete known leaf costs including fixed-pack remainder")
        local _,_,known=P.materialCosts({RoyalJelly=11},{packs={RoyalJelly={{amount=10,cost={Honey=10000000}},{amount=1,cost={Honey=1000000}}}}})
        check(not known,"One current quote cannot establish changing costs of future packs")
    end
    do
        local f=facts();f.inventory.Ticket=400
        local c=catalog("Clippers",0,{Diamond=1});c.purchases={Diamond={amount=1,cost={Ticket=400}}}
        check(P.plan(f,c).action.kind=="purchase-material","Diamond purchase uses supplied verified price")
        c.purchases.Diamond.conditions={"diamond-unlock"}
        check(P.plan(f,c).action.kind=="wait","Unknown Diamond purchase condition fails closed")
        c.purchases.Diamond.conditions=nil
        c.purchases.Diamond.cost=nil
        check(P.plan(f,c).action.kind=="wait","Unknown Diamond price does not fall back to guessed 400")
    end
    do
        local f=facts();f.inventory.Ticket=400;f.conditions["diamond-token"]=true
        local c=catalog("Clippers",0,{Diamond=1});c.purchases={Diamond={amount=1,cost={Ticket=400}}}
        c.sources={Diamond={id="observed-token",kind="claim-token",readyCondition="diamond-token"}}
        check(P.plan(f,c).action.kind=="acquire-material","A verified available Diamond token precedes buying the same missing egg")
    end
    do
        local f=facts();f.inventory.Glitter=1;f.inventory.MoonCharm=25
        local r=P.plan(f,catalog("Clippers",0,{Glitter=2}))
        check(r.action.kind=="wait" and r.missingItems.MagicBean==1,"Missing Magic Bean waits without buying")
        local c=catalog("Clippers",0,{ComfortingVial=1})
        c.sources={ComfortingVial={id="verified-condenser",kind="nectar-vial",readyCondition="nectar-12h"}}
        check(P.plan(f,c).action.kind=="wait","Unknown nectar readiness cannot produce a vial action")
        f.conditions["nectar-12h"]=true
        check(P.plan(f,c).action.kind=="acquire-material","Verified ready nectar source creates inert host action")
    end
    do
        local f=facts();local before=copy(f);P.plan(f,catalog("Clippers",0,{}))
        check(f.honey==before.honey and next(f.inventory)==nil,"Planning never mutates supplied inventory")
        f.ownedGearKnown=false
        check(P.plan(f,catalog("Clippers",0,{})).action.kind=="wait","Unknown ownership never skips a progression item")
        f=facts();local c=catalog("Clippers",0,{A=1});c.recipes={A={yield=1,ingredients={B=1}},B={yield=1,ingredients={A=1}}}
        check(P.plan(f,c).reason=="cyclic-recipe:A","Cyclic catalog fails closed")
    end
    do
        local f=facts()
        for _,stage in ipairs(P.stages) do for _,name in ipairs(stage.gear) do f.ownedGear[name]=true end end
        local r=P.plan(f,{})
        check(r.action.kind=="hive" and r.optionalHiveAllowed,"Existing hive scheduler resumes after ordered gear completion")
    end
    do
        local f=facts();f.inventory.BlueExtract=19;f.craft={item="BlueExtract",count=231,ready=false}
        local r=P.plan(f,catalog("Clippers",5000000000,{BlueExtract=250,Oil=150}))
        check(r.action.reason=="blender-busy" and r.materialPhase and r.optionalHiveAllowed,"Queued gear output remains material phase before honey saving")
        check(r.queuedItems.BlueExtract==231 and not r.materialDemand.Blueberry,"Queued output does not demand its already-consumed ingredients again")
        check(r.status.materials[1].actual==19 and r.status.materials[1].queued==231 and r.status.materials[1].deficit==0,"Status separates actual 19 from queued 231")
        check(r.reserveHoney==0 and r.status.phase=="materials","Timed material phase does not reserve the 5B gear price")
        f.craft.ready=true
        check(P.plan(f,catalog("Clippers",5000000000,{BlueExtract=250,Oil=150})).action.kind=="collect-craft","Ready output collects before remaining gear materials")
        f.craft=false;f.inventory.BlueExtract=250;f.inventory.Oil=150;f.honey=1
        r=P.plan(f,catalog("Clippers",5000000000,{BlueExtract=250,Oil=150}))
        check(r.action.reason=="saving-gear-honey" and r.optionalHiveAllowed and r.reserveHoney==5000000000,"Gear honey remains reserved while qualified existing-jelly rolls continue")
    end
    do
        local f=facts();f.inventory.Blueberry=50;f.inventory.SunflowerSeed=500;f.honey=5
        local c=catalog("Clippers",100,{BlueExtract=1,Oil=10})
        c.packs={RoyalJelly={{amount=1,cost={Honey=1}},{amount=10,cost={Honey=10}},{amount=100,cost={Honey=100}}}}
        local r=P.plan(f,c)
        check(r.nextCraft.item=="BlueExtract" and r.nextCraft.missingInputs.RoyalJelly==10,"Funding demand belongs to next recipe, not every future recipe")
        check(r.action.reason=="saving-crafting-jelly" and r.fundsRequired==10 and not r.optionalHiveAllowed,"Current recipe must be fully funded before any supported pack purchase")
        f.honey=10;r=P.plan(f,c)
        check(r.action.kind=="purchase-pack" and r.action.amount==10 and r.status.phase=="materials" and r.status.label=="Buying crafting supplies","Fully funded current recipe selects its largest fixed pack")
        f.honey=0;r=P.plan(f,c)
        check(r.action.reason=="saving-crafting-jelly" and not r.action.parallelHive and not r.optionalHiveAllowed,"Current recipe jelly currency wait protects accumulated craft inventory")
        c.packs.RoyalJelly[1].conditions={"unknown-condition"};f.honey=1
        r=P.plan(f,c)
        check(r.action.kind=="wait" and not r.optionalHiveAllowed,"Current recipe jelly remains protected during requirement waits")
    end
    do
        local f=facts();f.inventory.Blueberry=10600;f.inventory.RoyalJelly=1100;f.honey=0
        local c=catalog("Clippers",5000000000,{BlueExtract=212})
        c.packs={RoyalJelly={{amount=1,cost={Honey=1000000}},{amount=10,cost={Honey=10000000}},
            {amount=100,cost={Honey=100000000}},{amount=1000,cost={Honey=1000000000}}}}
        local r=P.plan(f,c)
        check(r.action.reason=="saving-crafting-jelly" and not r.optionalHiveAllowed and r.action.parallelHive==false,
            "Partial 1100 of 2120 crafting jelly is protected from auto-hive while saving funds")
        check(r.materialPhase and r.reserveHoney==0 and r.craftingJellyDeficit==1020
            and r.status.phase=="materials" and r.status.label=="Saving honey for crafting jelly",
            "Craft jelly funding is a materials phase rather than saving the 5B gear cost")
        f.craft={item="BlueExtract",count=212,ready=false};f.inventory.RoyalJelly=0
        r=P.plan(f,c)
        check(r.action.reason=="blender-busy" and r.optionalHiveAllowed and r.action.parallelHive,
            "Once the current recipe is queued its timed wait releases auto-hive")
        f.craft=false;f.inventory.Blueberry=0
        r=P.plan(f,c)
        check(not r.optionalHiveAllowed and r.action.reason=="saving-crafting-jelly","An attempted recipe-jelly purchase still requires full funding with other ingredients missing")
    end
    do
        local f=facts();f.inventory.Blueberry=12500;f.honey=2499999999
        local c=catalog("Clippers",5000000000,{BlueExtract=250})
        local function quote(purchased)
            c.royalJellyPricing={purchased=purchased,baseHoney=250000,stepHoney=10000,maxHoney=1000000}
            c.packs={RoyalJelly={}}
            for _,n in ipairs({1,10,100,1000}) do c.packs.RoyalJelly[#c.packs.RoyalJelly+1]={id=tostring(n),amount=n,cost={Honey=P.royalJellyCost(n,c.royalJellyPricing)}} end
        end
        quote(75)
        local r=P.plan(f,c)
        check(r.action.kind=="wait" and r.action.reason=="saving-crafting-jelly" and r.action.fundsRequired==2500000000
            and r.action.requiredRJ==2500 and r.action.missingRJ==2500,"2500 RJ requires 2.5B and one honey short sends no pack")
        f.honey=2500000000
        local trace={1000,1000,100,100,100,100,100}
        for _,expected in ipairs(trace) do
            r=P.plan(f,c)
            check(r.action.kind=="purchase-pack" and r.action.amount==expected,"Full recipe batch uses two 1000 and five 100 fixed packs")
            f.inventory.RoyalJelly=(f.inventory.RoyalJelly or 0)+r.action.amount
            f.honey-=r.action.cost.Honey
        end
        r=P.plan(f,c)
        check(f.inventory.RoyalJelly==2500 and f.honey==0 and r.action.kind=="craft","Exact fixed pack trace ends with funded craft")
        f.inventory.RoyalJelly=1000;f.honeyReserve=7;f.honey=1500000006
        r=P.plan(f,c)
        check(r.action.kind=="wait" and r.fundsRequired==1500000007 and r.missingRJ==1500,"Existing jelly reduces full deficit and honey reserve remains untouched")
        f.honey+=1
        check(P.plan(f,c).action.amount==1000,"Exact reserve-plus-deficit boundary admits largest fixed pack")
        f.inventory.RoyalJelly=2250;f.honeyReserve=0;f.honey=250000000
        r=P.plan(f,c)
        check(r.fundsRequired==250000000 and r.action.amount==100,"250 missing RJ costs 250M rather than 2.5B")
        f.inventory.RoyalJelly=2490;f.honey=2949999;quote(0)
        r=P.plan(f,c)
        check(r.action.kind=="wait" and r.fundsRequired==2950000,"Escalating initial prices fund all ten units before first pack")
        f.honey=2950000
        check(P.plan(f,c).action.amount==10,"Escalating full-deficit boundary admits verified pack")
        f.inventory.RoyalJelly=2495;f.honey=2850000;quote(5)
        r=P.plan(f,c)
        check(r.fundsRequired==1600000 and r.action.amount==1,"Partially purchased early batch reprices only remaining units with fresh purchased counter")
    end
    do
        -- Read-only observed Diamond Mask inventory, represented as inert
        -- fixture data. It must fund Blue Extract before missing Diamond eggs.
        local f=facts();f.honey=1999000000;f.inventory.BlueExtract=19;f.inventory.Oil=148
        f.inventory.RoyalJelly=2007;f.inventory.Blueberry=11550;f.inventory.SunflowerSeed=100
        f.inventory.Glitter=100;f.inventory.Diamond=3;f.inventory.Ticket=145;f.inventory.ComfortingVial=1
        local c=catalog("Clippers",5000000000,{BlueExtract=250,Oil=150,Glitter=100,Diamond=5,ComfortingVial=1})
        c.purchases={Diamond={amount=1,cost={Ticket=400}}}
        c.packs={RoyalJelly={{amount=1,cost={Honey=1000000}},{amount=10,cost={Honey=10000000}},
            {amount=100,cost={Honey=100000000}},{amount=1000,cost={Honey=1000000000}}}}
        c.royalJellyPricing={purchased=75,baseHoney=250000,stepHoney=10000,maxHoney=1000000}
        local r=P.plan(f,c)
        check(r.nextCraft.item=="BlueExtract" and r.nextCraft.amount==231 and r.nextCraft.missingInputs.RoyalJelly==303,"Observed partial supplies price only the current 231-extract recipe deficit")
        check(r.action.kind=="purchase-pack" and r.action.item=="RoyalJelly" and r.action.amount==100,"Current recipe funding precedes waiting on Diamond tickets")
        check(r.reserveHoney==0 and r.status.phase=="materials" and r.status.materials[1].actual==19,"19 of 250 extracts is a material phase, never 5B honey saving")
        f.craft={item="BlueExtract",count=231,ready=true};c.packs.RoyalJelly=nil
        r=P.plan(f,c)
        check(r.action.kind=="collect-craft" and r.queuedItems.BlueExtract==231,"Unknown future recipe pack quotes cannot hide ready collection")
    end
    do
        local f=facts();f.inventory.Oil=1;f.inventory.Enzymes=1;f.inventory.Coconut=10
        f.craft={item="Oil",count=1,ready=false}
        local m=assert(P.materials({TropicalDrink=1},f,{}))
        check(m.queuedItems.Oil==1 and not m.missingItems.SunflowerSeed,"Queued nested Oil satisfies only its own future parent demand")
        check(m.nextCraft.item=="Enzymes" and m.crafts[#m.crafts].item=="TropicalDrink" and not m.crafts[#m.crafts].ready,"Queued nested output is not consumable before collection")
    end
    do
        local function ticketCatalog(bought)
            local c=catalog("Clippers",5000000000,{Diamond=1})
            c.purchases={Diamond={amount=1,cost={Ticket=400}}};c.ticketPurchased=bought;c.packs={Ticket={}}
            for _,n in ipairs({1,10,100})do c.packs.Ticket[#c.packs.Ticket+1]={id="ticket"..n,amount=n,cost={Honey=P.ticketCost(bought,n)}}end
            return c
        end
        check(P.ticketCost(500,1)==38847000 and P.ticketCost(500,100)==4566725000,"Ticket curve matches current game quotes")
        for _,bought in ipairs({0,498,500,49999,50000})do
            local f=facts();f.inventory.Ticket=95;local c=ticketCatalog(bought)
            local total=assert(P.ticketCost(bought,305));f.honey=total-1
            local r=P.plan(f,c)
            check(r.action.reason=="saving-diamond-tickets"and not r.optionalHiveAllowed,"Full remaining one-egg ticket cost must be funded first")
            check(r.requiredTickets==305 and r.fundsRequired==total,"Report exposes the exact one-egg deficit and honey requirement")
            f.honey=total;r=P.plan(f,c)
            check(r.action.item=="Ticket"and r.action.amount==100 and r.action.kind=="purchase-pack","Funded route chooses a real100-ticket option")
            f.inventory.Ticket=395;f.honey=P.ticketCost(bought,5);r=P.plan(f,c)
            check(r.action.amount==1 and r.action.item=="Ticket","Five-ticket deficit uses1-ticket requests, never a custom5")
            f.inventory.Ticket=400;r=P.plan(f,c)
            check(r.action.kind=="purchase-material"and r.action.item=="Diamond","Owned tickets buy the egg without buying extra tickets")
            f.inventory.Diamond=1;r=P.plan(f,c)
            check(r.action.reason=="saving-gear-honey"or r.action.kind=="buy-gear","Enough eggs stops ticket acquisition and moves to the gear honey phase")
        end
        local f=facts();f.inventory.Ticket=95;local c=ticketCatalog(500)
        c.packs.Ticket[1].cost.Honey+=1;f.inventory.Ticket=399
        check(P.plan(f,c).action.reason=="inconsistent-ticket-price","Changed actual ticket quote blocks the modeled route")
        c=ticketCatalog(500);c.ticketPurchased=nil
        check(P.plan(f,c).action.reason=="unknown-ticket-funding-cost","Unknown purchase counter cannot price future packs")
        check(P.pack("Ticket",5,{{amount=5,cost={Honey=1}}})==nil,"Custom ticket amount rejected")
        check(P.ticketCost(-1,1)==nil and P.ticketCost(99999,2)==nil,"Invalid or over-limit ticket counters fail closed")
    end
    do
        local f=facts()
        ownedThrough(f,"Helmet")
        f.honey=100000;f.inventory.MoonCharm=1
        local c=catalog("Helmet",30000,{MoonCharm=5})
        c.gear["Super-Scooper"]={honey=40000,items={}}
        local r=P.plan(f,c)
        check(r.action.kind=="buy-gear" and r.gear=="Super-Scooper" and r.deferredGear=="Helmet","Missing materials defer Helmet for an affordable upgrade")
        c.gear["Super-Scooper"].items={MoonCharm=1}
        check(P.plan(f,c).action.kind=="wait","Deferred gear retains its reserved materials")
        f.inventory.MoonCharm=5
        check(P.plan(f,c).action.gear=="Helmet","Previously deferred gear regains priority when funded")
    end
    return {passed=passed}
end
