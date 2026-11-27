-- Tracks crafting fruit shortages and selects the return field by occupied bees.
local M={}
function M.fieldOptions(control)
    local parent=control and control.Parent
    if not parent then return nil end
    local frame=parent:FindFirstChild("Frame")
    local options=frame and frame:FindFirstChild("ScrollingFrame")
    if options then return options end
    frame=parent:FindFirstChild("Box")
    return frame and frame:FindFirstChild("Objects")
end
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
    if occupied<5 then return {field="Blue Flower Field"} end
    if occupied<15 then return {field="Bamboo Field",gate="5 Bee Gate"} end
    return M.routes[2]
end
function M.new(H)
    local state=H.state
    local function restore()
        if not state.previous then return end
        local route=M.returnRoute(H.occupied())
        if not route or not H.allowed(route) then return end
        if not H.set(route.field) then return end
        state.previous=nil;state.field=nil;state.item=nil;state.error=nil
    end
    local worker={restore=restore}
    function worker.snapshot(enabled,missing)
        local ok,current=pcall(H.get)
        if not ok or type(current)~="string"or current==""then current=nil end
        local remaining=state.item and (missing or {})[state.item]
        if type(remaining)~="number"or remaining<0 or remaining~=remaining then remaining=nil end
        return {enabled=enabled==true,currentField=current,targetField=state.field,item=state.item,
            active=enabled==true and current~=nil and current==state.field and state.item~=nil,
            remaining=remaining,error=state.error}
    end
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
        if H.set(route.field) then
            state.previous=destination and destination.field or true
            state.field=route.field;state.item=route.item;state.error=nil
        else
            state.field=nil;state.item=nil
            state.error="Waiting to switch Atlas field to "..route.field
        end
    end
    return worker
end
return M
