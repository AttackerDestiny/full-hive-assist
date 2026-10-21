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
    local recorded = stats.Totals and stats.Totals.EggUses and stats.Totals.EggUses.Star
    local recordedKnown = type(recorded) == "number" and recorded >= 0
        and recorded < math.huge and recorded % 1 == 0
    local used = recordedKnown and recorded or 0
    return {known=true, mother=mother, panda=panda, earned=earned, inventory=inventory,
        used=used, recordedKnown=recordedKnown,
        ready=mother and panda and inventory==0 and recordedKnown and used>=2}
end
return Progress
