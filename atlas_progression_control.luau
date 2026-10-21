-- Use the existing Atlas switch callbacks; never edit configuration upvalues.
-- Detached tab frames are discovered from the tab button callbacks because
-- Atlas parents only its currently visible tab into CoreGui.
return function(H)
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
    local function controls()
        local label=H.core:QueryDescendants('TextLabel[Text = "Stop Everything"]')[1]
        local window=label
        while window and window.Name~="Window" do window=window.Parent end
        if not window then return nil,"Atlas window is unavailable" end
        local tabButtons=window:FindFirstChild("TabButtons")
        tabButtons=tabButtons and tabButtons:FindFirstChild("ScrollingFrame")
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
                        for _,v in pairs(values(connection.Function) or {}) do
                            if type(v)=="table" and type(v[1])=="boolean" then
                                found={Name=text.Text,Button=button,Cell=v,Callback=connection.Function}
                                break
                            end
                        end
                        if found then break end
                    end
                    if not found then return nil,"Cannot verify Atlas switch: "..text.Text end
                    rows[#rows+1]=found
                end
            end
        end
        local progression=false
        for _,row in ipairs(rows) do if row.Name=="Auto Progression" then progression=true end end
        if not progression then return nil,"Atlas Auto Progression control is unavailable" end
        return rows
    end
    return function(apply)
        local rows,reason=controls()
        if not rows then return false,reason end
        local result={}
        for _,row in ipairs(rows) do
            if row.Cell[1] and apply then
                assert(H.activate(row.Button,row.Callback),"Cannot disable Atlas "..row.Name)
                local deadline=os.clock()+3
                while row.Cell[1] and os.clock()<deadline do task.wait(0.05) end
                assert(row.Cell[1]==false,"Atlas spender switch did not synchronize: "..row.Name)
            end
            result[#result+1]={Name=row.Name,Enabled=row.Cell[1]}
            if row.Cell[1] then return false,"Atlas is spending independently: "..row.Name,result end
        end
        return true,nil,result
    end
end
