-- Pure SpeedUpOrder reconciliation: ticket cost uses unfinished units, but
-- completed order output is its FULL Count. No services or mutation APIs.
-- capture(stats,action) -> copied scalar baseline | nil,reason.
-- validate(before,freshStats) -> boolean,reason; false never authorizes retry.
local R={}
local function integer(n)
    return type(n)=="number" and n>=0 and n<math.huge and n%1==0
end
local function startTime(n)
    return type(n)=="number" and n>=0 and n<math.huge
end
function R.capture(stats,action)
    if type(stats)~="table" or type(stats.Eggs)~="table" or type(action)~="table"
        or action.kind~="speedup-blender" or type(action.item)~="string" or action.item=="" then
        return nil,"unknown-blender-speedup-state"
    end
    local order=stats.BlenderState
    if type(order)~="table" or order.Recipe~=action.item or not integer(order.Count) or order.Count<1
        or not startTime(order.StartTime) then return nil,"invalid-blender-order" end
    if not integer(action.amount) or action.amount~=order.Count
        or action.orderCount~=order.Count or action.orderStartTime~=order.StartTime then
        return nil,"blender-order-changed"
    end
    if not integer(action.remainingUnits) or action.remainingUnits<1 or action.remainingUnits>order.Count
        or not integer(action.tickets) or action.tickets<1 then return nil,"invalid-blender-speedup-quote" end
    local tickets=stats.Eggs.Ticket
    if not integer(tickets) or tickets<action.tickets then return nil,"insufficient-blender-tickets" end
    local output=stats.Eggs[action.item]
    if output==nil then output=0 end
    if not integer(output) then return nil,"unknown-blender-output-inventory" end
    return {Item=action.item,Count=order.Count,StartTime=order.StartTime,
        RemainingUnits=action.remainingUnits,Tickets=action.tickets,
        BeforeTickets=tickets,BeforeOutput=output}
end
function R.validate(before,fresh)
    if type(before)~="table" or type(before.Item)~="string" or before.Item==""
        or not integer(before.Count) or before.Count<1 or not startTime(before.StartTime)
        or not integer(before.RemainingUnits) or before.RemainingUnits<1 or before.RemainingUnits>before.Count
        or not integer(before.Tickets) or before.Tickets<1 or not integer(before.BeforeTickets)
        or before.BeforeTickets<before.Tickets or not integer(before.BeforeOutput) then
        return false,"invalid-blender-speedup-snapshot"
    end
    if type(fresh)~="table" or type(fresh.Eggs)~="table" then return false,"unknown-blender-speedup-readback" end
    local tickets=fresh.Eggs.Ticket
    if tickets==nil then tickets=0 end
    if not integer(tickets) or tickets~=before.BeforeTickets-before.Tickets then
        return false,"blender-ticket-delta-uncertain"
    end
    if fresh.BlenderState~=nil and fresh.BlenderState~=false then return false,"blender-order-still-present" end
    local output=fresh.Eggs[before.Item]
    if output==nil then output=0 end
    if not integer(output) or output~=before.BeforeOutput+before.Count then
        return false,"blender-full-output-delta-uncertain"
    end
    return true
end
return R
