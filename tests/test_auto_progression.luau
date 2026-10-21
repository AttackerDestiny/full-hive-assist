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
            local r=P.plan(f,catalog(name,100,{}))
            check(r.gear==name and r.stage==stageIndex and r.action.kind=="buy-gear","Exact ordered next gear: "..name)
            check(not r.optionalHiveAllowed and r.reserveHoney==100,"Gear reserves honey before optional hive spending")
        end
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
        check(gear.action.kind=="wait" and gear.action.reason=="saving-gear-honey" and gear.optionalHiveAllowed==false and gear.reserveHoney==100,"After materials, gear honey blocks optional hive")
        f.craft={item="Oil",count=7,ready=false,speedupEnabled=false,remainingUnits=2,tickets=20}
        local disabled=P.plan(f,catalog("Clippers",100,{BlueExtract=2}))
        check(disabled.action.kind=="wait" and disabled.action.reason=="blender-busy","Blender ticket speedup is disabled by default")
        f.craft.speedupEnabled=true
        local sped=P.plan(f,setmetatable({blenderSpeedUp={perTicket=1}},{__index=catalog("Clippers",100,{BlueExtract=2})}))
        check(sped.action.kind=="speedup-blender" and sped.action.amount==2 and sped.action.tickets==2,"Explicit speedup spends exact remaining units")
        f.craft.tickets=1
        check(P.plan(f,setmetatable({blenderSpeedUp={perTicket=1}},{__index=catalog("Clippers",100,{BlueExtract=2})})).action.reason=="waiting-tickets-for-blender","Insufficient tickets waits without speedup")
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
        check(r.action.kind=="wait" and r.action.parallelHive==true and r.reserveHoney==0,"Material jelly wait remains parallel and does not reserve gear honey")
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
    return {passed=passed}
end
