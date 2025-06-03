-- HTTP Client for ComputerCraft
-- Supports GET, POST, PUT, DELETE requests with JSON handling
-- Compatible with CC: Tweaked and Advanced Peripherals

local json = {}

-- Simple JSON encoder/decoder
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
    
    -- For complex objects, return the string (basic fallback)
    return str
end

-- HTTP Client class
local HttpClient = {}
HttpClient.__index = HttpClient

function HttpClient.new()
    local self = setmetatable({}, HttpClient)
    self.base_url = ""
    self.headers = {}
    return self
end

function HttpClient:setBaseUrl(url)
    self.base_url = url
    return self
end

function HttpClient:setHeader(key, value)
    self.headers[key] = value
    return self
end

function HttpClient:setHeaders(headers)
    for k, v in pairs(headers) do
        self.headers[k] = v
    end
    return self
end

function HttpClient:_makeRequest(method, url, body, headers)
    -- Combine base URL with endpoint
    local full_url = self.base_url .. url
    
    -- Combine default headers with request headers
    local request_headers = {}
    for k, v in pairs(self.headers) do
        request_headers[k] = v
    end
    if headers then
        for k, v in pairs(headers) do
            request_headers[k] = v
        end
    end
    
    -- Prepare request options
    local options = {
        url = full_url,
        method = method,
        headers = request_headers
    }
    
    if body then
        options.body = body
    end
    
    print("Making " .. method .. " request to: " .. full_url)
    
    -- Make the HTTP request
    local response = http.request(options)
    
    if response then
        local status = response.getResponseCode()
        local responseBody = response.readAll()
        response.close()
        
        print("Response Status: " .. status)
        print("Response Body: " .. (responseBody or ""))
        
        return {
            status = status,
            body = responseBody,
            success = status >= 200 and status < 300
        }
    else
        print("HTTP request failed")
        return {
            status = 0,
            body = nil,
            success = false,
            error = "Request failed"
        }
    end
end

function HttpClient:get(url, headers)
    return self:_makeRequest("GET", url, nil, headers)
end

function HttpClient:post(url, body, headers)
    local request_headers = headers or {}
    if type(body) == "table" then
        body = json.encode(body)
        request_headers["Content-Type"] = "application/json"
    end
    return self:_makeRequest("POST", url, body, request_headers)
end

function HttpClient:put(url, body, headers)
    local request_headers = headers or {}
    if type(body) == "table" then
        body = json.encode(body)
        request_headers["Content-Type"] = "application/json"
    end
    return self:_makeRequest("PUT", url, body, request_headers)
end

function HttpClient:delete(url, headers)
    return self:_makeRequest("DELETE", url, nil, headers)
end

-- Utility functions for quick requests
local function quickGet(url, headers)
    local client = HttpClient.new()
    return client:get(url, headers)
end

local function quickPost(url, body, headers)
    local client = HttpClient.new()
    return client:post(url, body, headers)
end

local function quickPut(url, body, headers)
    local client = HttpClient.new()
    return client:put(url, body, headers)
end

local function quickDelete(url, headers)
    local client = HttpClient.new()
    return client:delete(url, headers)
end

-- Interactive menu system
local function showMenu()
    print("\n=== HTTP Client Menu ===")
    print("1. GET Request")
    print("2. POST Request")
    print("3. PUT Request")
    print("4. DELETE Request")
    print("5. Create HTTP Client")
    print("6. Examples")
    print("7. Exit")
    print("========================")
    write("Choose an option: ")
end

local function getInput(prompt)
    write(prompt)
    return read()
end

local function makeInteractiveRequest()
    local method = getInput("Method (GET/POST/PUT/DELETE): "):upper()
    local url = getInput("URL: ")
    local body = nil
    local headers = {}
    
    if method == "POST" or method == "PUT" then
        local bodyType = getInput("Body type (json/text/none): "):lower()
        if bodyType == "json" then
            print("Enter JSON data (one line):")
            local jsonStr = read()
            if jsonStr and jsonStr ~= "" then
                body = jsonStr
                headers["Content-Type"] = "application/json"
            end
        elseif bodyType == "text" then
            body = getInput("Body: ")
        end
    end
    
    local addHeaders = getInput("Add custom headers? (y/n): "):lower()
    if addHeaders == "y" then
        print("Enter headers in format 'key:value', empty line to finish:")
        while true do
            local header = read()
            if header == "" then break end
            local key, value = header:match("([^:]+):(.+)")
            if key and value then
                headers[key:gsub("^%s*(.-)%s*$", "%1")] = value:gsub("^%s*(.-)%s*$", "%1")
            end
        end
    end
    
    local client = HttpClient.new()
    local response
    
    if method == "GET" then
        response = client:get(url, headers)
    elseif method == "POST" then
        response = client:post(url, body, headers)
    elseif method == "PUT" then
        response = client:put(url, body, headers)
    elseif method == "DELETE" then
        response = client:delete(url, headers)
    else
        print("Invalid method!")
        return
    end
    
    print("\n=== Response ===")
    print("Success: " .. tostring(response.success))
    print("Status: " .. response.status)
    if response.body then
        print("Body: " .. response.body)
    end
    if response.error then
        print("Error: " .. response.error)
    end
end

local function showExamples()
    print("\n=== Examples ===")
    print("\n1. Simple GET request:")
    print('local response = quickGet("https://httpbin.org/get")')
    
    print("\n2. POST with JSON:")
    print('local data = {name = "test", value = 123}')
    print('local response = quickPost("https://httpbin.org/post", data)')
    
    print("\n3. Using HTTP Client with base URL:")
    print('local client = HttpClient.new()')
    print('client:setBaseUrl("https://api.example.com")')
    print('client:setHeader("Authorization", "Bearer token123")')
    print('local response = client:get("/users")')
    
    print("\n4. Custom headers:")
    print('local headers = {["User-Agent"] = "ComputerCraft/1.0"}')
    print('local response = quickGet("https://httpbin.org/get", headers)')
    
    print("\nPress Enter to continue...")
    read()
end

-- Main program
local function main()
    print("HTTP Client for ComputerCraft")
    print("Compatible with CC: Tweaked")
    
    while true do
        showMenu()
        local choice = read()
        
        if choice == "1" then
            local url = getInput("Enter URL: ")
            local response = quickGet(url)
            print("Response: " .. tostring(response.success) .. " - " .. response.status)
            if response.body then print("Body: " .. response.body) end
            
        elseif choice == "2" or choice == "3" then
            makeInteractiveRequest()
            
        elseif choice == "4" then
            local url = getInput("Enter URL: ")
            local response = quickDelete(url)
            print("Response: " .. tostring(response.success) .. " - " .. response.status)
            
        elseif choice == "5" then
            print("Creating HTTP Client example:")
            local client = HttpClient.new()
            local baseUrl = getInput("Base URL (optional): ")
            if baseUrl ~= "" then
                client:setBaseUrl(baseUrl)
            end
            print("Client created! You can now use it programmatically.")
            
        elseif choice == "6" then
            showExamples()
            
        elseif choice == "7" then
            print("Goodbye!")
            break
            
        else
            print("Invalid choice!")
        end
        
        print("\nPress Enter to continue...")
        read()
    end
end

-- Export functions for use as API
return {
    HttpClient = HttpClient,
    quickGet = quickGet,
    quickPost = quickPost,
    quickPut = quickPut,
    quickDelete = quickDelete,
    json = json,
    main = main
}

-- Auto-run main if executed directly
if not ... then
    main()
end 