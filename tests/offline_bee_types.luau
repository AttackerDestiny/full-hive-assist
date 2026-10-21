-- Fixed rarity fixture for isolated planning tests; never reads a game client.
local types={}
local groups={
    Basic={"Basic"},
    Rare={"Brave","Bumble","Cool","Hasty","Looker","Rad","Rascal","Stubborn"},
    Epic={"Bomber","Bubble","Bucko","Commander","Demo","Exhausted","Fire","Frosty","Honey","Rage","Riley","Shocked"},
    Legendary={"Baby","Carpenter","Demon","Diamond","Lion","Music","Ninja","Shy"},
    Mythic={"Buoyant","Fuzzy","Precise","Spicy","Tadpole","Vector"},
    Event={"Bear","Cobalt","Crimson","Digital","Festive","Gummy","Photon","Puppy","Tabby","Vicious","Windy"},
}
for rarity,names in pairs(groups) do for _,name in ipairs(names) do types[name]={Rarity=rarity} end end
return types
