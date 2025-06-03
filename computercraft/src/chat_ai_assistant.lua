-- AI Chat Assistant for ComputerCraft
-- Monitors Minecraft chat and responds to "ASK" commands with Claude AI
-- Compatible with CC: Tweaked and Advanced Peripherals

-- Service configuration
local API_BASE_URL = "https://gptcomputer-810360555756.us-central1.run.app"
local CHAT_ENDPOINT = "/chat"

-- Global variables
local chatBox = nil
local authToken = ""
local isRunning = false

-- Simple JSON encoder/decoder (same as in http_client.lua)
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
        return '"' .. obj:gsub('"', '\\"') .. '"'
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
        return str:sub(2,-2):gsub('\\"', '"')
    end
    
    -- For complex objects, try to extract text content
    if str:find('"text":') then
        local text = str:match('"text"%s*:%s*"([^"]*)"')
        if text then return text end
    end
    
    return str
end

-- Initialize the chat box peripheral
local function initializeChatBox()
    print("Looking for Chat Box peripheral...")
    chatBox = peripheral.find("chatBox")
    
    if not chatBox then
        print("ERROR: Chat Box not found!")
        print("Make sure an Advanced Peripherals Chat Box is connected to the computer.")
        return false
    end
    
    print("Chat Box found and initialized!")
    return true
end

-- Get authentication token from user
local function getAuthToken()
    print("\n=== AI Chat Assistant Setup ===")
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

-- Make API call to Claude service
local function callClaudeAPI(message)
    local url = API_BASE_URL .. CHAT_ENDPOINT
    local headers = {
        ["Authorization"] = "Bearer " .. authToken,
        ["Content-Type"] = "application/json"
    }
    
    -- Generate unique user ID for this computer/turtle
    local computerLabel = os.getComputerLabel()
    local userID
    if computerLabel then
        userID = "cc_" .. os.getComputerID() .. "_" .. computerLabel
    else
        userID = "cc_" .. os.getComputerID()
    end
    
    local requestBody = json.encode({
        user = userID,
        message = message,
        model = "claude-sonnet-4-20250514",
        max_tokens = 500
    })
    
    print("Making API request to Claude...")
    
    -- Make HTTP POST request
    local response = http.post(url, requestBody, headers)
    
    if response then
        local status = response.getResponseCode()
        local body = response.readAll()
        response.close()
        
        print("API Response Status: " .. status)
        
        if status == 200 then
            -- Parse JSON response
            local responseData = textutils.unserialiseJSON(body)
            if responseData and responseData.response then
                return true, responseData.response
            else
                return false, "Invalid response format from API"
            end
        elseif status == 401 then
            return false, "Authentication failed - check your password"
        else
            return false, "API error (status " .. status .. "): " .. (body or "Unknown error")
        end
    else
        return false, "Failed to connect to API service"
    end
end

-- Send message to Minecraft chat
local function sendChatMessage(message, username)
    if not chatBox then
        print("ERROR: Chat Box not available")
        return false
    end
    
    -- Split long messages into chunks (Minecraft chat has limits)
    local maxLength = 200  -- Conservative limit for chat messages
    
    if #message <= maxLength then
        local success, error = chatBox.sendMessage(message, "AI", "[]", "&b")
        if not success then
            print("Failed to send chat message: " .. (error or "Unknown error"))
            return false
        end
        -- Sleep to respect chat cooldown
        sleep(1)
        return true
    else
        -- Split message into chunks
        local chunks = {}
        local remaining = message
        
        while #remaining > 0 do
            if #remaining <= maxLength then
                table.insert(chunks, remaining)
                break
            else
                -- Find a good breaking point (space, period, etc.)
                local breakPoint = maxLength
                for i = maxLength, math.max(1, maxLength - 50), -1 do
                    local char = remaining:sub(i, i)
                    if char == " " or char == "." or char == "!" or char == "?" then
                        breakPoint = i
                        break
                    end
                end
                
                table.insert(chunks, remaining:sub(1, breakPoint))
                remaining = remaining:sub(breakPoint + 1)
            end
        end
        
        -- Send each chunk with delay to respect chat cooldown
        for i, chunk in ipairs(chunks) do
            local prefix = "AI"
            if i > 1 then
                prefix = "AI (" .. i .. ")"
            end
            
            local success, error = chatBox.sendMessage(chunk, prefix, "[]", "&b")
            if not success then
                print("Failed to send chat message chunk " .. i .. ": " .. (error or "Unknown error"))
                return false
            end
            
            -- 1 second delay between chunks to respect chat cooldown
            sleep(1)
        end
        return true
    end
end

-- Process chat messages and respond to all messages
local function processChatMessage(username, message, uuid, isHidden)
    -- Ignore hidden messages
    if isHidden then
        return
    end
    
    print("[CHAT] " .. username .. ": " .. message)
    
    -- Trim whitespace from message
    local trimmedMessage = message:match("^%s*(.-)%s*$")
    
    -- Skip very short messages or empty messages
    if trimmedMessage == "" or #trimmedMessage < 2 then
        return
    end
    
    print("Processing message from " .. username .. ": " .. trimmedMessage)
    
    -- Call Claude API with the full message
    local success, response = callClaudeAPI(trimmedMessage)
    
    if success then
        print("Claude API response received")
        sendChatMessage("@" .. username .. " " .. response, username)
    else
        print("Claude API error: " .. response)
        sendChatMessage("Sorry " .. username .. ", I encountered an error: " .. response, username)
    end
end

-- Main event loop
local function runChatMonitor()
    print("\n=== AI Chat Assistant Active ===")
    print("Monitoring chat for all messages...")
    print("The AI will respond to every message in chat")
    print("Press Ctrl+T to stop")
    print("=" .. string.rep("=", 35))
    
    isRunning = true
    
    while isRunning do
        local event, username, message, uuid, isHidden = os.pullEvent()
        
        if event == "chat" then
            processChatMessage(username, message, uuid, isHidden)
        elseif event == "terminate" then
            print("\nShutting down AI Chat Assistant...")
            isRunning = false
            break
        end
    end
end

-- Test API connection
local function testAPIConnection()
    print("\nTesting API connection...")
    local success, response = callClaudeAPI("Hello, this is a test message. Please respond with 'API test successful'.")
    
    if success then
        print("API test successful!")
        print("Response: " .. response)
        return true
    else
        print("API test failed: " .. response)
        return false
    end
end

-- Main program
local function main()
    print("=== AI Chat Assistant for ComputerCraft ===")
    print("Compatible with CC: Tweaked and Advanced Peripherals")
    print("Service: " .. API_BASE_URL)
    
    -- Initialize Chat Box
    if not initializeChatBox() then
        print("Exiting due to Chat Box initialization failure.")
        return
    end
    
    -- Get authentication token
    if not getAuthToken() then
        print("Exiting due to authentication setup failure.")
        return
    end
    
    -- Test API connection
    if not testAPIConnection() then
        print("Would you like to continue anyway? (y/n)")
        write("Continue: ")
        local choice = read():lower()
        if choice ~= "y" and choice ~= "yes" then
            print("Exiting.")
            return
        end
    end
    
    -- Send startup message to chat
    sendChatMessage("AI Chat Assistant is now online! I will respond to every message in chat.", "system")
    
    -- Start monitoring chat
    runChatMonitor()
    
    -- Send shutdown message
    sendChatMessage("AI Chat Assistant is now offline.", "system")
    print("AI Chat Assistant stopped.")
end

-- Run the program
main() 