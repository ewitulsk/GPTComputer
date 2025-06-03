-- Fast File Output Task for ComputerCraft Task Manager
-- Takes a filename and base64-encoded content string, decodes and writes content to the file
-- Uses base64 encoding to avoid command line argument parsing issues
-- Compatible with CC: Tweaked

-- Simple base64 decoder for ComputerCraft (Lua 5.0 compatible)
local function decodeBase64(data)
    local b64chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    local b64lookup = {}
    
    -- Build lookup table
    for i = 1, string.len(b64chars) do
        b64lookup[string.sub(b64chars, i, i)] = i - 1
    end
    
    -- Remove whitespace and padding
    data = string.gsub(data, '[^'..b64chars..'=]', '')
    
    local result = ""
    local padlen = string.len(string.match(data, '=*$'))
    data = string.gsub(data, '=', '')
    
    -- Process groups of 4 characters
    for i = 1, string.len(data), 4 do
        local group = string.sub(data, i, i + 3)
        local grouplen = string.len(group)
        
        if grouplen >= 2 then
            local val = 0
            for j = 1, grouplen do
                local char = string.sub(group, j, j)
                val = val * 64 + (b64lookup[char] or 0)
            end
            
            -- Pad the value based on group length
            for j = grouplen + 1, 4 do
                val = val * 64
            end
            
            -- Extract bytes
            if grouplen >= 2 then
                result = result .. string.char(math.floor(val / 65536) % 256)
            end
            if grouplen >= 3 then
                result = result .. string.char(math.floor(val / 256) % 256)
            end
            if grouplen >= 4 then
                result = result .. string.char(val % 256)
            end
        end
    end
    
    -- Remove padding bytes
    if padlen > 0 then
        result = string.sub(result, 1, string.len(result) - padlen)
    end
    
    return result
end

-- Get command line arguments
local args = {...}

-- Validate arguments
if table.getn(args) < 2 then
    print("ERROR: file_out requires exactly 2 arguments")
    print("Usage: file_out <filename> <base64_content>")
    print("Example: file_out test.txt cHJpbnQoJ0hlbGxvIFRyZXZvciEnKQ==")
    print("Note: Content must be base64 encoded")
    return false
end

local filename = args[1]
local base64Content = args[2]

-- Validate filename
if not filename or filename == "" then
    print("ERROR: Filename cannot be empty")
    return false
end

-- Validate base64 content
if not base64Content or base64Content == "" then
    print("ERROR: Base64 content cannot be empty")
    return false
end

print("Decoding base64 content...")

-- Decode the base64 content
local success, content = pcall(function()
    return decodeBase64(base64Content)
end)

if not success then
    print("ERROR: Failed to decode base64 content")
    print("Error: " .. tostring(content))
    return false
end

print("Decoded content length: " .. string.len(content) .. " characters")
print("Writing to file: " .. filename)

-- Write the file
local writeSuccess, errorMsg = pcall(function()
    local file = fs.open(filename, "w")
    if not file then
        error("Failed to open file for writing: " .. filename)
    end
    
    file.write(content)
    file.close()
end)

if writeSuccess then
    print("SUCCESS: File written (" .. string.len(content) .. " bytes)")
    return true
else
    print("ERROR: Failed to write file")
    print("Error: " .. tostring(errorMsg))
    return false
end 