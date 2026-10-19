-- Serialized requests; an uncertain response must never trigger a duplicate spend.
assert(not env.AutoHivePendingRequest, "An earlier server request is still pending; wait before rerunning")
local function invokeServer(target, ...)
    assert(not env.AutoHivePendingRequest, "Another server request is pending")
    local args = table.pack(...)
    local request = {Name = target.Name, Started = os.clock()}
    env.AutoHivePendingRequest = request
    local finished, success, values = false, false, nil
    task.spawn(function()
        success, values = pcall(function()
            return table.pack(target:InvokeServer(table.unpack(args, 1, args.n)))
        end)
        finished = true
        if env.AutoHivePendingRequest == request then env.AutoHivePendingRequest = nil end
    end)
    local timeout = target.Name == "ConstructHiveCellFromEgg" and 180 or 60
    while not finished and os.clock() - request.Started < timeout do task.wait(0.1) end
    assert(finished, "Server response timed out: " .. target.Name .. "; stopped without retrying. Wait for pending request before rerunning.")
    assert(success, "Server request failed: " .. tostring(values) .. "; stopped without retrying")
    return table.unpack(values, 1, values.n)
end
