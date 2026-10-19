local e = (type(getgenv)=="function" and getgenv()) or _G
local report = e.FullHiveReport or {}
local result = {Account=game:GetService("Players").LocalPlayer.Name,
    Executor=type(identifyexecutor)=="function" and identifyexecutor() or "unknown",
    Running=e.FullHiveRunning, Stop=e.FullHiveStop, Version=e.FullHiveVersion,
    Pending=e.FullHivePending, StarPending=e.AutoHivePendingRequest,
    StarRunning=e.AutoGiftedStarRunning, AtlasOwned=e.FullHiveAtlasOwned}
result.Report={}
for _,key in ipairs({"Version","StartedAt","Phase","Activity","Error","CleanupError","AtlasPaused","Actions","RoyalJellyUsed","Honey","RoyalJelly","Slots","Stage","RollMode","RefillMode","LastResult","LastPurchase","ActiveTarget","RespawnRecoveries","CollectorFallback","SafeNonCollector","NormalRefillAmount","RefillAmount","JellyBatch"}) do
    result.Report[key]=report[key]
end
local s=game:GetService("ReplicatedStorage").Events.RetrievePlayerStats:InvokeServer()
result.Stats={Honey=s.Honey,RoyalJelly=s.Eggs.RoyalJelly,Star=s.Eggs.Star,Settings=s.Settings}
local counts,slots={},0
for _,col in pairs(s.Honeycomb or {}) do
    if type(col)=="table" then for _,bee in pairs(col) do
        if type(bee)=="table" and bee.Type then
            slots+=1
            local key=(table.find(bee.Traits or {},"Gifted") and "Gifted " or "")..bee.Type
            counts[key]=(counts[key] or 0)+1
        end
    end end
end
result.Stats.Slots=slots; result.Stats.Bees=counts
local controls={}
for _,label in ipairs(game:GetService("CoreGui"):QueryDescendants('TextLabel[Text = "Stop Everything"]')) do
    local b=label.Parent
    local row={Path=b:GetFullName()}
    local reader=(debug and debug.getupvalues) or getupvalues
    if type(getconnections)=="function" and type(reader)=="function" then
        local ok,connections=pcall(getconnections,b.MouseButton1Click)
        if ok then for _,c in ipairs(connections) do
            if type(c.Function)=="function" then
                local got,u=pcall(reader,c.Function)
                if got then for _,v in pairs(u) do
                    if type(v)=="table" and type(v[1])=="boolean" then row.Stopped=v[1] end
                end end
            end
        end end
    end
    controls[#controls+1]=row
end
result.Atlas=controls
local parent=type(gethui)=="function" and gethui() or game:GetService("CoreGui")
local gui=parent:FindFirstChild("FullHiveStatus")
if gui then
    local label=gui:FindFirstChildWhichIsA("TextLabel",true)
    result.StatusText=label and label.Text
    local panel=gui:FindFirstChild("StatusPanel")
    if panel then
        local brand=panel:FindFirstChild("FeatherBrand")
        local version=panel:FindFirstChild("VersionBadge")
        local view=panel:FindFirstChild("ViewHiveButton")
        result.UI={Brand=brand and brand.BrandTitle.Text,Version=version and version.Text,
            HasViewHiveButton=view~=nil,StatusVisible=panel.Visible}
    end
end
return result
