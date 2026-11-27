-- Feather's UI adapter. Its only game-facing operations are the callbacks
-- supplied by the host for the existing controls and cached hive snapshot.
local UI={}
function UI.giftedDiscoveryCount(stats,types)
    if type(stats)~="table" or type(stats.DiscGiftTypes)~="table" or type(types)~="table" then return nil end
    local aliases,seen={},{}
    for name,info in pairs(types) do
        if type(name)=="string" and type(info)=="table" and info.ID~=nil then
            aliases[name]=name;aliases[info.ID]=name;aliases[tostring(info.ID)]=name
        end
    end
    local count=0
    for key,value in pairs(stats.DiscGiftTypes) do
        local token=value==true and key or (type(value)=="number" or type(value)=="string") and value
        local name=token and aliases[token]
        if name and not seen[name] then seen[name]=true;count+=1 end
    end
    return count
end

local function amount(value)
    local digits=string.format("%.0f",value)
    return (digits:reverse():gsub("(%d%d%d)","%1,"):reverse():gsub("^,",""))
end

function UI.describeSlot(slots,price)
    if not slots then return "Next hive slot · Waiting for hive data" end
    if slots>=50 then return "Hive capacity · Maximum reached" end
    return "Slot "..(slots+1).." · "..(price and amount(price).." honey" or "Price unavailable")
end

function UI.describeGear(report,requirementsOnly)
    if not report.Gear then
        if report.AllMaterialDeferred then return "Material targets are waiting for drops or unlocks.\nHive progression continues.\nSee Progression for details."end
        if report.DeferredRequirementGear and next(report.DeferredRequirementGear)then return "Waiting for gear unlock requirements.\nHive progression continues.\nSee Progression for details."end
        return report.Reason=="ordered-gear-complete" and "Gear route complete" or "Inspecting gear..."
    end
    local status=report.Status or {}
    local lines={report.Gear}
    if report.DeferredGear then lines[#lines+1]="Deferred: "..report.DeferredGear end
    if status.gearHoney~=nil then
        local have=report.Honey
        local honey="Honey  "..(have and amount(have) or "?").." / "..amount(status.gearHoney)
        if have and have<status.gearHoney then
            honey=honey.."  ("..amount(status.gearHoney-have).." needed)"
        end
        lines[#lines+1]=honey
    else
        lines[#lines+1]="Waiting for gear cost"
    end
    local materials=status.materials or {}
    if status.gearMaterialsKnown and #materials==0 then lines[#lines+1]="No materials required" end
    for _,row in ipairs(materials) do
        local name=row.item:gsub("(%l)(%u)","%1 %2")
        local line=name.."  "..(row.actual and amount(row.actual) or "?").." / "..amount(row.required)
        if row.queued>0 then line=line.."  (+"..amount(row.queued).." crafting)" end
        if row.deficit and row.deficit>0 then line=line.."  ("..amount(row.deficit).." needed)" end
        lines[#lines+1]=line
    end
    if report.GearQueues and not requirementsOnly then
        lines[#lines+1]="Queues · "..#(report.GearQueues.A or {}).." honey / "..#(report.GearQueues.B or {}).." material"
        if report.MaterialFarmGear then lines[#lines+1]="Material prep: "..report.MaterialFarmGear
        elseif report.AllMaterialDeferred then lines[#lines+1]="Material prep: waiting for drops or unlocks"end
        if report.DeferredMaterialGear and #report.DeferredMaterialGear>0 then
            lines[#lines+1]=#report.DeferredMaterialGear.." deferred · details in Progression"
        end
        if report.MaterialFarmStatus then lines[#lines+1]=report.MaterialFarmStatus end
        if report.DiscoveryPreparation then
            lines[#lines+1]=report.QueueMaterialsReady and "Combined queue materials: ready" or "Preparing combined queue materials before Mythic feeding"
        end
    end
    return table.concat(lines,"\n")
end

function UI.describeRouteGear(row,honey)
    local lines={row.owned==true and "Owned / superseded" or row.current and "Current purchase target"
        or row.owned==nil and "Ownership not yet known" or "Upcoming gear"}
    if row.honey~=nil then
        lines[#lines+1]="Honey  "..(honey and amount(honey) or "?").." / "..amount(row.honey)
    else lines[#lines+1]="Cost unavailable in this server" end
    if row.honey~=nil and #row.items==0 then lines[#lines+1]="No materials required" end
    for _,item in ipairs(row.items) do
        local missing=item.actual and math.max(0,item.required-item.actual)
        lines[#lines+1]=item.item:gsub("(%l)(%u)","%1 %2").."  "..(item.actual and amount(item.actual) or "?")
            .." / "..amount(item.required)..(missing and missing>0 and "  ("..amount(missing).." needed)" or "")
    end
    if row.owned~=true and (not row.hiveReady or row.shopAccess==false or row.requirementsMet==false) then
        lines[#lines+1]="Entry or purchase requirements not met"
    end
    if row.ownershipRequired then lines[#lines+1]="Requires owned "..row.ownershipRequired end
    if row.equipmentRequired then lines[#lines+1]="Requires equipped "..row.equipmentRequired end
    if row.capacityRequired then lines[#lines+1]="Requires "..row.capacityRequired.." unlocked hive slots"end
    if row.inventoryRequired then lines[#lines+1]="Queue unlock: "..row.inventoryRequired.amount.." "..row.inventoryRequired.item:gsub("(%l)(%u)","%1 %2").." in inventory"end
    return table.concat(lines,"\n")
end

function UI.describeMaterialFarm(farm,enabled,paused)
    farm=farm or {}
    if enabled==nil then enabled=farm.enabled end
    local active=enabled and not paused and farm.active==true
    local status=not enabled and "OFF"or paused and "Paused"or active and "Farming crafting fruit"or "Idle / waiting"
    local lines={status,(paused and "Last Atlas field: "or"Atlas field: ")..tostring(farm.currentField or "Unavailable")}
    local fruit=type(farm.item)=="string"and farm.item:gsub("(%l)(%u)","%1 %2")
    lines[#lines+1]="Fruit: "..(active and fruit or "None")
    if active then
        if type(farm.held)=="number"then lines[#lines+1]="Inventory: "..amount(farm.held)end
        if type(farm.remaining)=="number"then lines[#lines+1]="Still needed: "..amount(farm.remaining)end
        if farm.gear then lines[#lines+1]="For: "..farm.gear end
    elseif enabled and not paused and farm.targetField then
        lines[#lines+1]="Switch target: "..farm.targetField..(fruit and " ("..fruit..")"or"")
    end
    if enabled and not paused and farm.error then lines[#lines+1]=tostring(farm.error)end
    return table.concat(lines,"\n")
end

function UI.describeQueues(report)
    local lines={}
    for _,kind in ipairs({"A","B"})do
        lines[#lines+1]=kind=="A" and "HONEY QUEUE · honey cost" or "MATERIAL QUEUE · remaining materials"
        local queue=(report.GearQueues or {})[kind]or{}
        if #queue==0 then lines[#lines+1]="No queued gear"end
        for index,entry in ipairs(queue)do
            local line=index..". "..entry.id
            local reasons=(report.DeferredMaterialReasons or{})[entry.id]
            if reasons then
                local items={};for name,n in pairs(reasons)do items[#items+1]=name:gsub("(%l)(%u)","%1 %2").." ×"..amount(n)end
                table.sort(items);line..="\n   Waiting: "..table.concat(items,", ")
            elseif entry.id==report.Gear then line..=" · active"end
            local blocked={}
            for item,reason in pairs(entry.recipeBlocks or {})do
                blocked[#blocked+1]=item:gsub("(%l)(%u)","%1 %2")..": "..reason
            end
            table.sort(blocked)
            if #blocked>0 then line..="\n   Crafting blocked: "..table.concat(blocked,"; ")end
            lines[#lines+1]=line
        end
        lines[#lines+1]=""
    end
    local lockedNames={}
    for name in pairs(report.DeferredRequirementGear or{})do lockedNames[#lockedNames+1]=name end
    if #lockedNames>0 then
        table.sort(lockedNames);lines[#lines+1]="LOCKED · NOT QUEUED"
        for _,name in ipairs(lockedNames)do lines[#lines+1]=name.."\n   "..report.DeferredRequirementGear[name]end
        lines[#lines+1]=""
    end
    lines[#lines+1]="Material farming: "..(report.MaterialFarmEnabled and "ON"or"OFF")
    return table.concat(lines,"\n")
end

local jellyObjectives={
    ["Replacing normal Basic Bee"]="Replacing normal Basic bees",
    ["collector"]="Building the collector lineup",
    ["gifted-collector"]="Looking for gifted collectors",
    ["convert-flexible"]="Upgrading Bubble or Frosty to gifted",
    ["collector-fallback"]="Repairing the collector lineup",
    ["gifted-collector-fallback"]="Repairing the gifted collector lineup",
    ["slot-cap"]="Replacing a surplus bee",
    ["blue-fill"]="Building the blue hive",
    ["final-surplus"]="Replacing a surplus bee in the final hive",
}

function UI.describeJelly(goal)
    if not goal then return "Waiting for a hive plan" end
    local missing=goal.MissingFailsafes or {}
    local stage=goal.Stage and goal.Stage:gsub("^%l",string.upper) or "Hive"
    local objective
    if not goal.HasTarget then
        objective="No eligible roll target"
    elseif goal.LegendaryHunt then
        objective="Looking for missing gifted Legendary bees"
    elseif #missing>0 and goal.FailsafeGoalsActive~=false and (goal.Item=="StarJelly" or goal.Reason=="fixed-targets"
        and goal.Mode=="gifted") then
        objective="Looking for gifted failsafe bees"
    elseif goal.Reason=="fixed-targets" then
        objective=goal.Mode=="gifted" and "Looking for required gifted bees" or "Filling required bee quotas"
    else
        objective=jellyObjectives[goal.Reason] or "Rolling an eligible bee"
    end
    local item=goal.Item=="StarJelly" and "Star Jelly" or goal.Item=="RoyalJelly" and "Royal Jelly"
    local text=stage.." | "..objective..(item and " ("..item..")" or "")
    if #missing>0 then
        text..=goal.ForceQuotasReady==false and "\nFill 4 Baby, 4 Music and 3 Shy before gifted failsafes"
            or goal.FailsafeGoalsActive==false and "\nGifted failsafe goals unlock with Bubble Mask"
            or "\nGifted failsafes missing: "..table.concat(missing,", ")
    end
    return text
end

function UI.visibility(overlay,onVisibility,button)
    local shown=true
    local function setShown(value)
        shown=value
        overlay.Enabled=value
        if onVisibility then onVisibility() end
        button:SetAttribute("FeatherVisible",value)
        button.BackgroundColor3=value and Color3.fromRGB(24,27,29) or Color3.fromRGB(35,42,54)
    end
    button.Activated:Connect(function() setShown(not shown) end)
    setShown(true)
    return setShown
end

function UI.mountToggle(parent,overlay,onVisibility)
    local make=FeatherTheme.make
    local gui=make("ScreenGui","FeatherVisibility",parent,{
        ResetOnSpawn=false,ScreenInsets=Enum.ScreenInsets.DeviceSafeInsets,DisplayOrder=10002})
    local button=make("ImageButton","FeatherVisibilityButton",gui,{
        AnchorPoint=Vector2.new(0.5,0),Position=UDim2.new(0.5,0,0,48),
        Size=UDim2.fromOffset(52,52),BorderSizePixel=0,Image="",Active=true})
    make("UICorner","Circle",button,{CornerRadius=UDim.new(1,0)})
    make("UIStroke","Rim",button,{Color=Color3.fromRGB(66,74,81),Transparency=0.5,Thickness=1})
    make("ImageLabel","FeatherIcon",button,{
        AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(28,28),
        BackgroundTransparency=1,Image=FeatherTheme.featherIcon,ImageColor3=Color3.fromRGB(205,213,222)})
    UI.visibility(overlay,onVisibility,button)
    overlay.Destroying:Connect(function() gui:Destroy() end)
    return button
end

function UI.mount(parent,overlay,version,callbacks)
    local stage=Instance.new("Folder")
    stage.Name="FeatherWindUIStaging"
    local wind,window
    local layers={}
    local function cleanup()
        if window then window.Destroyed=true end
        if wind and wind.Creator then wind.Creator.DisconnectAll() end
        for _,layer in ipairs(layers) do layer:Destroy() end
        if stage then stage:Destroy(); stage=nil end
    end
    local ok,result=pcall(function()
        wind=loadFeatherWindUI(stage)
        layers={wind.ScreenGui,wind.NotificationGui,wind.DropdownGui,wind.TooltipGui}
        local visible=false
        local function syncVisibility()
            for _,layer in ipairs(layers) do layer.Enabled=visible and overlay.Enabled end
        end
        local function showWindow(value)
            visible=value
            syncVisibility()
        end
        window=wind:CreateWindow({
            Title="Feather",Icon="feather",IconThemed=true,Author="Atlas Hive Assist  •  v"..version,
            Theme="Dark",Size=UDim2.fromOffset(500,350),MinSize=Vector2.new(500,350),
            SideBarWidth=132,Resizable=false,HideSearchBar=true,ScrollBarEnabled=true,
            OpenButton={Enabled=false},
        })
        window:DisableTopbarButtons({"Minimize","Close","Fullscreen"})
        local overview=window:Tab({Title="Overview",Icon="activity"})
        local progression=window:Tab({Title="Progression",Icon="hexagon"})
        local statsTab=window:Tab({Title="Stats",Icon="chart-column"})
        local routeTab,routeSummary,routeRows
        local function showRoute()
            local snapshot=callbacks.routeSnapshot and callbacks.routeSnapshot()
            -- Game cost readers may lower this callback's thread identity.
            -- Restore executor UI access before touching WindUI's protected layer.
            local setIdentity=setthreadidentity or setidentity
            if type(setIdentity)=="function" then setIdentity(8) end
            if not routeTab then
                routeRows={}
                routeTab=window:Tab({Title="Route",Icon="route"})
                routeTab:Button({Title="Back to Stats",Icon="arrow-left",Callback=function()statsTab:Select()end})
                routeTab:Button({Title="Refresh route",Icon="refresh-cw",Callback=function()showRoute()end})
                routeSummary=routeTab:Paragraph({Title="Progression route",Desc="Waiting for progression data..."})
            end
            if snapshot then
                routeSummary:SetDesc("Current gear stage: "..tostring(snapshot.currentStage or (snapshot.complete and "Complete" or "Inspecting"))
                    .." | Hive stage: "..tostring(snapshot.hiveStage or "Inspecting")
                    .."\nCurrent target: "..tostring(snapshot.currentGear or (snapshot.complete and "Gear route complete" or "Inspecting"))
                    .."\n"..tostring(snapshot.occupied or "?").." bees / "..tostring(snapshot.capacity or "?").." slots"
                    .."\nReady queued gear can buy first. Values are from the latest cached player snapshot.")
                for _,stageInfo in ipairs(snapshot.stages) do
                    local key="stage"..stageInfo.index
                    if not routeRows[key] then routeRows[key]=routeTab:Paragraph({Title="Stage "..stageInfo.index,Desc=""}) end
                    routeRows[key]:SetTitle((stageInfo.index==snapshot.currentStage and "CURRENT · " or "").."Stage "..stageInfo.index)
                    routeRows[key]:SetDesc((stageInfo.complete and "Complete" or "In progress / upcoming")
                        ..(stageInfo.gate>0 and " · "..stageInfo.gate.." bees required" or " · No hive gate"))
                    for _,row in ipairs(stageInfo.gear) do
                        if not routeRows[row.id] then routeRows[row.id]=routeTab:Paragraph({Title=row.id,Desc=""}) end
                        routeRows[row.id]:SetTitle((row.owned==true and "✓ " or row.current and "→ " or "")..row.id)
                        routeRows[row.id]:SetDesc(UI.describeRouteGear(row,snapshot.honey))
                    end
                end
            else routeSummary:SetDesc("Waiting for progression data. Use Refresh route once the game has loaded.") end
            routeTab:Select()
        end
        statsTab:Button({Title="Progression route",Icon="route",Callback=function()
            if callbacks.viewRoute then callbacks.viewRoute() else showRoute() end
        end})
        local giftedTypes=statsTab:Paragraph({Title="Different Gifted type",Desc="Waiting for discovery data..."})
        local mythicProgress=statsTab:Paragraph({Title="SSA discovery",Desc="Waiting for post-Star preparation"})
        local controls=window:Tab({Title="Controls",Icon="settings"})
        local restarting=false
        controls:Button({Title="Re-execute script",Icon="refresh-cw",Desc="Reload the latest source after a safe stop. Keeps paused accounts paused.",
            Callback=function()
                if restarting then return end
                restarting=true
                if callbacks.reexecute then callbacks.reexecute() end
                restarting=false
            end})
        controls:Slider({Title="Tween speed",Desc="1 = 10 studs/second; 6 = 60; 40 = 400. Updates active movement.",
            Step=1,Value={Min=1,Max=40,Default=callbacks.tweenSpeed()},Callback=callbacks.setTweenSpeed})
        local status=overview:Paragraph({Title="Starting",Desc="Preparing progression..."})
        local hive=overview:Paragraph({Title="Hive",Desc="Waiting for hive data..."})
        local jellyGoal=overview:Paragraph({Title="Jelly rolling",Desc="Waiting for a hive plan"})
        local gear=progression:Paragraph({Title="Gear and Blender",Desc="Inspecting gear..."})
        local materialFarm=progression:Paragraph({Title="Super Material Farm",Desc="Reading Atlas field..."})
        local queues=progression:Paragraph({Title="Gear queues",Desc="Reading queued gear..."})
        local background=progression:Paragraph({Title="Amulets and quests",Desc="Inspecting..."})
        overview:Button({Title="View hive",Icon="eye",Callback=function() callbacks.viewHive() end})
        local gearTarget=overview:Paragraph({Title="Gear target",Desc="Inspecting gear..."})
        local tickets=controls:Toggle({Title="Blender tickets",Icon="hammer",
            Desc="Allow tickets to speed up Blender crafting.",Value=callbacks.ticketsEnabled(),
            Callback=callbacks.setTickets})
        local assist=controls:Toggle({Title="Assist enabled",Icon="activity",Value=callbacks.assistEnabled(),
            Desc="Turn off to pause. Turn on to resume.",
            Callback=callbacks.setAssistEnabled})
        if callbacks.setMaterialFarm then
            controls:Toggle({Title="Super Material Farm",Icon="feather",
                Desc="Farm crafting fruit in the background. Return to Blue Flower below 5 bees, Bamboo at 5–14, Pine Tree from 15.",
                Value=callbacks.materialFarmEnabled(),Callback=callbacks.setMaterialFarm})
        end
        -- The viewer sits in its own layer. Its close button restores the window.
        local camera=workspace.CurrentCamera
        if camera and (camera.ViewportSize.X>=1100 or camera.ViewportSize.Y>=800) then
            window.Position=camera.ViewportSize.X>=1100 and UDim2.fromScale(0.25,0.5)
                or UDim2.fromScale(0.5,0.25)
            window.UIElements.Main.Position=window.Position
        end
        local names={"FeatherWindWindow","FeatherWindNotifications","FeatherWindDropdowns","FeatherWindTooltips"}
        for index,layer in ipairs(layers) do
            layer.Name=names[index]
            layer.DisplayOrder=9995+index
        end
        wind:SetParent(parent)
        stage:Destroy(); stage=nil
        showWindow(true)
        overlay.Destroying:Connect(cleanup)
        local last={}
        local function update(element,method,key,value)
            if last[key]==value then return end
            last[key]=value
            element[method](element,value)
        end
        return {
            showWindow=showWindow,
            openRouteList=showRoute,
            syncVisibility=syncVisibility,
            render=function(state)
                update(status,"SetTitle","phase",state.phase)
                update(status,"SetDesc","activity",state.activity)
                update(hive,"SetDesc","hive",state.metrics.."\n"..state.progress.."\n"..(state.nextSlot or ""))
                update(jellyGoal,"SetDesc","jellyGoal",state.jellyGoal or "Waiting for a hive plan")
                update(gearTarget,"SetDesc","gearTarget",state.gearTarget)
                update(gear,"SetDesc","gear",state.gear)
                update(materialFarm,"SetDesc","materialFarm",state.materialFarm or "Reading Atlas field...")
                update(queues,"SetDesc","queues",state.gearQueues or "Reading queued gear...")
                update(background,"SetDesc","background",state.background)
                update(giftedTypes,"SetDesc","giftedTypes",state.giftedTypes~=nil and tostring(state.giftedTypes).." discovered gifted bee types" or "Waiting for discovery data...")
                update(mythicProgress,"SetDesc","mythicProgress",state.mythicDiscovery or "Waiting for post-Star preparation")
                if state.finished and not last.finished then
                    last.finished=true
                    tickets:Lock()
                    assist:Lock()
                end
            end,
        }
    end)
    if ok then return result end
    cleanup()
    return nil,tostring(result)
end
return UI
