-- Serial handoff to a new execution. Never cancels a server request.
local R={}
function R.prepare(env,clock,wait)
    assert(not env.FullHiveReloadBusy,"A script restart is already in progress")
    local token={};env.FullHiveReloadBusy=token
    local ok,result=pcall(function()
        local old=env.FullHiveReport or {}
        local paused=env.FullHiveStop==true or old.PauseRequested==true
        assert(not env.FullHiveStarRunning and not env.AutoGiftedStarRunning,"Finish the Star Egg workflow before restarting")
        local deadline=clock()+190
        while env.FullHivePending or env.AutoHivePendingRequest do
            assert(clock()<deadline,"Restart blocked by a pending server request")
            wait(0.1)
        end
        assert(not env.FullHiveUncertain and not env.AutoHiveUncertain,"Restart blocked: an earlier mutation needs reconciliation")
        assert(not env.FullHiveStarRunning and not env.AutoGiftedStarRunning,"Star Egg work started while waiting; restart blocked")
        paused=paused or env.FullHiveStop==true or old.PauseRequested==true
        -- Prevent any new spend before asking the old main loop to clean up.
        if env.FullHiveRunning then
            env.FullHiveStop=true
            deadline=clock()+20
            while env.FullHiveRunning do
                assert(clock()<deadline,"Old assist did not stop cleanly; restart blocked")
                wait(0.1)
            end
        end
        assert(not env.FullHivePending and not env.AutoHivePendingRequest
            and not env.FullHiveUncertain and not env.AutoHiveUncertain
            and not env.FullHiveStarRunning and not env.AutoGiftedStarRunning
            and not env.FullHiveAtlasOwned and not old.CleanupError,"Restart blocked by unresolved work or failed cleanup")
        env.FullHiveStartPaused=paused
        return token
    end)
    if not ok then
        if env.FullHiveReloadBusy==token then env.FullHiveReloadBusy=nil end
        error(result,0)
    end
    return result
end
function R.finish(env,token)
    assert(env.FullHiveReloadBusy==token,"Restart handoff changed")
    env.FullHiveReloadBusy=nil
end
return R
