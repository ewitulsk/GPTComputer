# ComputerCraft HTTP Client Programs

This directory contains Lua programs for making HTTP requests in ComputerCraft (CC: Tweaked).

## Files

### `http_client.lua`
A comprehensive HTTP client with:
- Object-oriented API for making requests
- Support for GET, POST, PUT, DELETE methods
- JSON encoding/decoding
- Header management
- Base URL configuration
- Interactive menu system
- Error handling

### `simple_http_examples.lua`
Simple, copy-paste examples for:
- Basic GET/POST/PUT/DELETE requests
- Authentication with API keys
- File downloads
- Error handling and retry logic
- Form data and JSON posting

## How to Use

### In ComputerCraft:

1. **Copy the entire file content** from either `http_client.lua` or `simple_http_examples.lua`
2. **In your ComputerCraft computer, create a new file:**
   ```
   edit http_client
   ```
3. **Paste the code** and save with `Ctrl+S`
4. **Run the program:**
   ```
   http_client
   ```

### Quick Examples:

```lua
-- Simple GET request
local response = http.get("https://httpbin.org/get")
if response then
    print("Status:", response.getResponseCode())
    print("Body:", response.readAll())
    response.close()
end

-- POST with JSON
local response = http.request({
    url = "https://httpbin.org/post",
    method = "POST",
    headers = {["Content-Type"] = "application/json"},
    body = '{"name": "turtle", "active": true}'
})
```

### Using the HTTP Client Class:

```lua
-- Load the http_client program
local httpClient = require("http_client")

-- Create a client
local client = httpClient.HttpClient.new()
client:setBaseUrl("https://api.example.com")
client:setHeader("Authorization", "Bearer your-token")

-- Make requests
local response = client:get("/users")
local postData = {name = "New User", email = "user@example.com"}
local createResponse = client:post("/users", postData)
```

## Requirements

- **CC: Tweaked** (ComputerCraft mod)
- **HTTP enabled** in the ComputerCraft configuration
- **Internet access** from your Minecraft world

## HTTP Configuration

Make sure HTTP requests are enabled in your ComputerCraft configuration:

1. In your Minecraft world folder, find `computercraft-server.toml` or `computercraft-common.toml`
2. Ensure `http.enabled = true`
3. Check that the URLs you want to access are not blocked in the `http.rules` section

## Common Use Cases

### API Integration
- Fetch data from REST APIs
- Send sensor data to external services
- Integrate with web services

### File Downloads
- Download scripts or data files
- Update turtle programs remotely
- Fetch configuration files

### Webhooks
- Send notifications to Discord/Slack
- Trigger external automation
- Log events to external systems

### IoT Communication
- Send data to IoT platforms
- Receive commands from web interfaces
- Synchronize with external databases

## Error Handling

Always check if the HTTP request was successful:

```lua
local response = http.get("https://example.com/api")
if response then
    local status = response.getResponseCode()
    if status >= 200 and status < 300 then
        -- Success
        local data = response.readAll()
        print("Success:", data)
    else
        -- HTTP error
        print("HTTP Error:", status)
    end
    response.close()
else
    -- Network error
    print("Request failed - check URL and internet connection")
end
```

## Security Notes

- Never hardcode sensitive API keys in your scripts
- Consider using environment variables or secure storage
- Be careful with user input in URLs to prevent injection attacks
- Validate responses before using them

## Advanced Features

The `http_client.lua` includes:
- Automatic JSON encoding for table data
- Chainable method calls
- Response object with status and body
- Built-in error handling
- Interactive testing interface

## Troubleshooting

**"HTTP request failed"**
- Check internet connectivity
- Verify the URL is correct
- Ensure HTTP is enabled in CC configuration
- Check if the domain is whitelisted

**"attempt to index nil value"**
- The response object is nil, meaning the request failed
- Add proper error checking before using response methods

**JSON encoding issues**
- The built-in JSON encoder is basic
- For complex nested objects, consider a more robust JSON library 