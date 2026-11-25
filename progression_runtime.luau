-- One serialized progression worker. Uses the host's Atlas lease, proximity,
-- AlignPosition movement and durable uncertain-request receipt.
return function(H)
    local P,env,report=H.Policy,H.env,H.Report
    local R={}
    local function read(s)
        local facts,catalog=H.buildFacts(s)
        local slot=catalog.hiveSlot
        report.NextHiveSlotPrice=slot and slot.cost and slot.cost.Honey
        local decision=P.plan(facts,catalog)
        report.Progression={Gear=decision.gear,DeferredGear=decision.deferredGear,Stage=decision.stage,Action=decision.action.kind,
            Reason=decision.reason or decision.action.reason,ReserveHoney=decision.reserveHoney,
            ReservedItems=decision.reservedItems,MissingItems=decision.missingItems,GrowthHoney=decision.growthHoney,
            CostReservations=decision.costReservations,OptionalHiveAllowed=decision.optionalHiveAllowed,
            SavingCraftingJelly=decision.saveCraftingJelly==true,SavingGearHoney=decision.savingGearHoney==true,
            Status=decision.status,PlanterCatchup=decision.planterCatchup,FundsRequired=decision.fundsRequired,
            RequiredRJ=decision.requiredRJ,MissingRJ=decision.missingRJ,RequiredTickets=decision.requiredTickets,Honey=facts.honey}
        local craft=facts.craft
        report.Blender=craft and {Recipe=craft.item,Count=craft.count,ElapsedSeconds=craft.elapsedSeconds,
            TotalSeconds=craft.totalSeconds,RemainingSeconds=craft.remainingSeconds,Complete=craft.ready,
            Output=craft.output,Tickets=craft.tickets,SpeedupEnabled=craft.speedupEnabled,
            SpeedupTickets=craft.remainingUnits and craft.autoCompletePerTicket
                and math.ceil(craft.remainingUnits/craft.autoCompletePerTicket) or 0} or nil
        return decision,facts,catalog
    end
    function R.allowsHive(s,item)
        if H.Config.AutoProgression==false then return true end
        local d=read(s)
        if d.saveCraftingJelly then return item=="StarJelly" and d.action.kind=="wait" end
        return d.optionalHiveAllowed==true
    end
    function R.eventCurrency(s,currency)
        if H.Config.AutoProgression==false then return s.Eggs[currency] or 0 end
        local d=read(s)
        if d.action.kind~="wait" and d.action.kind~="hive" then return nil end
        return math.max(0,(s.Eggs[currency] or 0)-(d.reservedItems[currency] or 0))
    end
    function R.allowsEventPurchase(s,currency,cost)
        local available=R.eventCurrency(s,currency)
        return available~=nil and available>=cost
    end
    R.inspect=read
    function R.materials(s)
        local facts,catalog=H.buildFacts(s)
        H.materialFarm(s,P.plan(facts,catalog))
    end
    local function same(a,b)
        for _,k in ipairs({"kind","gear","item","amount","code","x","y","sourceId","packId","tickets","remainingUnits","orderCount","orderStartTime"}) do
            if a[k]~=b[k] then return false end
        end
        return true
    end
    local function destination(a,c)
        if a.kind=="buy-gear" then return c.gear[a.gear].part end
        if a.kind=="purchase-pack" then
            if a.packId=="custom-royal-jelly" then
                local entry=c.customRoyalJelly and c.customRoyalJelly(a.amount)
                return entry and entry.part
            end
            for _,pack in ipairs((c.packs or {})[a.item] or {}) do
                if pack.amount==a.amount and pack.id==a.packId then return pack.part end
            end
        end
        if a.kind=="purchase-material" then return c.purchases[a.item].part end
        if a.kind=="buy-hive-slot" then return c.hiveSlot.part end
        if a.kind=="buy-basic-egg" then return c.basicEgg.part end
        if a.kind=="craft" or a.kind=="collect-craft" or a.kind=="speedup-blender" then return H.toyPart("Blender") end
        if a.kind=="acquire-material" then return (c.sources[a.item] or {}).part end
        return H.hiveFloor()
    end
    local function codeHas(s,code)
        for k,v in pairs(s.Codes or {}) do
            if type(v)=="string" and v:lower()==code:lower()
                or type(k)=="string" and k:lower()==code:lower() and v==true then return true end
        end
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
    local function purchase(a,c,s,decision)
        local entry
        if a.kind=="buy-gear" then entry=c.gear[a.gear]
        elseif a.kind=="buy-hive-slot" then entry=c.hiveSlot
        elseif a.kind=="buy-basic-egg" then entry=c.basicEgg
        elseif a.kind=="purchase-material" then entry=c.purchases[a.item]
        elseif a.packId=="custom-royal-jelly" then entry=c.customRoyalJelly and c.customRoyalJelly(a.amount)
        else for _,pack in ipairs(c.packs[a.item] or {}) do if pack.amount==a.amount and pack.id==a.packId then entry=pack;break end end end
        assert(entry and entry.package,"Verified shop package unavailable")
        local package=entry.package
        if package.Category=="Eggs" and a.packId~="custom-royal-jelly" then
            package=H.fixedShopPackage(package.Type,package.Amount,entry.shopName or entry.shop.Name)
        end
        assert(H.Packages.CanPurchase(package,s)==true and H.Packages.CanGive(package,s)==true,
            "Package can no longer be purchased")
        local reqs=H.Packages.PurchaseRequirements(package,s)
        assert(not reqs or H.Reqs.Check(s,reqs),"Purchase requirements changed")
        local funded,why=H.Funds.check(a,decision,H.Packages.GetCost(package,s),s,H.Config.HoneyReserve)
        if not funded then return false,why end
        local beforeAmount=package.Category=="Eggs" and (s.Eggs[package.Type] or 0) or nil
        local beforeSlots=s.UnlockedCells
        local beforePurchased=((s.Totals or {}).Purchases or {}).HiveSlots or 0
        local accepted=H.invoke(H.Events.ItemPackageEvent,"Purchase",package)
        local receipt=env.FullHiveUncertain
        if a.kind=="buy-hive-slot" and receipt then
            receipt.ResponseReceived=true
            receipt.Accepted=accepted==true
        end
        assert(accepted,"Progression purchase rejected; reconcile receipt before retry")
        local fresh=H.refresh()
        if a.kind=="buy-hive-slot" then
            assert(fresh.UnlockedCells==beforeSlots+1,"Hive slot purchase uncertain")
            assert((((fresh.Totals or {}).Purchases or {}).HiveSlots or 0)==beforePurchased+1,"Hive slot counter uncertain")
        elseif package.Category=="Eggs" then
            assert((fresh.Eggs[package.Type] or 0)-beforeAmount==package.Amount,"Purchased item delta uncertain")
            if package.Type=="Ticket"then
                local old=assert(receipt.TicketBefore,"Ticket purchase baseline missing")
                local bought=((((fresh.Totals or{}).Purchases or{}).Eggs or{}).Ticket or 0)
                assert(bought==old.Purchased+package.Amount,"Ticket purchase counter uncertain; no retry")
            end
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
        local before,why=H.BlenderReceipt.capture(s,a)
        assert(before,why)
        H.invokeSpeedup(before)
        local receipt=env.FullHiveUncertain
        local fresh=H.refresh()
        local reconciled,reason=H.BlenderReceipt.validate(before,fresh)
        assert(reconciled,"Blender speedup output not reconciled: "..tostring(reason))
        receipt.Kind="speedup-blender";receipt.Item=a.item;receipt.Amount=a.amount;receipt.Tickets=a.tickets
        return finishReceipt(s,fresh,receipt)
    end
    local function hatch(a,s,facts)
        local empty=facts.emptyCell
        assert(empty and empty.verified and empty.x==a.x and empty.y==a.y,"Empty cell changed")
        assert(not (s.Honeycomb["x"..a.x] or {})["y"..a.y],"Hatch cell is already occupied")
        -- Stats/cache tables may change while InvokeServer yields. Capture all
        -- receipt baselines first and retain them with the uncertain request.
        local before,why=H.HatchReceipt.capture(s,a.x,a.y,a.item)
        assert(before,why)
        local remaining,accepted,comb=H.invokeHatch(before,a.x,a.y,a.item)
        local receipt=env.FullHiveUncertain
        receipt.HatchResponse={Remaining=remaining,Accepted=accepted,HasComb=type(comb)=="table"}
        local fresh=H.refresh()
        local reconciled,reason=H.HatchReceipt.validate(before,
            {remaining=remaining,accepted=accepted,comb=comb},fresh)
        assert(reconciled,"Hatch result uncertain: "..tostring(reason))
        receipt.Kind=a.kind;receipt.Item=a.item;receipt.Amount=1
        return finishReceipt(s,fresh,receipt)
    end
    function R.perform(decision,s,facts,catalog,replan)
        local action=decision.action
        if action.kind=="wait" then
            if decision.saveCraftingJelly then
                if (s.Eggs.StarJelly or 0)>0 then return false end
                return true,"Saving Royal Jelly for "..tostring(decision.gear)
            end
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
        if action.kind=="acquire-material" and action.item=="Diamond" and action.sourceKind=="claim-token" then
            s=H.refresh()
            local fresh,_,currentCatalog=replan(s)
            if not same(action,fresh.action) or destination(fresh.action,currentCatalog)~=part or not part.Parent then return false end
            assert(report.Actions<H.Config.MaxActions,"Action limit reached")
            assert(not env.FullHivePending and not env.AutoHivePendingRequest and not env.FullHiveUncertain
                and not env.AutoHiveUncertain,"Unresolved request before Diamond Egg pickup")
            local before=s.Eggs.Diamond or 0
            local known={}
            for _,id in ipairs(s.Treasures or {}) do known[id]=true end
            env.FullHiveDiamondTokenAttemptAt=os.time()
            report.Activity="Collecting the Diamond Egg under Onett"
            H.move(part,true)
            local deadline=os.clock()+6
            repeat
                H.checkStop()
                local after=H.refresh()
                if (after.Eggs.Diamond or 0)==before+1 then
                    for _,id in ipairs(after.Treasures or {}) do
                        if not known[id] then
                            report.Actions+=1
                            report.LastProgressionAction={Kind="acquire-material",Item="Diamond",Amount=1,At=os.time()}
                            H.release();return true
                        end
                    end
                end
                task.wait(0.25)
            until os.clock()>=deadline
            H.release();return true,"Diamond Egg pickup unconfirmed; waiting before checking again"
        end
        H.move(part);H.near(part)
        s=H.refresh()
        local fresh,f,c=replan(s)
        if not same(action,fresh.action) then H.release();return true,"Progression decision changed during travel" end
        local freshPart=destination(fresh.action,c)
        if freshPart~=part then H.release();return true,"Progression destination changed during travel" end
        assert(report.Actions<H.Config.MaxActions,"Action limit reached")
        H.near(freshPart)
        H.assertAtlasPaused()
        report.Phase="progression";report.Activity=action.kind..": "..tostring(fresh.gear or action.item or action.code or "hive growth")
        if action.kind=="redeem-code" then
            if codeHas(s,action.code) then return true end
            event(H.Events.PromoCodeEvent,{action.code},function(after) return codeHas(after,action.code) end,
                {Name="PromoCodeEvent",Kind="redeem-code",Item=action.code,Amount=1,Started=os.clock()})
        elseif action.kind=="craft" then craft(action,c,s)
        elseif action.kind=="collect-craft" then collect(action,s)
        elseif action.kind=="speedup-blender" then speedup(action,s)
        elseif action.kind=="hatch-basic" or action.kind=="hatch-egg" then hatch(action,s,f)
        elseif action.kind=="acquire-material" then
            local source=c.sources[action.item]
            assert(source and source.kind=="nectar-vial","Unverified material claim interface")
            local duration=H.nectarSeconds(source.nectar)
            assert(duration and duration>=43200,"Nectar duration changed")
            local beforeVial=s.Eggs[action.item] or 0
            env.FullHiveLastNectarCondenserAt=H.OsTime()
            event(H.Events.NectarCondenser,{source.nectar},function(after)
                local left=H.nectarSeconds(source.nectar)
                return (after.Eggs[action.item] or 0)==beforeVial+1
                    and left and duration-left>=43199
            end,{Name="NectarCondenser",Kind="acquire-material",Item=action.item,Amount=1,Started=os.clock()})
        else
            local purchased,why=purchase(action,c,s,fresh)
            if purchased==false then H.release();return true,why end
        end
        H.release()
        return true
    end
    function R.step(s)
        if not H.Config.AutoProgression then return false end
        local d,f,c=read(s)
        if d.action.kind=="wait" and (d.saveCraftingJelly or
            type(d.action.reason)=="string" and d.action.reason:match("^saving%-")) and f.occupied and f.capacity
            and f.occupied<f.capacity and R.grow(s,f.capacity) then return true end
        return R.perform(d,s,f,c,read)
    end
    function R.hatchEvent(s,egg,bee)
        local function replan(fresh)
            local f,c=H.buildFacts(fresh)
            local current=P.plan(f,c)
            local empty=f.emptyCell
            local ready=not H.Config.AutoProgression or current.action.kind=="wait" or current.action.kind=="hive"
            if ready and empty and empty.verified and (fresh.Eggs[egg] or 0)>0 then
                for _,cell in ipairs(H.scan(fresh)) do
                    if cell.bee.Type==bee then return {action={kind="wait"}},f,c end
                end
                return {action={kind="hatch-egg",item=egg,x=empty.x,y=empty.y,amount=1}},f,c
            end
            return {action={kind="wait"}},f,c
        end
        local d,f,c=replan(s)
        if d.action.kind=="wait" then return false,nil,f.emptyCell~=nil end
        return R.perform(d,s,f,c,replan)
    end
    function R.grow(s,target)
        local function replan(fresh)
            local f,c=H.buildFacts(fresh)
            local current=P.plan(f,c)
            if current.action.kind=="buy-gear" then
                return {action={kind="wait",reason="gear-ready"}},f,c
            end
            local reserve=math.max(H.Config.HoneyReserve,current.reserveHoney or 0)
            local d={action=P.growth(f,c,target,reserve,current.reservedItems)}
            return d,f,c
        end
        local d,f,c=replan(s)
        if d.action.kind=="wait" or d.action.kind=="gate-ready" then return false end
        return R.perform(d,s,f,c,replan)
    end
    return R
end
