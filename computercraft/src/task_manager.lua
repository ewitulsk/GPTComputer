-- Task Manager for ComputerCraft
-- Polls server for tasks and executes them in parallel threads
-- Compatible with CC: Tweaked and Advanced Peripherals

-- Service configuration
local API_BASE_URL = "https://gptcomputer-810360555756.us-central1.run.app"

-- Global variables
local authToken = ""
local computerId = ""
local isRunning = false
local activeTasks = {}
local receivedTasks = {}  -- Local queue of received tasks

-- Simple JSON encoder/decoder (reused from other scripts)
local json = {}
local _json_encode_custom -- forward declare
local _json_decode_custom -- forward declare

if textutils and textutils.serialiseJSON then
    json.encode = function(obj)
        local success, result = pcall(textutils.serialiseJSON, obj)
        if success then
            return result
        else
            print("Warning: textutils.serialiseJSON failed: " .. tostring(result) .. ". Falling back to custom encoder.")
            return _json_encode_custom(obj) 
        end
    end
else
    print("Warning: textutils.serialiseJSON not found. Using custom JSON encoder.")
    json.encode = function(obj) return _json_encode_custom(obj) end
end

if textutils and textutils.unserialiseJSON then
    json.decode = function(str)
        local success, result = pcall(textutils.unserialiseJSON, str)
        if success then
            return result
        else
            -- For unJSON, if it's already nil or a non-string, pcall might return false.
            -- Only print warning if str was actually a string and failed.
            if type(str) == "string" and str ~= "" then
                print("Warning: textutils.unserialiseJSON failed for string: \'" .. str .. "\': " .. tostring(result) .. ". Falling back to custom decoder.")
            end
            return _json_decode_custom(str)
        end
    end
else
    print("Warning: textutils.unserialiseJSON not found. Using custom JSON decoder.")
    json.decode = function(str) return _json_decode_custom(str) end
end

_json_encode_custom = function(obj)
    if type(obj) == "table" then
        local result = "{"
        local first = true
        for k, v in pairs(obj) do
            if not first then
                result = result .. ","
            end
            first = false
            result = result .. '"' .. tostring(k) .. '":' .. json.encode(v)
        end
        result = result .. "}"
        return result
    elseif type(obj) == "string" then
        return '"' .. obj:gsub('"', '\\"'):gsub("\n", "\\n"):gsub("\r", "\\r") .. '"'
    elseif type(obj) == "number" or type(obj) == "boolean" then
        return tostring(obj)
    elseif obj == nil then
        return "null"
    else
        return '"' .. tostring(obj) .. '"'
    end
end

_json_decode_custom = function(str)
    -- Simple JSON decoder - handles basic cases
    if str == "null" then return nil end
    if str == "true" then return true end
    if str == "false" then return false end
    
    local num = tonumber(str)
    if num then return num end
    
    if str:sub(1,1) == '"' and str:sub(-1,-1) == '"' then
        return str:sub(2,-2):gsub('\\"', '"'):gsub("\\n", "\n"):gsub("\\r", "\r")
    end
    
    -- Try to parse JSON object/array (basic support)
    if str:sub(1,1) == "{" and str:sub(-1,-1) == "}" then
        local obj = {}
        -- Very basic JSON object parsing
        local content = str:sub(2, -2)
        for pair in content:gmatch('"([^"]+)"%s*:%s*"([^"]*)"') do
            local key, value = pair, content:match('"' .. pair .. '"%s*:%s*"([^"]*)"')
            if key and value then
                obj[key] = value
            end
        end
        return obj
    end
    
    return str
end

-- Get authentication token from user
local function getAuthToken()
    print("\n=== Task Manager Setup ===")
    print("Enter the authentication password (Bearer token):")
    write("Password: ")
    authToken = read("*") -- Hide password input
    
    if authToken == "" then
        print("ERROR: Password cannot be empty!")
        return false
    end
    
    print("Authentication token set successfully!")
    return true
end

-- Make authenticated HTTP request
local function makeRequest(method, endpoint, body)
    local url = API_BASE_URL .. endpoint
    local headers = {
        ["Authorization"] = "Bearer " .. authToken,
        ["Content-Type"] = "application/json"
    }
    
    local requestBody = body and json.encode(body) or nil
    
    local response
    if method == "GET" then
        response = http.get(url, headers)
    elseif method == "POST" then
        response = http.post(url, requestBody or "", headers)
    elseif method == "PUT" then
        local options = {
            url = url,
            method = "PUT",
            headers = headers,
            body = requestBody or ""
        }
        response = http.request(options)
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

-- Register computer with server and get computer ID
local function registerComputer()
    print("Registering computer with server...")
    
    local response = makeRequest("POST", "/computer/hello", {})
    
    if response and response.success and response.data then
        if type(response.data) == "table" and response.data.computerId then
            computerId = response.data.computerId
        elseif type(response.data) == "string" then
            -- Try to extract computer ID from string response
            local id = response.data:match('"computerId"%s*:%s*"([^"]+)"') or
                      response.data:match('computerId[^:]*:[^"]*"([^"]+)"')
            if id then
                computerId = id
            else
                computerId = response.data
            end
        else
            computerId = tostring(response.data)
        end
        
        print("Computer registered with ID: " .. computerId)
        return true
    else
        print("Failed to register computer")
        if response then
            print("Status: " .. response.status)
            print("Response: " .. tostring(response.data))
        end
        return false
    end
end

-- Poll server for available tasks
local function pollForTasks()
    local response = makeRequest("GET", "/computer/" .. computerId .. "/poll", nil)
    
    if response and response.success and response.data then
        return response.data
    end
    
    return nil
end

-- Add task to local received queue
local function addToReceivedQueue(task)
    if not task or not task.id then
        return false
    end
    
    -- Check if task already exists in received queue
    for _, existingTask in ipairs(receivedTasks) do
        if existingTask.id == task.id then
            return false -- Already exists
        end
    end
    
    -- Add to received tasks queue
    table.insert(receivedTasks, {
        id = task.id,
        program = task.program,
        parameters = task.parameters,
        priority = task.priority or 0,
        expectedDuration = task.expectedDuration,
        receivedAt = os.clock(),
        status = "received"
    })
    
    print("Added task " .. task.id .. " to local queue")
    return true
end

-- Get next task from local received queue
local function getNextReceivedTask()
    if table.getn(receivedTasks) == 0 then
        return nil
    end
    
    -- Sort by priority (higher first) then by received time
    table.sort(receivedTasks, function(a, b)
        if a.priority ~= b.priority then
            return a.priority > b.priority
        end
        return a.receivedAt < b.receivedAt
    end)
    
    -- Remove and return first task
    local task = receivedTasks[1]
    table.remove(receivedTasks, 1)
    return task
end

-- Sync local queue state with server
local function syncQueueState()
    -- Check if computer ID is set
    if not computerId or computerId == "" then
        print("ERROR: Cannot sync - computer not registered")
        return false
    end
    
    local currentTime = os.clock()
    
    -- Prepare queue state report
    local queuedTasks = {}
    for _, task in ipairs(receivedTasks) do
        table.insert(queuedTasks, {
            id = task.id,
            program = task.program,
            status = task.status,
            receivedAt = task.receivedAt
        })
    end
    
    local activeTasksReport = {}
    local activeCount = 0 -- Initialize counter
    for taskId, task in pairs(activeTasks) do
        table.insert(activeTasksReport, {
            id = taskId,
            program = task.program,
            status = "in-progress",
            startTime = task.startTime
        })
        activeCount = activeCount + 1 -- Increment counter
    end
    
    local response = makeRequest("POST", "/computer/" .. computerId .. "/tasks/received", {
        queuedTasks = queuedTasks,
        activeTasks = activeTasksReport,
        localQueueState = {
            queueLength = table.getn(receivedTasks),
            activeCount = activeCount, -- Use corrected activeCount
            lastSyncTime = currentTime
        }
    })
    
    if response and response.success then
        -- Only print sync success occasionally to reduce spam
        if table.getn(receivedTasks) > 0 or table.getn(activeTasks) > 0 then
            print("Queue state synced with server")
        end
        if response.data and response.data.syncStatus == "out-of-sync" then
            print("WARNING: Queue out of sync with server")
            if response.data.recommendations and response.data.recommendations.shouldRefreshQueue then
                print("Server recommends refreshing queue")
            end
        end
        return true
    else
        local errorMsg = "Failed to sync queue state"
        if response then
            errorMsg = errorMsg .. " (HTTP " .. tostring(response.status) .. ")"
            if response.data then
                errorMsg = errorMsg .. ": " .. tostring(response.data)
            end
        else
            errorMsg = errorMsg .. " (No response)"
        end
        print("ERROR: " .. errorMsg)
        return false
    end
end

-- Report task start (non-blocking)
local function reportTaskStart(taskId)
    local success, response = pcall(function()
        return makeRequest("POST", "/computer/" .. computerId .. "/start/" .. taskId, {})
    end)
    return success and response and response.success
end

-- Report task completion (non-blocking)
local function reportTaskFinish(taskId, output)
    local success, response = pcall(function()
        return makeRequest("POST", "/computer/" .. computerId .. "/finish/" .. taskId, {
            output = output or ""
        })
    end)
    return success and response and response.success
end

-- Report task failure (non-blocking)
local function reportTaskFailure(taskId, error, details)
    local success, response = pcall(function()
        return makeRequest("POST", "/computer/" .. computerId .. "/failure/" .. taskId, {
            error = error or "Unknown error",
            details = details or "",
            timestamp = os.time()
        })
    end)
    return success and response and response.success
end

-- Execute a task program
local function executeTask(taskId, programName, parameters)
    print("Executing task " .. taskId .. ": " .. programName)
    
    -- Validate inputs
    if not taskId or not programName then
        local error = "Invalid task parameters: taskId=" .. tostring(taskId) .. ", program=" .. tostring(programName)
        print("ERROR: " .. error)
        reportTaskFailure(taskId or "unknown", "Invalid task parameters", error)
        return false
    end
    
    -- Check if program exists in various locations
    local possiblePaths = {
        programName,
        programName .. ".lua",
        "tasks/" .. programName,
        "tasks/" .. programName .. ".lua",
        "/tasks/" .. programName,
        "/tasks/" .. programName .. ".lua",
        "src/" .. programName,
        "src/" .. programName .. ".lua"
    }
    
    local foundPath = nil
    for _, path in ipairs(possiblePaths) do
        if fs.exists(path) then
            foundPath = path
            break
        end
    end
    
    if not foundPath then
        local error = "Program not found: " .. programName
        print("ERROR: " .. error)
        print("Searched locations:")
        for _, path in ipairs(possiblePaths) do
            print("  " .. path)
        end
        reportTaskFailure(taskId, error, "Program file does not exist on this computer")
        return false
    end
    
    print("Found program at: " .. foundPath)
    
    -- Report task start
    local reportSuccess, reportError = pcall(reportTaskStart, taskId)
    if not reportSuccess then
        print("Failed to report task start for " .. taskId .. ": " .. tostring(reportError))
        -- Continue anyway - this is not a fatal error
    end
    
    -- Build command line arguments safely
    local cmdArgs = {}
    if parameters then
        if type(parameters) == "table" then
            for i, arg in ipairs(parameters) do
                table.insert(cmdArgs, tostring(arg))
            end
        else
            table.insert(cmdArgs, tostring(parameters))
        end
    end
    
    -- Execute the program using shell.run in a protected call
    local executeSuccess, executeResult = pcall(function()
        -- Run the program directly without output capture for better performance
        local programSuccess = shell.run(foundPath, unpack(cmdArgs))
        return programSuccess
    end)
    
    -- Handle execution results
    if executeSuccess then
        if executeResult then
            print("Task " .. taskId .. " completed successfully")
            
            -- Report success (with error handling)
            local reportSuccess, reportError = pcall(reportTaskFinish, taskId, "Task completed successfully")
            if not reportSuccess then
                print("Failed to report task completion: " .. tostring(reportError))
            end
            
            return true
        else
            print("Task " .. taskId .. " failed - program returned false")
            
            -- Report failure (with error handling)
            local reportSuccess, reportError = pcall(reportTaskFailure, taskId, "Program execution failed", "Program returned false or failed")
            if not reportSuccess then
                print("Failed to report task failure: " .. tostring(reportError))
            end
            
            return false
        end
    else
        local error = "Failed to execute program: " .. tostring(executeResult)
        print("ERROR: " .. error)
        
        -- Report failure (with error handling)
        local reportSuccess, reportError = pcall(reportTaskFailure, taskId, error, "Exception during program execution")
        if not reportSuccess then
            print("Failed to report task failure: " .. tostring(reportError))
        end
        
        return false
    end
end

-- Execute a single task completely (synchronous)
local function processTask(task)
    if not task or not task.id or not task.program then
        print("ERROR: Invalid task to process")
        return false
    end
    
    local taskId = tostring(task.id)
    local programName = task.program
    local parameters = task.parameters or {}
    
    print("Processing task: " .. taskId .. " (" .. programName .. ")")
    
    -- Mark task as active
    activeTasks[taskId] = {
        id = taskId,
        program = programName,
        parameters = parameters,
        startTime = os.time()
    }
    
    local success = false
    
    -- Execute the task with full error handling
    local taskSuccess, taskResult = pcall(function()
        return executeTask(taskId, programName, parameters)
    end)
    
    if taskSuccess then
        success = taskResult
    else
        print("CRITICAL ERROR in task " .. taskId .. ": " .. tostring(taskResult))
        
        -- Try to report failure
        local reportSuccess, reportError = pcall(reportTaskFailure, taskId, "Critical execution error", tostring(taskResult))
        if not reportSuccess then
            print("Failed to report critical error: " .. tostring(reportError))
        end
        
        success = false
    end
    
    -- Clean up task tracking
    activeTasks[taskId] = nil
    
    print("Task " .. taskId .. " completed with success: " .. tostring(success))
    return success
end

-- Process new tasks from server poll
local function processServerPoll(serverResponse)
    if not serverResponse then
        return
    end
    
    if type(serverResponse) == "table" then
        -- Handle multiple tasks
        if serverResponse.tasks then
            for _, task in ipairs(serverResponse.tasks) do
                if addToReceivedQueue(task) then
                    print("Received new task from server: " .. task.id .. " (" .. task.program .. ")")
                end
            end
        elseif serverResponse.id then
            -- Single task
            if addToReceivedQueue(serverResponse) then
                print("Received new task from server: " .. serverResponse.id .. " (" .. serverResponse.program .. ")")
            end
        elseif serverResponse.message then
            -- No tasks available - this is normal
        end
    end
end

-- Simple sequential main loop - NO MULTITHREADING
local function mainLoop()
    print("\n=== Task Manager Active ===")
    print("Computer ID: " .. computerId)
    print("Polling every 2 seconds for fast response")
    print("Press Ctrl+T to stop")
    print("=" .. string.rep("=", 30))
    
    isRunning = true
    local lastPollTime = 0
    local lastSyncTime = 0
    
    while isRunning do
        local currentTime = os.clock()
                
        -- 1. Poll server for new tasks every 2 seconds (faster response)
        if currentTime - lastPollTime >= 2 then
            local success, serverResponse = pcall(pollForTasks)
            if success and serverResponse then
                local processSuccess, processError = pcall(processServerPoll, serverResponse)
                if not processSuccess then
                    print("ERROR: Failed to process server response: " .. tostring(processError))
                end
            elseif not success then
                print("ERROR: Failed to poll server: " .. tostring(serverResponse))
            end
            lastPollTime = currentTime
        end
        
        -- 2. Process one task if available (completely synchronous)
        local nextTask = getNextReceivedTask()
        if nextTask then
            print("Found task in queue: " .. nextTask.id .. " (" .. nextTask.program .. ")")
            local success, result = pcall(processTask, nextTask)
            if not success then
                print("ERROR: Failed to process task " .. tostring(nextTask.id) .. ": " .. tostring(result))
                -- Clean up
                if activeTasks[tostring(nextTask.id)] then
                    activeTasks[tostring(nextTask.id)] = nil
                end
                -- Report the error
                pcall(reportTaskFailure, tostring(nextTask.id), "Task processing error", tostring(result))
            end
        end
        
        -- 3. Sync queue state every 60 seconds (not critical for performance)
        -- Wait at least 10 seconds after startup before first sync
        if currentTime >= 10 and currentTime - lastSyncTime >= 60 then
            local success, error = pcall(syncQueueState)
            if not success then
                print("ERROR: Failed to sync queue state: " .. tostring(error))
            end
            lastSyncTime = currentTime
        end
        
        -- 4. Quick terminate check (non-blocking)
        local timer = os.startTimer(0.1)
        local event, timerID = os.pullEvent()
        
        if event == "terminate" then
            print("\nReceived terminate signal, shutting down...")
            isRunning = false
            break
        end
    end
    
    -- Clean shutdown
    print("Task Manager stopped.")
    
    -- Force cleanup any remaining tasks
    for taskId, task in pairs(activeTasks) do
        print("Cleaning up task: " .. taskId)
        pcall(reportTaskFailure, taskId, "Task manager shutdown", "System shutdown")
        activeTasks[taskId] = nil
    end
end

-- Display status
local function showStatus()
    print("\n=== Task Manager Status ===")
    print("Computer ID: " .. (computerId ~= "" and computerId or "Not registered"))
    print("Authentication: " .. (authToken ~= "" and "Set" or "Not set"))
    print("Received Tasks (Queue): " .. table.getn(receivedTasks))
    print("Active Tasks: " .. table.getn(activeTasks))
    
    if table.getn(receivedTasks) > 0 then
        print("\nQueued Tasks:")
        for i, task in ipairs(receivedTasks) do
            print("  " .. i .. ". " .. task.id .. ": " .. task.program .. " (priority: " .. task.priority .. ")")
        end
    end
    
    if table.getn(activeTasks) > 0 then
        print("\nActive Tasks:")
        for taskId, task in pairs(activeTasks) do
            print("  " .. taskId .. ": " .. task.program .. " (running for " .. (os.time() - task.startTime) .. "s)")
        end
    end
    print("========================")
end

-- Main program
local function main()
    print("=== Task Manager for ComputerCraft ===")
    print("Compatible with CC: Tweaked")
    print("Service: " .. API_BASE_URL)
    
    -- Get authentication token
    if not getAuthToken() then
        print("Exiting due to authentication setup failure.")
        return
    end
    
    -- Register computer with server
    if not registerComputer() then
        print("Exiting due to computer registration failure.")
        return
    end
    
    -- Show initial status
    showStatus()
    
    -- Ask user if they want to start
    print("\nReady to start task polling.")
    print("Commands: 'start' to begin, 'status' to check status, 'exit' to quit")
    
    while true do
        write("> ")
        local command = read():lower()
        
        if command == "start" then
            mainLoop()
            break
        elseif command == "status" then
            showStatus()
        elseif command == "exit" then
            print("Goodbye!")
            return
        else
            print("Unknown command. Use 'start', 'status', or 'exit'")
        end
    end
    
    print("Task Manager stopped.")
end

-- Run the program
main() 