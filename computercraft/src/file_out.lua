-- Fast File Output Task for ComputerCraft Task Manager
-- Takes a filename and content string, writes content to the file
-- Optimized version with minimal verification
-- Compatible with CC: Tweaked

-- Get command line arguments
local args = {...}

-- Validate arguments
if #args < 2 then
    print("ERROR: file_out_fast requires exactly 2 arguments")
    print("Usage: file_out_fast <filename> <content>")
    print("Example: file_out_fast test.txt \"Hello World\"")
    return false
end

local filename = args[1]
local content = args[2]

-- Validate filename
if not filename or filename == "" then
    print("ERROR: Filename cannot be empty")
    return false
end

-- Sanitize filename to prevent directory traversal
local sanitizedFilename = filename:gsub("%.%.", ""):gsub("/", ""):gsub("\\", "")
if sanitizedFilename ~= filename then
    print("WARNING: Filename sanitized from '" .. filename .. "' to '" .. sanitizedFilename .. "'")
    filename = sanitizedFilename
end

-- Content can be empty string, but should be defined
if content == nil then
    content = ""
end

print("Writing " .. #content .. " chars to: " .. filename)

-- Write the file with minimal verification
local success, errorMsg = pcall(function()
    local file = fs.open(filename, "w")
    if not file then
        error("Failed to open file for writing: " .. filename)
    end
    
    file.write(content)
    file.close()
end)

if success then
    print("SUCCESS: File written (" .. #content .. " bytes)")
    return true
else
    print("ERROR: Failed to write file")
    print("Error: " .. tostring(errorMsg))
    return false
end 