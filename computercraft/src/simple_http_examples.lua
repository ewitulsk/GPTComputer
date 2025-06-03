-- Simple HTTP Examples for ComputerCraft using Custom HTTP Client
-- Copy these examples and modify them for your needs
--
-- REQUIREMENTS: This file requires http_client.lua to be present
-- Either place http_client.lua in the same directory or copy its contents here
--
-- USAGE: 
-- 1. Make sure http_client.lua is available
-- 2. Run this script to see examples of HTTP requests
-- 3. Copy and modify individual functions for your own use

-- Load the HTTP client (assuming http_client.lua is available)
-- If running as standalone, you can copy the HttpClient code here
local httpClient = require("http_client") or loadfile("http_client.lua")()

-- Quick access to utility functions
local quickGet = httpClient.quickGet
local quickPost = httpClient.quickPost
local quickPut = httpClient.quickPut
local quickDelete = httpClient.quickDelete
local HttpClient = httpClient.HttpClient
local json = httpClient.json

-- Example 1: Simple GET request using custom client
function simpleGet()
    print("Making simple GET request...")
    local response = quickGet("https://httpbin.org/get")
    
    print("Success:", response.success)
    print("Status:", response.status)
    if response.body then
        print("Body:", response.body)
    end
    if response.error then
        print("Error:", response.error)
    end
end

-- Example 2: GET with headers using custom client
function getWithHeaders()
    local headers = {
        ["User-Agent"] = "ComputerCraft/1.0",
        ["Accept"] = "application/json"
    }
    
    print("Making GET request with custom headers...")
    local response = quickGet("https://httpbin.org/get", headers)
    
    print("Success:", response.success)
    print("Status:", response.status)
    if response.body then
        print("Body:", response.body)
    end
    if response.error then
        print("Error:", response.error)
    end
end

-- Example 3: POST with JSON data using custom client
function postJson()
    local url = "https://httpbin.org/post"
    
    -- Using table data - the client will automatically encode to JSON
    local data = {
        name = "ComputerCraft", 
        type = "turtle", 
        active = true,
        timestamp = os.time()
    }
    
    print("Making POST request with JSON data...")
    local response = quickPost(url, data)
    
    print("Success:", response.success)
    print("Status:", response.status)
    if response.body then
        print("Body:", response.body)
    end
    if response.error then
        print("Error:", response.error)
    end
end

-- Example 4: POST with form data using custom client
function postForm()
    local url = "https://httpbin.org/post"
    local headers = {
        ["Content-Type"] = "application/x-www-form-urlencoded"
    }
    local body = "username=turtle123&password=secret&location=minecraft"
    
    print("Making POST request with form data...")
    local response = quickPost(url, body, headers)
    
    print("Success:", response.success)
    print("Status:", response.status)
    if response.body then
        print("Body:", response.body)
    end
    if response.error then
        print("Error:", response.error)
    end
end

-- Example 5: PUT request using custom client
function putRequest()
    local url = "https://httpbin.org/put"
    
    -- Using table data - the client will automatically encode to JSON
    local data = {
        id = 123, 
        name = "Updated Turtle", 
        status = "active",
        last_updated = os.time()
    }
    
    print("Making PUT request with JSON data...")
    local response = quickPut(url, data)
    
    print("Success:", response.success)
    print("Status:", response.status)
    if response.body then
        print("Body:", response.body)
    end
    if response.error then
        print("Error:", response.error)
    end
end

-- Example 6: DELETE request using custom client
function deleteRequest()
    local url = "https://httpbin.org/delete"
    local headers = {
        ["Authorization"] = "Bearer your-token-here"
    }
    
    print("Making DELETE request with authorization...")
    local response = quickDelete(url, headers)
    
    print("Success:", response.success)
    print("Status:", response.status)
    if response.body then
        print("Body:", response.body)
    end
    if response.error then
        print("Error:", response.error)
    end
end

-- Example 7: API call with authentication using custom client
function authenticatedApiCall()
    local url = "https://api.github.com/user"
    local headers = {
        ["Authorization"] = "token YOUR_GITHUB_TOKEN",
        ["User-Agent"] = "ComputerCraft-Client"
    }
    
    print("Making authenticated API call to GitHub...")
    local response = quickGet(url, headers)
    
    print("Success:", response.success)
    print("Status:", response.status)
    
    if response.success then
        print("User data:", response.body)
    else
        print("Error:", response.body or response.error)
    end
end

-- Example 8: Error handling and retry logic using custom client
function robustRequest()
    local url = "https://httpbin.org/status/200"
    local maxRetries = 3
    local retryDelay = 1 -- seconds
    
    for attempt = 1, maxRetries do
        print("Attempt", attempt, "of", maxRetries)
        
        local response = quickGet(url)
        
        if response.success then
            print("Success! Status:", response.status)
            print("Body:", response.body)
            return true
        else
            if response.status > 0 then
                print("HTTP error:", response.status)
            else
                print("Network error:", response.error or "Request failed")
            end
        end
        
        if attempt < maxRetries then
            print("Retrying in", retryDelay, "seconds...")
            sleep(retryDelay)
        end
    end
    
    print("All attempts failed")
    return false
end

-- Example 9: Download file using custom client
function downloadFile(url, filename)
    print("Downloading from:", url)
    
    local response = quickGet(url)
    
    if response.success then
        print("Download successful, saving to file...")
        
        local file = fs.open(filename, "w")
        if file then
            file.write(response.body)
            file.close()
            print("File saved as:", filename)
            print("File size:", #response.body, "bytes")
            return true
        else
            print("Failed to save file")
        end
    else
        print("Download failed - Status:", response.status)
        if response.error then
            print("Error:", response.error)
        end
    end
    return false
end

-- Example 10: JSON API interaction using custom client
function weatherExample()
    -- Note: You'll need a real API key for OpenWeatherMap
    local apiKey = "YOUR_API_KEY"
    local city = "London"
    local url = "http://api.openweathermap.org/data/2.5/weather?q=" .. city .. "&appid=" .. apiKey
    
    print("Fetching weather data for", city .. "...")
    local response = quickGet(url)
    
    if response.success then
        print("Weather data received successfully!")
        print("Full response:", response.body)
        
        -- Basic JSON parsing (the custom client provides json utilities)
        local temp = response.body:match('"temp":([%d%.]+)')
        local description = response.body:match('"description":"([^"]+)"')
        local humidity = response.body:match('"humidity":([%d]+)')
        
        if temp then
            print("Temperature:", temp, "K")
        end
        if description then
            print("Description:", description)
        end
        if humidity then
            print("Humidity:", humidity .. "%")
        end
    else
        print("Weather API request failed")
        print("Status:", response.status)
        if response.error then
            print("Error:", response.error)
        end
    end
end

-- Example 11: Using the full HttpClient class with configuration
function advancedClientExample()
    print("Demonstrating advanced HttpClient usage...")
    
    -- Create a configured client
    local client = HttpClient.new()
    client:setBaseUrl("https://httpbin.org")
    client:setHeader("User-Agent", "ComputerCraft-Advanced/2.0")
    client:setHeader("Accept", "application/json")
    
    print("Client configured with base URL and default headers")
    
    -- Make multiple requests with the same client
    print("\n1. GET request to /get")
    local getResponse = client:get("/get")
    print("GET Success:", getResponse.success, "- Status:", getResponse.status)
    
    print("\n2. POST request to /post with JSON data")
    local postData = {
        message = "Hello from ComputerCraft!",
        turtle_id = os.getComputerID(),
        timestamp = os.time()
    }
    local postResponse = client:post("/post", postData)
    print("POST Success:", postResponse.success, "- Status:", postResponse.status)
    
    print("\n3. Adding authentication header and making authenticated request")
    client:setHeader("Authorization", "Bearer demo-token-123")
    local authResponse = client:get("/bearer")
    print("Auth Success:", authResponse.success, "- Status:", authResponse.status)
    
    print("\nAdvanced client example completed!")
end

-- Menu to run examples
function runExamples()
    print("=== HTTP Examples Menu (Using Custom Client) ===")
    print("1. Simple GET")
    print("2. GET with headers")
    print("3. POST JSON")
    print("4. POST form data")
    print("5. PUT request")
    print("6. DELETE request")
    print("7. Authenticated API call")
    print("8. Robust request with retry")
    print("9. Download file")
    print("10. Weather API example")
    print("11. Advanced client configuration")
    print("0. Exit")
    
    while true do
        write("Choose example (0-11): ")
        local choice = read()
        
        if choice == "1" then
            simpleGet()
        elseif choice == "2" then
            getWithHeaders()
        elseif choice == "3" then
            postJson()
        elseif choice == "4" then
            postForm()
        elseif choice == "5" then
            putRequest()
        elseif choice == "6" then
            deleteRequest()
        elseif choice == "7" then
            authenticatedApiCall()
        elseif choice == "8" then
            robustRequest()
        elseif choice == "9" then
            write("Enter URL: ")
            local url = read()
            write("Enter filename: ")
            local filename = read()
            downloadFile(url, filename)
        elseif choice == "10" then
            weatherExample()
        elseif choice == "11" then
            advancedClientExample()
        elseif choice == "0" then
            break
        else
            print("Invalid choice!")
        end
        
        print("\nPress Enter to continue...")
        read()
    end
end

-- Run examples if executed directly
runExamples() 