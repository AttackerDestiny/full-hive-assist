-- Uses standard Roblox APIs; optional executor APIs are feature-detected.
local function loadModule(module)
    local ok, value = pcall(require, module)
    if ok then return value end
    local setIdentity = setthreadidentity or setidentity
    local getIdentity = getthreadidentity or getidentity
    if type(setIdentity) == "function" and type(getIdentity) == "function" then
        local gotIdentity, original = pcall(getIdentity)
        if gotIdentity then
            local changed = pcall(setIdentity, 2)
            if changed then
                ok, value = pcall(require, module)
                local restored = pcall(setIdentity, original)
                assert(restored, "Could not restore execution identity; stopping")
                if ok then return value end
            end
        end
    end
    error("Cannot load game module " .. module.Name .. ": " .. tostring(value), 0)
end
local function fencePartsUnder(root)
    if not root then return {} end
    local ok, result = pcall(function() return root:QueryDescendants("BasePart") end)
    if ok then return result end
    -- Compatibility fallback for runtimes without QueryDescendants. The root
    -- is only Map.Fences, never the whole game or workspace.
    local parts, queue = {}, {root}
    local index = 1
    while index <= #queue do
        local node = queue[index]
        index = index + 1
        for _, child in ipairs(node:GetChildren()) do
            if child:IsA("BasePart") then parts[#parts + 1] = child end
            queue[#queue + 1] = child
        end
    end
    return parts
end
