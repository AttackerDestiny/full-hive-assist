$ErrorActionPreference = 'Stop'
function Read-Source([string]$Path) {
    [IO.File]::ReadAllText((Join-Path $PSScriptRoot $Path)).Replace("`r`n","`n")
}
function Replace-Once([string]$Source,[string]$Before,[string]$After) {
    if ([regex]::Matches($Source,[regex]::Escape($Before)).Count -ne 1) {
        throw "WindUI integration hook must match once: $Before"
    }
    return $Source.Replace($Before,$After)
}
$wind = Read-Source 'vendor/windui/main.lua'
# Drop trailing whitespace only in the upstream banner comment.
$wind = [regex]::Replace($wind,'\A--\[\[.*?\]\]',{param($banner) $banner.Value -replace '(?m)[ \t]+$',''},'Singleline')
$icons = Read-Source 'vendor/windui/icons.luau'
$adapter = Read-Source 'feather_wind_ui.luau'
$notice = (Read-Source 'vendor/windui/LICENSE')+"`n"+(Read-Source 'vendor/windui/ICONS-LICENSE')
$bootstrap = @'
local l="https://raw.githubusercontent.com/Footagesus/Icons/main/Main-v2.lua"

local m
if d:IsStudio()or not writefile then
m=a.load'b'
else
m=loadstring(
game.HttpGet and game:HttpGet(l)or h:GetAsync(l)
)()
end
'@ -replace "`r`n","`n"
$wind = Replace-Once $wind $bootstrap 'local m=createFeatherWindIcons()'
$wind = Replace-Once $wind 'local d=b(game:GetService"ReplicatedStorage":WaitForChild("GetIcons",99999):InvokeServer())' 'local d={} -- unused upstream icon fallback; never call a game remote'
# Track the global input and drag handlers in WindUI's existing cleanup list.
# The local alias `as` is declared after these hooks in the upstream bundle.
$wind = Replace-Once $wind 'an.InputBegan:Connect(function(ap,aq)' 'aa.Creator.AddSignal(an.InputBegan,function(ap,aq)'
$wind = Replace-Once $wind 'an.InputEnded:Connect(function(ap,aq)' 'aa.Creator.AddSignal(an.InputEnded,function(ap,aq)'
$wind = Replace-Once $wind 'e.InputChanged:Connect(function(M)' 'r.AddSignal(e.InputChanged,function(M)'
$wind = Replace-Once $wind 'e.InputEnded:Connect(function(M)' 'r.AddSignal(e.InputEnded,function(M)'
$cleanup = @'
for u,v in next,r.Signals do
local x=table.remove(r.Signals,u)
x:Disconnect()
end
'@ -replace "`r`n","`n"
$wind = Replace-Once $wind $cleanup 'for _,signal in ipairs(r.Signals) do signal:Disconnect() end; table.clear(r.Signals)'
@"
--[=[
$notice
]=]
local createFeatherWindIcons = (function()
    return function()
$icons
    end
end)()
local function loadFeatherWindUI(staging)
    -- Parent only this instance's GUI and keep optional executor file/config APIs disabled.
    local gethui = function() return staging end
    local writefile, readfile, isfile, makefolder, isfolder, gethwid, protectgui, syn
$wind
end
local FeatherWindUI = (function()
$adapter
end)()
"@ + "`n"
