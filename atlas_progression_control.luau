-- Use the existing Atlas switch callbacks; never edit configuration upvalues.
-- Detached tab frames are discovered from the tab button callbacks because
-- Atlas parents only its currently visible tab into CoreGui.
return function(H)
    local clock=H.Clock or os.clock
    local cached
    local counters={Discoveries=0,CacheHits=0}
    if H.Stats then H.Stats.Controls=counters end
    local disabled={
        ["Auto Progression"]=true,["Auto Use Materials"]=true,["Auto Oil"]=true,
        ["Auto Stingers"]=true,["Auto Star Saw"]=true,["Use Coconut To Convert"]=true,
        ["Use Enzymes For Converting Balloon"]=true,["Auto Buy Robo Pass"]=true,
        ["Auto Memory Match"]=true,["Auto Mega Memory Match"]=true,
        ["Auto Night Memory Match"]=true,["Auto Extreme Memory Match"]=true,
        ["Auto Wind Shrine"]=true,["Auto Sticker Stacker"]=true,["Auto Sticker Printer"]=true,
    }
    local function values(callback)
        if type(callback)~="function" then return nil end
        local ok,u=pcall(H.upvalues,callback)
        return ok and type(u)=="table" and u or nil
    end
    local function switchState(upvalues,label,button)
        local keys,hasLabel={},false
        for _,value in pairs(upvalues) do
            if value==label then
                hasLabel=true
            elseif type(value)=="string" then
                keys[value]=true
            end
        end
        local cell,key
        local bound=false
        for _,value in pairs(upvalues) do if value==button then bound=true end end
        for _,value in pairs(upvalues) do
            if type(value)=="table" then
                for candidate in pairs(hasLabel and keys or {}) do
                    if type(rawget(value,candidate))=="boolean" then
                        if cell and (cell~=value or key~=candidate) then return nil end
                        cell,key=value,candidate
                    end
                end
            end
        end
        if cell then return cell,key end
        -- Older Atlas callbacks capture a separate one-element state table.
        for _,value in pairs(upvalues) do
            local stateKey=type(value)=="table" and (type(rawget(value,1))=="boolean" and 1
                or bound and type(rawget(value,4))=="boolean" and 4)
            if stateKey then
                if cell and cell~=value then return nil end
                cell=value;key=stateKey
            end
        end
        return cell,key
    end
    local function cachedAlive()
        if not cached or clock()-cached.At>=2 then return false end
        if not cached.Window.Parent or cached.Window.Name~="Window"
            or cached.Label.Text~="Stop Everything"
            or not cached.Label:IsDescendantOf(cached.Window)
            or cached.Window:FindFirstChild("TabButtons")~=cached.TabRoot
            or cached.TabRoot:FindFirstChild("ScrollingFrame")~=cached.TabButtons then return false end
        for _,row in ipairs(cached.Rows) do
            -- Hidden Atlas tabs intentionally have no parent; the label/button
            -- pair still belongs to that detached tab and must remain intact.
            if row.Label.Parent~=row.Button or not row.Button.Parent
                or row.Label.Text~=row.Name or not row.Button:IsA("TextButton")
                or type(rawget(row.Cell,row.Key))~="boolean" then return false end
        end
        return true
    end
    local function discover()
        counters.Discoveries+=1
        local labels=H.findLabels and H.findLabels("Stop Everything")
            or H.core:QueryDescendants('TextLabel[Text = "Stop Everything"]')
        local label=labels[1]
        local window=label
        while window and window.Name~="Window" do window=window.Parent end
        if not window and H.window then window=H.window() end
        if not window then return nil,"Atlas window is unavailable" end
        local tabRoot=window:FindFirstChild("TabButtons")
        local tabButtons=tabRoot and tabRoot:FindFirstChild("ScrollingFrame")
        if not tabButtons then return nil,"Atlas tab controls are unavailable" end
        local tabs,seen={},{}
        for _,button in ipairs(tabButtons:GetChildren()) do
            if button:IsA("TextButton") then
                for _,connection in ipairs(H.connections(button.MouseButton1Click)) do
                    for _,v in pairs(values(connection.Function) or {}) do
                        if typeof(v)=="Instance" and v:IsA("ScrollingFrame") and not seen[v] then
                            seen[v]=true;tabs[#tabs+1]=v
                        end
                    end
                end
            end
        end
        local rows={}
        for _,tab in ipairs(tabs) do
            for _,text in ipairs(tab:QueryDescendants("TextLabel")) do
                local button=text.Parent
                if disabled[text.Text] and button and button:IsA("TextButton") then
                    local found
                    for _,connection in ipairs(H.connections(button.MouseButton1Click)) do
                        local cell,key=switchState(values(connection.Function) or {},text.Text,button)
                        if cell then
                            if found then return nil,"Ambiguous Atlas switch: "..text.Text end
                            found={Name=text.Text,Label=text,Button=button,Cell=cell,Key=key,Callback=connection.Function}
                        end
                    end
                    if not found then return nil,"Cannot verify Atlas switch: "..text.Text end
                    rows[#rows+1]=found
                end
            end
        end
        local progression=false
        for _,row in ipairs(rows) do if row.Name=="Auto Progression" then progression=true end end
        if not progression then return nil,"Atlas Auto Progression control is unavailable" end
        cached={Window=window,Label=label,TabRoot=tabRoot,TabButtons=tabButtons,Rows=rows,At=clock()}
        return rows
    end
    local function controls()
        if cached then
            local ok,alive=pcall(cachedAlive)
            if ok and alive then counters.CacheHits+=1;return cached.Rows end
            cached=nil
        end
        return discover()
    end
    return function(apply)
        local rows,reason=controls()
        if not rows then return false,reason end
        local result={}
        for _,row in ipairs(rows) do
            if rawget(row.Cell,row.Key)==true and apply then
                assert(H.activate(row.Button,row.Callback),"Cannot disable Atlas "..row.Name)
                local deadline=os.clock()+3
                while rawget(row.Cell,row.Key)==true and os.clock()<deadline do task.wait(0.05) end
            end
            local enabled=rawget(row.Cell,row.Key)
            if type(enabled)~="boolean" then return false,"Atlas switch state unavailable: "..row.Name,result end
            result[#result+1]={Name=row.Name,Enabled=enabled}
            if enabled then return false,"Atlas is spending independently: "..row.Name,result end
        end
        return true,nil,result
    end
end
