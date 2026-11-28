return function(M)
    local passed=0
    local function check(v,m)assert(v,m);passed+=1 end
    local function clone(t)local out={};for k,v in pairs(t)do out[k]=type(v)=="table" and clone(v)or v end;return out end
    local types,cells={},{}
    local legends={"Music","Baby","Shy","Diamond","Lion","Demon"}
    local function add(name,rarity,gifted)
        types[name]=types[name]or{ID=name.."Id",Rarity=rarity}
        cells[#cells+1]={x=#cells+1,y=1,bee={Type=name,Traits=gifted and {"Gifted"}or{},Birth=#cells+10}}
    end
    for _,name in ipairs(legends)do add(name,"Legendary",true)end
    for _,name in ipairs(M.order)do types[name]={ID=name.."Id",Rarity="Mythic"}end
    local stats={Eggs={Star=0},DiscGiftTypes={},UnlockedCells=44}
    local history={earned=2,used=0}
    check(M.unlocked(history,stats,cells,44),"A0 unlocks after six gifted Legendaries")
    history.used=2
    check(M.unlocked(history,stats,cells,44,{Phase="complete"}),"A1 unlocks after completed rebuild")
    check(not M.unlocked(history,stats,cells,44,{Phase="rebuild"}),"A1 incomplete rebuild stays blocked")
    check(not M.unlocked({earned=1},stats,cells,44),"Both quests required")
    check(not M.unlocked(history,stats,cells,43),"Late route requires44 slots")
    stats.Eggs.Star=2;check(not M.unlocked(history,stats,cells,44),"Unused Star Eggs block feeding");stats.Eggs.Star=0
    cells[1].bee.Traits={};check(not M.unlocked(history,stats,cells,44),"All six gifted Legendary goals required");cells[1].bee.Traits={"Gifted"}
    local d={discoveryPreparation=true,queueMaterialsReady=true,reservedItems={}}
    check(M.plan(stats,cells,types,{}).kind=="wait","Preparation flag required")
    d.queueMaterialsReady=false;check(M.plan(stats,cells,types,d).kind=="wait","All queued gear materials required");d.queueMaterialsReady=true
    check(M.plan(stats,cells,types,d).kind=="acquire","No normal Mythic requests ordinary safe-slot acquisition")
    for _,name in ipairs(M.order)do
        local h=clone(cells);h[#h+1]={x=7,y=1,bee={Type=name,Traits={},Birth=100}}
        local s=clone(stats);for _,other in ipairs(M.order)do if other~=name then s.DiscGiftTypes[#s.DiscGiftTypes+1]=types[other].ID end end
        local item=M.fruit[name];s.Eggs[item]=4000
        local a=M.plan(s,h,types,d)
        check(a.kind=="feed" and a.name==name and a.item==item and a.amount==2000,"Correct2000 favorite fruit for "..name)
        s.Eggs[item]=37;check(M.plan(s,h,types,d).amount==37,"Final fruit remainder is fed before Star Treat fallback");s.Eggs[item]=4000
        local reserve={discoveryPreparation=true,queueMaterialsReady=true,reservedItems={[item]=2500}}
        check(M.plan(s,h,types,reserve).amount==1500,"Only the unreserved remainder may be consumed")
        s.Eggs[item]=0;s.Eggs.StarTreat=1
        a=M.plan(s,h,types,d)
        check(a.kind=="feed" and a.item=="StarTreat" and a.amount==1,"Owned Star Treat fallback for "..name)
        types.Photon={ID="PhotonId",Rarity="Event"};h[#h+1]={x=8,y=1,bee={Type="Photon",Traits={}}}
        check(M.plan(s,h,types,d).kind=="wait","Normal Event blocks Mythic Star Treat")
        s.Eggs[item]=2000
        check(M.plan(s,h,types,d).item==item,"Fruit remains available while Events need gifts")
        h[#h].bee.Traits={"Gifted"};s.Eggs[item]=0
        check(M.plan(s,h,types,d).item=="StarTreat","All Event types gifted releases Mythic Star Treat")
    end
    stats.DiscGiftTypes={Spicy=true,[types.Vector.ID]=true,types.Precise.ID,"Tadpole","Buoyant","Fuzzy"}
    check(M.plan(stats,cells,types,d).kind=="complete","History accepts names IDs and boolean maps")
    stats.DiscGiftTypes=nil;check(M.plan(stats,cells,types,d).kind=="wait","Unknown discovery history blocks spending")
    local h={{x=1,y=1,bee={Type="Fuzzy",Traits={},Birth=5}},{x=2,y=1,bee={Type="Music",Traits={"Gifted"},Birth=6}}}
    local s={Eggs={Pineapple=2500},UnlockedCells=44,Honeycomb={x1={y1=clone(h[1].bee)},x2={y1=clone(h[2].bee)}}}
    local a={item="Pineapple",amount=2000,name="Fuzzy",x=1,y=1}
    local b=M.feedBaseline(s,h,a);s.Eggs.Pineapple=500
    local ok,n=M.validateFeed(b,500,true,s.Honeycomb,s)
    check(ok and n==2000,"Full fruit feed receipt validates")
    local wrong=clone(s.Honeycomb);wrong.x1.y1.Type="Vector"
    check(not M.validateFeed(b,500,true,wrong,s),"Conflicting response comb stays unresolved")
    s.Honeycomb.x1.y1.Type="Spicy";check(not M.validateFeed(b,500,true,s.Honeycomb,s),"Feeding never changes bee type");s.Honeycomb.x1.y1.Type="Fuzzy"
    s.Honeycomb.x2.y1.Traits={};check(not M.validateFeed(b,500,true,s.Honeycomb,s),"Other gifted bees remain protected");s.Honeycomb.x2.y1.Traits={"Gifted"}
    check(not M.validateFeed(b,500,false,s.Honeycomb,s),"Rejected feeding is unresolved")
    s.Eggs.Pineapple=2499
    check(not M.validateFeed(b,2499,true,s.Honeycomb,s),"Partial feed without gift is unresolved")
    s.Honeycomb.x1.y1.Traits={"Gifted"}
    check(M.validateFeed(b,2499,true,s.Honeycomb,s),"Server early stop on gifted outcome is accepted")
    s.Eggs.StarTreat=1;a.item="StarTreat";a.amount=1;h[1].bee.Traits={};s.Honeycomb.x1.y1.Traits={}
    b=M.feedBaseline(s,h,a);s.Eggs.StarTreat=0
    check(not M.validateFeed(b,0,true,s.Honeycomb,s),"Star Treat requires a confirmed gift")
    s.Honeycomb.x1.y1.Traits={"Gifted"};check(M.validateFeed(b,0,true,s.Honeycomb,s),"Star Treat gift receipt validates")
    s.Honeycomb.x1.y1.Birth=99;check(not M.validateFeed(b,0,true,s.Honeycomb,s),"Same-coordinate replacement cannot validate a feed")
    check(M.eventsGifted({{bee={Type="Cobalt",Traits={}}}},{Cobalt={Rarity="Event"}}),"Excluded Cobalt cannot stall Mythic Star Treat fallback")
    check(not M.eventsGifted({{bee={Type="Tabby",Traits={}}}},{Tabby={Rarity="Event"}}),"Other Events retain first priority for Star Treats")
    return {passed=passed}
end
