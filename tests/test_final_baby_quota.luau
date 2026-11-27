-- Pure final-stage task decisions only; never invokes a game workflow/remote.
return function(P,T)
    local passed=0
    local function check(v,m) assert(v,m);passed+=1 end
    local function add(cells,name,count,gifted)
        for _=1,count do
            local n=#cells
            cells[n+1]={x=n%5+1,y=math.floor(n/5)+1,bee={Type=name,Traits=gifted and {"Gifted"} or {}}}
        end
    end
    local function plan(cells) return P.plan(cells,T,{slots=50,starUsed=2,jelly=500000,lateStarted=true,questRetired={Shy=true}}) end
    -- Fully satisfied final recipe except for one surplus Baby, exactly50 bees.
    do
        local cells={}
        for _,name in ipairs(P.trueSingles) do add(cells,name,1,true) end
        add(cells,"Diamond",3,true);add(cells,"Music",1,true);add(cells,"Music",3,false)
        for _,name in ipairs({"Tabby","Gummy","Vicious","Puppy","Festive"}) do add(cells,name,1,true) end
        add(cells,"Fuzzy",1,true);add(cells,"Tadpole",4,true);add(cells,"Tadpole",6,false)
        add(cells,"Buoyant",1,true);add(cells,"Buoyant",16,false);add(cells,"Baby",1,false);add(cells,"Frosty",1,true)
        local p=plan(cells);local target=p.target
        check(#cells==50 and p.babyGoal==0 and #p.needs==0 and p.reason=="final-surplus"
            and target and target.bee.Type=="Baby","Counterexample is a valid 50-bee final Baby cleanup")
        local task=P.startRollTask(target,cells,p);task.Rolled=true
        target.bee={Type="Baby",Traits={"Gifted"}};p=plan(cells)
        check(not p.keep[P.key(target)],"Zero Baby quota leaves the new gifted Baby unkept")
        check(not P.rollTaskDone(task,target,cells,T,p),"Zero Baby quota must not finish on a gifted Baby")
        check(P.rollTaskSafe(task,target,cells,T,p),"Unwanted gifted Baby remains safe on the active coordinate")
    end
    local function fixture(goal,babies,giftedBabies)
        local cells={}
        add(cells,"Tadpole",4-goal,true);add(cells,"Tadpole",6+goal,false)
        add(cells,"Baby",giftedBabies,true);add(cells,"Baby",babies-giftedBabies,false)
        while #cells<50 do add(cells,"Frosty",1,false) end
        local p=plan(cells);local target=p.target
        assert(target and target.bee.Type~="Baby","Expected an unkept filler for this test")
        return cells,target,p
    end
    for goal=0,4 do
        for _,gifted in ipairs({false,true}) do
            local cells,target,p=fixture(goal,goal,goal)
            local task=P.startRollTask(target,cells,p);task.Rolled=true
            target.bee={Type="Baby",Traits=gifted and {"Gifted"} or {}};p=plan(cells)
            check(p.babyGoal==goal,"Final Baby goal follows the fresh gifted Tadpole count")
            check(not P.rollTaskDone(task,target,cells,T,p),"Surplus normal/gifted Baby cannot finish above quota "..goal)
            check(P.rollTaskSafe(task,target,cells,T,p),"Surplus Baby can be rerolled above quota "..goal)
            task.Goals={{name="Baby",gifted=gifted,before=0,target=8}}
            check(not P.rollTaskDone(task,target,cells,T,p),"Stale stored Baby goal cannot override the fresh quota "..goal)
        end
        if goal>0 then
            local cells,target,p=fixture(goal,goal,goal-1)
            local task=P.startRollTask(target,cells,p);task.Rolled=true
            target.bee={Type="Baby",Traits={"Gifted"}};p=plan(cells)
            check(P.rollTaskDone(task,target,cells,T,p),"A useful gifted Baby can upgrade a normal copy at quota "..goal)
            check(not P.rollTaskSafe(task,target,cells,T,p),"Accepted gifted Baby upgrade is preserved at quota "..goal)
            cells,target,p=fixture(goal,goal-1,0)
            task=P.startRollTask(target,cells,p);task.Rolled=true
            target.bee={Type="Baby",Traits={}};p=plan(cells)
            check(P.rollTaskDone(task,target,cells,T,p),"Needed normal Baby can fill quota "..goal)
        end
    end
    for _,name in ipairs({"Baby","Music"}) do
        local cells={};add(cells,name,1,true);add(cells,"Honey",1,false)
        local p=P.plan(cells,T,{slots=43,starUsed=1,jelly=100,honey=1,collectorFallback=true})
        local target=cells[2];local task=P.startRollTask(target,cells,p);task.Rolled=true
        target.bee={Type=name,Traits={"Gifted"}}
        p=P.plan(cells,T,{slots=43,starUsed=1,jelly=100,honey=1,collectorFallback=true})
        check(P.rollTaskDone(task,target,cells,T,p),"Mid-stage gifted "..name.." upgrade remains useful")
        check(not P.rollTaskSafe(task,target,cells,T,p),"Mid-stage gifted "..name.." upgrade stays protected")
    end
    return {passed=passed}
end
