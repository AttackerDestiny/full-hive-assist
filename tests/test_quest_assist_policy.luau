return function(P)
 local n=0;local function check(v,m)assert(v,m);n+=1 end
 local function q(name,item,typ,current,goal,active)
  return{{name=name,key="active-instance",active=active~=false,tasks={{index=1,item=item,type=typ,current=current,goal=goal}}}}
 end
 check(#P.actions(q("Nature's Lessons","MagicBean","Use Items",0,1,false))==0,"Inactive quests never spend")
 check(#P.actions(q("Nature's Lessons","MagicBean","Use Items",1,1))==0,"Completed objective never spends")
 local a=P.actions(q("Nature's Lessons","MagicBean","Use Items",0,1));check(a[1].mode=="field","Magic Bean waits on field")
 check(P.duringSaving(a[1]),"Magic Bean objective may run while Star honey is being saved")
 check(P.duringSaving({mode="active"}),"Requested potions and dice are not starved by a savings wait")
 check(P.duringSaving({mode="coconut"}),"Field-bound Coconut uses may run during savings")
 check(not P.duringSaving({mode="own"}),"Ticket purchase remains in the paid action queue")
 check(not P.duringSaving({mode="toy"}),"Generator work is not moved into the passive consumable queue")
 a=P.actions(q("Forcefully Friendly","FieldDice","Use Items",6,10));check(a[1].remaining==4,"Only remaining dice requested")
 local reserve;a,reserve=P.actions(q("Hive Minded Bias","MoonCharm","Use Items",12,44))
 check(a[1].mode=="feed"and reserve.MoonCharm==32,"Pending quest food reserved before Moon generator")
 check(#P.actions(q("Hive Minded Bias","Basic","Use Items",0,44))==0,"No arbitrary feeding of eggs")
 check(#P.actions(q("Unlisted Quest","Oil","Use Items",0,1))==0,"Quest whitelist enforced")
 check(#P.actions(q("Beeternity","RedExtract","Donate To Wind Shrine",0,5))==0,"Donation is not potion use")
 a=P.actions(q("The Ways Of The Winds / The Wind And Its Ways","Gold","Donate To Wind Shrine",0,1))
 check(a[1].mode=="own","Gold objective only acquires egg, does not donate")
 a=P.actions(q("Beeternity",nil,"Catch Falling Coconuts",7,20));check(a[1].mode=="coconut"and a[1].remaining==13,"Coconut catch progress remains actual counter")
 for name,rules in pairs(P.rules)do for item,mode in pairs(rules)do
  local typ=mode=="toy"and"Use Toy"or mode=="own"and"Donate To Wind Shrine"or mode=="coconut"and"Catch Falling Coconuts"or"Use Items"
  local input=q(name,item,typ,0,3)
  if mode=="toy"then input[1].tasks[1].item=nil;input[1].tasks[1].toy=item end
  local rows=P.actions(input);check(#rows==1 and rows[1].mode==mode,"Requested objective mapped exactly")
  input[1].tasks[1].current=3;check(#P.actions(input)==0,"Mapped objective stops at completion")
 end end
 for quest,rule in pairs(P.hiveRules)do
  local function facts(current,active,tag,typ,goal)
   return{{name=quest,active=active~=false,tasks={{type=typ or"Collect Tokens",tag=tag or rule.tag,current=current,goal=goal or rule.goal}}}}
  end
  check(not P.hiveRetirements(facts(rule.goal-1),{})[rule.species],"Incomplete token objective retains forces")
  local retired,evidence=P.hiveRetirements(facts(rule.goal),{})
  check(retired[rule.species]and evidence[rule.species].reason=="token-objective","Exact completed token objective retires its normal species")
  check(P.hiveRetirements(facts(rule.goal+10),{})[rule.species],"Over-completed objective also qualifies")
  check(not P.hiveRetirements(facts(rule.goal,false),{})[rule.species],"Inactive progress without completion history is insufficient")
  check(not P.hiveRetirements(facts(rule.goal,true,"Honey"),{})[rule.species],"Other token types cannot retire a force")
  check(not P.hiveRetirements(facts(rule.goal,true,nil,"Use Items"),{})[rule.species],"Objective type must match")
  check(not P.hiveRetirements(facts(rule.goal,true,nil,nil,rule.goal+1),{})[rule.species],"Objective goal must match verified definition")
  check(not P.hiveRetirements(facts(math.huge),{})[rule.species],"Invalid progress fails closed")
  retired,evidence=P.hiveRetirements({}, {quest})
  check(retired[rule.species]and evidence[rule.species].reason=="completed-quest","Historical completed quest proves its token objective")
  check(not P.hiveRetirements({}, {quest.."0"})[rule.species],"Quest names match exactly")
 end
 local retired=P.hiveRetirements({}, {"Star Journey 1"})
 check(retired.Ninja and not retired.Shy,"Quest1 changes Ninja only")
 retired=P.hiveRetirements({}, {"Star Journey 2"})
 check(retired.Shy and not retired.Ninja,"Quest2 changes Shy only")
 check(next((P.hiveRetirements({},{})))==nil,"Unknown quest state preserves original forces")
 do
  local quests={{name="The Family Final",npc="Mother Bear",active=true,tasks={
   {index=1,type="Have Bees",level=8,current=14,goal=15},
   {index=2,type="Have Bees",level=9,current=4,goal=5}}}}
  local cells={{x=1,y=1,bee={Type="Puppy",Lvl=8,Bond=220000}},
   {x=2,y=1,bee={Type="Tabby",Lvl=8,Bond=349900}},
   {x=3,y=1,bee={Type="Frosty",Lvl=9,Bond=350100}}}
  local threshold=function(level)return level==9 and 350000 or 80000 end
  local treat=function()return 10 end
  local goal,bee=P.motherLevelTarget(quests,cells,threshold,treat,1.25)
  check(goal.index==2 and bee.x==2 and bee.treats==8,"Uses the highest unfinished level and cheapest bond deficit with bonuses")
  quests[1].tasks[2].current=5
  quests[1].tasks[1].current=15
  check(P.motherLevelTarget(quests,cells,threshold,treat,1.25)==nil,"Completed objectives consume no treats")
  quests[1].tasks[2].current=4;quests[1].npc="Other Bear"
  check(P.motherLevelTarget(quests,cells,threshold,treat,1.25)==nil,"Other NPCs do not authorize leveling")
 end
 return{passed=n}
end
