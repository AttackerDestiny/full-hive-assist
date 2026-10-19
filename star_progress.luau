local Progress = {}
function Progress.read(stats)
    local completed = stats.Quests and stats.Quests.Completed
    if type(completed) ~= "table" then return {known=false, ready=false} end
    local function done(name)
        if completed[name] == true then return true end
        for _, value in pairs(completed) do if value == name then return true end end
        return false
    end
    local mother, panda = done("Seven To Seven"), done("Royal Rumble")
    local earned = (mother and 1 or 0) + (panda and 1 or 0)
    local inventory = stats.Eggs and stats.Eggs.Star or 0
    local recorded = stats.Totals and stats.Totals.EggUses and stats.Totals.EggUses.Star or 0
    return {known=true, mother=mother, panda=panda, earned=earned, inventory=inventory,
        used=math.max(recorded, math.max(0, earned-inventory)),
        ready=mother and panda and inventory==0}
end
return Progress
