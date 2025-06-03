-- Setup Script for ComputerCraft Task Management System
-- Organizes task files and creates necessary directories
-- Compatible with CC: Tweaked

print("=== ComputerCraft Task Management Setup ===")
print("This script will organize your task files and create necessary directories.")

-- Create tasks directory if it doesn't exist
if not fs.exists("tasks") then
    fs.makeDir("tasks")
    print("Created tasks/ directory")
else
    print("tasks/ directory already exists")
end

-- List of task files that should be available
local taskFiles = {
    "file_out.lua",
    "file_out_fast.lua",
    "sync_queue.lua"
}

-- List of system files that should be in the root or current directory
local systemFiles = {
    "task_manager.lua",
    "chat_ai_assistant.lua", 
    "http_client.lua"
}

-- Check for task files and offer to move them to tasks/ directory
print("\n=== Checking Task Files ===")
for _, taskFile in ipairs(taskFiles) do
    local baseName = taskFile:gsub("%.lua$", "")
    
    -- Check various locations
    local locations = {
        taskFile,
        "src/" .. taskFile,
        baseName .. ".lua",
        "src/" .. baseName .. ".lua"
    }
    
    local found = false
    local foundLocation = nil
    
    for _, location in ipairs(locations) do
        if fs.exists(location) then
            found = true
            foundLocation = location
            break
        end
    end
    
    if found then
        local targetPath = "tasks/" .. taskFile
        if foundLocation ~= targetPath and not fs.exists(targetPath) then
            print("Moving " .. foundLocation .. " to " .. targetPath)
            fs.copy(foundLocation, targetPath)
            print("✓ " .. taskFile .. " installed in tasks/")
        else
            print("✓ " .. taskFile .. " already in correct location")
        end
    else
        print("✗ " .. taskFile .. " not found. Please copy it to this computer.")
        print("  You can place it in: tasks/" .. taskFile)
    end
end

-- Check for system files
print("\n=== Checking System Files ===")
for _, systemFile in ipairs(systemFiles) do
    local baseName = systemFile:gsub("%.lua$", "")
    
    -- Check current directory and src/
    local locations = {
        systemFile,
        "src/" .. systemFile,
        baseName,
        "src/" .. baseName
    }
    
    local found = false
    local foundLocation = nil
    
    for _, location in ipairs(locations) do
        if fs.exists(location) then
            found = true
            foundLocation = location
            break
        end
    end
    
    if found then
        -- Copy to root if it's in src/
        if foundLocation:sub(1, 4) == "src/" and not fs.exists(systemFile) then
            print("Copying " .. foundLocation .. " to " .. systemFile)
            fs.copy(foundLocation, systemFile)
            print("✓ " .. systemFile .. " available in root directory")
        else
            print("✓ " .. systemFile .. " found")
        end
    else
        print("✗ " .. systemFile .. " not found. Please copy it to this computer.")
    end
end

-- Test task execution
print("\n=== Testing Task Execution ===")

-- Test the fast version if available, otherwise regular version
local testTaskPath = "tasks/file_out_fast"
local taskName = "file_out_fast"
if not (fs.exists(testTaskPath) or fs.exists(testTaskPath .. ".lua")) then
    testTaskPath = "tasks/file_out"
    taskName = "file_out"
end

if fs.exists(testTaskPath) or fs.exists(testTaskPath .. ".lua") then
    print("Testing " .. taskName .. " task...")
    
    -- Test with a simple file write
    local testSuccess = shell.run(testTaskPath, "setup_test.txt", "Setup test successful!")
    
    if testSuccess and fs.exists("setup_test.txt") then
        print("✓ " .. taskName .. " task executed successfully")
        
        -- Read and display the test file
        local testFile = fs.open("setup_test.txt", "r")
        if testFile then
            local content = testFile.readAll()
            testFile.close()
            print("Test file content: " .. content)
            
            -- Clean up test file
            fs.delete("setup_test.txt")
            print("Test file cleaned up")
        end
    else
        print("✗ " .. taskName .. " task failed to execute")
    end
else
    print("✗ Cannot test - no file_out task found")
end

-- Display final status
print("\n=== Setup Complete ===")
print("File structure:")
print("├── task_manager.lua         (Main task manager)")
print("├── chat_ai_assistant.lua    (AI chat system)")
print("├── http_client.lua          (HTTP utilities)")
print("└── tasks/")
print("    ├── file_out.lua         (File output task)")
print("    ├── file_out_fast.lua    (Fast file output task)")
print("    └── sync_queue.lua       (Queue sync task)")

print("\n=== Next Steps ===")
print("1. Run: task_manager")
print("2. Enter your authentication token")
print("3. Start the task manager to begin processing tasks")
print("4. Queue tasks via the API or example_usage.sh script")

print("\n=== Usage Examples ===")
print("Start task manager:")
print("  task_manager")
print("")
print("Start AI chat assistant:")  
print("  chat_ai_assistant")
print("")
print("Manual task execution test:")
print("  tasks/file_out test.txt \"Hello World\"")

print("\nSetup script completed!") 