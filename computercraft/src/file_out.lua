-- File Output Task for ComputerCraft Task Manager
-- Takes a filename and content string, writes content to the file
-- Compatible with CC: Tweaked

-- Get command line arguments
local args = {...}

-- Validate arguments
if #args < 2 then
    print("ERROR: file_out requires exactly 2 arguments")
    print("Usage: file_out <filename> <content>")
    print("Example: file_out test.txt \"Hello World\"")
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

print("Writing to file: " .. filename)
print("Content length: " .. #content .. " characters")

-- Try to write the file
local success, errorMsg = pcall(function()
    local file = fs.open(filename, "w")
    if not file then
        error("Failed to open file for writing: " .. filename)
    end
    
    file.write(content)
    file.close()
end)

if success then
    print("SUCCESS: File written successfully")
    print("File: " .. filename)
    print("Size: " .. (#content) .. " bytes")
    
    -- Verify the file was written correctly
    if fs.exists(filename) then
        local size = fs.getSize(filename)
        print("Verified file exists with size: " .. size .. " bytes")
        
        -- Read back a preview of the content
        local readFile = fs.open(filename, "r")
        if readFile then
            local readContent = readFile.readAll()
            readFile.close()
            
            if readContent == content then
                print("Content verification: PASSED")
            else
                print("WARNING: Content verification failed")
                print("Expected length: " .. #content)
                print("Actual length: " .. #readContent)
            end
            
            -- Show preview of content (first 100 chars)
            local preview = readContent:sub(1, 100)
            if #readContent > 100 then
                preview = preview .. "..."
            end
            print("Content preview: " .. preview)
        end
    else
        print("WARNING: File verification failed - file does not exist after write")
    end
    
    return true
else
    print("ERROR: Failed to write file")
    print("Error: " .. tostring(errorMsg))
    return false
end 