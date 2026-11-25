return function(M)
    local passed=0
    local function check(value,message) assert(value,message);passed+=1 end
    local current="Clover Field"
    local state={}
    local locked={}
    local changes=0
    local occupied=35
    local worker=M.new({state=state,get=function() return current end,
        occupied=function() return occupied end,
        set=function(field) current=field;changes+=1;return true end,
        allowed=function(route) return not locked[route.field] end})
    worker.update(false,{Strawberry=50})
    check(current=="Clover Field" and changes==0,"Disabled starts idle")
    worker.update(true,{Strawberry=50,Blueberry=100})
    check(current=="Strawberry Field" and state.previous=="Pine Tree Forest","Saves main field")
    worker.update(true,{Strawberry=1,Blueberry=100})
    check(current=="Strawberry Field" and changes==1,"Stays until whole deficit is met")
    worker.update(true,{Blueberry=100})
    check(current=="Pine Tree Forest" and state.previous=="Pine Tree Forest","Advances without losing original field")
    worker.update(true,{})
    check(current=="Pine Tree Forest" and state.previous==nil,"Completion returns to Pine Tree Forest")
    locked["Pine Tree Forest"]=true
    worker.update(true,{Blueberry=100,SunflowerSeed=20})
    check(current=="Sunflower Field","Skips inaccessible field")
    locked["Pine Tree Forest"]=nil
    worker.update(false,{SunflowerSeed=20})
    check(current=="Pine Tree Forest","Turning toggle off restores field")
    worker.update(true,{Pineapple=100})
    check(current=="Pineapple Patch","Pineapple mapping")
    current="Bamboo Field"
    worker.update(true,{Pineapple=99})
    worker.update(true,{})
    check(current=="Pine Tree Forest","Completion returns to Pine Tree Forest after a manual change")
    worker.update(true,{RoyalJelly=100,SoftWax=5})
    check(current=="Pine Tree Forest" and state.field==nil,"Other ingredients do not trigger fields")
    worker.update(true,{Strawberry=1})
    local resumed=M.new({state=state,get=function() return current end,
        occupied=function() return occupied end,
        set=function(field) current=field;return true end,allowed=function() return true end})
    resumed.restore()
    check(current=="Pine Tree Forest","Maintenance returns to Pine Tree Forest")
    for _,count in ipairs({0,1,14,15,16,35}) do
        occupied=count
        worker.update(true,{Strawberry=1})
        worker.update(true,{})
        check(current==(count<15 and "Blue Flower Field" or "Pine Tree Forest"),"Occupied boundary "..count)
    end
    occupied=14
    worker.update(true,{Strawberry=1})
    occupied=15
    worker.update(false,{})
    check(current=="Pine Tree Forest","Return uses fresh count after hatching")
    occupied=15
    worker.update(true,{Pineapple=1})
    occupied=14
    worker.restore()
    check(current=="Blue Flower Field","Cleanup uses fresh count after bee loss")
    check(M.returnRoute(nil)==nil and M.returnRoute(-1)==nil,"Unknown counts defer return")
    return {passed=passed}
end

