$path = 'auto_use_star_egg.luau'
$s = Get-Content -Raw $path
if ($s.Contains('local StarProgress =')) { throw 'Already patched' }
$module = Get-Content -Raw star_progress.luau
$s = $s.Replace('local Policy = (function()', "local StarProgress = (function()`n" + $module + "`nend)()`nlocal Policy = (function()")
$s = $s.Replace('Policy.optionalMythics = {}', 'Policy.optionalMythics = {Spicy=true, Vector=true}
Policy.giftedDiscovered = {}
Policy.postEgg = false')
$s = $s.Replace('return info.Rarity == "Event" or info.Rarity == "Mythic"', 'return info.Rarity == "Event" or (info.Rarity == "Mythic" and not (Policy.postEgg and Policy.optionalMythics[cell.bee.Type]))')
$needle = '    for _, name in ipairs(giftedSingles) do'
$start = $s.IndexOf('function Policy.honeyPlan')
$at = $s.IndexOf($needle, $start)
$rules = @'
    if Policy.postEgg then
        for _, name in ipairs({"Spicy", "Vector"}) do
            if not Policy.giftedDiscovered[name] then
                local found = false
                for _, cell in ipairs(cells) do
                    if cell.bee and cell.bee.Type == name and not isGifted(cell.bee) then
                        keep[key(cell)] = true
                        found = true
                        break
                    end
                end
                if not found then needs[#needs+1] = {type=name, gifted=false, amount=1, forceMythic=true} end
            end
        end
    end

'@
$s = $s.Insert($at, $rules)
$s = $s.Replace('"Honey", "Eggs", "Totals", "Honeycomb", "Settings"', '"Honey", "Eggs", "Totals", "Honeycomb", "Settings", "Quests", "DiscGiftTypes"')
$s = $s.Replace('    Report.StarEggs = stats.Eggs.Star or 0', '    Report.StarEggs = stats.Eggs.Star or 0
    Report.StarProgress = StarProgress.read(stats)
    for _, name in ipairs({"Spicy", "Vector"}) do
        local info = Types[name]
        local discovered = stats.DiscGiftTypes
        assert(type(discovered)=="table" and info and info.ID, "Gifted discovery data unavailable")
        for k,v in pairs(discovered) do
            if v == info.ID or v == name or ((k==info.ID or k==name) and v==true) then
                Policy.giftedDiscovered[name] = true
            end
        end
    end')
$s = $s.Replace('local eggBudget = math.min(Config.MaxStarEggs, stats.Eggs.Star or 0)', 'local questProgress = StarProgress.read(stats)
assert(questProgress.known, "Quest completion data unavailable; stopping")
local eggBudget = math.min(Config.MaxStarEggs, stats.Eggs.Star or 0)
Report.QuestEggsEarned = questProgress.earned
Report.QuestEggsUsed = questProgress.used')
$start = $s.IndexOf('        -- Early-game mode only spends Star Eggs')
$end = $s.IndexOf('    end', $start)
if ($start -lt 0) { throw 'Egg placeholder not found' }
$egg = @'
        local target = Policy.choose(cells, function(cell)
            return Policy.starSafe(cell, cells, Types, required)
        end)
        assert(target, "No safe extra slot for Star Egg")
        useItem(target, "Star", "eggs")

'@
$s = $s.Substring(0,$start) + $egg + $s.Substring($end)
$gate = @'
refreshStats()
local progress = StarProgress.read(Cache:Get())
Report.StarProgress = progress
if not progress.ready then
    Report.Phase = "waiting-for-star-quests"
    Report.Activity = "Post-egg rebuild deferred: claim Seven To Seven and Royal Rumble rewards and use the available eggs first"
    return
end
Policy.postEgg = true

'@
$s = $s.Replace('-- Only the post-egg phase may release non-target gifted Legendaries.', $gate + '-- Only the post-egg phase may release non-target gifted Legendaries.')
# Refresh discovery from the same authoritative result before selecting again.
$s = $s.Replace('    if discovered then Cache:Set("DiscoveredBees", discovered) end', '    if discovered then Cache:Set("DiscoveredBees", discovered) end
    refreshStats()')
$s = $s.Replace('            local optional = Policy.optionalMythics[cell.bee.Type]', '            local optional = Policy.optionalMythics[cell.bee.Type]')
$s = $s.Replace('    Policy.stageGifted = jelly >= 5000', '    Policy.stageGifted = jelly >= 5000')
# Post-egg cleanup must remove forbidden optional Mythics even when no other need exists.
$s = $s.Replace('    Report.HoneyExtraSlots = #plan.candidates', '    Report.HoneyExtraSlots = #plan.candidates')
Set-Content -LiteralPath $path -Value $s
