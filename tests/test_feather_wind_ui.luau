-- Exercise the real adapter with fake WindUI elements and screen layers.
return function(adapter)
    local passed=0
    local function check(ok,message) assert(ok,message); passed+=1 end
    local function signal()
        local event={}
        function event:Connect(fn) self.callback=fn end
        function event:Fire(...) self.callback(...) end
        return event
    end
    local function instance()
        local item={Enabled=true,Destroying=signal(),Activated=signal(),attributes={}}
        function item:Destroy() self.destroyed=true end
        function item:SetAttribute(key,value) self.attributes[key]=value end
        return item
    end
    local registered,disconnects={},0
    local function element(tab,kind,config)
        local row={config=config,updates=0}
        function row:SetTitle(value) self.title=value; self.updates+=1 end
        function row:SetDesc(value) self.desc=value; self.updates+=1 end
        function row:Lock() self.locked=true end
        registered[tab.."/"..kind.."/"..config.Title]=row
        return row
    end
    local uiAccess=true
    local window={UIElements={Main={}}}
    function window:Tab(config)
        assert(uiAccess,"UI callback lost protected-layer access")
        return {
            Paragraph=function(_,args) return element(config.Title,"Paragraph",args) end,
            Button=function(_,args) return element(config.Title,"Button",args) end,
            Toggle=function(_,args) return element(config.Title,"Toggle",args) end,
            Slider=function(_,args) return element(config.Title,"Slider",args) end,
            Select=function()window.selected=config.Title end,
        }
    end
    function window:DisableTopbarButtons(names) self.disabled=names end
    local wind={ScreenGui=instance(),NotificationGui=instance(),DropdownGui=instance(),TooltipGui=instance(),
        Creator={DisconnectAll=function() disconnects+=1 end}}
    function wind:CreateWindow(config) self.config=config; return window end
    function wind:SetParent(parent) self.parent=parent end
    local fail=false
    local lastStage
    local make=assert(loadstring("return function(loadFeatherWindUI,Instance,UDim2,Vector2,Color3,workspace,setthreadidentity)\n"..adapter.."\nend"))()
    local UI=make(function(stage) if fail then error("unavailable") end; lastStage=stage; return wind end,
        {new=instance},{fromOffset=function(...) return {...} end,fromScale=function(...) return {...} end},
        {new=function(...) return {...} end},{fromRGB=function(...) return {...} end},{},function(identity)uiAccess=identity==8 end)
    local parent,overlay,button=instance(),instance(),instance()
    local types={Basic={ID=1},Cool={ID=2},Music={ID=3}}
    check(UI.giftedDiscoveryCount({DiscGiftTypes={1,"Basic",2,"Music"}},types)==3,"Discovery deduplicates names and IDs")
    check(UI.giftedDiscoveryCount({DiscGiftTypes={[1]=true,Cool=true,["3"]=true,Unknown=true}},types)==3,"Discovery accepts ID/name boolean maps")
    check(UI.giftedDiscoveryCount({DiscGiftTypes={Cool=false,Unknown=true}},types)==0,"False and unknown types are excluded")
    check(UI.giftedDiscoveryCount({DiscGiftTypes={},Honeycomb={Basic={Gifted=true}}},types)==0,"Current hive does not replace discovery history")
    check(UI.giftedDiscoveryCount({},types)==nil,"Missing discovery data is not shown as zero")
    local stop,view,tickets,restarts=0,0,true,0
    local routeData={currentStage=2,currentGear="Mondo Belt Bag",hiveStage="early",occupied=25,capacity=25,honey=100,
        stages={{index=2,gate=0,complete=false,gear={
            {id="Mondo Belt Bag",current=true,items={{item="Oil",actual=1,required=3}},honey=1000,hiveReady=true},
            {id="Beekeeper's Boots",owned=true,items={},honey=2000,hiveReady=true}}}}}
    local mounted=assert(UI.mount(parent,overlay,"test",{
        viewHive=function() view+=1 end,assistEnabled=function() return false end,
        setAssistEnabled=function(enabled) stop+=enabled and -1 or 1 end,
        ticketsEnabled=function() return tickets end,setTickets=function(v) tickets=v end,
        materialFarmEnabled=function() return false end,setMaterialFarm=function(v) registered.materialFarm=v end,
        tweenSpeed=function() return 6 end,setTweenSpeed=function(v) registered.speed=v end,
        routeSnapshot=function()uiAccess=false;return routeData end,reexecute=function()restarts+=1 end,
    }))
    local ticketRow=registered["Controls/Toggle/Blender tickets"]
    registered["Stats/Button/Progression route"].config.Callback()
    check(window.selected=="Route","Stats button opens a scrolling WindUI route tab")
    check(registered["Route/Paragraph/Progression route"].desc:find("Current gear stage: 2",1,true),"Route identifies current gear stage")
    check(registered["Route/Paragraph/Mondo Belt Bag"].title=="→ Mondo Belt Bag","Current gear is highlighted")
    check(registered["Route/Paragraph/Mondo Belt Bag"].desc:find("Oil  1 / 3  (2 needed)",1,true),"Route shows actual and required materials")
    check(registered["Route/Paragraph/Beekeeper's Boots"].desc:find("Owned / superseded",1,true),"Owned route gear remains visible")
    routeData.honey=200
    registered["Route/Button/Refresh route"].config.Callback()
    check(registered["Route/Paragraph/Mondo Belt Bag"].desc:find("Honey  200 / 1,000",1,true),"Refresh rereads cached route data")
    registered["Route/Button/Back to Stats"].config.Callback()
    check(window.selected=="Stats","Route can return to Stats")
    registered["Controls/Button/Re-execute script"].config.Callback()
    check(restarts==1 and stop==0,"Reload button dispatches only the safe restart callback")
    local speedRow=registered["Controls/Slider/Tween speed"]
    check(speedRow.config.Value.Min==1 and speedRow.config.Value.Max==40 and speedRow.config.Value.Default==6,"Tween speed slider bounds")
    speedRow.config.Callback(27)
    check(registered.speed==27,"Tween speed dispatches to runtime")
    local stopRow=registered["Controls/Toggle/Assist enabled"]
    local farmRow=registered["Controls/Toggle/Super Material Farm"]
    check(farmRow and farmRow.config.Value==false,"Material farm defaults off")
    farmRow.config.Callback(true)
    check(registered.materialFarm==true,"Material farm toggle dispatches")
    check(stopRow.config.Value==false,"Preserves the initial paused state")
    check(wind.config.Title=="Feather" and wind.config.Icon=="feather" and not wind.config.OpenButton.Enabled,"Uses the Feather WindUI window")
    check(wind.parent==parent and lastStage.destroyed and ticketRow.config.Value,"Parents only the owned layers and preserves the existing setting")
    UI.visibility(overlay,mounted.syncVisibility,button)
    check(wind.ScreenGui.Enabled and overlay.Enabled and button.attributes.FeatherVisible,"Starts visible")
    button.Activated:Fire()
    check(not overlay.Enabled and not wind.ScreenGui.Enabled and not wind.DropdownGui.Enabled and not button.attributes.FeatherVisible,"Hides all content, leaving the button alive")
    button.Activated:Fire()
    check(overlay.Enabled and wind.ScreenGui.Enabled and wind.DropdownGui.Enabled,"Restores the window")
    registered["Overview/Button/View hive"].config.Callback()
    mounted.showWindow(false)
    button.Activated:Fire()
    button.Activated:Fire()
    check(view==1 and overlay.Enabled and not wind.ScreenGui.Enabled,"Hiding and restoring preserves the open hive view")
    mounted.showWindow(true)
    check(wind.ScreenGui.Enabled and stop==0 and tickets,"Returning from the hive restores only the window")
    ticketRow.config.Callback(false)
    stopRow.config.Callback(false)
    check(not tickets and stop==1,"Existing controls still dispatch their callbacks")
    local state={phase="WAITING",activity="Farming",metrics="41 slots",progress="No rolls",gear="Tacky Planter",background="Amulets",giftedTypes=12}
    state.nextSlot=UI.describeSlot(41,152902986)
    state.jellyGoal=UI.describeJelly({Stage="mid",Reason="fixed-targets",Mode="gifted",HasTarget=true,
        Item="StarJelly",MissingFailsafes={"Cool","Frosty"}})
    state.gearTarget=UI.describeGear({Gear="Diamond Mask",Honey=3000000000,Status={
        gearHoney=5000000000,gearMaterialsKnown=true,materials={
            {item="BlueExtract",actual=19,required=250,queued=200,deficit=31},
            {item="DiamondEgg",actual=5,required=5,queued=0,deficit=0},
        },
    }})
    mounted.render(state)
    check(registered["Stats/Paragraph/Different Gifted type"].desc=="12 discovered gifted bee types","Stats tab shows discovered gifted count")
    check(registered["Overview/Paragraph/Hive"].desc:find("Slot 42 · 152,902,986 honey",1,true)~=nil,
        "Shows the next slot and exact quoted honey price")
    check(UI.describeSlot(50,152902986)=="Hive capacity · Maximum reached","Hides obsolete quotes when the hive is full")
    check(registered["Overview/Paragraph/Jelly rolling"].desc=="Mid | Looking for gifted failsafe bees (Star Jelly)\nGifted failsafes missing: Cool, Frosty",
        "Shows the current roll objective and missing gifted failsafes")
    check(UI.describeJelly({Stage="early",HasTarget=false})=="Early | No eligible roll target",
        "Waiting does not claim that an eligible roll exists")
    local overviewGear=registered["Overview/Paragraph/Gear target"]
    check(overviewGear.desc=="Diamond Mask\nHoney  3,000,000,000 / 5,000,000,000  (2,000,000,000 needed)"
        .."\nBlue Extract  19 / 250  (+200 crafting)  (31 needed)\nDiamond Egg  5 / 5",
        "Overview shows the actual balance, required honey, and material progress")
    check(UI.describeGear({Gear="Bubble Wand",Honey=0,Status={gearHoney=3500000,gearMaterialsKnown=true}})
        =="Bubble Wand\nHoney  0 / 3,500,000  (3,500,000 needed)\nNo materials required",
        "An empty material list is distinct from unavailable requirements")
    check(UI.describeGear({Gear="Beekeeper's Boots",DeferredGear="Beekeeper's Mask"})
        :find("Deferred: Beekeeper's Mask",1,true)~=nil,
        "Overview explains why the selected gear differs from the ordered target")
    local status=registered["Overview/Paragraph/Starting"]
    local queueText=UI.describeGear({Gear="Canister",GearQueues={A={{id="Canister"},{id="Vacuum"}},B={{id="Mask"}}},MaterialFarmGear="Mask"})
    check(queueText:find("Queues · 2 honey / 1 material",1,true),"Overview summarizes queue counts without long gear lists")
    check(queueText:find("Material prep: Mask",1,true),"Queue status identifies the independent farming target")
    local requirements=UI.describeGear({Gear="Silver Soakers",Honey=13000000,Status={gearHoney=22222222,gearMaterialsKnown=true},GearQueues={A={},B={}}},true)
    check(requirements=="Silver Soakers\nHoney  13,000,000 / 22,222,222  (9,222,222 needed)\nNo materials required","Gear and Blender requirements include exact honey deficit without duplicate queues")
    local full=UI.describeQueues({Gear="Canister",GearQueues={A={{id="Canister"}},B={{id="Candy Planter"}}},DeferredMaterialReasons={["Candy Planter"]={SoftWax=3,MagicBean=2}}})
    check(full:find("Canister · active",1,true)and full:find("Soft Wax ×3",1,true)and full:find("Magic Bean ×2",1,true),"Progression shows full queues with exact deferred reasons")
    check(UI.describeGear({AllMaterialDeferred=true}):find("waiting for drops",1,true),"Empty active preparation is not labeled as completed gear")
    local locked=UI.describeQueues({GearQueues={A={},B={}},DeferredRequirementGear={["Silver Soakers"]="Earn 10 Hotshot Badges"}})
    check(locked:find("LOCKED · NOT QUEUED",1,true)and locked:find("Earn 10 Hotshot Badges",1,true),"Locked gear is explained separately from active queues")
    check(status.title=="WAITING" and status.desc=="Farming","Shows live report values")
    check(not stopRow.locked,"Pause does not disable the resume control")
    stopRow.config.Callback(true)
    check(stop==0,"Toggle can resume the assist")
    state.finished=true
    mounted.render(state)
    check(status.updates==2 and stopRow.locked and ticketRow.locked,"Skips unchanged text and locks controls after stop")
    overlay.Destroying:Fire()
    check(wind.ScreenGui.destroyed and wind.TooltipGui.destroyed and disconnects==1,"Disposes only this WindUI instance")
    fail=true
    local unavailable,reason=UI.mount(parent,instance(),"test",{})
    check(not unavailable and string.find(reason,"unavailable",1,true),"Load failures return control to native fallback")
    return {passed=passed}
end
