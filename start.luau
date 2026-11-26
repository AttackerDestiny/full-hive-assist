-- Feather loader v1.3.1. Download and compile before a safe runtime handoff.
local env=(type(getgenv)=="function" and getgenv()) or _G
if env.FullHiveLoaderBusy or env.FullHiveReloadBusy then
    warn("[Feather] A script reload is already in progress")
    return
end
env.FullHiveLoaderBusy=true
local ok,chunk=pcall(function()
    local compile=loadstring or load
    assert(type(compile)=="function","Executor does not expose loadstring/load")
    local source=game:HttpGet("https://raw.githubusercontent.com/AttackerDestiny/full-hive-assist/main/core.luau?reload="..tostring(os.time()),true)
    local header="-- Full Hive Assist for Atlas / Arceus X Android / Potassium."
    assert(type(source)=="string" and source:sub(1,#header)==header,"Downloaded content is not the Feather bundle")
    return assert(compile(source))
end)
env.FullHiveLoaderBusy=nil
assert(ok,"Cannot load Feather: "..tostring(chunk))
return chunk()
