-- Tracks crafting fruit shortages and selects the return field by occupied bees.
local M={}
M.routes={
    {item="Strawberry",field="Strawberry Field",gate="5 Bee Gate"},
    {item="Blueberry",field="Pine Tree Forest",gate="15 Bee Gate"},
    {item="SunflowerSeed",field="Sunflower Field"},
    {item="Pineapple",field="Pineapple Patch",gate="10 Bee Gate"},
}
function M.choose(missing,allowed)
    for _,route in ipairs(M.routes) do
        if type(missing[route.item])=="number" and missing[route.item]>0 and allowed(route) then return route end
    end
end
function M.returnRoute(occupied)
    if type(occupied)~="number" or occupied<0 or occupied%1~=0 then return nil end
    if occupied<15 then return {field="Blue Flower Field"} end
    return M.routes[2]
end
function M.new(H)
    local state=H.state
    local function restore()
        if not state.previous then return end
        local route=M.returnRoute(H.occupied())
        if not route or not H.allowed(route) then return end
        if not H.set(route.field) then return end
        state.previous=nil;state.field=nil;state.item=nil
    end
    local worker={restore=restore}
    function worker.update(enabled,missing)
        if not enabled then restore();return end
        if state.field then
            local current=H.get()
            if not current then return end
            if current~=state.field then
                state.field=nil;state.item=nil
            elseif M.choose({[state.item]=missing[state.item]},H.allowed) then return end
        end
        local route=M.choose(missing,H.allowed)
        if not route then restore();return end
        local current=H.get()
        if not current then return end
        local destination=M.returnRoute(H.occupied())
        state.previous=destination and destination.field or true
        state.field=route.field;state.item=route.item
        H.set(route.field)
    end
    return worker
end
return M
