return function(P)
 local n=0;local function ok(v,m)assert(v,m);n+=1 end
 local function a(t,mods)return{Type=t,Mods=mods or{}}end
 local function m(t,v,p,op)return{Type=t,Value=v,Params=p,Op=op or"Add"}end
 local function ant(t,b,c,p,rate,attack)
  local mods={m("BaseProductionRate",rate or.5),m("PollenBonus",b,{Color="Blue"})}
  if c then mods[#mods+1]=m("CriticalChance",c)end;if p then mods[#mods+1]=m("CriticalPower",p)end
  if attack then mods[#mods+1]=m("BeeAttack",attack)end;return a(t.." Ant Amulet",mods)
 end
 ok(P.choose("King Beetle",nil,a("King Beetle Amulet",{})),"First King Beetle is accepted")
 ok(P.choose("King Beetle",a("King Beetle Amulet",{m("BaseProductionRate",1)}),a("King Beetle Amulet",{m("BaseProductionRate",.3),m("BeeAttack",1)})),"First global attack overrides conversion")
 ok(not P.choose("King Beetle",a("King Beetle Amulet",{m("BaseProductionRate",1)}),a("King Beetle Amulet",{m("BaseProductionRate",.3),m("BeeAttack",1,{Color="Blue"})})),"Colored attack is not global bee attack")
 ok(not P.choose("King Beetle",a("King Beetle Amulet",{m("BaseProductionRate",1)}),a("King Beetle Amulet",{m("BaseProductionRate",1)})),"Conversion tie keeps current")
 for _,crit in ipairs({"chance","power"})do
  local current=ant("Bronze",.05,nil,nil,.35)
  local new=ant("Silver",.05,crit=="chance"and.01 or nil,crit=="power"and.08 or nil,.45)
  ok(P.choose("Ant",current,new),"Either possible Silver crit meets corrected requirements")
 end
 ok(P.choose("Ant",ant("Bronze",0,nil,nil,.35),ant("Bronze",.01,nil,nil,.15)),"Same tier missing blue is repaired")
 ok(not P.choose("Ant",ant("Diamond",.18,.02,.3,.85),ant("Gold",.15,.02,.2,.8)),"Tier downgrade rejected")
 ok(P.choose("Ant",ant("Diamond",.1,.01,.2,.5),ant("Supreme",.15,nil,.3,.7)),"Higher incomplete fallback compares common percentage stats")
 ok(not P.choose("Ant",ant("Diamond",.1,.01,.2,.6),ant("Supreme",.11,nil,.2,.4)),"Worse fallback sum keeps current")
 ok(not P.choose("Ant",ant("Diamond",.18,.02,.3,.85),ant("Diamond",.17,.02,.4,.9)),"Blue wins over secondary improvements")
 ok(P.choose("Ant",ant("Diamond",.18,.01,.4,.9),ant("Diamond",.18,.02,.25,.8)),"Critical chance is second priority")
 ok(not P.choose("Ant",ant("Supreme",.2,.03,.4,.9,1),ant("Supreme",.3,.03,.5,1.1)),"Same Supreme cannot lose required attack")
 local function star(t,blue,pollen,pop)
  local mods={m("ContainerSpaceMultiplier",2,nil,"Mul"),m("PollenBonus",blue or.3,{Color="Blue"})}
  if pollen then mods[#mods+1]=m("PollenBonus",pollen)end
  if pop then mods[#mods+1]=m("PlayerAbility",1,{Ability="Pop Star"})end
  return a(t.." Star Amulet",mods)
 end
 for i,t in ipairs(P.tiers)do
  local threshold=P.requirements[i];local target=P.starTarget(threshold,nil)
  ok(target and target.price==P.prices[i]and target.rank==i,"Correct discovered threshold and fixed price")
  ok(P.choose("Star",nil,star(t,.3,.1,t=="Supreme")),"Required Star stats qualify")
  ok(not P.starTarget(threshold,star(t,.3,.1,t=="Supreme")),"Satisfied highest unlocked Star stops generation")
 end
 ok(not P.starTarget(4,nil),"Four gifted types do not unlock generation")
 ok(P.starTarget(40,nil).price==10000000000,"Supreme uses10B never500B")
 ok(P.rejectDualPrompt("Spend 500 billion honey to guarantee 2 passive abilities?"),"Exact optional500B prompt is declined")
 ok(not P.rejectDualPrompt("Equip the new amulet?"),"Unrelated confirmation is untouched")
 ok(not P.generated(3,4,"Supreme Star Amulet",{}),"Early toy counter cannot acknowledge a generator before its offer arrives")
 ok(P.generated(3,4,"Supreme Star Amulet",{{package={Type="Supreme Star Amulet",Mods={}}}}),"Counter plus exact generated offer acknowledges the request")
 ok(not P.generated(3,4,"Supreme Star Amulet",{{package={Type="Gold Star Amulet",Mods={}}}}),"An unrelated offer cannot acknowledge generation")
 ok(not P.generated(3,3,"Moon Amulet",{{package={Type="Moon Amulet",Mods={}}}}),"An old offer without a new use is insufficient")
 ok(not P.choose("Star",nil,star("Supreme",.7,.2,false)),"Supreme without PopStar rejected")
 ok(not P.choose("Star",nil,star("Gold",.3,nil,false)),"Gold without global pollen rejected")
 ok(not P.choose("Star",star("Diamond",.3,.1),star("Gold",.4,.2)),"Lower Star tier does not replace higher")
 local good=a("Moon Amulet",{m("ContainerSpace",250000),m("PollenValue",.02)})
 ok(P.moonGood(P.read(good)),"250k with honey per pollen stops")
 ok(not P.moonGood(P.read(a("Moon Amulet",{m("ContainerSpace",250000),m("PollenBonus",.1)}))),"Pollen is not honey per pollen")
 ok(P.choose("Moon",a("Moon Amulet",{m("ContainerSpace",200000)}),good),"Final Moon goal accepted")
 ok(not P.choose("Moon",good,a("Moon Amulet",{m("ContainerSpace",250000),m("PollenValue",.08)})),"Satisfied Moon stops even if another offer improves value")
 ok(P.choose("Moon",a("Moon Amulet",{m("ContainerSpace",25000)}),a("Moon Amulet",{m("ContainerSpace",30000)})),"Capacity rises before250k")
 ok(P.read({Type="bad",Mods={{Type="PollenBonus",Value=0/0}}})==nil,"Malformed stat fails closed")
 return{passed=n}
end
