table.find = function(t, value) for i,v in ipairs(t) do if v == value then return i end end end
local policy = assert(loadfile('hive_roll_policy.luau'))()
local types = {Demon={Rarity='Legendary'},Ninja={Rarity='Legendary'},Music={Rarity='Legendary'},Tabby={Rarity='Event'},Fuzzy={Rarity='Mythic'}}
local checked=0
for _, entry in ipairs({{'Demon',3},{'Ninja',4},{'Music',3}}) do
    local cells={}
    for i=1,entry[2] do cells[i]={x=i,y=1,bee={Type=entry[1],Traits={'Gifted'}}} end
    while #cells>1 do
        assert(policy.prepSafe(cells[#cells],cells,types))
        assert(policy.starSafe(cells[#cells],cells,types,{entry[1]}))
        checked=checked+2
        table.remove(cells)
    end
    assert(not policy.prepSafe(cells[1],cells,types))
    assert(not policy.starSafe(cells[1],cells,types,{entry[1]}))
    checked=checked+2
end
assert(loadfile('auto_claim_gifted_star.luau'))
print('Passed '..checked..' duplicate/singleton checks; combined script syntax valid')
