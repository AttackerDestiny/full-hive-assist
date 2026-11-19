-- Pure final purchase admission. A target's price is spent, not reserved twice.
local F={}
local function amount(value)
    return type(value)=="number" and value>=0 and value<math.huge
end
function F.check(action,decision,cost,stats,userReserve)
    if type(action)~="table" or type(stats)~="table" or type(stats.Eggs)~="table"
        or type(cost)~="table" then return false,"unknown-purchase-funds" end
    userReserve=userReserve or 0
    local reserve=action.kind=="buy-gear" and userReserve
        or (decision and decision.reserveHoney) or userReserve
    if not amount(userReserve) or not amount(reserve) then return false,"invalid-purchase-reserve" end
    reserve=math.max(userReserve,reserve)
    local rows=cost[1] and cost or {cost}
    local needed,count={},0
    for _,row in pairs(rows) do
        if type(row)~="table" or not amount(row.Amount) then return false,"unknown-purchase-cost" end
        local currency
        if row.Category=="Honey" then currency="Honey"
        elseif row.Category=="Eggs" and type(row.Type)=="string" then currency=row.Type
        else return false,"unsupported-purchase-currency" end
        needed[currency]=(needed[currency] or 0)+row.Amount
        count+=1
    end
    if count==0 then return false,"unknown-purchase-cost" end
    for currency,n in pairs(needed) do
        local owned=currency=="Honey" and stats.Honey or (stats.Eggs[currency] or 0)
        if not amount(owned) then return false,"unknown-purchase-balance:"..currency end
        if currency=="Honey" then owned-=reserve end
        if currency~="Honey" and action.kind=="buy-gear" and decision and decision.deferredGear then
            owned-=((decision.reservedItems or {})[currency] or 0)
        end
        if owned<n then return false,"waiting-purchase-funds:"..currency end
    end
    return true
end
return F
