-- Full Hive Assist loader v1.0.0. Loads the current main-branch bundle.
-- Load Atlas separately first. Existing FullHiveConfig options are preserved.
local env = (type(getgenv) == "function" and getgenv()) or _G
local function ready()
    if env.FullHiveRunning then
        warn("[Full Hive loader] Assist already running; left it unchanged")
        return false
    end
    assert(not env.AutoGiftedStarRunning, "Another hive assist is running")
    assert(not env.FullHivePending and not env.AutoHivePendingRequest,
        "A previous hive request is pending; do not retry")
    assert(not env.FullHiveUncertain,
        "An earlier hive mutation needs reconciliation; do not retry")
    return true
end
if not ready() then return end

local compile = loadstring or load
assert(type(compile) == "function", "Executor does not expose loadstring/load")
local url = "https://raw.githubusercontent.com/AttackerDestiny/full-hive-assist/main/auto_full_hive_assist.luau"
local ok, source = pcall(function() return game:HttpGet(url) end)
assert(ok, "Cannot download Full Hive Assist: " .. tostring(source))
local header = "-- Full Hive Assist for Atlas / Arceus X Android / Potassium."
assert(type(source) == "string" and source:sub(1, #header) == header,
    "Downloaded content is not the Full Hive Assist bundle")
local chunk, err = compile(source)
assert(chunk, "Cannot compile Full Hive Assist: " .. tostring(err))
if not ready() then return end -- HttpGet may yield while another workflow starts.
return chunk()
