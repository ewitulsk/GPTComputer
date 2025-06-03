# GPTComputer - ComputerCraft Task Management System

A comprehensive task management system for ComputerCraft computers with AI chat capabilities powered by Claude.

## Features

### Task Management
- **Distributed Task Execution**: Queue and execute tasks across multiple ComputerCraft computers
- **Parallel Processing**: Execute multiple tasks simultaneously using ComputerCraft's parallel API
- **Automatic Timeout Handling**: Tasks that exceed their expected duration are automatically re-queued
- **Priority Queue System**: Tasks can be prioritized for execution order
- **Failure Recovery**: Failed tasks are properly logged with detailed error information
- **Computer Registration**: Automatic computer ID assignment and tracking

### AI Chat Assistant
- **Claude AI Integration**: Powered by Anthropic's Claude AI
- **Context-Aware Conversations**: Maintains conversation history per user
- **Minecraft Chat Integration**: Responds to all chat messages in-game
- **Advanced Peripherals Support**: Uses Chat Box for seamless integration

## Architecture

```
┌─────────────────┐    HTTP/JSON    ┌─────────────────┐
│  ComputerCraft  │ ◄────────────► │   Express.js    │
│   Computers     │                │    Server       │
│                 │                │                 │
│ • Task Manager  │                │ • Task Queue    │
│ • Chat AI       │                │ • Claude API    │
│ • File Tasks    │                │ • Task Tracking │
└─────────────────┘                └─────────────────┘
```

## Quick Start

### Server Setup

1. **Navigate to the server directory:**
   ```bash
   cd server
   ```

2. **Install dependencies:**
   ```bash
   npm install
   ```

3. **Set up environment variables:**
   ```bash
   cp env.example .env
   # Edit .env with your Claude API key and auth secret
   ```

4. **Build and start the server:**
   ```bash
   npm run build
   npm start
   ```

   Or for development:
   ```bash
   npm run dev
   ```

### ComputerCraft Setup

1. **Copy the scripts to your ComputerCraft computer:**
   - `computercraft/src/task_manager.lua` - Main task management system
   - `computercraft/src/chat_ai_assistant.lua` - AI chat assistant
   - `computercraft/src/file_out.lua` - Example task program
   - `computercraft/src/http_client.lua` - HTTP utility library

2. **Run the task manager:**
   ```lua
   task_manager
   ```

3. **Or run the chat assistant:**
   ```lua
   chat_ai_assistant
   ```

## Task Management System

### Core Concepts

**Tasks**: Programs that can be executed on ComputerCraft computers with parameters
**Queues**: Each computer maintains its own task queue with priority ordering
**Execution**: Tasks run in parallel threads with timeout monitoring
**Reporting**: Computers report task status back to the server

### Task Lifecycle

1. **Queued** - Task is added to a computer's queue
2. **In-Progress** - Task is being executed by a computer
3. **Completed** - Task finished successfully
4. **Failed** - Task encountered an error
5. **Timeout** - Task exceeded expected duration and was re-queued

### ComputerCraft Task Manager (`task_manager.lua`)

The main client that runs on ComputerCraft computers:

```lua
-- Features:
-- • Automatic computer registration
-- • Continuous task polling (every 5 seconds)
-- • Parallel task execution
-- • Error handling and reporting
-- • Output capture and logging
-- • Task timeout monitoring
```

**Commands:**
- `start` - Begin task polling and execution
- `status` - Show current computer and task status
- `exit` - Shutdown the task manager

### Example Task: File Output (`file_out.lua`)

A simple task that writes content to a file:

```lua
-- Usage: file_out <filename> <content>
-- Example: file_out test.txt "Hello World"
```

**Features:**
- Input validation
- Filename sanitization
- Content verification
- Detailed success/error reporting

## API Documentation

### Authentication

All endpoints require Bearer token authentication:
```
Authorization: Bearer <your-auth-secret>
```

### Computer Management Endpoints

#### Register Computer
```http
POST /computer/hello
```
**Response:**
```json
{
  "computerId": "uuid-string",
  "registeredAt": "2024-01-01T00:00:00.000Z",
  "message": "Computer registered successfully"
}
```

#### Poll for Tasks
```http
GET /computer/{computerId}/poll
```
**Response (with task):**
```json
{
  "id": "task-uuid",
  "program": "file_out",
  "parameters": ["test.txt", "Hello World"],
  "expectedDuration": 30
}
```

**Response (no tasks):**
```json
{
  "message": "No tasks available"
}
```

#### Report Task Start
```http
POST /computer/{computerId}/start/{taskId}
```
**Response:**
```json
{
  "taskId": "task-uuid",
  "status": "started",
  "startedAt": "2024-01-01T00:00:00.000Z"
}
```

#### Report Task Completion
```http
POST /computer/{computerId}/finish/{taskId}
Content-Type: application/json

{
  "output": "Task output here..."
}
```

#### Report Task Failure
```http
POST /computer/{computerId}/failure/{taskId}
Content-Type: application/json

{
  "error": "Error message",
  "details": "Detailed error information",
  "timestamp": 1704067200
}
```

### Task Queue Management

#### Queue New Task
```http
POST /computer/{computerId}/queue
Content-Type: application/json

{
  "program": "file_out",
  "parameters": ["output.txt", "Task content"],
  "expectedDuration": 30,
  "priority": 1
}
```

#### Get Computer Status
```http
GET /computer/{computerId}/status
```
**Response:**
```json
{
  "computerId": "uuid-string",
  "registeredAt": "2024-01-01T00:00:00.000Z",
  "lastSeen": "2024-01-01T00:05:00.000Z",
  "activeTasks": [
    {
      "id": "task-uuid",
      "program": "file_out",
      "status": "in-progress",
      "startedAt": "2024-01-01T00:04:30.000Z",
      "runningFor": 30
    }
  ],
  "queuedTasks": [
    {
      "id": "task-uuid-2",
      "program": "another_task",
      "priority": 0,
      "createdAt": "2024-01-01T00:04:45.000Z"
    }
  ],
  "queueLength": 1
}
```

### Chat API Endpoints

See existing chat documentation for Claude AI integration endpoints.

## Creating Custom Tasks

### Task Program Requirements

1. **Command Line Arguments**: Accept parameters via `{...}` 
2. **Return Values**: Return `true` for success, `false` for failure
3. **Output**: Use `print()` for output that will be captured
4. **Error Handling**: Handle errors gracefully with descriptive messages

### Example Custom Task

```lua
-- my_custom_task.lua
local args = {...}

if #args < 1 then
    print("ERROR: my_custom_task requires at least 1 argument")
    return false
end

local input = args[1]
print("Processing: " .. input)

-- Your task logic here
local success = pcall(function()
    -- Task implementation
end)

if success then
    print("SUCCESS: Task completed")
    return true
else
    print("ERROR: Task failed")
    return false
end
```

### Queuing Your Task

```bash
curl -X POST http://localhost:3000/computer/{computerId}/queue \
  -H "Authorization: Bearer your-auth-secret" \
  -H "Content-Type: application/json" \
  -d '{
    "program": "my_custom_task",
    "parameters": ["parameter1", "parameter2"],
    "expectedDuration": 60,
    "priority": 1
  }'
```

## Monitoring and Debugging

### Server Logs
The server provides detailed logging for:
- Computer registration and activity
- Task state changes
- Timeout and failure events
- Error conditions

### Task Status Monitoring
Use the status endpoint to monitor:
- Active tasks and their duration
- Queue length and pending tasks
- Computer last-seen timestamps
- Task execution history

### Error Handling
Failed tasks include:
- Error messages from the ComputerCraft program
- Detailed execution context
- Timestamp information for debugging

## Advanced Features

### Task Timeouts
- Default timeout: 5 minutes
- Configurable per task via `expectedDuration`
- Automatic re-queuing with increased priority
- Timeout detection runs every minute

### Priority System
- Higher numbers = higher priority
- Tasks sorted by priority, then creation time
- Failed/timed out tasks get priority boost
- Queue reordering on each poll

### Computer Management
- Automatic cleanup of inactive computers (1 hour)
- Re-queuing of orphaned tasks
- Last-seen timestamp tracking
- Graceful handling of computer disconnections

## Troubleshooting

### Common Issues

**Computer not registering:**
- Check authentication token
- Verify server URL is correct
- Ensure HTTP is enabled in ComputerCraft config

**Tasks not executing:**
- Verify program files exist on the computer
- Check file permissions and syntax
- Review server logs for error messages

**Tasks timing out:**
- Increase `expectedDuration` for long-running tasks
- Check for infinite loops in task programs
- Monitor server resources

**Authentication errors:**
- Verify `AUTH_SECRET` environment variable
- Check Bearer token format
- Ensure consistent token across client/server

### Getting Help

1. Check server console logs for detailed error messages
2. Use the computer status endpoint to monitor task states
3. Enable debug logging in ComputerCraft programs
4. Verify all required peripherals are connected

## Contributing

This system is designed to be extensible:

1. **Add new task types** by creating ComputerCraft programs
2. **Extend the API** with additional endpoints
3. **Enhance monitoring** with custom metrics
4. **Improve error handling** with better recovery strategies

## License

This project is part of the GPTComputer system for ComputerCraft automation and AI integration. 