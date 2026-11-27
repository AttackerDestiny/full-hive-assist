return function(M,runtime)
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
    local before=changes;local snapshot=worker.snapshot(true,{Strawberry=50})
    check(snapshot.active and snapshot.currentField=="Strawberry Field"and snapshot.item=="Strawberry"and snapshot.remaining==50,"Read-only snapshot exposes confirmed field, fruit and deficit")
    check(changes==before,"Status snapshot never changes Atlas field")
    check(not worker.snapshot(false,{Strawberry=50}).active,"Disabled status cannot report active farming")
    current="Bamboo Field";check(not worker.snapshot(true,{Strawberry=50}).active,"Actual field mismatch is shown as waiting rather than successful farming")
    current="Strawberry Field"
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
    for _,count in ipairs({0,1,4,5,6,14,15,16,35}) do
        occupied=count
        worker.update(true,{Strawberry=1})
        worker.update(true,{})
        check(current==(count<5 and "Blue Flower Field" or count<15 and "Bamboo Field" or "Pine Tree Forest"),"Occupied boundary "..count)
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
    check(current=="Bamboo Field","Cleanup uses fresh count after bee loss")
    occupied=4
    worker.update(true,{Strawberry=1})
    occupied=5
    locked["Bamboo Field"]=true
    worker.restore()
    check(current=="Strawberry Field" and state.previous~=nil,"Locked Bamboo defers return")
    locked["Bamboo Field"]=nil
    worker.restore()
    check(current=="Bamboo Field" and state.previous==nil,"Unlocked Bamboo returns using fresh count")
    check(M.returnRoute(nil)==nil and M.returnRoute(-1)==nil,"Unknown counts defer return")
    local options={}
    local function node(children)return {FindFirstChild=function(_,name)return children[name]end}end
    check(M.fieldOptions({Parent=node({Frame=node({ScrollingFrame=options})})})==options,"Actual Atlas dropdown hierarchy")
    check(M.fieldOptions({Parent=node({Box=node({Objects=options})})})==options,"Legacy dropdown hierarchy")
    check(M.fieldOptions({Parent=node({})})==nil,"Missing dropdown stays unavailable")
    local failedState={};local succeeds=false
    local retry=M.new({state=failedState,occupied=function()return 6 end,get=function()return "Bamboo Field"end,
        allowed=function()return true end,set=function()return succeeds end})
    retry.update(true,{SunflowerSeed=1})
    check(failedState.field==nil and failedState.error~=nil,"Failed switch never reports active farming")
    succeeds=true;retry.update(true,{SunflowerSeed=1})
    check(failedState.field=="Sunflower Field" and failedState.error==nil,"Failed switch retries and verifies")
    do
        local function button(text,parent)
            return {Text=text,Parent=parent,IsA=function(_,class)return class=="TextButton"end}
        end
        local function folder(title)
            local f={Name="Folder"};local h=button(title,f)
            f.GetChildren=function()return {h}end
            return f
        end
        local farming=folder("   Farming");local quests=folder("   Auto Quest")
        local main=button("   Field: Pine Tree Forest",{Parent=farming})
        local other=button("   Field: Strawberry Field",{Parent=quests})
        local root={QueryDescendants=function()return {other,main}end}
        check(M.mainFieldControl({root})==main,"Main Farming selector wins over unrelated Field controls")
        check(M.mainFieldControl({root,root})==main,"Repeated visible and detached roots deduplicate")
        check(M.mainFieldControl({{QueryDescendants=function()return {other}end}})==nil,"Unrelated selector alone never substitutes for main field")
        local second=button("Field: Bamboo Field",{Parent=folder("Farming")})
        check(M.mainFieldControl({{QueryDescendants=function()return {main,second}end}})==nil,"Two actual main controls remain ambiguous")
        check(M.mainFieldControl({{QueryDescendants=function()return {}end},root})==main,"Detached Farming tab remains discoverable")
        main.Text="Field: Sunflower Field"
        check(M.isMainField(main),"Main control stays valid after switching")
        main.Parent=nil
        check(not M.isMainField(main),"Detached or destroyed control cannot remain cached")
    end
    if runtime then
        local body=assert(runtime:match("set=function%(field%)(.-)\n        end,\n        allowed"))
        local factory=assert(loadstring("return function(MaterialFarm,fieldControl,fieldAccess,getconnections,task,os) local function set(field) "..body.." end return set end"))()
        local control={Text="Field: Bamboo Field"}
        local sunflower={Text="       Sunflower Field",IsA=function()return true end}
        local bamboo={Text="   Bamboo Field",IsA=function()return true end}
        local objects={GetChildren=function()return {sunflower,bamboo}end}
        control.Parent=node({Frame=node({ScrollingFrame=objects})})
        local listeners=1
        local set=factory(M,function()return control end,function(fn)return fn()end,
            function(signal)
                local rows={}
                for _=1,listeners do rows[#rows+1]={Fire=function()control.Text="Field: "..(signal==sunflower and "Sunflower Field" or "Bamboo Field")end}end
                return rows
            end,{wait=function()end},{clock=function()return 0 end})
        sunflower.MouseButton1Click=sunflower;bamboo.MouseButton1Click=bamboo
        check(set("Sunflower Field") and control.Text=="Field: Sunflower Field","Actual setter fires and verifies the Sunflower option")
        check(set("Bamboo Field") and control.Text=="Field: Bamboo Field","Actual setter can restore the prior field")
        listeners=2
        check(not set("Sunflower Field") and control.Text=="Field: Bamboo Field","Ambiguous callbacks do not claim a switch")
        control.Parent=node({})
        check(not set("Sunflower Field"),"Actual setter handles missing options gracefully")
    end
    return {passed=passed}
end

