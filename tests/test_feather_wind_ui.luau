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
    local window={UIElements={Main={}}}
    function window:Tab(config)
        return {
            Paragraph=function(_,args) return element(config.Title,"Paragraph",args) end,
            Button=function(_,args) return element(config.Title,"Button",args) end,
            Toggle=function(_,args) return element(config.Title,"Toggle",args) end,
        }
    end
    function window:DisableTopbarButtons(names) self.disabled=names end
    local wind={ScreenGui=instance(),NotificationGui=instance(),DropdownGui=instance(),TooltipGui=instance(),
        Creator={DisconnectAll=function() disconnects+=1 end}}
    function wind:CreateWindow(config) self.config=config; return window end
    function wind:SetParent(parent) self.parent=parent end
    local fail=false
    local lastStage
    local make=assert(loadstring("return function(loadFeatherWindUI,Instance,UDim2,Vector2,Color3,workspace)\n"..adapter.."\nend"))()
    local UI=make(function(stage) if fail then error("unavailable") end; lastStage=stage; return wind end,
        {new=instance},{fromOffset=function(...) return {...} end,fromScale=function(...) return {...} end},
        {new=function(...) return {...} end},{fromRGB=function(...) return {...} end},{})
    local parent,overlay,button=instance(),instance(),instance()
    local stop,view,tickets=0,0,true
    local mounted=assert(UI.mount(parent,overlay,"test",{
        viewHive=function() view+=1 end,stop=function() stop+=1 end,
        ticketsEnabled=function() return tickets end,setTickets=function(v) tickets=v end,
    }))
    local ticketRow=registered["Controls/Toggle/Blender tickets"]
    local stopRow=registered["Controls/Button/Stop assist"]
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
    stopRow.config.Callback()
    check(not tickets and stop==1,"Existing controls still dispatch their callbacks")
    local state={phase="WAITING",activity="Farming",metrics="41 slots",progress="No rolls",gear="Tacky Planter",background="Amulets"}
    mounted.render(state)
    local status=registered["Overview/Paragraph/Starting"]
    check(status.title=="WAITING" and status.desc=="Farming","Shows live report values")
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
