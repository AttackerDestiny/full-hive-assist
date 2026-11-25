return function(S)
    local passed=0
    local function check(v,m) assert(v,m);passed+=1 end
    local disk,writes={},0
    local function host(userId)
        return {userId=userId,exists=function(path)return disk[path]~=nil end,
            read=function(path)return disk[path]end,write=function(path,value)writes+=1;disk[path]=value end,
            encode=function(value)return value end,decode=function(value)return value end}
    end
    local s=S.new(host(10))
    check(next(s.load())==nil,"First run uses defaults")
    check(s.save({Speed=80,SuperMaterialFarm=true,UseBlenderTickets=false,Pending={uncertain=true},Honey=9},false),"Preferences save")
    local doc=disk[s.path]
    check(doc.schema==1 and doc.userId==10,"Schema and account are recorded")
    check(doc.values.Pending==nil and doc.values.Honey==nil,"Progression and uncertainty excluded")
    local restored=S.new(host(10)).load()
    check(restored.Speed==80 and restored.SuperMaterialFarm and restored.UseBlenderTickets==false and restored.AssistEnabled==false,"Restart restores settings and pause")
    s.save({Speed=80,SuperMaterialFarm=true,UseBlenderTickets=false},false)
    check(writes==1,"Unchanged state is not rewritten")
    s.save({Speed=120,SuperMaterialFarm=false,UseBlenderTickets=true},true)
    check(writes==2 and S.new(host(10)).load().AssistEnabled,"Changes and resume persist")
    check(next(S.new(host(11)).load())==nil,"Accounts do not share settings")
    disk[s.path]={schema=1,userId=11,values={SuperMaterialFarm=true}}
    check(next(S.new(host(10)).load())==nil,"Wrong-account data rejected")
    disk[s.path]={schema=1,userId=10,values={Speed=900,SuperMaterialFarm="yes",AssistEnabled="no"}}
    restored=S.new(host(10)).load()
    check(restored.Speed==400 and restored.SuperMaterialFarm==nil and restored.AssistEnabled==nil,"Invalid types rejected and speed clamped")
    local h=host(10);h.decode=function()error("corrupt")end
    check(next(S.new(h).load())==nil,"Corrupt file retains defaults")
    h=host(10);h.write=function()error("disk failure")end;s=S.new(h)
    check(not s.save({Speed=60},true) and s.error~=nil,"Write errors are reported without terminating gameplay")
    h=host(10);h.read=nil;s=S.new(h)
    check(next(s.load())==nil and s.error~=nil,"Missing executor filesystem is graceful")
    h=host(10);h.exists=function()error("filesystem failure")end
    check(next(S.new(h).load())==nil,"Filesystem errors are contained")
    return {passed=passed}
end
