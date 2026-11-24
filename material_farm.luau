-- Tracks the current recipe's fruit shortages and returns to Pine Tree Forest.
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
function M.new(H)
    local state=H.state
    local function restore()
        if not state.previous then return end
        if not H.allowed(M.routes[2]) then return end
        if not H.set("Pine Tree Forest") then return end
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
        state.previous="Pine Tree Forest";state.field=route.field;state.item=route.item
        H.set(route.field)
    end
    return worker
end
return M
