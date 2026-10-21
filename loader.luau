-- Full Hive Assist loader v1.1.0. Loads the current main-branch bundle.
-- Load Atlas separately first. Existing FullHiveConfig options are preserved.
-- Private repository: set env.FullHiveGitHubToken in your executor, not here.
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
local token = env.FullHiveGitHubToken
local source
if token ~= nil then
    assert(type(token) == "string" and token ~= "", "FullHiveGitHubToken must be a nonempty string")
    local http = request or http_request or (type(syn) == "table" and syn.request)
    assert(type(http) == "function", "Authenticated loading requires an executor HTTP request function")
    local ok, response = pcall(http, {
        Url = "https://api.github.com/repos/AttackerDestiny/full-hive-assist/contents/auto_full_hive_assist.luau?ref=main",
        Method = "GET",
        Headers = {Authorization = "Bearer " .. token, Accept = "application/vnd.github.raw+json",
            ["User-Agent"] = "FullHiveAssist-Loader"},
    })
    assert(ok and type(response) == "table", "Authenticated Full Hive download failed")
    assert(response.StatusCode == 200,
        "GitHub download failed (HTTP " .. tostring(response.StatusCode) .. "); check repository contents-read access")
    source = response.Body
else
    local ok, body = pcall(function() return game:HttpGet(url) end)
    assert(ok, "Cannot download Full Hive Assist. This repository is private; set FullHiveGitHubToken in your executor")
    source = body
end
local header = "-- Full Hive Assist for Atlas / Arceus X Android / Potassium."
assert(type(source) == "string" and source:sub(1, #header) == header,
    "Downloaded content is not the Full Hive Assist bundle")
local chunk, err = compile(source)
assert(chunk, "Cannot compile Full Hive Assist: " .. tostring(err))
if not ready() then return end -- HttpGet may yield while another workflow starts.
return chunk()
