-- Read-only MCP BeeTypes snapshot, 2026-10-20. Never reads a client at test time.
local types={}
local groups={
    Common={"Basic"},
    Rare={"Bomber","Brave","Bumble","Cool","Hasty","Looker","Rad","Rascal","Stubborn"},
    Epic={"Bubble","Bucko","Commander","Demo","Exhausted","Fire","Frosty","Honey","Rage","Riley","Shocked"},
    Legendary={"Baby","Carpenter","Demon","Diamond","Lion","Music","Ninja","Shy"},
    Mythic={"Buoyant","Fuzzy","Precise","Spicy","Tadpole","Vector"},
    Event={"Bear","Cobalt","Crimson","Digital","Festive","Gummy","Photon","Puppy","Tabby","Vicious","Windy"},
}
for rarity,names in pairs(groups) do for _,name in ipairs(names) do types[name]={Rarity=rarity} end end
return types
