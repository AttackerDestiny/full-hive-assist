-- Serialized amulet/quest worker. All requests share the host's durable guards.
return function(H)
    local R={};local A,Q,env,report=H.AmuletPolicy,H.QuestPolicy,H.env,H.Report
    local RS,player=H.RS,H.player
    local Amulets=H.load(RS:WaitForChild("Amulets"))
    local Quests=H.load(RS:WaitForChild("Quests"))
    local Actives=H.load(RS:WaitForChild("PlayerActives"))
    local ToyUI=H.load(RS.Activatables:WaitForChild("Toys"))
    local Rewards=H.load(RS.Gui:WaitForChild("RewardsPopUp"))
    local state={Amulet="Inspecting amulets",Quest="Inspecting active quests",ReserveHoney=0}
    report.Background=state
    local function clone(t)
        local o={};for k,v in pairs(t or{})do o[k]=type(v)=="table"and clone(v)or v end;return o
    end
    local function key(v)
        if type(v)~="table"then return type(v)..":"..tostring(v)end
        local ks={};for k in pairs(v)do ks[#ks+1]=k end;table.sort(ks,function(a,b)return tostring(a)<tostring(b)end)
        local out={};for _,k in ipairs(ks)do out[#out+1]=key(k).."="..key(v[k])end
        return "{"..table.concat(out,";").."}"
    end
    local function fingerprint(a) return a and key({Type=a.Type,Mods=a.Mods})or"none"end
    local function pending()
        return env.FullHivePending or env.AutoHivePendingRequest or env.FullHiveUncertain or env.AutoGiftedStarRunning
    end
    local function offers(s)
        local out,seen={},{}
        local function walk(v,depth)
            if type(v)~="table"or depth>4 then return end
            if type(v.Type)=="string"and type(v.Mods)=="table"then
                local g=Amulets.GetGroup(v.Type)
                if g=="Ant"or g=="King Beetle"or g=="Star"or g=="Moon"then
                    local k=fingerprint(v);if not seen[k]then seen[k]=true;out[#out+1]={group=g,package=v,key=k}end
                end
                return
            end
            for _,x in pairs(v)do walk(x,depth+1)end
        end
        walk(s.IncomingAmulets,0)
        return out
    end
    local function hasOffer(s,k)for _,o in ipairs(offers(s))do if o.key==k then return true end end;return false end
    local function finish(receipt,s)
        assert(env.FullHiveUncertain==receipt,"Background receipt changed; reconcile before retry")
        env.FullHiveReconciledReceipts=env.FullHiveReconciledReceipts or{}
        env.FullHiveReconciledReceipts[tostring(receipt.Started)..":"..receipt.Name]={At=os.time(),Kind=receipt.Kind,Item=receipt.Item,NoReplay=true}
        env.FullHiveUncertain=nil;report.Actions+=1
        report.LastBackgroundAction={Kind=receipt.Kind,Item=receipt.Item,Quest=receipt.Quest,At=os.time()}
        H.jellyBatchSpent(s.Eggs.RoyalJelly or 0)
    end
    local function event(remote,args,receipt,proof)
        H.checkStop();assert(not pending(),"Unresolved request before background action")
        assert(report.Actions<H.Config.MaxActions,"Action limit reached")
        receipt.Owner=player.UserId;receipt.Job=game.JobId;receipt.Started=os.clock();receipt.Name=remote.Name
        env.FullHiveUncertain=receipt;env.FullHivePending=receipt
        local ok,err=pcall(function()remote:FireServer(table.unpack(args))end)
        if env.FullHivePending==receipt then env.FullHivePending=nil end
        assert(ok,"Background request uncertain; no retry: "..tostring(err))
        local untilTime=os.clock()+12
        repeat
            task.wait(0.25);local fresh=H.refresh()
            if receipt.Item=="Supreme Star Amulet Generator"then
                -- Use only the verified No button for this exact optional
                -- 500B prompt. Never accept it or change a remote callback.
                for _,frame in ipairs(player.PlayerGui:QueryDescendants('Frame[Name = "QuestionBox"]'))do
                    local box=frame:FindFirstChild("Box");local text=box and box:FindFirstChild("TextBox")
                    local no=box and box:FindFirstChild("NoButton")
                    if frame.Visible and text and A.rejectDualPrompt(text.Text)and no then
                        for _,c in ipairs(getconnections(no.MouseButton1Click))do
                            if type(c.Function)=="function"then c.Function();break end
                        end
                    end
                end
            end
            if proof(fresh)then finish(receipt,fresh);return fresh end
        until os.clock()>untilTime
        error("Background outcome uncertain; receipt retained; no retry: "..receipt.Kind,0)
    end
    function R.offers(s)
        if pending()or H.Config.DryRun then return false end
        local incoming=offers(s)
        if #incoming==0 then return false end
        local o=incoming[1];local old=(s.Amulets or{})[o.group]
        local take,why=A.choose(o.group,old,o.package)
        state.Amulet=o.group..": "..tostring(why)
        if take==nil then return false end
        -- Passive King Beetle/Ant decisions do not acquire or move Atlas.
        local fresh=H.refresh();if pending()or not hasOffer(fresh,o.key)then return false end
        if fingerprint((fresh.Amulets or{})[o.group])~=fingerprint(old)then return false end
        local nowTake=A.choose(o.group,(fresh.Amulets or{})[o.group],o.package)
        if nowTake~=take then return false end
        local desc=Amulets.ModsDescription(o.package)
        local remote=take and H.Events.ClientAcceptAmulet or H.Events.ClientRejectAmulet
        local expected=take and o.key or fingerprint(old)
        event(remote,take and{o.group,o.package.Type,desc}or{o.group,o.package.Type},
            {Kind=take and"replace-amulet"or"keep-amulet",Item=o.package.Type,Offer=clone(o.package),Before=clone(old)},
            function(after)return not hasOffer(after,o.key)and fingerprint((after.Amulets or{})[o.group])==expected end)
        pcall(Rewards.Close)
        state.Amulet=o.group..": "..(take and"replaced"or"kept current")
        return true
    end
    local function questFacts(s)
        local list={}
        for _,active in ipairs((s.Quests or{}).Active or{})do
            if Q.rules[active.Name]then
                local def=Quests:Get(active.Name)
                if def then
                    local tasks=Quests.ResolveTasks(def,s)
                    -- Omit the optional quest name: GetProgression must never
                    -- auto-send CompleteQuest during a read-only inspection.
                    local values=Quests:GetProgression(tasks,s,clone(active.StartValues))
                    local q={name=active.Name,key=key(active.StartValues),active=true,tasks={}}
                    for i,t in ipairs(tasks)do
                        local v=values[i]
                        if v then q.tasks[#q.tasks+1]={index=i,type=t.Type,item=t.Item,toy=t.Toy,current=v[2],goal=v[3]}end
                    end
                    list[#list+1]=q
                end
            end
        end
        return list
    end
    local function questActions(s)return Q.actions(questFacts(s))end
    local function matchingQuest(s,a)
        for _,v in ipairs(questActions(s))do
            if v.quest==a.quest and v.questKey==a.questKey and v.index==a.index and v.mode==a.mode and v.item==a.item then return v end
        end
    end
    local function onField()
        local char=player.Character;local root=char and char:FindFirstChild("HumanoidRootPart")
        local zones=workspace:FindFirstChild("FlowerZones")
        if not root or not zones then return false end
        local name=player:GetAttribute("CurrentZone")
        local zone=type(name)=="string"and zones:FindFirstChild(name)
        if not zone or not zone:IsA("BasePart")then return false end
        local pos=zone.CFrame:PointToObjectSpace(root.Position)
        return math.abs(pos.X)<=zone.Size.X/2 and math.abs(pos.Z)<=zone.Size.Z/2 and pos.Y>=0 and pos.Y<=12
    end
    local function toy(name,s)
        local t=workspace.Toys:FindFirstChild(name)
        local part=t and t:FindFirstChild("Platform")
        if not t or not part or not part:IsA("BasePart")or not t:FindFirstChild("ServerEffect")then return nil end
        local req=t:FindFirstChild("Requirements")
        if req and not H.Reqs.Check(s,H.load(req))then return nil end
        local _,_,disabled=ToyUI.ButtonText(player,t)
        if disabled then return nil end
        return t,part
    end
    local function generate(name,s,expected,quest)
        local t,part=toy(name,s);if not t then return false end
        if H.Config.DryRun then return false end
        H.move(part);H.near(part);s=H.refresh()
        if pending()or #offers(s)>0 then H.release();return false end
        local again,freshPart=toy(name,s)
        if again~=t or freshPart~=part then H.release();return false end
        if quest and not matchingQuest(s,quest)then H.release();return false end
        if expected then
            local category=t:FindFirstChild("CostCategory");local amount=t:FindFirstChild("CostAmount")
            if not category or not amount or category.Value~=expected.category or amount.Value~=expected.amount then H.release();return false end
            if expected.category=="Honey"then
                local disc=#(s.DiscGiftTypes or{})
                local target=A.starTarget(disc,(s.Amulets or{}).Star)
                if not target or target.name~=name or s.Honey<expected.amount+H.Config.HoneyReserve
                    or(s.Transient or{}).GenerateSupremeDualPassive==true then H.release();return false end
                local req=t:FindFirstChild("GiftedReq");if not req or req.Value~=target.gifted then H.release();return false end
            else
                local typeValue=t:FindFirstChild("CostType")
                local _,res=questActions(s)
                if not typeValue or typeValue.Value~="MoonCharm"or(s.Eggs.MoonCharm or 0)<100+(quest and 0 or(res.MoonCharm or 0))then H.release();return false end
                if not quest and A.moonGood(A.read((s.Amulets or{}).Moon))then H.release();return false end
            end
        end
        local before=(((s.Totals or{}).ToyUses or{})[name]or 0)
        local amuletType=t:FindFirstChild("AmuletType")
        local expectedType=expected and amuletType and amuletType.Value
        if expected and type(expectedType)~="string"then H.release();return false end
        H.near(part);H.assertAtlasPaused()
        report.Phase="background";report.Activity="Using "..name
        event(H.Events.ToyEvent,{name},{Kind="use-toy",Item=name,Quest=quest and quest.quest,BeforeUses=before},
            function(after)return A.generated(before,(((after.Totals or{}).ToyUses or{})[name]or 0),expectedType,offers(after))end)
        H.release();return true
    end
    local activeNames={Stinger="Stinger",Enzymes="Enzymes",Oil="Oil",MagicBean="Magic Bean",FieldDice="Field Dice",CloudVial="Cloud Vial",Coconut="Coconut",RedExtract="Red Extract",BlueExtract="Blue Extract"}
    local function assistQuest(a,s)
        state.Quest=a.quest..": "..a.item.." ("..a.remaining.." remaining)"
        if H.Config.DryRun then return false end
        if a.mode=="toy"then
            return generate(a.item,s,a.item=="Moon Amulet Generator"and{category="Eggs",amount=100}or nil,a)
        elseif a.mode=="own"then
            if(s.Eggs.Gold or 0)>0 then state.Quest=a.quest..": Gold Egg ready for donation";return false end
            if not H.Config.AutoPurchase then return false end
            local pkg=H.fixedShopPackage("Gold",1,"TicketTent")
            if not H.Packages.CanPurchase(pkg,s)or not H.Packages.CanGive(pkg,s)then return false end
            if not H.Funds.check({kind="purchase-material"},{reserveHoney=H.Config.HoneyReserve},H.Packages.GetCost(pkg,s),s,H.Config.HoneyReserve)then return false end
            H.move(H.shopFloor("TicketTent"));H.near(H.shopFloor("TicketTent"));s=H.refresh()
            if not matchingQuest(s,a)or(s.Eggs.Gold or 0)>0 then H.release();return false end
            pkg=H.fixedShopPackage("Gold",1,"TicketTent")
            if not H.Funds.check({kind="purchase-material"},{reserveHoney=H.Config.HoneyReserve},H.Packages.GetCost(pkg,s),s,H.Config.HoneyReserve)then H.release();return false end
            H.assertAtlasPaused();H.near(H.shopFloor("TicketTent"))
            local n=s.Eggs.Gold or 0;local accepted=H.invoke(H.Events.ItemPackageEvent,"Purchase",pkg);local receipt=env.FullHiveUncertain
            local fresh=H.refresh();assert(accepted and(fresh.Eggs.Gold or 0)==n+1,"Quest Gold Egg purchase uncertain; do not retry")
            finish(receipt,fresh);H.release();return true
        elseif a.mode=="feed"then
            local count=math.min(a.remaining,s.Eggs.MoonCharm or 0);if count<1 then return false end
            H.move(H.hiveFloor());H.near(H.hiveFloor());s=H.refresh();local now=matchingQuest(s,a)
            if not now then H.release();return false end
            count=math.min(now.remaining,s.Eggs.MoonCharm or 0);if count<1 then H.release();return false end
            local cells=H.scan(s);local c=cells[1];if not c then H.release();return false end
            local before=s.Eggs.MoonCharm or 0;local beforeType=c.bee.Type;local beforeGift=table.find(c.bee.Traits or{},"Gifted")~=nil
            H.near(H.hiveFloor());H.assertAtlasPaused()
            local remain,ok=H.invoke(H.Events.ConstructHiveCellFromEgg,c.x,c.y,"MoonCharm",count,false)
            local receipt=env.FullHiveUncertain;local fresh=H.refresh();local b=(fresh.Honeycomb["x"..c.x]or{})["y"..c.y]
            assert(ok and remain==before-count and(fresh.Eggs.MoonCharm or 0)==remain and b and b.Type==beforeType
                and(not beforeGift or table.find(b.Traits or{},"Gifted")),"Quest feeding uncertain; no retry")
            finish(receipt,fresh);H.release();return true
        end
        if(a.mode=="field"or a.mode=="coconut")and not onField()then return false end
        local name=activeNames[a.item];local active=name and Actives.Get(name)
        if not active or not active.Cost or active.Cost.Type~=a.item or active.Cost.Amount~=1 or not active:CanActivate()then return false end
        s=H.refresh();if not matchingQuest(s,a)or(s.Eggs[a.item]or 0)<1 or not active:CanActivate()then return false end
        if(a.mode=="field"or a.mode=="coconut")and not onField()then return false end
        local before=s.Eggs[a.item]or 0
        event(H.Events.PlayerActivesCommand,{{Name=name}},{Kind="quest-use-item",Item=a.item,Quest=a.quest,Before=before,Objective=a.index},
            function(after)return(after.Eggs[a.item]or 0)==before-1 end)
        return true
    end
    function R.inspect(s)
        local quests,res=questActions(s)
        local target,why=A.starTarget(type(s.DiscGiftTypes)=="table"and #s.DiscGiftTypes or nil,(s.Amulets or{}).Star)
        state.Amulet=target and("Target: "..target.name)or why
        state.Quest=quests[1]and(quests[1].quest..": "..quests[1].item)or"No requested active quest objectives"
        state.ReserveHoney=target and target.price or 0
        return target,quests,res
    end
    function R.consumables(s)
        if pending()or H.Config.DryRun or not H.Config.AutoQuestAssist then return false end
        for _,a in ipairs(questActions(s))do if Q.duringSaving(a)and assistQuest(a,s)then return true end end
        return false
    end
    function R.allowsHive(s)
        if H.Config.AutoAmulets==false then return true end
        local target=A.starTarget(type(s.DiscGiftTypes)=="table"and #s.DiscGiftTypes or nil,(s.Amulets or{}).Star)
        return target==nil
    end
    function R.step(s)
        if pending()then return false end
        local target,quests,res=R.inspect(s)
        if H.Config.DryRun then return false end
        -- Item uses need no honey or movement. Saving must not starve an
        -- active objective while Atlas is already farming in a valid field.
        if R.consumables(s)then return true end
        if H.Config.AutoAmulets then
            if target then
                state.Amulet="Saving for "..target.name
                if s.Honey>=target.price+H.Config.HoneyReserve then
                    if generate(target.name,s,{category="Honey",amount=target.price})then return true end
                end
                H.release();return true,"Saving honey for "..target.name
            end
            -- Reserve active Hive Minded Bias food before Moon generation.
            for _,a in ipairs(quests)do if a.mode=="feed"and H.Config.AutoQuestAssist and assistQuest(a,s)then return true end end
            if not A.moonGood(A.read((s.Amulets or{}).Moon))and(s.Eggs.MoonCharm or 0)>=100+(res.MoonCharm or 0)then
                if generate("Moon Amulet Generator",s,{category="Eggs",amount=100})then return true end
            end
        end
        if H.Config.AutoQuestAssist then for _,a in ipairs(quests)do if assistQuest(a,s)then return true end end end
        return false
    end
    return R
end
