-- Atlas AddSwitch.Set updates its UI, config and saved setting together.
-- Read the setter's live binding; never write its captured configuration.
return function(H)
    return function(name,desired,apply)
        if name~="Auto Kill Coconut Crab" or type(desired)~="boolean" then return false,"Unsupported Atlas switch" end
        local ok,tables=pcall(H.tables)
        if not ok or type(tables)~="table" then return false,"Atlas switch APIs unavailable" end
        local found
        for _,controls in ipairs(tables) do
            local api=rawget(controls,"Auto Coconut Crab")
            if type(api)=="table" and type(api.Set)=="function" then
                if found and found~=api then return false,"Ambiguous Atlas Coconut Crab control" end
                found=api
            end
        end
        if not found then return false,"Atlas Coconut Crab control unavailable" end
        local cell,button
        local function bind(values)
        for _,v in pairs(values or {}) do
            if type(v)=="table" and type(rawget(v,"killcrab"))=="boolean" then
                if cell and cell~=v then return false,"Ambiguous Atlas switch state" end
                cell=v
            elseif H.isButton(v,name) then
                if button and button~=v then return false,"Ambiguous Atlas switch button" end
                button=v
            end
        end
        return true
        end
        local read,values=pcall(H.values,found.Set)
        if read then
            local ok,why=bind(values)
            if not ok then return false,why end
        end
        -- Atlas may virtualize Set while leaving its GUI click closure readable.
        -- Discover that exact label even when its tab is detached.
        if (not cell or not button) and H.buttons then
            local buttons=H.buttons(name)
            if #buttons~=1 then return false,"Atlas switch button unavailable or ambiguous" end
            button=buttons[1]
            for _,connection in ipairs(H.connections(button.MouseButton1Click)) do
                local ok,u=pcall(H.values,connection.Function)
                if ok then
                    local bound,why=bind(u)
                    if not bound then return false,why end
                end
            end
        end
        if not cell or not button then return false,"Atlas switch binding unavailable" end
        local function state()
            local enabled=rawget(cell,"killcrab")
            if type(enabled)~="boolean" or not H.isButton(button,name)
                or H.checked(button)~=enabled then return nil end
            return enabled
        end
        local enabled=state()
        if enabled==nil then return false,"Atlas switch state unavailable" end
        if apply and enabled~=desired then
            local changed=pcall(found.Set,desired) -- exactly one idempotent setter call
            if not changed then return false,"Atlas switch setter failed" end
            local deadline=H.clock()+3
            while state()~=desired and H.clock()<deadline do H.wait(0.05) end
            enabled=state()
        end
        if enabled==desired then return true,nil,enabled end
        return false,"Atlas switch not confirmed",enabled
    end
end
