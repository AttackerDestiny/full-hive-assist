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
-- StopOrder returns completed output and ingredients for unfinished units.
-- The copied baseline travels with the original request, including timeouts.
function R.captureCancel(stats,action,definition,completed)
    if type(stats)~="table"or type(stats.Eggs)~="table"or type(action)~="table"or action.kind~="cancel-craft"or type(action.item)~="string"then return nil,"invalid-cancel-state"end
    local order=stats.BlenderState
    if type(order)~="table"or order.Recipe~=action.item or not integer(order.Count)or order.Count<1
        or not startTime(order.StartTime)or order.Count~=action.amount or order.Count~=action.orderCount
        or order.StartTime~=action.orderStartTime then return nil,"cancel-order-changed"end
    if not integer(completed)or completed>order.Count or type(definition)~="table"
        or type(definition.Ingredients)~="table"or #definition.Ingredients==0 then return nil,"unknown-cancel-recipe"end
    local inputs={}
    for _,v in ipairs(definition.Ingredients)do
        if v.Category~="Eggs"or type(v.Type)~="string"or v.Type==action.item
            or not integer(v.Amount)or v.Amount<1 then return nil,"unknown-cancel-ingredient"end
        local owned=stats.Eggs[v.Type]or 0
        if not integer(owned)then return nil,"unknown-cancel-inventory"end
        local row=inputs[v.Type]or{Unit=0,Before=owned};row.Unit+=v.Amount;inputs[v.Type]=row
    end
    local output,tickets=stats.Eggs[action.item]or 0,stats.Eggs.Ticket or 0
    if not integer(output)or not integer(tickets)then return nil,"unknown-cancel-output"end
    return {Item=order.Recipe,Count=order.Count,StartTime=order.StartTime,CompletedBefore=completed,
        BeforeOutput=output,BeforeTickets=tickets,Inputs=inputs,Kind="cancel-craft"}
end
function R.validateCancel(before,fresh)
    if type(before)~="table"or before.Kind~="cancel-craft"or type(before.Item)~="string"
        or not integer(before.Count)or before.Count<1 or not integer(before.CompletedBefore)
        or before.CompletedBefore>before.Count or not startTime(before.StartTime)
        or not integer(before.BeforeOutput)or not integer(before.BeforeTickets)
        or type(before.Inputs)~="table"or not next(before.Inputs)then return false,"invalid-cancel-baseline"end
    if type(fresh)~="table"or type(fresh.Eggs)~="table"then return false,"unknown-cancel-readback"end
    if fresh.BlenderState~=nil and fresh.BlenderState~=false then return false,"cancel-order-still-present"end
    local output,tickets=fresh.Eggs[before.Item]or 0,fresh.Eggs.Ticket or 0
    if not integer(output)or not integer(tickets)or tickets<before.BeforeTickets then return false,"cancel-currency-uncertain"end
    local completed=output-before.BeforeOutput
    if not integer(completed)or completed<before.CompletedBefore or completed>before.Count then return false,"cancel-output-uncertain"end
    local left=before.Count-completed;local refunded={}
    for item,row in pairs(before.Inputs)do
        if type(item)~="string"or type(row)~="table"or not integer(row.Unit)or row.Unit<1 or not integer(row.Before)then return false,"invalid-cancel-input-baseline"end
        local expected=row.Unit*left;local actual=fresh.Eggs[item]or 0
        if not integer(expected)or not integer(actual)or actual~=row.Before+expected then return false,"cancel-refund-uncertain:"..item end
        refunded[item]=expected
    end
    return true,nil,{Completed=completed,Unfinished=left,Refunded=refunded}
end
return R
