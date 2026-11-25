-- Account-scoped preferences only; request receipts and progression are never serialized.
local S={}
local booleans={UseBlenderTickets=true,SuperMaterialFarm=true,AssistEnabled=true}
local function clean(values)
    local out={}
    if type(values)~="table" then return out end
    for key in pairs(booleans) do if type(values[key])=="boolean" then out[key]=values[key] end end
    if type(values.Speed)=="number" and values.Speed==values.Speed and values.Speed<math.huge and values.Speed>-math.huge then
        out.Speed=math.clamp(values.Speed,10,400)
    end
    return out
end
function S.new(H)
    local path="Feather-settings-"..tostring(H.userId)..".json"
    local store={path=path}
    local last
    function store.load()
        if type(H.read)~="function" then store.error="Executor settings read unavailable";return {} end
        local ok,data=pcall(function()
            if H.exists and not H.exists(path) then return {schema=1,userId=H.userId,values={}} end
            return H.decode(H.read(path))
        end)
        if not ok or type(data)~="table" or data.schema~=1 or data.userId~=H.userId then
            store.error="Saved settings unavailable or invalid";return {}
        end
        store.error=nil
        return clean(data.values)
    end
    function store.save(config,enabled)
        if type(H.write)~="function" then store.error="Executor settings write unavailable";return false end
        local values=clean(config);values.AssistEnabled=enabled==true
        local unchanged=last~=nil
        for key,value in pairs(values) do if not last or last[key]~=value then unchanged=false end end
        if unchanged then return true end
        local ok,why=pcall(function() H.write(path,H.encode({schema=1,userId=H.userId,values=values})) end)
        store.error=not ok and tostring(why) or nil
        if ok then last=values end
        return ok
    end
    return store
end
return S
