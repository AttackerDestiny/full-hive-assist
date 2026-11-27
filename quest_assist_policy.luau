-- Only explicitly requested quest/objective pairs. Counts come from Quests.GetProgression.
local P={rules={
 ["Hive Minded Bias"]={MoonCharm="feed",Stinger="active",Enzymes="active",Oil="active"},
 ["Nature's Lessons"]={MagicBean="field"},["Beans Becoming"]={MagicBean="field"},
 ["Forcefully Friendly"]={FieldDice="active"},["A Breath Of Blue"]={BlueExtract="active",FieldDice="active"},
 ["Beeternity"]={RedExtract="active",Coconut="coconut"},
 ["The Ways Of The Winds / The Wind And Its Ways"]={CloudVial="field",Gold="own"},
 ["Do You Bee-lieve In Magic?"]={["Moon Amulet Generator"]="toy",["Sprout Summoner"]="toy",Honeystorm="toy"}
}}
local caps={MoonCharm=44,Stinger=4,Enzymes=1,Oil=1,MagicBean=1,FieldDice=10,CloudVial=3,Gold=1,RedExtract=5,BlueExtract=5,Coconut=20,
 ["Moon Amulet Generator"]=1,["Sprout Summoner"]=1,Honeystorm=1}
P.hiveRules={
 ["Star Journey 1"]={species="Ninja",tag="Haste",goal=2500},
 ["Star Journey 2"]={species="Shy",tag="Red Boost",goal=5000}
}
function P.hiveRetirements(quests,completed)
    local retired,evidence={},{}
    for _,name in ipairs(completed or{})do
        local rule=type(name)=="string"and P.hiveRules[name]
        if rule then retired[rule.species]=true;evidence[rule.species]={quest=name,reason="completed-quest",goal=rule.goal}end
    end
    for _,q in ipairs(quests or{})do
        local rule=P.hiveRules[q.name]
        if rule and q.active==true and not retired[rule.species]then
            for _,t in ipairs(q.tasks or{})do
                if t.type=="Collect Tokens"and t.tag==rule.tag and t.goal==rule.goal
                    and type(t.current)=="number"and t.current<math.huge and t.current>=rule.goal and t.current%1==0 then
                    retired[rule.species]=true
                    evidence[rule.species]={quest=q.name,reason="token-objective",current=t.current,goal=rule.goal}
                end
            end
        end
    end
    return retired,evidence
end
function P.actions(quests)
    local out={};local reserves={}
    for _,q in ipairs(quests or{})do
        local rule=P.rules[q.name]
        if rule and q.active==true then for _,t in ipairs(q.tasks or{})do
            local mode=rule[t.item or t.toy or(t.type=="Catch Falling Coconuts"and"Coconut")]
            if mode and type(t.current)=="number"and type(t.goal)=="number"and t.current>=0 and t.goal<math.huge and t.current%1==0
                and t.goal%1==0 and t.goal>t.current and t.current<(caps[t.item or t.toy or"Coconut"]or 0) then
                local item=t.item or t.toy or"Coconut"
                local matches=(mode=="toy"and t.type=="Use Toy")or(mode=="coconut"and t.type=="Catch Falling Coconuts")
                    or(mode=="own"and t.type=="Donate To Wind Shrine")or((mode=="active"or mode=="feed"or mode=="field")and t.type=="Use Items")
                if matches then
                    local left=math.ceil(math.min(t.goal,caps[item])-t.current)
                    out[#out+1]={quest=q.name,index=t.index,item=item,mode=mode,remaining=left,current=t.current,goal=t.goal,questKey=q.key}
                    if mode=="feed"then reserves[item]=math.max(reserves[item]or 0,left)end
                end
            end
        end end
    end
    return out,reserves
end
function P.duringSaving(a)
    return a and(a.mode=="field"or a.mode=="active"or a.mode=="coconut")or false
end

function P.motherLevelTarget(quests,cells,levelBond,treatValue,treatMultiplier)
    local objective
    for _,q in ipairs(quests) do
        if q.active and q.npc=="Mother Bear" then
            for _,t in ipairs(q.tasks) do
                if t.type=="Have Bees" and type(t.level)=="number" and t.level%1==0 and t.level>=2 and t.level<=10
                    and type(t.current)=="number" and type(t.goal)=="number" and t.goal<=50 and t.current<t.goal
                    and (not objective or t.level>objective.level) then
                    objective={quest=q.name,questKey=q.key,index=t.index,level=t.level}
                end
            end
        end
    end
    if not objective then return nil end
    local threshold=levelBond(objective.level)
    if type(threshold)~="number" or threshold<=0 then return nil end
    local best
    for _,c in ipairs(cells) do
        local bee=c.bee
        if type(bee.Lvl)=="number" and bee.Lvl<objective.level and type(bee.Bond)=="number" and bee.Bond>=0 then
            local bond=math.max(0,threshold-bee.Bond)
            local treats=math.max(1,math.ceil(bond/(treatValue(bee.Type)*treatMultiplier)))
            if not best or bond<best.bond or bond==best.bond and treats<best.treats then
                best={x=c.x,y=c.y,bee=bee,bond=bond,treats=treats}
            end
        end
    end
    if best then return objective,best end
end
function P.motherComplete(completed,quests)
    if type(completed)~="table" or type(quests)~="table" then return false end
    for _,q in ipairs(quests) do if q.npc=="Mother Bear" and q.active then return false end end
    return table.find(completed,"The Family Final")~=nil
end
function P.viciousTarget(complete,cells,owned,threshold,multiplier)
    if complete~=true or type(owned)~="number" or owned<0 or owned%1~=0
        or type(threshold)~="number" or threshold<=0 or threshold==math.huge
        or type(multiplier)~="number" or multiplier<=0 or multiplier==math.huge then return nil end
    local target
    for _,c in ipairs(cells) do if c.bee.Type=="Vicious" then
        if target then return nil end
        target=c
    end end
    local b=target and target.bee
    if not b or type(b.Lvl)~="number" or b.Lvl%1~=0 or b.Lvl<1 or b.Lvl>25
        or type(b.Bond)~="number" or b.Bond<0 or b.Bond==math.huge or not b.Birth then return nil end
    if b.Lvl>=12 then return {ready=true,x=target.x,y=target.y,bee=b} end
    if b.Bond>=threshold or owned<1 then return nil end
    return {x=target.x,y=target.y,bee=b,amount=math.min(owned,math.ceil((threshold-b.Bond)/(10*multiplier)))}
end
return P
