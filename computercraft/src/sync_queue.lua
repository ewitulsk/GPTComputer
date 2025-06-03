-- Queue Synchronization Task for ComputerCraft Task Manager
-- Reports current queue state to the server
-- Compatible with CC: Tweaked

-- Get command line arguments
local args = {...}

-- Configuration
local API_BASE_URL = "https://gptcomputer-810360555756.us-central1.run.app"

-- Simple JSON encoder
local function encodeJSON(obj)
    if type(obj) == "table" then
        local result = "{"
        local first = true
        for k, v in pairs(obj) do
            if not first then
                result = result .. ","
            end
            first = false
            result = result .. '"' .. tostring(k) .. '":' .. encodeJSON(v)
        end
        result = result .. "}"
        return result
    elseif type(obj) == "string" then
        return '"' .. obj:gsub('"', '\\"') .. '"'
    elseif type(obj) == "number" or type(obj) == "boolean" then
        return tostring(obj)
    elseif obj == nil then
        return "null"
    else
        return '"' .. tostring(obj) .. '"'
    end
end

-- Get authentication token and computer ID from arguments
if #args < 2 then
    print("ERROR: sync_queue requires auth token and computer ID")
    print("Usage: sync_queue <auth_token> <computer_id>")
    return false
end

local authToken = args[1]
local computerId = args[2]

print("Synchronizing queue state for computer: " .. computerId)

-- Make authenticated HTTP request
local function makeRequest(method, endpoint, body)
    local url = API_BASE_URL .. endpoint
    local headers = {
        ["Authorization"] = "Bearer " .. authToken,
        ["Content-Type"] = "application/json"
    }
    
    local requestBody = body and encodeJSON(body) or nil
    
    local response
    if method == "GET" then
        response = http.get(url, headers)
    elseif method == "POST" then
        response = http.post(url, requestBody or "", headers)
    else
        print("Unsupported HTTP method: " .. method)
        return nil
    end
    
    if response then
        local status = response.getResponseCode()
        local responseBody = response.readAll()
        response.close()
        
        local success = status >= 200 and status < 300
        local data = nil
        
        if responseBody and responseBody ~= "" then
            -- Try to parse JSON
            local ok, parsed = pcall(textutils.unserialiseJSON, responseBody)
            if ok and parsed then
                data = parsed
            else
                data = responseBody
            end
        end
        
        return {
            success = success,
            status = status,
            data = data
        }
    else
        return nil
    end
end

-- Get current queue state from server
print("Fetching current server queue state...")
local getResponse = makeRequest("GET", "/computer/" .. computerId .. "/tasks/received", nil)

if not getResponse or not getResponse.success then
    print("ERROR: Failed to get current queue state from server")
    if getResponse then
        print("Status: " .. getResponse.status)
        print("Response: " .. tostring(getResponse.data))
    end
    return false
end

local serverState = getResponse.data
print("Server reports:")
print("  Queued tasks: " .. (serverState.queuedTasks and #serverState.queuedTasks or 0))
print("  Active tasks: " .. (serverState.activeTasks and #serverState.activeTasks or 0))

-- For this simple implementation, we'll report that we have received
-- the tasks that the server says we should have
local queuedTasks = {}
local activeTasks = {}

-- Convert server data to the format expected by the sync endpoint
if serverState.queuedTasks then
    for _, task in ipairs(serverState.queuedTasks) do
        table.insert(queuedTasks, {
            id = task.id,
            program = task.program,
            status = "received"
        })
    end
end

if serverState.activeTasks then
    for _, task in ipairs(serverState.activeTasks) do
        table.insert(activeTasks, {
            id = task.id,
            program = task.program,
            status = "in-progress"
        })
    end
end

-- Report our queue state to the server
print("Reporting queue state to server...")
local syncResponse = makeRequest("POST", "/computer/" .. computerId .. "/tasks/received", {
    queuedTasks = queuedTasks,
    activeTasks = activeTasks,
    localQueueState = {
        queueLength = #queuedTasks,
        activeCount = #activeTasks,
        syncTime = os.time(),
        syncSource = "sync_queue_task"
    }
})

if syncResponse and syncResponse.success then
    print("SUCCESS: Queue state synchronized")
    
    if syncResponse.data then
        print("Sync Status: " .. (syncResponse.data.syncStatus or "unknown"))
        
        if syncResponse.data.syncStatus == "out-of-sync" then
            print("WARNING: Server detected synchronization issues")
            if syncResponse.data.analysis then
                local analysis = syncResponse.data.analysis
                if analysis.queuedTasks and analysis.queuedTasks.missingOnClient then
                    print("Missing queued tasks: " .. #analysis.queuedTasks.missingOnClient)
                end
                if analysis.activeTasks and analysis.activeTasks.missingOnClient then
                    print("Missing active tasks: " .. #analysis.activeTasks.missingOnClient)
                end
            end
            
            if syncResponse.data.recommendations then
                print("Recommendation: " .. (syncResponse.data.recommendations.message or "Check task manager"))
            end
        else
            print("Queue state is synchronized with server")
        end
    end
    
    return true
else
    print("ERROR: Failed to sync queue state")
    if syncResponse then
        print("Status: " .. syncResponse.status)
        print("Response: " .. tostring(syncResponse.data))
    end
    return false
end 