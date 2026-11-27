return function(source,runtime)
    local passed=0
    local function check(v,m)assert(v,m);passed+=1 end
    local create=assert(loadstring("return function(typeof) "..source.." end"))()(function(v)
        return type(v)=="table"and v.fakeInstance and "Instance"or type(v)
    end)
    local function instance(name,class,parent)
        local v={Name=name,ClassName=class,Parent=parent,fakeInstance=true,labels={},children={}}
        function v:IsA(c)return self.ClassName==c end
        function v:FindFirstChild(key)return self.children[key]end
        function v:GetChildren()local out={};for _,x in pairs(self.children)do out[#out+1]=x end;return out end
        function v:QueryDescendants()return self.labels end
        function v:IsDescendantOf(root)local p=self.Parent;while p do if p==root then return true end;p=p.Parent end;return false end
        return v
    end
    local function fixture(mode)
        local core=instance("CoreGui","CoreGui",{})
        local window=instance("Window","Frame",core)
        local tabs=instance("TabButtons","Frame",window);window.children.TabButtons=tabs
        local buttons=instance("ScrollingFrame","ScrollingFrame",tabs);tabs.children.ScrollingFrame=buttons
        local folder=instance("Folder","Frame",window)
        local button=instance("Switch","TextButton",folder)
        local label=instance("Title","TextLabel",button);label.Text="Auto Progression"
        local config={prog=mode=="enabled"};local calls=0
        local cb=function()config.prog=false;calls+=1 end
        button.MouseButton1Click={{Function=cb}}
        local detached=instance("Tab","ScrollingFrame",nil);detached.labels={label}
        local nav=instance("Toys","TextButton",buttons);buttons.children.Toys=nav
        local navcb=function()end;nav.MouseButton1Click={{Function=navcb}}
        local values={[cb]={label.Text,"prog",config,button},[navcb]={detached,detached}}
        if mode=="visible"then window.labels={label};values[navcb]={}
        elseif mode=="duplicate"then window.labels={label}
        elseif mode=="missing"then detached.labels={}
        elseif mode=="unreadable"then values[cb]={}
        elseif mode=="ambiguous"then
            local b=instance("Switch2","TextButton",folder);local l=instance("Title","TextLabel",b);l.Text=label.Text
            local f=function()error("Must not toggle an ambiguous control")end
            b.MouseButton1Click={{Function=f}};values[f]={l.Text,"prog",{prog=false},b}
            window.labels={l}
        end
        local stats={};local now=0
        local worker=create({core=core,window=function()return window end,findLabels=function()return{}end,
            Stats=stats,Clock=function()return now end,upvalues=function(f)return values[f]or{}end,
            connections=function(signal)return signal end,activate=function(_,f)f();return true end})
        return worker,config,function()return calls end,window,detached,label,stats,function(v)now=v end
    end
    local worker,config,calls,window,tab,label,stats,time=fixture("visible")
    local ok,why,rows=worker(false)
    check(ok and #rows==1 and rows[1].Name=="Auto Progression","Visible control is discoverable while tab callback metadata is unavailable")
    check(calls()==0,"Discovery never mutates switches")
    check(worker(false)and stats.Controls.CacheHits==1,"Visible fallback validates cached window without a visible Stop label")
    config.prog=true
    check(not worker(false)and calls()==0,"Cached references still read current switch state")
    check(worker(true)and config.prog==false and calls()==1,"Existing verified callback disables exactly once")
    check(worker(true)and calls()==1,"Already disabled callbacks are not replayed")
    window.labels={};time(3)
    ok,why=worker(false)
    check(not ok and why=="Atlas Auto Progression control is unavailable","Missing control after cache expiry fails closed")
    worker=fixture("detached");ok,why,rows=worker(false)
    check(ok and #rows==1,"Detached tab control remains discoverable")
    worker=fixture("duplicate");ok,why,rows=worker(false)
    check(ok and #rows==1,"Same visible/detached control is deduplicated")
    worker,config,calls=fixture("ambiguous");ok,why=worker(true)
    check(not ok and why=="Ambiguous Atlas Auto Progression control"and calls()==0,"Two distinct progression controls fail closed before activation")
    worker=fixture("unreadable");ok,why=worker(false)
    check(not ok and why=="Cannot verify Atlas switch: Auto Progression","Unverified callback state cannot be treated as disabled")
    worker,config,calls,window,tab,label=fixture("missing");ok,why=worker(true)
    check(not ok and calls()==0,"Partially loaded Atlas sends no activation")
    tab.labels={label}
    check(worker(false),"Next fresh discovery succeeds when control finishes loading")
    -- Exercise the actual acquire failure boundary with a scoped UI call.
    local acquireSource=assert(runtime:match("(local function acquire%(%).-)\nlocal function move"))
    local make=assert(loadstring('return function(env,Report,guard,leased) local Config={AutoProgression=true,AtlasInitiallyStopped=false};local ATLAS_UNAVAILABLE={};local atlasFarmOnly=guard;local access=0;local previousAtlas,previousSettings;local Cache={Get=function()return {Settings={}}end};local function checkStop()end;local function assertAtlasPaused()end;local function atlasControl()return {},{}end;local function readAtlasState()return false end;local function setAtlas(v)env.FullHiveAtlasOwned=v end;local function atlasAccess(f,...)access+=1;return f(...)end;'
        ..acquireSource..' return acquire,ATLAS_UNAVAILABLE,function()return leased,access end end'))()
    for _,held in ipairs({false,true})do
        local env={};local report={}
        local acquire,token,state=make(env,report,function()return false,"Atlas Auto Progression control is unavailable"end,held)
        local success,err=pcall(acquire)
        check(not success and err==token and report.AtlasControlError:find("Auto Progression",1,true),"Missing spender control enters recoverable path with or without a current lease")
        local retained,count=state()
        check(retained and count==1,"Control inspection runs through scoped UI access")
    end
    for _,flag in ipairs({"FullHivePending","AutoHivePendingRequest","FullHiveUncertain","AutoHiveUncertain","FullHiveStarRunning","AutoGiftedStarRunning"})do
        local marker={};local env={[flag]=marker};local report={}
        local acquire,token=make(env,report,function()return false,"missing"end,false)
        local ok,err=pcall(acquire)
        check(not ok and err~=token and env[flag]==marker,"Unresolved state prevents automatic retry: "..flag)
    end
    local branch=assert(runtime:match("(        if err==ATLAS_UNAVAILABLE then.-)\n        if err==PAUSE_REQUESTED then"))
    local recover=assert(loadstring('return function(env,Report,blocked,failCleanup) local ATLAS_UNAVAILABLE={};local err=ATLAS_UNAVAILABLE;local leased=true;local released,waits=0,0;local function release()released+=1;if not failCleanup then leased=false;env.FullHiveAtlasOwned=false else Report.CleanupError="release failed"end end;local function waitFor()waits+=1 end;local once=true;while once do once=false;'
        ..branch..' end;return released,waits end'))()
    local lease,batch={},{};local env={FullHiveRollTask=lease,FullHiveJellyBatch=batch,FullHiveAtlasOwned=true}
    local released,waits=recover(env,{})
    check(released==1 and waits==1 and not env.FullHiveAtlasOwned,"Actual readiness recovery releases Atlas before waiting")
    check(env.FullHiveRollTask==lease and env.FullHiveJellyBatch==batch,"Unsent UI recovery preserves exact active task and admission")
    check(not pcall(recover,{FullHiveAtlasOwned=true},{},nil,true),"Failed cleanup prevents automatic resume")
    for _,flag in ipairs({"FullHivePending","AutoHivePendingRequest","FullHiveUncertain","AutoHiveUncertain","FullHiveStarRunning","AutoGiftedStarRunning"})do
        local marker={};local blocked={[flag]=marker,FullHiveRollTask=lease,FullHiveJellyBatch=batch}
        check(not pcall(recover,blocked,{})and blocked[flag]==marker and blocked.FullHiveRollTask==lease and blocked.FullHiveJellyBatch==batch,"Recovery retains every unresolved flag: "..flag)
    end
    return {passed=passed}
end
