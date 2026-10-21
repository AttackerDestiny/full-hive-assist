-- One serialized progression worker. Uses the host's Atlas lease, proximity,
-- AlignPosition movement and durable uncertain-request receipt.
return function(H)
    local P,env,report=H.Policy,H.env,H.Report
    local R={}
    local function read(s)
        local facts,catalog=H.buildFacts(s)
        local decision=P.plan(facts,catalog)
        report.Progression={Gear=decision.gear,Stage=decision.stage,Action=decision.action.kind,
            Reason=decision.reason or decision.action.reason,ReserveHoney=decision.reserveHoney,
            ReservedItems=decision.reservedItems,MissingItems=decision.missingItems,
            CostReservations=decision.costReservations,OptionalHiveAllowed=decision.optionalHiveAllowed}
        local craft=facts.craft
        report.Blender=craft and {Recipe=craft.item,Count=craft.count,ElapsedSeconds=craft.elapsedSeconds,
            TotalSeconds=craft.totalSeconds,RemainingSeconds=craft.remainingSeconds,Complete=craft.ready,
            Output=craft.output,Tickets=craft.tickets,SpeedupEnabled=craft.speedupEnabled,
            SpeedupTickets=craft.speedupEnabled and math.ceil((craft.remainingUnits or 0)/1) or 0} or nil
        return decision,facts,catalog
    end
    function R.allowsHive(s)
        if H.Config.AutoProgression==false then return true end
        local d=read(s)
        return d.optionalHiveAllowed==true
    end
    local function same(a,b)
        for _,k in ipairs({"kind","gear","item","amount","code","x","y","sourceId","packId"}) do
            if a[k]~=b[k] then return false end
        end
        return true
    end
    local function destination(a,c)
        if a.kind=="buy-gear" then return c.gear[a.gear].part end
        if a.kind=="purchase-pack" then
            for _,pack in ipairs((c.packs or {})[a.item] or {}) do
                if pack.amount==a.amount and pack.id==a.packId then return pack.part end
            end
        end
        if a.kind=="purchase-material" then return c.purchases[a.item].part end
        if a.kind=="buy-hive-slot" then return c.hiveSlot.part end
        if a.kind=="buy-basic-egg" then return c.basicEgg.part end
        if a.kind=="craft" or a.kind=="collect-craft" then return H.toyPart("Blender") end
        if a.kind=="acquire-material" then return (c.sources[a.item] or {}).part end
        return H.hiveFloor()
    end
    local function codeHas(s,code)
        for _,v in ipairs(s.Codes or {}) do if type(v)=="string" and v:lower()==code:lower() then return true end end
        return false
    end
    local function finishReceipt(before,s,receipt)
        assert(env.FullHiveUncertain==receipt,"Progression receipt changed; reconciliation required")
        env.FullHiveUncertain=nil
        H.jellyBatchSpent(s.Eggs.RoyalJelly or 0)
        report.Actions+=1
        report.LastProgressionAction={Kind=receipt.Kind,Item=receipt.Item,Amount=receipt.Amount,At=os.time()}
        return s
    end
    local function event(remote,args,proof,receipt)
        H.checkStop()
        assert(not env.FullHivePending and not env.AutoHivePendingRequest and not env.FullHiveUncertain,
            "Unresolved request before progression action")
        env.FullHiveUncertain=receipt
        env.FullHivePending=receipt
        local ok,err=pcall(function() remote:FireServer(table.unpack(args)) end)
        if env.FullHivePending==receipt then env.FullHivePending=nil end
        assert(ok,"Progression event uncertain; no retry: "..tostring(err))
        local deadline=os.clock()+12
        repeat
            task.wait(0.25)
            local fresh=H.refresh()
            if proof(fresh) then return finishReceipt(nil,fresh,receipt) end
        until os.clock()>=deadline
        error("Progression outcome uncertain; receipt retained; no retry",0)
    end
    local function costsFit(s,cost,reserve)
        if type(cost)~="table" then return false end
        local list=cost[1] and cost or {cost}
        for _,v in ipairs(list) do
            local have=v.Category=="Honey" and ((s.Honey or 0)-(reserve or 0)) or (s.Eggs[v.Type] or 0)
            if type(v.Amount)~="number" or v.Amount<0 or have<v.Amount then return false end
        end
        return true
    end
    local function purchase(a,c,s)
        local entry
        if a.kind=="buy-gear" then entry=c.gear[a.gear]
        elseif a.kind=="buy-hive-slot" then entry=c.hiveSlot
        elseif a.kind=="buy-basic-egg" then entry=c.basicEgg
        elseif a.kind=="purchase-material" then entry=c.purchases[a.item]
        else for _,pack in ipairs(c.packs[a.item] or {}) do if pack.amount==a.amount and pack.id==a.packId then entry=pack;break end end end
        assert(entry and entry.package,"Verified shop package unavailable")
        local package=entry.package
        assert(H.Packages.CanPurchase(package,s)==true and H.Packages.CanGive(package,s)==true,
            "Package can no longer be purchased")
        local reqs=H.Packages.PurchaseRequirements(package,s)
        assert(not reqs or H.Reqs.Check(s,reqs),"Purchase requirements changed")
        local reserve=(report.Progression and report.Progression.ReserveHoney) or H.Config.HoneyReserve
        assert(costsFit(s,H.Packages.GetCost(package,s),reserve),"Fresh progression funds changed")
        local beforeAmount=package.Category=="Eggs" and (s.Eggs[package.Type] or 0) or nil
        local beforeSlots=s.UnlockedCells
        local beforePurchased=((s.Totals or {}).Purchases or {}).HiveSlots or 0
        local accepted=H.invoke(H.Events.ItemPackageEvent,"Purchase",package)
        local receipt=env.FullHiveUncertain
        assert(accepted,"Progression purchase rejected; reconcile receipt before retry")
        local fresh=H.refresh()
        if a.kind=="buy-hive-slot" then
            assert(fresh.UnlockedCells==beforeSlots+1,"Hive slot purchase uncertain")
            assert((((fresh.Totals or {}).Purchases or {}).HiveSlots or 0)==beforePurchased+1,"Hive slot counter uncertain")
        elseif package.Category=="Eggs" then
            assert((fresh.Eggs[package.Type] or 0)-beforeAmount==package.Amount,"Purchased item delta uncertain")
        else
            assert(H.Packages.PlayerHas(package,fresh),"Gear ownership not confirmed")
            -- Verified gear PurchaseEffect equips the purchased item.
            assert(H.Packages.PlayerHasEquipped(package,fresh),"Gear equipment not confirmed")
        end
        receipt.Kind=a.kind;receipt.Item=package.Type;receipt.Amount=package.Amount or 1
        return finishReceipt(s,fresh,receipt)
    end
    local function craft(a,c,s)
        local definition=H.Recipes.Get(a.item)
        assert(definition and not P.bannedCraft[a.item],"Recipe is not permitted")
        local recipe=c.recipes[a.item]
        assert(type(recipe)=="table" and H.Reqs.Check(s,definition.Requirements or {}),"Recipe requirements changed")
        assert(not s.BlenderState,"Blender already has an order")
        assert(a.amount>0 and a.amount%1==0,"Invalid craft count")
        for _,v in ipairs(definition.Ingredients) do
            assert(v.Category=="Eggs" and (s.Eggs[v.Type] or 0)>=v.Amount*a.amount,"Craft ingredients changed")
        end
        local beforeIngredients={}
        for _,v in ipairs(definition.Ingredients) do beforeIngredients[v.Type]=s.Eggs[v.Type] or 0 end
        local result=H.invoke(H.Events.BlenderCommand,"PlaceOrder",{Recipe=a.item,Count=a.amount})
        local receipt=env.FullHiveUncertain
        assert(type(result)=="table" and result.Recipe==a.item and result.Count==a.amount,"Blender order uncertain")
        local fresh=H.refresh()
        assert(fresh.BlenderState and fresh.BlenderState.Recipe==a.item and fresh.BlenderState.Count==a.amount,
            "Blender order not confirmed by server stats")
        for _,v in ipairs(definition.Ingredients) do
            assert(beforeIngredients[v.Type]-(fresh.Eggs[v.Type] or 0)==v.Amount*a.amount,"Blender ingredient delta uncertain")
        end
        receipt.Kind="craft";receipt.Item=a.item;receipt.Amount=a.amount
        return finishReceipt(s,fresh,receipt)
    end
    local function collect(a,s)
        local current=s.BlenderState
        assert(current and current.Recipe==a.item and current.Count==a.amount,"Craft order changed")
        local beforeOutput=s.Eggs[a.item] or 0
        H.invoke(H.Events.BlenderCommand,"StopOrder")
        local receipt=env.FullHiveUncertain
        local fresh=H.refresh()
        assert(not fresh.BlenderState and (fresh.Eggs[a.item] or 0)-beforeOutput==a.amount,
            "Completed craft collection uncertain")
        receipt.Kind="collect-craft";receipt.Item=a.item;receipt.Amount=a.amount
        return finishReceipt(s,fresh,receipt)
    end
    local function speedup(a,s)
        assert(H.Config.UseBlenderTickets==true,"Blender ticket speedup is disabled")
        local current=s.BlenderState
        assert(current and current.Recipe==a.item and current.Count>0,"Craft order changed")
        local beforeTickets=s.Eggs.Ticket or 0
        local beforeOutput=s.Eggs[a.item] or 0
        H.invoke(H.Events.BlenderCommand,"SpeedUpOrder")
        local receipt=env.FullHiveUncertain
        local fresh=H.refresh()
        assert((fresh.Eggs.Ticket or 0)==beforeTickets-a.tickets,"Blender ticket delta uncertain")
        assert(not fresh.BlenderState and (fresh.Eggs[a.item] or 0)-beforeOutput==a.amount,
            "Blender speedup output not reconciled")
        receipt.Kind="speedup-blender";receipt.Item=a.item;receipt.Amount=a.amount;receipt.Tickets=a.tickets
        return finishReceipt(s,fresh,receipt)
    end
    local function hatch(a,s,facts)
        local empty=facts.emptyCell
        assert(empty and empty.verified and empty.x==a.x and empty.y==a.y,"Empty cell changed")
        assert(not (s.Honeycomb["x"..a.x] or {})["y"..a.y],"Hatch cell is already occupied")
        local remaining,accepted,comb=H.invoke(H.Events.ConstructHiveCellFromEgg,a.x,a.y,"Basic",1,false)
        local receipt=env.FullHiveUncertain
        local beforeBasic=s.Eggs.Basic or 0
        assert(accepted and remaining==beforeBasic-1 and type(comb)=="table","Hatch result uncertain")
        local fresh=H.refresh()
        local bee=(fresh.Honeycomb["x"..a.x] or {})["y"..a.y]
        assert(bee and bee.Type and (fresh.Eggs.Basic or 0)==remaining,"New bee not reconciled")
        local before=H.scan(s);local after,capacity=H.scan(fresh)
        assert(#after==#before+1 and capacity==s.UnlockedCells,"Hatch occupancy/capacity uncertain")
        for _,old in ipairs(before) do
            local b=(fresh.Honeycomb["x"..old.x] or {})["y"..old.y]
            assert(b and b.Type==old.bee.Type and (not table.find(old.bee.Traits or {},"Gifted")
                or table.find(b.Traits or {},"Gifted")),"Existing bee changed during empty hatch")
        end
        receipt.Kind="hatch-basic";receipt.Item="Basic";receipt.Amount=1
        return finishReceipt(s,fresh,receipt)
    end
    function R.perform(decision,s,facts,catalog,replan)
        local action=decision.action
        if action.kind=="wait" then
            if action.parallelHive==true then return false end
            if facts and facts.craft and not facts.craft.ready then
                return true,"Waiting for Blender: "..facts.craft.item.." ("..math.ceil(facts.craft.remainingSeconds).."s remaining)"
            end
            return true,action.reason or decision.reason
        end
        if action.kind=="hive" then return false end
        if H.Config.DryRun then return true,"dry-run:"..action.kind end
        if H.Config.AutoPurchase==false and (action.kind=="buy-gear" or action.kind=="buy-hive-slot"
            or action.kind=="buy-basic-egg" or action.kind=="purchase-pack" or action.kind=="purchase-material") then
            return true,"Purchases disabled; saving for "..tostring(decision.gear or action.item)
        end
        H.checkStop()
        local part=assert(destination(action,catalog),"Verified progression destination unavailable")
        H.move(part);H.near(part)
        s=H.refresh()
        local fresh,f,c=replan(s)
        if not same(action,fresh.action) then return true,"Progression decision changed during travel" end
        local freshPart=destination(fresh.action,c)
        if freshPart~=part then return true,"Progression destination changed during travel" end
        assert(report.Actions<H.Config.MaxActions,"Action limit reached")
        H.near(freshPart)
        report.Phase="progression";report.Activity=action.kind..": "..tostring(fresh.gear or action.item or action.code or "hive growth")
        if action.kind=="redeem-code" then
            if codeHas(s,action.code) then return true end
            event(H.Events.PromoCodeEvent,{action.code},function(after) return codeHas(after,action.code) end,
                {Name="PromoCodeEvent",Kind="redeem-code",Item=action.code,Amount=1,Started=os.clock()})
        elseif action.kind=="craft" then craft(action,c,s)
        elseif action.kind=="collect-craft" then collect(action,s)
        elseif action.kind=="speedup-blender" then speedup(action,s)
        elseif action.kind=="hatch-basic" then hatch(action,s,f)
        elseif action.kind=="acquire-material" then
            local source=c.sources[action.item]
            assert(source and source.kind=="nectar-vial","Unverified material claim interface")
            local duration=H.nectarSeconds(source.nectar)
            assert(duration and duration>=43200,"Nectar duration changed")
            env.FullHiveLastNectarCondenserAt=H.OsTime()
            event(H.Events.NectarCondenser,{source.nectar},function(after)
                local left=H.nectarSeconds(source.nectar)
                return (after.Eggs[action.item] or 0)==(s.Eggs[action.item] or 0)+1
                    and left and duration-left>=43199
            end,{Name="NectarCondenser",Kind="acquire-material",Item=action.item,Amount=1,Started=os.clock()})
        else purchase(action,c,s) end
        H.release()
        return true
    end
    function R.step(s)
        if not H.Config.AutoProgression then return false end
        local d,f,c=read(s)
        return R.perform(d,s,f,c,read)
    end
    function R.grow(s,target)
        local function replan(fresh)
            local f,c=H.buildFacts(fresh)
            local d={action=P.growth(f,c,target,H.Config.HoneyReserve,{})}
            return d,f,c
        end
        local d,f,c=replan(s)
        if d.action.kind=="wait" or d.action.kind=="gate-ready" then return false end
        return R.perform(d,s,f,c,replan)
    end
    return R
end
