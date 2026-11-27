-- Pure tables only. The caller supplies the planner; this file contains no
-- transport, game services, movement, or live executor access.
return function(P,workerSource)
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
        f.craft={item="Oil",count=1,ready=false}
        local busy=P.plan(f,c)
        check(busy.action.reason=="blender-busy" and busy.savingGearHoney and busy.reserveHoney==100,
            "An unrelated Blender order preserves the price of gear whose materials are ready")
        f.craft=false
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
        local f=facts();ownedThrough(f,"Bubble Wand");f.occupied=16
        local c=catalog("Bubble Wand",3000000)
        c.gear["Bubble Wand"].shopName="BlueHQ"
        c.gear["Bubble Wand"].shopAccess=false
        local blocked=P.plan(f,c)
        check(blocked.action.reason=="waiting-shop-access:BlueHQ" and blocked.action.parallelHive,
            "Closed shop waits without monopolizing hive work")
        check(blocked.optionalHiveAllowed and blocked.reserveHoney==3000000,
            "Closed shop preserves the gear budget")
        c.gear["Bubble Wand"].shopAccess=true
        check(P.plan(f,c).action.kind=="buy-gear","Gear resumes priority as soon as the shop opens")
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
    do
        local f=facts();ownedThrough(f,"Basic Sprinkler");f.occupied=22
        for _,expected in ipairs({"Basic Sprinkler","Candy Planter","Blue Port-O-Hive","Beekeeper's Mask","Mondo Belt Bag",
            "Beekeeper's Boots","Blue Clay Planter","Red Clay Planter"}) do
            check(P.nextGear(f).id==expected,"Follows the requested gear order at 22 bees: "..expected)
            f.ownedGear[expected]=true
        end
    end
    for stageIndex,stage in ipairs(P.stages) do
        for _,name in ipairs(stage.gear) do
            local f=facts();ownedThrough(f,name);f.occupied=50;f.capacity=50;f.inventory.SpiritPetal=1
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
        check(route[at+1]=="Coconut Canister" and route[at+2]=="The Supreme Saturator" and route[at+3]=="Pesticide Planter","Pesticide Planter follows Supreme Saturator")
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
    do
        local f=facts();ownedThrough(f,"Basic Sprinkler");f.occupied=22
        local c=catalog("Basic Sprinkler",1111111)
        c.gear["Basic Sprinkler"].conditions={"sprinkler-badges"}
        f.conditions["sprinkler-badges"]=true
        check(P.plan(f,c).action.kind=="buy-gear","An affordable Basic Sprinkler takes priority at 22 occupied bees")
        f.conditions["sprinkler-badges"]=false
        check(P.plan(f,c).action.kind=="wait","Removing the hive gate still requires the game's badges")
    end
    for _,name in ipairs({"Porcelain Port-O-Hive","Bubble Mask","Silver Soakers","Cobalt Guard"})do
        local f=facts();ownedThrough(f,name);f.occupied=20;f.capacity=28
        local c=catalog(name,100,{})
        check(P.plan(f,c).action.kind=="buy-gear","No custom bee or capacity gate for "..name)
        c.gear[name].conditions={"game-unlock"};f.conditions["game-unlock"]=false
        check(P.plan(f,c).action.kind=="wait","Actual game requirement still enforced for "..name)
    end

    do
        local f=facts();ownedThrough(f,"Red Clay Planter")
        f.occupied=33;f.capacity=33;f.honey=150000000
        local c=catalog("Porcelain Dipper",150000000,{})
        c.gear["Red Clay Planter"]={honey=10000000,items={SoftWax=20}}
        f.inventory.SoftWax=13
        local r=P.plan(f,c)
        check(r.action.kind=="buy-gear" and r.action.gear=="Porcelain Dipper" and r.deferredGear=="Red Clay Planter",
            "Affordable Porcelain Dipper can pass a materials-blocked planter at 33 bees")
        f.ownedGear["Red Clay Planter"]=true
        f.honey=149999999
        r=P.plan(f,c)
        check(r.action.reason=="saving-gear-honey" and r.reserveHoney==150000000,
            "Porcelain Dipper still needs its full quoted honey cost")
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
    for _,item in ipairs({"Gumdrops","MoonCharm","StarJelly","MagicBean","SoftWax","HardWax"}) do
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
        local f=facts();f.inventory.SoftWax=3;f.inventory.Enzymes=8
        f.inventory.Bitterberry=33;f.inventory.Neonberry=25;f.inventory.RoyalJelly=5500
        local c=catalog("Clippers",0,{CausticWax=1})
        local r=P.plan(f,c)
        check(r.action.kind=="wait" and r.missingItems.HardWax==5 and r.reservedItems.SoftWax==nil,
            "A Caustic Wax recipe waits for Hard Wax without funding or scheduling its recipe")
        f.inventory.HardWax=5
        r=P.plan(f,c)
        check(r.action.kind=="craft" and r.action.item=="CausticWax",
            "Owned Hard Wax can still be used in an otherwise allowed gear recipe")
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
        c.gear.Clippers.items.BlueExtract=250
        check(P.plan(f,c).action.kind=="acquire-material","Other missing ingredients do not block the verified Diamond token")
        c.gear.Clippers.items.BlueExtract=nil
        f.conditions["diamond-token"]=false
        check(P.plan(f,c).action.kind=="purchase-material","An unavailable token leaves the verified purchase route eligible")
        f.conditions["diamond-token"]=true;f.inventory.Diamond=1
        check(P.plan(f,c).action.kind=="buy-gear","No extra token trip after the gear's egg requirement is met")
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
        check(not r.saveCraftingJelly and r.action.reason=="waiting-material:Blueberry","A recipe cannot reserve or buy jelly before its own non-jelly inputs are ready")
    end
    do
        local f=facts();f.inventory.Blueberry=150;f.inventory.RoyalJelly=7;f.honey=230
        local c=catalog("Clippers",1000,{BlueExtract=3})
        c.royalJellyPricing={purchased=0,baseHoney=10,stepHoney=0,maxHoney=10}
        c.customRoyalJelly=function(n)return {id="custom-royal-jelly",amount=n,cost={Honey=n*10}} end
        local r=P.plan(f,c)
        check(r.action.kind=="purchase-pack" and r.action.packId=="custom-royal-jelly" and r.action.amount==23,
            "Crafting buys the exact custom jelly deficit")
        f.honey=229
        check(P.plan(f,c).action.reason=="saving-crafting-jelly","Custom quantity still needs the entire deficit funded")
    end
    do
        local f=facts();ownedThrough(f,"Red Clay Planter")
        f.inventory={Strawberry=750,MagicBean=5,SoftWax=19,RoyalJelly=20}
        local c=catalog("Red Clay Planter",10000000,{RedExtract=15,SoftWax=20,MagicBean=5})
        c.packs={RoyalJelly={{amount=1,cost={Honey=10}},{amount=10,cost={Honey=100}},{amount=100,cost={Honey=1000}}}}
        f.honey=0
        local r=P.plan(f,c)
        check(r.action.reason=="saving-crafting-jelly" and r.saveCraftingJelly and r.missingRJ==130,
            "An unrelated Soft Wax deficit does not block a ready Red Extract recipe")
        f.honey=1300
        r=P.plan(f,c)
        check(r.action.kind=="purchase-pack" and r.action.item=="RoyalJelly" and r.action.amount==100,
            "Buy only a supported pack toward the ready recipe shortfall")
    end
    do
        local f=facts();f.honey=0
        f.inventory={BlueExtract=42,Oil=21,Glitter=26,ComfortingVial=3,Diamond=1,Blueberry=10639,SunflowerSeed=4179}
        local c=catalog("Clippers",5000000000,{BlueExtract=250,Oil=150,Glitter=100,ComfortingVial=1,Diamond=5})
        c.packs={RoyalJelly={{amount=1,cost={Honey=1000000}},{amount=1000,cost={Honey=1000000000}}}}
        local r=P.plan(f,c)
        check(r.action.reason=="saving-crafting-jelly" and r.nextCraft.item=="BlueExtract" and r.nextCraft.amount==208
            and r.missingRJ==2080 and r.fundsRequired==2080000000,
            "Fund exactly the 208 missing Blue Extract despite unrelated Diamond Mask inputs")
        f.inventory.RoyalJelly=2080
        r=P.plan(f,c)
        check(r.action.kind=="craft" and r.action.item=="BlueExtract" and r.action.amount==208,"Queue the complete extract deficit")
        f.inventory.BlueExtract=250;f.inventory.RoyalJelly=0
        r=P.plan(f,c)
        check(not r.saveCraftingJelly,"Partial sunflower supply cannot start an Oil order")
        f.inventory.SunflowerSeed=6450
        r=P.plan(f,c)
        check(r.action.reason=="saving-crafting-jelly" and r.nextCraft.item=="Oil" and r.nextCraft.amount==129
            and r.missingRJ==1290,"Fund the full Oil deficit once its sunflower seeds are ready")
        f.inventory.BlueExtract=42;f.inventory.Blueberry=0
        r=P.plan(f,c)
        check(r.nextCraft.item=="Oil" and r.missingRJ==1290,"An unready earlier recipe does not block the ready Oil recipe")
    end
    do
        local f=facts();f.honey=662465095
        f.inventory={BlueExtract=261,Oil=32,Glitter=39,ComfortingVial=3,Diamond=1,
            SunflowerSeed=5900,RoyalJelly=1180}
        local c=catalog("Clippers",5000000000,{BlueExtract=250,Oil=150,Glitter=100,ComfortingVial=1,Diamond=5})
        local r=P.plan(f,c)
        check(r.action.kind=="craft" and r.action.item=="Oil" and r.action.amount==118,
            "Craft all 118 missing Oil despite missing Diamond Eggs, Glitter and gear honey")
        check(r.action.ingredients.SunflowerSeed==5900 and r.action.ingredients.RoyalJelly==1180,
            "The complete Oil deficit uses exactly 5900 seeds and 1180 jelly")
        f.inventory.SunflowerSeed=5899
        check(P.plan(f,c).action.kind~="craft","One missing seed cannot start a partial Oil batch")
        f.inventory.SunflowerSeed=5900;f.inventory.RoyalJelly=1179
        check(P.plan(f,c).action.kind~="craft","One missing jelly cannot start a partial Oil batch")
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
        check(r.action.kind=="craft"and r.action.item=="Oil"and r.action.amount==2,"Actual owned jelly completes the ready Oil recipe before funding extracts")
        f.inventory.Oil=150;f.inventory.RoyalJelly=1987;r=P.plan(f,c)
        check(r.nextCraft.item=="BlueExtract" and r.nextCraft.amount==231 and r.nextCraft.missingInputs.RoyalJelly==323,"After Oil queues the current extract deficit is repriced from actual remaining jelly")
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
    do
        local f=facts();ownedThrough(f,"Candy Planter");f.occupied=22
        local c=catalog("Candy Planter",5000000,{MagicBean=5,Gumdrops=30,SoftWax=5})
        local mask="Beekeeper's Mask"
        c.gear[mask]={honey=20000000,items={Enzymes=5,Glue=3,Glitter=1}}
        c.packs={RoyalJelly={{id="RJ1",amount=1,cost={Honey=10}},
            {id="RJ10",amount=10,cost={Honey=100}},{id="RJ100",amount=100,cost={Honey=1000}}}}
        f.inventory={Pineapple=250,Gumdrops=150,MoonCharm=25,MagicBean=1}
        local r=P.plan(f,c)
        check(r.gear==mask and r.action.kind=="craft"and r.action.item=="Glitter","Ready Glitter crafts before funding another Mask recipe")
        f.inventory.Glitter=1;f.inventory.MoonCharm=0;f.inventory.MagicBean=0;r=P.plan(f,c)
        check(r.gear==mask and r.deferredGear=="Candy Planter" and r.action.kind=="purchase-pack",
            "Ready non-jelly recipe ingredients advance the Mask while Candy Planter waits")
        check(r.missingRJ==50 and r.action.amount==10 and r.reserveHoney==20000000,
            "Funds Enzymes first through fixed packs while reserving the Mask price")
        f.inventory.RoyalJelly=20
        r=P.plan(f,c)
        check(r.missingRJ==30 and r.action.amount==10 and r.fundsRequired==20000300,
            "Existing jelly offsets the full recipe bill")
        f.honey=20000299
        r=P.plan(f,c)
        check(r.gear==mask and r.action.reason=="saving-crafting-jelly" and not r.optionalHiveAllowed
            and r.saveCraftingJelly and r.reservedItems.RoyalJelly==20,
            "An eligible later recipe saves owned jelly until the full purchase fits")
        f.honey=0
        check(P.plan(f,c).saveCraftingJelly,"The reserve starts even when the gear price itself is unaffordable")
        f.honey=20000600;f.inventory.Pineapple=249
        check(P.plan(f,c).gear=="Candy Planter","Missing non-jelly ingredients prevent a fallback")
        f.inventory.Pineapple=250;f.inventory.RoyalJelly=80;f.honey=20000000
        r=P.plan(f,c)
        check(r.gear==mask and r.action.kind=="craft" and r.action.item=="Enzymes","Fully funded fallback starts crafting")
        f.inventory.Enzymes=5;f.inventory.Pineapple=0;f.inventory.RoyalJelly=30
        check(P.plan(f,c).action.item=="Glue","Replans with the remaining ingredients after crafting Enzymes")
        f.inventory.Enzymes=0;f.craft={item="Enzymes",count=5,ready=false}
        r=P.plan(f,c)
        check(r.gear==mask and r.saveCraftingJelly and r.reservedItems.RoyalJelly==30,
            "The remaining jelly stays reserved during a Blender order")
        f.inventory.Enzymes=5;f.craft=false
        f.inventory.Glue=3;f.inventory.Gumdrops=0;f.inventory.RoyalJelly=0
        f.inventory.Glitter=0;f.inventory.MoonCharm=25;f.inventory.MagicBean=1
        check(P.plan(f,c).action.item=="Glitter","Uses the shared Magic Bean to finish the fallback recipe")
        f.inventory.Glitter=1;f.inventory.MoonCharm=0;f.inventory.MagicBean=0
        r=P.plan(f,c)
        check(r.action.kind=="buy-gear" and r.gear==mask,"Ready crafted materials lead to the Mask purchase")
    end
    do
        local f=facts()
        f.occupied=24;f.emptyCell={x=1,y=1,verified=true}
        f.inventory={Silver=1,Gold=1}
        check(P.growth(f,{},25).item=="Silver","Hatch an owned Silver Egg in an empty slot")
        f.inventory.Silver=0
        check(P.growth(f,{},25).item=="Gold","Hatch an unreserved Gold Egg in an empty slot")
        f.questGoldReserve=1
        check(P.growth(f,{},25).kind=="wait","Keep a Gold Egg reserved for donation")
        f.inventory.Gold=2
        check(P.growth(f,{},25).item=="Gold","A spare Gold Egg remains eligible")
    end
    do
        local f=facts();ownedThrough(f,"Canister");f.occupied=3;f.honey=8110
        f.emptyCell={x=1,y=1,verified=true}
        local c=catalog("Canister",22000,{})
        c.basicEgg={cost={Honey=2500}}
        local r=P.plan(f,c)
        check(r.action.kind=="buy-basic-egg" and r.reserveHoney==0 and not r.savingGearHoney,"Cheap egg precedes Canister savings")
        f.honey=30000
        check(P.plan(f,c).action.kind=="buy-basic-egg","Cheap egg precedes affordable starter gear")
        f.inventory.Basic=1
        check(P.plan(f,c).action.kind=="hatch-basic","Owned egg fills the cell first")
        f.inventory.Basic=0
        for _,price in ipairs({22000,22001}) do
            c.basicEgg.cost.Honey=price
            check(P.plan(f,c).action.kind=="buy-gear","Equality or higher egg price restores gear priority")
            f.honey=8110;r=P.plan(f,c)
            check(r.savingGearHoney and r.reserveHoney==22000,"Equality or higher price saves the gear budget")
            f.honey=30000
        end
        c.basicEgg.cost.Honey=2500;f.honey=8110;f.honeyReserve=6000
        check(P.plan(f,c).action.kind=="wait","Cheap eggs respect the safety reserve")
        f.honeyReserve=0;f.emptyCell=nil
        check(P.plan(f,c).action.reason=="need-verified-empty-cell","Cheap egg needs a verified empty cell")
        f.emptyCell={x=1,y=1,verified=true};f.occupied=25
        check(P.plan(f,c).savingGearHoney,"Full hive does not stall gear for cheaper eggs")
        f.occupied=3;c.basicEgg=nil
        check(P.plan(f,c).savingGearHoney,"Unknown egg price preserves gear savings")
        c.basicEgg={cost={Honey=2500}};c.gear.Canister.items={SoftWax=1}
        check(not P.plan(f,c).eggBeforeGear,"Missing gear materials do not enter honey-only exception")
        c.gear.Canister.items={};f.ownedGear.Canister=true;ownedThrough(f,"Silver Soakers");f.occupied=36;f.capacity=36
        for _,planter in ipairs(P.planterCatchup) do f.ownedGear[planter]=true end
        c.gear["Silver Soakers"]={honey=22000,items={}}
        check(P.plan(f,c).savingGearHoney and not P.plan(f,c).eggBeforeGear,"Later route preserves ordinary gear priority")
    end
    do
        local f=facts();ownedThrough(f,"Porcelain Dipper");f.honey=300000000
        local c=catalog("Porcelain Dipper",300000000,{})
        c.hiveSlot={cost={Honey=200000000}};c.basicEgg={cost={Honey=10000000}}
        local r=P.plan(f,c)
        check(r.action.kind=="buy-hive-slot" and r.growthHoney==210000000,"Slot26 includes an egg in gear comparison")
        for _,egg in ipairs({"Basic","Silver","Gold"}) do
            f.inventory={[egg]=1};r=P.plan(f,c)
            check(r.action.kind=="buy-hive-slot" and r.growthHoney==200000000,"Owned "..egg.." removes egg funding")
        end
        f.questGoldReserve=1;r=P.plan(f,c)
        check(r.growthHoney==210000000,"Reserved quest Gold cannot fund a new cell")
        f.questGoldReserve=0;f.inventory={}
        for _,slotPrice in ipairs({290000000,300000000}) do
            c.hiveSlot.cost.Honey=slotPrice
            check(P.plan(f,c).action.kind=="buy-gear","Combined equality or higher restores gear")
        end
        c.hiveSlot.cost.Honey=200000000;f.honey=209999999
        check(P.plan(f,c).action.kind=="wait","Save entire slot plus egg budget before slot purchase")
        f.honey=210000000;r=P.plan(f,c)
        check(r.action.kind=="buy-hive-slot","Exact slot plus egg budget qualifies")
        f.honeyReserve=1
        check(P.plan(f,c).action.kind=="wait","Slot and egg respect safety reserve")
        f.honeyReserve=0;c.hiveSlot=nil
        check(P.plan(f,c).savingGearHoney,"Unknown slot quote cannot redirect gear funds")
        c.hiveSlot={cost={Honey=200000000},conditions={"slot-open"}}
        f.conditions["slot-open"]=false
        check(P.plan(f,c).action.kind=="wait","Closed expansion condition cannot purchase")
        f.conditions["slot-open"]=true;f.capacity=26;f.occupied=25;f.emptyCell={x=1,y=1,verified=true}
        check(P.plan(f,c).action.kind=="buy-basic-egg" and P.plan(f,c).growthHoney==10000000,"After expansion only egg remains")
        f.inventory.Silver=1
        check(P.plan(f,c).action.kind=="hatch-egg","Owned Silver hatches after expansion")
        f.capacity=50;f.occupied=50
        check(not P.plan(f,c).eggBeforeGear,"Maximum capacity cannot defer gear for growth")
    end
    do
        local stages=P.stages
        P.stages={{gate=0,gear={"A1","B1","A2","B2","A3","B3","A4","B4","A5","B5","A6","B6"}}}
        local f=facts();f.gearQueues=true;f.honey=1000
        local c={gear={A1={honey=100,items={}},A2={honey=200,items={}},A3={honey=300,items={}},A4={honey=400,items={}},
            B1={honey=500,items={SunflowerSeed=3}},B2={honey=450,items={Strawberry=2}},
            B3={honey=600,items={SoftWax=1}},B4={honey=700,items={Blueberry=5}},
            A5={honey=500,items={}},A6={honey=600,items={}},B5={honey=800,items={Pineapple=5}},B6={honey=900,items={Oil=1}}}}
        local r=P.plan(f,c)
        check(r.action.kind=="buy-gear" and r.gear=="A1","Ready honey gear takes its turn while materials grow")
        check(#r.gearQueues.A==5 and #r.gearQueues.B==5,"Both queues contain five targets")
        check(r.gearQueues.B[1].id=="B2" and r.gearQueues.B[1].priority==1,"Material priority follows honey price regardless of remaining requirements")
        check(r.farmMissing.Strawberry==2 and r.materialFarmGear=="B2","Farm follows material queue even during honey purchases")
        c.gear.A1.honey=300;c.gear.A2.honey=100;c.gear.A3.honey=200;r=P.plan(f,c)
        check(r.gear=="A2" and r.gearQueues.A[1].priority==1 and r.gearQueues.A[3].id=="A1","Honey queue ranks by price rather than route position")
        c.gear.A1.honey=100;c.gear.A3.honey=100;r=P.plan(f,c)
        check(r.gearQueues.A[1].id=="A1" and r.gearQueues.A[2].id=="A2" and r.gearQueues.A[3].id=="A3","Equal honey prices retain route order")
        c.gear.A2.honey=200;c.gear.A3.honey=300
        f.ownedGear.A1=true;r=P.plan(f,c)
        check(r.gear=="A2" and r.gearQueues.A[3].id=="A4","Honey queue replenishes from its own category")
        check(r.gearQueues.A[5].id=="A6","Honey queue replaces purchased gear with its sixth candidate")
        f.honey=0;r=P.plan(f,c)
        check(r.gear=="B2" and r.farmMissing.Strawberry==2,"Unfunded honey gear cannot block material collection")
        c.gear.B1.items={SunflowerSeed=1000};c.gear.B4.items={Blueberry=1000};c.gear.B5.items={Pineapple=1000}
        c.gear.B2.items={RedExtract=1};r=P.plan(f,c)
        check(r.farmMissing.Strawberry==50 and r.farmMissing.RoyalJelly==10,"Queued Red Extract expands into its complete fruit and jelly recipe")
        f.inventory.Strawberry=50;r=P.plan(f,c)
        check(not r.farmMissing.Strawberry and r.saveCraftingJelly,"Enough fruit ends farming and funds crafting jelly")
        c.gear.B2.items={Strawberry=2};f.inventory={}
        c.gear.B1.items={SunflowerSeed=3};c.gear.B4.items={Blueberry=5};c.gear.B5.items={Pineapple=5}
        f.ownedGear.B2=true;r=P.plan(f,c)
        check(r.gearQueues.B[3].id=="B4" and r.materialFarmGear=="B1","Material queue replenishes from its own category")
        check(r.gearQueues.B[5].id=="B6","Material queue replaces owned gear with its sixth candidate")
        f.ownedGear.A2=true;f.ownedGear.A3=true;f.ownedGear.A4=true
        f.ownedGear.A5=true;f.ownedGear.A6=true
        f.honey=1000;f.inventory.SunflowerSeed=3;r=P.plan(f,c)
        check(r.action.kind=="buy-gear" and r.gear=="B1","Complete priority1 buys immediately")
        c.gear.B1.items.SoftWax=1;c.gear.B3.items={SunflowerSeed=3};r=P.plan(f,c)
        check(r.action.kind=="buy-gear" and r.gear=="B3","A ready queued purchase may use blocked priority1 ingredients")
        c.gear.B3.items={Blueberry=1};f.inventory.Blueberry=1;r=P.plan(f,c)
        check(r.action.kind=="buy-gear" and r.gear=="B3","Independent ready material gear may buy while priority1 is blocked")
        check(r.materialFarmGear=="B3" and not r.farmMissing.SoftWax,"Passive priority1 shortage yields preparation to the next queue target")
        c.gear.B3.shopAccess=false;f.inventory.Oil=1;r=P.plan(f,c)
        check(r.action.kind=="buy-gear"and r.gear=="B6"and r.gearQueues.B[1].id=="B1","Ready material target can buy while price-ranked earlier gear still lacks materials")
        f.pending=true;r=P.plan(f,c)
        check(r.action.reason=="unresolved-progression-request","Queues preserve unresolved request guard")
        f.pending=false;f.redeemedCodes.Wax=false
        check(P.plan(f,c).action.kind=="redeem-code","Queues preserve code task ordering")
        f.redeemedCodes.Wax=true;c.gear.B1=nil
        check(not P.plan(f,c).gearQueues,"Unknown primary gear quote retains fail-closed planning")
        P.stages=stages
    end
    do
        local stages=P.stages
        P.stages={{gate=0,gear={"Candy Planter","Blue Port-O-Hive","Beekeeper's Mask","HoneyGear"}}}
        local f=facts();f.gearQueues=true;f.honey=30746216
        f.inventory={SoftWax=5,Gumdrops=253,JellyBeans=5,MagicBean=4,BlueExtract=2,Oil=2}
        local c={gear={
            ["Candy Planter"]={honey=5000000,items={SoftWax=5,Gumdrops=30,JellyBeans=3,MagicBean=5}},
            ["Blue Port-O-Hive"]={honey=12500000,items={BlueExtract=2,Oil=2},conditions={"blue-open"}},
            ["Beekeeper's Mask"]={honey=20000000,items={Oil=2,MagicBean=5}},
            HoneyGear={honey=60000000,items={}}}}
        f.conditions["blue-open"]=true
        local r=P.plan(f,c)
        check(r.action.kind=="buy-gear" and r.gear=="Blue Port-O-Hive","Screenshot case buys ready Blue backpack before blocked Candy")
        check(not r.deferredGear and not r.reservedItems.MagicBean,"Ready purchase does not inherit blocked target reservations")
        f.craft={item="Oil",count=5,ready=false}
        check(P.plan(f,c).gear=="Blue Port-O-Hive" and P.plan(f,c).action.kind=="buy-gear","Unrelated running Blender order cannot block ready purchase")
        f.craft.ready=true
        check(P.plan(f,c).action.kind=="buy-gear","Ready purchase can precede Blender collection")
        f.craft=false;f.inventory.Oil=1
        check(P.plan(f,c).action.kind~="buy-gear","Missing actual gear material cannot purchase")
        f.craft={item="Oil",count=1,ready=false}
        check(P.plan(f,c).action.kind~="buy-gear","Queued output cannot count as actual inventory")
        f.craft=false;f.inventory.Oil=2;f.honey=12500000;f.honeyReserve=1
        check(P.plan(f,c).action.kind~="buy-gear","Safety honey reserve is preserved")
        f.honeyReserve=0
        check(P.plan(f,c).action.kind=="buy-gear","Exact affordable cost buys")
        c.gear["Blue Port-O-Hive"].shopAccess=false
        check(P.plan(f,c).action.kind~="buy-gear","Locked shop cannot be bypassed")
        c.gear["Blue Port-O-Hive"].shopAccess=true;f.conditions["blue-open"]=false
        check(P.plan(f,c).action.kind~="buy-gear","Unmet purchase requirement cannot be bypassed")
        f.conditions["blue-open"]=nil
        check(P.plan(f,c).action.kind~="buy-gear","Unknown requirement fails closed")
        f.conditions["blue-open"]=true;f.uncertain=true
        check(P.plan(f,c).action.reason=="unresolved-progression-request","Uncertain receipt blocks ready queue purchase")
        f.uncertain=false;f.ownedGear["Blue Port-O-Hive"]=true;f.inventory.Oil=0;f.inventory.BlueExtract=0
        check(P.plan(f,c).gearQueues.B[1].id=="Candy Planter","After ownership update blocked Candy remains queued for later")
        f.honey=30746216;f.inventory.MagicBean=5
        check(P.plan(f,c).gear=="Candy Planter" and P.plan(f,c).action.kind=="buy-gear","Skipped Candy returns once its own requirements are met")
        P.stages=stages
    end
    do
        local stages=P.stages;P.stages={{gate=0,gear={"Material1","Material2","Material3"}}}
        local f=facts();f.gearQueues=true;f.discoveryPreparation=true;f.honey=0
        f.inventory={SunflowerSeed=250,RoyalJelly=60,Gumdrops=50}
        local c={gear={Material1={honey=100,items={Oil=2,MagicBean=1}},Material2={honey=200,items={Oil=3,SoftWax=2}},Material3={honey=300,items={Glue=1}}}}
        local r=P.plan(f,c)
        check(r.queueMaterialRequirements.Oil==5 and r.queueMaterialRequirements.SoftWax==2,"Combined queue sums shared and uncraftable ingredients")
        check(r.action.kind=="craft" and r.action.item=="Oil" and r.action.amount==5,"Craft the full combined output rather than first gear amount")
        check(not r.queueMaterialsReady and r.queueMaterialMissing.SoftWax==2 and r.queueMaterialMissing.MagicBean==1,"Uncraftable shortages block Mythic fruit use")
        check(r.reservedItems.SunflowerSeed==250,"All combined recipe fruit is reserved")
        f.craft={item="Oil",count=5,ready=false};f.inventory={Glue=1,MagicBean=1,SoftWax=2}
        check(not P.plan(f,c).queueMaterialsReady,"Queued output is not actual ready gear inventory")
        f.craft=false;f.inventory.Oil=5;r=P.plan(f,c)
        check(r.queueMaterialsReady and r.discoveryPreparation,"All actual combined materials unlock the feeding gate")
        f.ownedGear.Material1=true;r=P.plan(f,c)
        check(r.queueMaterialRequirements.Oil==3,"Queue totals refresh after gear ownership changes")
        P.stages=stages
    end
    do
        local f=facts();f.inventory.Oil=2;f.ownedGear.Clippers=true
        local c={gear={Jar={honey=100,items={Oil=3},conditions={"open"}}},routeGear={
            Clippers={honey=10,items={}},Jar={honey=100,items={Oil=3},conditions={"open"}}}}
        f.conditions.open=false
        local r=P.routeStatus(f,c,{gear="Jar",stage=1})
        check(#r.stages==#P.stages and r.currentStage==1 and r.currentGear=="Jar","Route includes all configured stages and active queued target")
        local clip,jar=r.stages[1].gear[1],r.stages[1].gear[2]
        check(clip.owned and clip.honey==10,"Owned gear retains its available cost")
        check(jar.current and jar.items[1].actual==2 and jar.items[1].required==3,"Route reports actual material progress")
        check(jar.requirementsMet==false,"Unmet prerequisites are exposed")
        check(not r.stages[1].complete and r.stages[2].gear[1].honey==nil,"Unknown prices remain unknown")
        check(f.inventory.Oil==2 and not f.pending,"Route generation never consumes or requests")
        f.inventory.Oil=3;f.conditions.open=true
        check(P.routeStatus(f,c,{gear="Jar",stage=1}).stages[1].gear[2].items[1].actual==3,"Refreshed snapshot follows actual inventory")
    end
    do
        local stages=P.stages;P.stages={{gate=0,gear={"M1","M2","M3","M4","M5"}}}
        local f=facts();f.gearQueues=true;f.discoveryPreparation=true;f.honey=0
        local c={gear={}}
        for i=1,5 do c.gear["M"..i]={honey=i*100,items={Oil=i}}end
        local r=P.plan(f,c)
        check(#r.gearQueues.B==5 and r.queueMaterialRequirements.Oil==15,"Combined material preparation includes all five targets")
        f.ownedGear.M1=true;r=P.plan(f,c)
        check(r.queueMaterialRequirements.Oil==14,"Combined materials refresh after ownership changes")
        P.stages=stages
    end
    do
        local stages=P.stages
        P.stages={{gate=0,gear={"Candy Planter","Next Mask","Third Gear"}}}
        local f=facts();f.gearQueues=true;f.honey=11653997
        f.inventory={SoftWax=2,Gumdrops=268,JellyBeans=7,MagicBean=5}
        local c={gear={
            ["Candy Planter"]={honey=5000000,items={SoftWax=5,Gumdrops=30,JellyBeans=3,MagicBean=5}},
            ["Next Mask"]={honey=20000000,items={BlueExtract=2}},
            ["Third Gear"]={honey=30000000,items={Pineapple=500}}}}
        local r=P.plan(f,c)
        check(r.gear=="Next Mask"and r.materialFarmGear=="Next Mask","Screenshot Candy wax shortage yields to the next material target")
        check(r.farmMissing.Blueberry==100 and r.farmMissing.RoyalJelly==20,"Next target expands its own complete recipe requirements")
        check(r.deferredMaterialGear[1]=="Candy Planter"and not r.reservedItems.MagicBean,"Deferred Candy is reported without holding its unrelated ingredients")
        f.inventory.Gumdrops=0;r=P.plan(f,c)
        check(r.gear=="Candy Planter","Missing actively purchasable Gumdrops keep current preparation")
        f.inventory.Gumdrops=268;f.inventory.SoftWax=5;f.inventory.JellyBeans=0;f.inventory.MagicBean=0;r=P.plan(f,c)
        check(r.gear=="Next Mask","Jelly Beans and Magic Beans are passive shortages too")
        f.inventory.JellyBeans=7;f.inventory.MagicBean=5;r=P.plan(f,c)
        check(r.gear=="Candy Planter"and r.action.kind=="buy-gear","Skipped Candy returns immediately when all actual materials arrive")
        f.inventory.SoftWax=2;f.inventory.Blueberry=100;r=P.plan(f,c)
        check(r.gear=="Next Mask"and r.saveCraftingJelly,"Next recipe may reserve crafting jelly while earlier gear awaits drops")
        f.inventory.RoyalJelly=20;r=P.plan(f,c)
        check(r.gear=="Next Mask"and r.action.kind=="craft","Ready next-target recipe crafts before passive Candy")
        f.inventory.BlueExtract=2;f.honey=20000000;r=P.plan(f,c)
        check(r.gear=="Next Mask"and r.action.kind=="buy-gear","Completed next target buys with original live guard path")
        f.pending=true;check(P.plan(f,c).action.reason=="unresolved-progression-request","Passive skipping never bypasses pending requests")
        f.pending=false;f.uncertain=true;check(P.plan(f,c).action.reason=="unresolved-progression-request","Passive skipping never bypasses uncertain receipts")
        f.uncertain=false;f.inventory={MoonCharm=25}
        c.gear["Candy Planter"].items={Glitter=1}
        r=P.plan(f,c)
        check(r.gear=="Next Mask","An unready nested craft blocked solely by a passive ingredient may defer")
        f.inventory.MagicBean=1;r=P.plan(f,c)
        check(r.gear=="Candy Planter"and r.action.kind=="craft","An actually ready current recipe is completed before deferral")
        c.gear["Candy Planter"].items={SoftWax=5};c.gear["Next Mask"].items={HardWax=1}
        f.inventory={};r=P.plan(f,c)
        check(r.gear=="Third Gear"and #r.deferredMaterialGear==2,"Multiple passive-only targets yield to an obtainable third target")
        c.gear["Third Gear"].items={MagicBean=2};r=P.plan(f,c)
        check(not r.gear and not r.materialFarmGear and r.allMaterialDeferred and #r.deferredMaterialGear==3,"All-passive queue has no falsely active material target")
        check(r.action.reason=="waiting-passive-materials"and r.optionalHiveAllowed,"All-passive wait keeps hive progression available")
        check(r.deferredMaterialReasons["Candy Planter"].SoftWax==5,"Deferred target reports its exact remaining drop requirement")
        P.stages[1].gear[#P.stages[1].gear+1]="Honey Gear"
        c.gear["Honey Gear"]={honey=200000000,items={}};f.honey=100000000
        r=P.plan(f,c)
        check(r.gear=="Honey Gear"and r.savingGearHoney and r.allMaterialDeferred,"All-passive material queues yield to real honey gear funding")
        check(not r.materialFarmGear and not next(r.farmMissing),"No material field is falsely selected for passive drops")
        f.ownedGear["Honey Gear"]=true
        f.discoveryPreparation=true;r=P.plan(f,c)
        check(r.discoveryPreparation and r.queueMaterialRequirements.SoftWax==5 and #r.deferredMaterialGear==0,"Combined SSA material accounting remains intact")
        P.stages=stages
    end
    do
        local f=facts();f.gearQueues=true;f.honey=1e12
        for _,stage in ipairs(P.stages)do for _,id in ipairs(stage.gear)do f.ownedGear[id]=true end end
        f.ownedGear["Pesticide Planter"]=false
        local c=catalog("Pesticide Planter",100,{SoftWax=1})
        f.inventory.SoftWax=1
        for _,capacity in ipairs({25,44,46})do
            f.capacity=capacity;f.occupied=25
            check(P.nextGear(f).id=="Pesticide Planter","Pesticide has no custom unlocked-slot gate")
            local r=P.plan(f,c)
            check(r.action.kind=="buy-gear"and r.gear=="Pesticide Planter","Affordable Pesticide can buy below47 when game requirements permit")
        end
        f.capacity=47;f.occupied=25
        local r=P.plan(f,c)
        check(r.gear=="Pesticide Planter"and r.action.kind=="buy-gear","Unlocked47 admits Pesticide without requiring47 occupied bees")
        check(#r.gearQueues.B==1,"Pesticide joins the normal material queue at47")
        f.pending=true;check(P.plan(f,c).action.reason=="unresolved-progression-request","Slot47 does not bypass pending guard")
        f.pending=false;f.capacity=46
        local row=P.routeStatus(f,c,{}).stages[6].gear[#P.stages[6].gear]
        check(row.capacityRequired==nil and row.hiveReady,"Route removes the custom Pesticide capacity requirement")
    end
    do
        local stages=P.stages
        P.stages={{gate=0,gear={"Candy Planter","Blue Clay Planter","Red Clay Planter","Beekeeper's Boots","Beekeeper's Mask","Honey1","Honey2"}}}
        local f=facts();f.gearQueues=true;f.honey=0
        local c={useSuppliedRecipes=false,gear={
            ["Candy Planter"]={honey=5000000,items={SoftWax=3}},
            ["Blue Clay Planter"]={honey=10000000,items={BlueExtract=14,SoftWax=18}},
            ["Red Clay Planter"]={honey=10000000,items={RedExtract=10,SoftWax=18}},
            ["Beekeeper's Boots"]={honey=15000000,items={BlueExtract=2,Oil=3}},
            ["Beekeeper's Mask"]={honey=20000000,items={Glue=2}},
            Honey1={honey=500,items={}},Honey2={honey=100,items={}}}}
        local r=P.plan(f,c);local q=r.gearQueues.B
        check(q[1].id=="Candy Planter"and q[2].id=="Blue Clay Planter"and q[3].id=="Red Clay Planter","Material queue ranks honey cost with route ties instead of remaining quantities")
        check(q[4].id=="Beekeeper's Boots"and q[5].id=="Beekeeper's Mask","Expensive gear follows cheaper gear regardless of material count")
        check(q[1].materialShortfall==nil and q[5].materialShortfall==nil,"Material quantities no longer create a priority score")
        check(r.gearQueues.A[1].id=="Honey2","Honey queue remains ranked by honey price")
        c.useSuppliedRecipes=true;r=P.plan(f,c);q=r.gearQueues.B
        check(q[1].id=="Candy Planter"and q[2].id=="Blue Clay Planter"and q[3].id=="Red Clay Planter","Recipe availability does not reorder the queue")
        check(q[4].honey==15000000 and q[5].honey==20000000,"Both queues retain verified honey price ordering")
        check(r.materialFarmGear=="Blue Clay Planter"and r.deferredMaterialGear[1]=="Candy Planter","Passive Candy yields to the next active honey-ranked target")
        f.inventory={Gumdrops=100,RoyalJelly=20};r=P.plan(f,c)
        check(r.gearQueues.B[1].id=="Candy Planter"and r.gear=="Beekeeper's Mask"and r.action.kind=="craft","Ready crafting can execute without changing displayed queue priorities")
        f.ownedGear["Beekeeper's Mask"]=true;f.inventory={};r=P.plan(f,c)
        check(r.materialFarmGear=="Blue Clay Planter","After a craft finishes material farming returns to the honey-ranked target")
        f.ownedGear.Honey1=true;f.ownedGear.Honey2=true
        f.inventory={BlueExtract=14,Oil=3};f.honey=15000000;r=P.plan(f,c)
        check(r.gear=="Beekeeper's Boots"and r.action.kind=="buy-gear","Actual completed gear remains purchasable after dynamic ranking")
        f.pending=true;check(P.plan(f,c).action.reason=="unresolved-progression-request","New material ranking retains pending guard")
        f.pending=false;f.uncertain=true;check(P.plan(f,c).action.reason=="unresolved-progression-request","New material ranking retains uncertain guard")
        P.stages=stages
    end
    do
        local f=facts();f.gearQueues=true;f.capacity=46
        for _,stage in ipairs(P.stages)do for _,id in ipairs(stage.gear)do f.ownedGear[id]=true end end
        f.ownedGear["Petal Belt"]=false
        local c=catalog("Petal Belt",100,{SpiritPetal=1})
        for _,amount in ipairs({0,1,2})do
            f.inventory.SpiritPetal=amount
            local r=P.plan(f,c)
            check(#r.gearQueues.B==1 and r.gearQueues.B[1].id=="Petal Belt","Petal Belt remains queued without a custom inventory admission gate")
            check((r.action.kind=="buy-gear")== (amount>=1),"Direct purchase shares the inventory gate")
        end
        f.inventory.SpiritPetal=nil
        check(#P.plan(f,c).gearQueues.B==1 and P.plan(f,c).action.kind~="buy-gear","Missing Spirit Petal stays an actual material deficit")
        f.inventory.SpiritPetal=1;f.craft={item="SpiritPetal",count=1,ready=false};f.inventory.SpiritPetal=0
        check(P.plan(f,c).action.kind~="buy-gear","Queued or expected Spirit Petals cannot pay the actual cost")
        local row=P.routeStatus(f,c,{}).stages[6].gear[6]
        check(row.id=="Petal Belt"and row.inventoryRequired==nil and row.hiveReady,"Route no longer adds a separate Petal inventory prerequisite")
        f.craft=false;f.inventory.SpiritPetal=1;f.pending=true
        check(P.plan(f,c).action.reason=="unresolved-progression-request","Owned petal does not bypass pending guard")
    end
    do
        local stages=P.stages;P.stages={{gate=0,gear={"Silver Soakers","Next Honey"}}}
        local f=facts();f.gearQueues=true;f.honey=23871059;f.conditions.badges=false
        local c={gear={["Silver Soakers"]={honey=22222222,items={},conditions={"badges"},requirementText="Earn 10 Hotshot Badges"},["Next Honey"]={honey=150000000,items={}}}}
        local r=P.plan(f,c)
        check(r.gear=="Next Honey"and r.savingGearHoney,"Funded badge-locked Silver Soakers yields funding to next honey gear")
        check(r.deferredRequirementGear["Silver Soakers"]=="Earn 10 Hotshot Badges"and #r.gearQueues.A==1 and r.gearQueues.A[1].id=="Next Honey","Locked Silver stays outside the queue with its exact requirement")
        check(r.reserveHoney==150000000,"Skipped locked gear does not retain an independent honey reservation")
        f.conditions.badges=true;r=P.plan(f,c)
        check(r.gear=="Silver Soakers"and r.action.kind=="buy-gear","Rechecked badge completion returns to affordable Silver Soakers")
        f.conditions.badges=false;f.honey=100
        check(P.plan(f,c).deferredRequirementGear["Silver Soakers"]~=nil,"Unfunded but badge-locked gear is excluded too")
        f.honey=23871059;f.honeyReserve=2000000
        check(P.plan(f,c).deferredRequirementGear["Silver Soakers"]~=nil,"Unlock admission remains separate from the honey reserve")
        f.honeyReserve=0;f.conditions.badges=nil;r=P.plan(f,c)
        check(r.gear=="Next Honey"and r.action.kind~="buy-gear","Unknown requirement never permits a purchase or blocks independent planning")
        P.stages={{gate=0,gear={"Locked Mat","Prep Mat"}}}
        c={gear={["Locked Mat"]={honey=100,items={Oil=1},conditions={"badges"}},["Prep Mat"]={honey=200,items={BlueExtract=2}}}}
        f.honey=1000;f.inventory={Oil=1};f.conditions.badges=false;r=P.plan(f,c)
        check(r.gear=="Prep Mat"and r.materialFarmGear=="Prep Mat","Funded locked material gear yields to another recipe's preparation")
        f.discoveryPreparation=true;r=P.plan(f,c)
        check(r.gear=="Prep Mat"and not r.queueMaterialRequirements.Oil and r.queueMaterialRequirements.BlueExtract==2,"Combined preparation includes eligible queue targets only")
        f.discoveryPreparation=false;f.inventory.Oil=0;f.craft={item="Oil",count=1,ready=false};r=P.plan(f,c)
        check(r.deferredRequirementGear["Locked Mat"]~=nil and #r.gearQueues.B==1,"Queued output cannot admit requirement-locked gear")
        f.craft=false;f.inventory={Oil=1,BlueExtract=2};c.gear["Prep Mat"].conditions={"badges"};r=P.plan(f,c)
        check(not r.gear and r.action.reason=="waiting-gear-unlocks"and r.optionalHiveAllowed,"All funded but locked gear yields safely to hive work")
        c.gear["Prep Mat"].conditions={};c.gear["Prep Mat"].shopAccess=false;r=P.plan(f,c)
        check(r.deferredRequirementGear["Prep Mat"]=="Shop entry requirements not met","Funded locked shops are deferred too")
        f.pending=true;check(P.plan(f,c).action.reason=="unresolved-progression-request","Unlock skipping preserves pending guard")
        f.pending=false;f.uncertain=true;check(P.plan(f,c).action.reason=="unresolved-progression-request","Unlock skipping preserves uncertain guard")
        P.stages=stages
    end
    do
        local stages=P.stages
        P.stages={{gate=0,gear={"Locked Honey","Locked Material","H1","B1","H2","B2","H3","B3","H4","B4","H5","B5"}}}
        local f=facts();f.gearQueues=true;f.honey=0;f.conditions.lock=false;f.conditions.open=true
        local c={gear={["Locked Honey"]={honey=1,items={},conditions={"lock"}},["Locked Material"]={honey=1,items={Oil=1},conditions={"lock"}}}}
        for i=1,5 do c.gear["H"..i]={honey=i*100,items={}};c.gear["B"..i]={honey=i*100,items={Blueberry=i}}end
        local r=P.plan(f,c)
        check(#r.gearQueues.A==5 and #r.gearQueues.B==5,"Locked items never consume queue capacity; later eligible gear fills all five slots")
        check(r.gearQueues.A[1].id=="H1"and r.gearQueues.B[1].id=="B1","Both honey and material queue exclude locked items without needing funds")
        f.conditions.lock=true;r=P.plan(f,c)
        check(r.gearQueues.A[1].id=="Locked Honey"and #r.gearQueues.A==5,"Newly unlocked gear enters automatically and queue cap stays five")
        f.conditions.lock=false;f.conditions["can-purchase:H1"]=false
        c.gear.H1.conditions={"open","can-purchase:H1"};c.gear.H1.unlockConditions={"open"}
        r=P.plan(f,c)
        check(r.gearQueues.A[1].id=="H1","Unlocked gear remains queued when CanPurchase is false only because it lacks funds")
        f.honey=100;r=P.plan(f,c)
        check(r.gearQueues.A[1].id=="H2"and r.deferredRequirementGear.H1,"Funded residual purchase ineligibility is excluded safely")
        f.conditions.lock=nil;r=P.plan(f,c)
        check(r.deferredRequirementGear["Locked Honey"]=="Purchase requirements not verified","Unknown unlock evidence cannot admit a target")
        P.stages=stages
    end
    do
        local stages=P.stages;P.stages={{gate=0,gear={"Honey","Fruit Gear","Craft Gear"}}}
        local f=facts();f.gearQueues=true;f.honey=0;f.honeyReserve=5
        f.inventory={SunflowerSeed=100,RoyalJelly=10}
        local c={gear={Honey={honey=1000,items={}},["Fruit Gear"]={honey=2000,items={Strawberry=1}},
            ["Craft Gear"]={honey=3000,items={Oil=2,SoftWax=100}}},
            packs={RoyalJelly={{id="ten",amount=10,cost={Honey=10}}}}}
        local r=P.plan(f,c)
        check(r.gear=="Craft Gear" and r.saveCraftingJelly and not r.optionalHiveAllowed,"An independently complete non-jelly recipe wins over fruit and honey waits")
        check(r.missingRJ==10 and r.fundsRequired==15 and r.reserveHoney==5,"Recipe funding needs only its deficit and safety reserve, not the honey queue price")
        f.honey=14;check(P.plan(f,c).action.reason=="saving-crafting-jelly","Never buy a partial unaffordable recipe deficit")
        f.honey=15;r=P.plan(f,c)
        check(r.action.kind=="purchase-pack"and r.action.amount==10 and r.gear=="Craft Gear","Affordable missing recipe jelly is purchased despite unfunded honey gear")
        f.inventory.RoyalJelly=20;r=P.plan(f,c)
        check(r.action.kind=="craft"and r.action.item=="Oil"and r.action.amount==2,"Whole Oil deficit crafts before waiting for unrelated Soft Wax or fruit")
        f.craft={item="Oil",count=2,ready=false};r=P.plan(f,c)
        check(r.action.kind=="wait"and r.action.reason=="blender-busy","Busy Blender cannot receive a second order")
        f.pending=true;check(P.plan(f,c).action.reason=="unresolved-progression-request","Craft selection cannot bypass a pending request")
        f.pending=false;f.uncertain=true;check(P.plan(f,c).action.reason=="unresolved-progression-request","Craft selection cannot bypass an uncertain receipt")
        P.stages=stages
    end
    do
        local stages=P.stages;P.stages={{gate=0,gear={"Porcelain Dipper","Beekeeper's Boots","Beekeeper's Mask"}}}
        local f=facts();f.gearQueues=true;f.honey=150000000;f.honeyReserve=1000000
        f.inventory={Blueberry=100,SunflowerSeed=150,Gumdrops=100,RoyalJelly=10}
        local c={gear={["Porcelain Dipper"]={honey=150000000,items={}},["Beekeeper's Boots"]={honey=15000000,items={BlueExtract=2,Oil=3}},
            ["Beekeeper's Mask"]={honey=20000000,items={Glue=2}}},packs={RoyalJelly={{id="one",amount=1,cost={Honey=1000000}},{id="ten",amount=10,cost={Honey=10000000}}}}}
        local r=P.plan(f,c)
        check(r.action.kind=="purchase-pack"and r.gear=="Beekeeper's Boots"and r.missingRJ==10,"Boots recipe jelly takes priority over Dipper savings")
        f.honey=200000000;r=P.plan(f,c)
        check(r.action.kind=="purchase-pack"and r.saveCraftingJelly and not r.optionalHiveAllowed,"Recipe funding outranks even an affordable Dipper purchase")
        f.inventory.RoyalJelly=20;r=P.plan(f,c)
        check(r.action.kind=="craft"and r.action.item=="BlueExtract"and r.action.amount==2,"Craft full Blue Extract deficit before buying honey gear")
        f.inventory.BlueExtract=2;f.inventory.RoyalJelly=5;r=P.plan(f,c)
        check(r.requiredRJ==30 and r.missingRJ==25,"Oil recipe uses the actual jelly already owned")
        f.honey=25000000;r=P.plan(f,c)
        check(r.action.reason=="saving-crafting-jelly"and r.fundsRequired==26000000,"Full recipe funding retains only safety reserve plus missing jelly cost")
        f.honey=26000000;r=P.plan(f,c)
        check(r.action.kind=="purchase-pack"and r.action.amount==10,"Existing supported pack path purchases recipe deficit when fully affordable")
        f.inventory.Oil=3;f.inventory.RoyalJelly=0;f.ownedGear["Beekeeper's Boots"]=true;r=P.plan(f,c)
        check(r.gear=="Beekeeper's Mask"and r.requiredRJ==20,"Next independently ready Glue recipe becomes the funding target")
        c.useSuppliedRecipes=false;c.recipes={Glue=false,Oil=false,BlueExtract=false};r=P.plan(f,c)
        check(r.action.kind~="craft"and r.action.item~="RoyalJelly"and not r.saveCraftingJelly,"Unavailable game recipes cannot authorize jelly purchases or crafting")
        P.stages=stages
    end
    do
        local f=facts();f.honey=1e12;f.inventory={Blueberry=0,SunflowerSeed=150,RoyalJelly=20}
        local c=catalog("Clippers",100,{BlueExtract=20,Oil=3})
        c.packs={RoyalJelly={{id="ten",amount=10,cost={Honey=10}}}}
        local r=P.plan(f,c)
        check(r.requiredRJ==30 and r.missingRJ==10,"An unready earlier Blue Extract recipe cannot hide 20 owned jelly from Oil")
        f.inventory.RoyalJelly=30;r=P.plan(f,c)
        check(r.action.kind=="craft"and r.action.item=="Oil"and r.action.amount==3,"Owned jelly can craft Oil while Blue Extract fruit is missing")
        f.inventory={Blueberry=100,SunflowerSeed=150,RoyalJelly=30};c.gear.Clippers.items={BlueExtract=2,Oil=3};r=P.plan(f,c)
        check(r.action.kind=="craft"and r.action.item=="BlueExtract","A ready recipe is preferred to funding another recipe")
        f.craft={item="BlueExtract",count=2,ready=false};r=P.plan(f,c)
        check(r.action.kind=="wait"and r.action.reason=="blender-busy","Independent selection never double-books the Blender")
    end
    do
        local stages=P.stages;P.stages={{gate=0,gear={"Porcelain Dipper","Boots"}}}
        local f=facts();f.gearQueues=true;f.honey=100;f.inventory={SunflowerSeed=150,RoyalJelly=0}
        local c={useSuppliedRecipes=false,recipes={Oil=false},recipeBlockers={Oil="Earn 3 Ability Badges"},
            gear={["Porcelain Dipper"]={honey=150000000,items={}},Boots={honey=15000000,items={Oil=3}}},
            packs={RoyalJelly={{id="one",amount=1,cost={Honey=1}}}}}
        local r=P.plan(f,c)
        check(r.gear=="Porcelain Dipper"and r.allMaterialDeferred and r.craftingBlocked.Oil=="Earn 3 Ability Badges","Screenshot fallback identifies unavailable recipe rather than silently ignoring Boots")
        check(r.gearQueues.B[1].recipeBlocks.Oil=="Earn 3 Ability Badges"and not r.saveCraftingJelly,"Actual recipe locks stay enforced and explain the queue")
        c.recipes.Oil=P.recipes.Oil;c.recipeBlockers.Oil=nil;r=P.plan(f,c)
        check(r.gear=="Boots"and r.saveCraftingJelly and r.action.kind=="purchase-pack"and not next(r.craftingBlocked),"Fresh unlock automatically restores crafting-jelly priority")
        P.stages=stages
    end
    do
        local other={Type="Test game requirement"}
        local filtered=P.craftingRequirements({{Type="Earn Badges",Amount=3},other})
        check(#filtered==1 and filtered[1]==other,"Crafting ignores obsolete badge metadata while preserving other conditions")
        check(#P.craftingRequirements(nil)==0 and P.craftingRequirements("bad")==nil,"Absent recipe metadata is allowed but malformed metadata fails closed")
        for _,stage in ipairs(P.stages)do check(stage.gate==0,"Default gear stages never impose custom bee counts")end
        check(not next(P.capacityRequirements)and not next(P.inventoryRequirements),"No custom slot or inventory gates remain for gear queues")
    end
    if workerSource then
        local source=assert(workerSource:match("(    local function craft%(a,c,s%).-)\n    local function collect"))
        local make=assert(loadstring("return function(H,P,env,finishReceipt) "..source.." return craft end"))()
        local definition={Requirements={{Type="Earn Badges",Amount=3}},Ingredients={{Category="Eggs",Type="SunflowerSeed",Amount=50},{Category="Eggs",Type="RoyalJelly",Amount=10}}}
        local function exercise(change)
            local s={Eggs={SunflowerSeed=100,RoyalJelly=20}};local env={};local calls=0
            local action={item="Oil",amount=2};local catalog={recipes={Oil={}}}
            local H={Recipes={Get=function()return definition end},Reqs={Check=function()error("Badge metadata must not be checked")end},Events={BlenderCommand={}}}
            H.invoke=function(_,command,order)
                calls+=1;check(command=="PlaceOrder"and order.Count==2,"Actual worker places the exact whole recipe deficit once")
                env.FullHiveUncertain={};s.Eggs.SunflowerSeed-=100;s.Eggs.RoyalJelly-=20
                s.BlenderState={Recipe="Oil",Count=2};return s.BlenderState
            end
            H.refresh=function()return s end
            if change then change(H,s,env,action,catalog)end
            local worker=make(H,P,env,function(_,_,receipt)check(receipt==env.FullHiveUncertain,"Worker reconciles its original receipt");return true end)
            local ok,result=pcall(worker,action,catalog,s)
            return ok,result,calls,env
        end
        local ok,result,calls=exercise()
        check(ok and result and calls==1,"Both final craft validation and receipt permit a badge-free Oil order")
        ok,result,calls=exercise(function(H,s)s.Eggs.RoyalJelly=19 end)
        check(not ok and calls==0,"Missing actual jelly still blocks the worker before sending")
        ok,result,calls=exercise(function(H,s)s.BlenderState={Recipe="Oil",Count=1}end)
        check(not ok and calls==0,"Existing Blender order still blocks duplicate craft")
        definition.Requirements={{Type="Test game condition"}}
        ok,result,calls=exercise(function(H)H.Reqs.Check=function()return false end end)
        check(not ok and calls==0,"Other explicit recipe conditions remain enforced at the final guard")
        definition.Requirements={{Type="Earn Badges",Amount=3}}
        local env;ok,result,calls,env=exercise(function(H)
            H.refresh=function()return {Eggs={SunflowerSeed=1,RoyalJelly=0},BlenderState={Recipe="Oil",Count=2}}end
        end)
        check(not ok and calls==1 and env.FullHiveUncertain~=nil,"Changed receipt delta stops without replaying or clearing uncertainty")
    end
    return {passed=passed}
end
