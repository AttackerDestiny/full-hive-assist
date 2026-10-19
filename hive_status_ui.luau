-- Status view only: the workflow owns movement, settings, and item requests.
local playerGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui", 30)
assert(playerGui, "PlayerGui unavailable")
local old = playerGui:FindFirstChild("AutoHiveStatus")
if old then old:Destroy() end
local gui = Instance.new("ScreenGui")
gui.Name = "AutoHiveStatus"
gui.ResetOnSpawn = false
gui.DisplayOrder = 100
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui
local panel = Instance.new("Frame")
panel.Size = UDim2.fromOffset(350, 380)
panel.Position = UDim2.fromOffset(16, 70)
panel.BackgroundColor3 = Color3.fromRGB(24, 28, 38)
panel.BorderSizePixel = 0
panel.Parent = gui
local corner = Instance.new("UICorner", panel)
corner.CornerRadius = UDim.new(0, 12)
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -85, 0, 44)
title.Position = UDim2.fromOffset(14, 0)
title.BackgroundTransparency = 1
title.Text = "Bee Hive • Status"
title.Font = Enum.Font.GothamBold
title.TextSize = 17
title.TextColor3 = Color3.fromRGB(255, 218, 108)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Active = true
title.Parent = panel
local body = Instance.new("TextLabel")
local scroll = Instance.new("ScrollingFrame")
scroll.Position = UDim2.fromOffset(14, 50)
scroll.Size = UDim2.new(1, -28, 1, -116)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 4
scroll.CanvasSize = UDim2.new()
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.Parent = panel
body.Size = UDim2.new(1, -8, 0, 0)
body.AutomaticSize = Enum.AutomaticSize.Y
body.BackgroundTransparency = 1
body.TextColor3 = Color3.fromRGB(231, 235, 244)
body.TextSize = 14
body.Font = Enum.Font.Gotham
body.TextXAlignment = Enum.TextXAlignment.Left
body.TextYAlignment = Enum.TextYAlignment.Top
body.TextWrapped = true
body.Parent = scroll
local stop = Instance.new("TextButton")
stop.Position = UDim2.new(0, 14, 1, -51)
stop.Size = UDim2.new(1, -28, 0, 44)
stop.BackgroundColor3 = Color3.fromRGB(179, 65, 69)
stop.TextColor3 = Color3.new(1, 1, 1)
stop.Text = "Stop"
stop.Font = Enum.Font.GothamBold
stop.TextSize = 14
stop.Parent = panel
Instance.new("UICorner", stop).CornerRadius = UDim.new(0, 8)
local minimize = Instance.new("TextButton")
minimize.Position = UDim2.new(1, -50, 0, 0)
minimize.Size = UDim2.fromOffset(44, 44)
minimize.BackgroundTransparency = 1
minimize.TextColor3 = Color3.new(1, 1, 1)
minimize.Text = "−"
minimize.TextSize = 22
minimize.Parent = panel
local collapsed = false
local lastViewport
local function fitPanel()
    local camera = workspace.CurrentCamera
    if not camera then return end
    local topLeft, bottomRight = game:GetService("GuiService"):GetGuiInset()
    local viewport = camera.ViewportSize - topLeft - bottomRight
    if viewport.X <= 0 or viewport.Y <= 0 then return end
    local width = math.min(350, math.max(180, viewport.X - 24))
    local height = collapsed and 44 or math.min(380, math.max(170, viewport.Y - 24))
    panel.Size = UDim2.fromOffset(width, height)
    local x = math.clamp(panel.Position.X.Offset, 0, math.max(0, viewport.X - width))
    local y = math.clamp(panel.Position.Y.Offset, 0, math.max(0, viewport.Y - height))
    panel.Position = UDim2.fromOffset(x, y)
    lastViewport = camera.ViewportSize
end
minimize.Activated:Connect(function()
    collapsed = not collapsed
    fitPanel()
    scroll.Visible, stop.Visible = not collapsed, not collapsed
    minimize.Text = collapsed and "+" or "−"
end)
stop.Activated:Connect(function()
    env.AutoGiftedStarStop = true
    stop.Text = "Stopping after current request…"
    stop.Active = false
end)
local inputService = game:GetService("UserInputService")
local dragStart, origin, dragging
local connections = {}
connections[#connections + 1] = title.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging, dragStart, origin = input, input.Position, panel.Position
    end
end)
connections[#connections + 1] = inputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input == dragging) then
        local delta = input.Position - dragStart
        local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize
        local x, y = origin.X.Offset + delta.X, origin.Y.Offset + delta.Y
        if viewport then
            local topLeft, bottomRight = game:GetService("GuiService"):GetGuiInset()
            viewport = viewport - topLeft - bottomRight
            x = math.clamp(x, 0, math.max(0, viewport.X - panel.AbsoluteSize.X))
            y = math.clamp(y, 0, math.max(0, viewport.Y - panel.AbsoluteSize.Y))
        end
        panel.Position = UDim2.new(origin.X.Scale, x, origin.Y.Scale, y)
    end
end)
connections[#connections + 1] = inputService.InputEnded:Connect(function(input)
    if dragging and input == dragging then dragging = nil end
end)
gui.Destroying:Connect(function()
    for _, connection in ipairs(connections) do connection:Disconnect() end
end)
local function number(value)
    value = tonumber(value) or 0
    if value >= 1e9 then return string.format("%.2fB", value / 1e9) end
    if value >= 1e6 then return string.format("%.2fM", value / 1e6) end
    return tostring(math.floor(value))
end
task.spawn(function()
    fitPanel()
    while gui.Parent do
        if workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize ~= lastViewport then fitPanel() end
        local r = env.AutoGiftedStarReport or {}
        local pending = env.AutoHivePendingRequest
        local status = env.AutoGiftedStarError and "Stopped: error"
            or (r.DryRun and "Preview • no items used")
            or (not env.AutoGiftedStarRunning and "Finished")
            or (env.AutoGiftedStarStop and "Stopping") or (r.Phase or "Starting")
        local lines = {"Status: " .. status}
        if r.Activity then lines[#lines + 1] = r.Activity end
        if pending then lines[#lines + 1] = "Waiting for server: " .. pending.Name end
        lines[#lines + 1] = "Roll mode: " .. (r.RollMode or "—")
        lines[#lines + 1] = "Jelly: " .. number(r.RoyalJelly) .. "   Used: " .. number(r.JelliesUsed)
        lines[#lines + 1] = "Honey: " .. number(r.Honey) .. "   Refills: " .. number(r.Purchases)
        lines[#lines + 1] = "Star Eggs: " .. number(r.StarEggs) .. "   Used: " .. number(r.StarEggsUsed)
        if r.LastResult then
            local last = r.LastResult
            lines[#lines + 1] = "Last: " .. (last.Gifted and "Gifted " or "") .. last.Type
        end
        if r.Phase == "prepare" or r.DryRun then
            lines[#lines + 1] = "Missing gifted: " .. table.concat(r.Missing or {}, ", ")
        end
        if r.Phase == "rebuild" or r.DryRun then
            local needs = {}
            for _, need in ipairs(r.HoneyNeeds or {}) do
                needs[#needs + 1] = need.amount .. " " .. (need.gifted and "gifted " or "") .. need.type
            end
            lines[#lines + 1] = "Needed: " .. (#needs > 0 and table.concat(needs, ", ") or "none")
        end
        if env.AutoGiftedStarError then lines[#lines + 1] = env.AutoGiftedStarError end
        body.Text = table.concat(lines, "\n\n")
        if not env.AutoGiftedStarRunning then
            stop.Text = r.DryRun and "Preview complete" or "Stopped"
            stop.Active = false
        end
        task.wait(0.5)
    end
end)
