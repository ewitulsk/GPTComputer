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
local taskThreads = {}

-- Simple JSON encoder/decoder (reused from other scripts)
local json = {}

function json.encode(obj)
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

function json.decode(str)
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

-- Report task start
local function reportTaskStart(taskId)
    local response = makeRequest("POST", "/computer/" .. computerId .. "/start/" .. taskId, {})
    return response and response.success
end

-- Report task completion
local function reportTaskFinish(taskId, output)
    local response = makeRequest("POST", "/computer/" .. computerId .. "/finish/" .. taskId, {
        output = output or ""
    })
    return response and response.success
end

-- Report task failure
local function reportTaskFailure(taskId, error, details)
    local response = makeRequest("POST", "/computer/" .. computerId .. "/failure/" .. taskId, {
        error = error or "Unknown error",
        details = details or "",
        timestamp = os.time()
    })
    return response and response.success
end

-- Execute a task program
local function executeTask(taskId, programName, parameters)
    print("Executing task " .. taskId .. ": " .. programName)
    
    -- Check if program exists
    if not fs.exists(programName) and not fs.exists(programName .. ".lua") then
        local error = "Program not found: " .. programName
        print("ERROR: " .. error)
        reportTaskFailure(taskId, error, "Program file does not exist on this computer")
        return false
    end
    
    -- Report task start
    if not reportTaskStart(taskId) then
        print("Failed to report task start for " .. taskId)
    end
    
    -- Build command line arguments
    local args = parameters or {}
    local cmdArgs = {}
    if type(args) == "table" then
        for i, arg in ipairs(args) do
            table.insert(cmdArgs, tostring(arg))
        end
    end
    
    -- Execute the program using shell.run in a protected call
    local success, result = pcall(function()
        -- Create a temporary output capture
        local originalPrint = print
        local output = {}
        
        -- Override print to capture output
        print = function(...)
            local args = {...}
            local line = ""
            for i, arg in ipairs(args) do
                if i > 1 then line = line .. " " end
                line = line .. tostring(arg)
            end
            table.insert(output, line)
            originalPrint(line)
        end
        
        -- Run the program
        local programSuccess = shell.run(programName, unpack(cmdArgs))
        
        -- Restore original print
        print = originalPrint
        
        -- Join output
        local outputStr = table.concat(output, "\n")
        
        return programSuccess, outputStr
    end)
    
    if success and result then
        local programSuccess, output = result, ""
        if type(result) == "table" then
            programSuccess = result[1]
            output = result[2] or ""
        end
        
        if programSuccess then
            print("Task " .. taskId .. " completed successfully")
            reportTaskFinish(taskId, output)
            return true
        else
            print("Task " .. taskId .. " failed during execution")
            reportTaskFailure(taskId, "Program execution failed", output)
            return false
        end
    else
        local error = "Failed to execute program: " .. tostring(result)
        print("ERROR: " .. error)
        reportTaskFailure(taskId, error, "Exception during program execution")
        return false
    end
end

-- Task execution thread
local function taskThread(taskId, programName, parameters)
    activeTasks[taskId] = {
        id = taskId,
        program = programName,
        parameters = parameters,
        startTime = os.time()
    }
    
    local success = executeTask(taskId, programName, parameters)
    
    activeTasks[taskId] = nil
    return success
end

-- Process a task from the server
local function processTask(task)
    if not task or not task.id or not task.program then
        print("Invalid task received")
        return
    end
    
    local taskId = tostring(task.id)
    local programName = task.program
    local parameters = task.parameters or {}
    
    print("Processing task: " .. taskId .. " (" .. programName .. ")")
    
    -- Start task in parallel thread
    local thread = function()
        taskThread(taskId, programName, parameters)
    end
    
    taskThreads[taskId] = thread
    
    -- Execute in parallel
    parallel.waitForAny(thread)
    
    taskThreads[taskId] = nil
end

-- Main polling loop
local function mainLoop()
    print("\n=== Task Manager Active ===")
    print("Computer ID: " .. computerId)
    print("Polling for tasks...")
    print("Press Ctrl+T to stop")
    print("=" .. string.rep("=", 30))
    
    isRunning = true
    
    while isRunning do
        -- Poll for tasks
        local tasks = pollForTasks()
        
        if tasks then
            if type(tasks) == "table" then
                -- Handle multiple tasks
                if tasks.tasks then
                    for _, task in ipairs(tasks.tasks) do
                        processTask(task)
                    end
                elseif tasks.id then
                    -- Single task
                    processTask(tasks)
                end
            end
        end
        
        -- Check for terminate event
        local timer = os.startTimer(5) -- Poll every 5 seconds
        local event = os.pullEvent()
        
        if event == "terminate" then
            print("\nShutting down Task Manager...")
            isRunning = false
            break
        elseif event == "timer" then
            -- Continue polling
        end
    end
    
    -- Wait for active tasks to complete
    if table.getn(activeTasks) > 0 then
        print("Waiting for active tasks to complete...")
        while table.getn(activeTasks) > 0 do
            sleep(1)
        end
    end
end

-- Display status
local function showStatus()
    print("\n=== Task Manager Status ===")
    print("Computer ID: " .. (computerId ~= "" and computerId or "Not registered"))
    print("Authentication: " .. (authToken ~= "" and "Set" or "Not set"))
    print("Active Tasks: " .. table.getn(activeTasks))
    
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