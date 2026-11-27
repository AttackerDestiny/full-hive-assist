return function(runtime)
    local source=assert(runtime:match("(local function atlasAccess%(callback,%.%.%.%).-)\nlocal function uiParent"))
    local make=assert(loadstring("return function(getthreadidentity,setthreadidentity,getidentity,setidentity) "..source.." return atlasAccess end"))()
    local n=0
    local function check(v,m)assert(v,m);n+=1 end
    local identity=2;local setterCalls={}
    local access=make(function()return identity end,function(id)identity=id;setterCalls[#setterCalls+1]=id end)
    local a,b,c=access(function(value)
        check(identity==8,"Protected Atlas Instance lookup runs with executor UI identity")
        identity=5 -- model a called closure changing the thread context
        return value,nil,"callback"
    end,"button")
    check(a=="button"and b==nil and c=="callback","Preserves callback return tuple including nils")
    check(identity==2 and setterCalls[1]==8 and setterCalls[2]==2,"Restores original identity after callback drift")
    local token={};local ok,err=pcall(access,function()identity=5;error(token,0)end)
    check(not ok and err==token and identity==2,"Restores identity on errors and preserves recovery tokens")
    local mutations=0
    local blocked=make(function()return 2 end,function()error("unavailable")end)
    ok=pcall(blocked,function()mutations+=1 end)
    check(not ok and mutations==0,"Unavailable UI capability cannot execute a callback")
    local unavailable=make(function()error("unavailable")end,function()mutations+=1 end)
    check(not pcall(unavailable,function()mutations+=1 end) and mutations==0,"Unknown original identity fails closed")
    local compatible=make(nil,nil,nil,nil)
    check(compatible(function()return "legacy"end)=="legacy","Executors without identity API retain existing behavior")
    local alias=make(nil,nil,function()return identity end,function(id)identity=id end)
    check(alias(function()return identity end)==8 and identity==2,"Supports alternate executor identity API names")
    access(function()
        check(identity==8,"Outer scope enters executor identity")
        access(function()identity=5 end)
        check(identity==8,"Nested callback restores outer executor identity")
    end)
    check(identity==2,"Nested protected calls restore the original caller")
    local toggleSource=assert(runtime:match("(local function atlasToggle%(%)%s.-)\nlocal atlasState"))
    local toggle=assert(loadstring("return function(atlasAccess,atlasToggleRaw) "..toggleSource.." return atlasToggle end"))()
    local button={};local cell={Cell={true},Key=1};local cb=function()end
    local call=toggle(access,function()
        if identity~=8 then error("The current thread cannot access 'Instance' (lacking capability Plugin)")end
        return button,cell,cb
    end)
    a,b,c=call()
    check(a==button and b==cell and c==cb and identity==2,"Actual Atlas lookup wrapper resolves low-identity Plugin capability failure")
    local setSource=assert(runtime:match("(local function setAtlas%(value%)%s.-)\nlocal function acquire"))
    local set=assert(loadstring("return function(atlasAccess,setAtlasRaw) "..setSource.." return setAtlas end"))()
    local flags={pending={},uncertain={},task={},batch={}}
    local before={pending=flags.pending,uncertain=flags.uncertain,task=flags.task,batch=flags.batch}
    local value
    set(access,function(on)check(identity==8,"Atlas toggle state checks run with protected UI access");value=on end)(false)
    check(value==false and identity==2,"Cleanup resumes Atlas with scoped access and restores caller")
    for k,v in pairs(before)do check(flags[k]==v,"Context helper never clears request task or batch state")end
    check(runtime:find('pcall(atlasAccess,callback)',1,true)~=nil,"Stop Everything callback restores its execution context")
    return {passed=n}
end
