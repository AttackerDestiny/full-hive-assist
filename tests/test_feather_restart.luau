return function(R,loader)
    local passed=0
    local function check(v,m)assert(v,m);passed+=1 end
    local function run(env,tick)
        local now=0
        return pcall(R.prepare,env,function()return now end,function(dt)now+=dt;if tick then tick(env,now)end end)
    end
    local task={x=2,y=3};local batch={remaining=9}
    local e={FullHiveRunning=true,FullHiveReport={},FullHiveRollTask=task,FullHiveJellyBatch=batch}
    local ok,token=run(e,function(env)if env.FullHiveStop then env.FullHiveRunning=false end end)
    check(ok and e.FullHiveStartPaused==false and e.FullHiveStop,"Active run stops cleanly without becoming a user pause")
    check(e.FullHiveRollTask==task and e.FullHiveJellyBatch==batch,"Restart preserves task and admission")
    check(e.FullHiveReloadBusy==token,"Handoff remains serialized until new run is registered")
    R.finish(e,token);check(not e.FullHiveReloadBusy,"New execution releases restart lock")
    for _,kind in ipairs({"pause","stop"})do
        e={FullHiveRunning=true,FullHiveStop=kind=="stop",FullHiveReport={PauseRequested=kind=="pause"}}
        ok,token=run(e,function(env)env.FullHiveRunning=false end)
        check(ok and e.FullHiveStartPaused,"Intentional stop/pause survives restart")
        R.finish(e,token)
    end
    e={FullHiveReport={},FullHivePending={Name="read"}}
    ok,token=run(e,function(env)env.FullHivePending=nil end)
    check(ok,"Original read may complete before restart")
    R.finish(e,token)
    e={FullHiveReport={},FullHivePending={}}
    ok,token=run(e,function(env)env.FullHivePending=nil;env.FullHiveReport.PauseRequested=true end)
    check(ok and e.FullHiveStartPaused,"A user pause while waiting is preserved")
    R.finish(e,token)
    for _,flag in ipairs({"FullHivePending","AutoHivePendingRequest","FullHiveUncertain","AutoHiveUncertain","FullHiveStarRunning","AutoGiftedStarRunning","FullHiveAtlasOwned","FullHiveReloadBusy"})do
        local request={};e={[flag]=request,FullHiveReport={}}
        ok=run(e)
        check(not ok and e[flag]==request,"Unresolved state blocks restart without being cleared: "..flag)
        if flag~="FullHiveReloadBusy"then check(not e.FullHiveReloadBusy,"Rejected restart unlocks its own handoff")end
    end
    e={FullHiveRunning=true,FullHiveReport={}}
    ok=run(e)
    check(not ok and e.FullHiveRunning and not e.FullHiveReloadBusy,"An unclean stop cannot launch a duplicate")
    e={FullHiveReport={CleanupError="failed"}}
    check(not run(e),"Failed cleanup blocks restart")
    e={FullHivePending={},FullHiveReport={}}
    ok=run(e,function(env)env.FullHivePending=nil;env.AutoGiftedStarRunning=true end)
    check(not ok and e.AutoGiftedStarRunning and not e.FullHiveStop,"New Star work during pending wait is not interrupted")
    if loader then
        local called,downloads,warnings=0,0,0
        e={FullHiveRunning=true}
        local downloadFail=false
        local make=assert(loadstring("return function(getgenv,game,loadstring,warn) "..loader.." end"))()
        local game={HttpGet=function(_,url,bypass)
            check(url:find("core.luau?reload=",1,true)~=nil and bypass==true,"Bundle download bypasses stale executor URL cache")
            downloads+=1
            if downloadFail then error("offline")end
            return "-- Full Hive Assist for Atlas / Arceus X Android / Potassium. mock"
        end}
        local function launch()
            return pcall(make,function()return e end,game,function()return function()called+=1 end end,function()warnings+=1 end)
        end
        check(launch()and called==1 and downloads==1,"Loader compiles and enters running-client restart path")
        check(not e.FullHiveLoaderBusy and e.FullHiveRunning,"Download does not stop the current client")
        e.FullHiveLoaderBusy=true
        check(launch()and called==1 and warnings==1,"Overlapping loader is ignored")
        e.FullHiveLoaderBusy=nil;downloadFail=true
        check(not launch()and called==1 and e.FullHiveRunning and not e.FullHiveLoaderBusy,"Failed download unlocks loader and leaves current run intact")
    end
    return {passed=passed}
end
