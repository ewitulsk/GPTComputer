import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import Anthropic from '@anthropic-ai/sdk';
import { v4 as uuidv4 } from 'uuid';

// Load environment variables
dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;

// Initialize Claude API client
const anthropic = new Anthropic({
  apiKey: process.env.CLAUDE_API_KEY,
});

// Store conversation history per user
interface Message {
  role: 'user' | 'assistant';
  content: string;
}

interface UserSession {
  messages: Message[];
  lastActivity: Date;
}

const userSessions = new Map<string, UserSession>();

// Task Management System
interface Task {
  id: string;
  program: string;
  parameters: string[];
  expectedDuration?: number; // in seconds
  priority?: number;
  createdAt: Date;
  status: 'queued' | 'in-progress' | 'completed' | 'failed' | 'timeout';
  computerId?: string;
  startedAt?: Date;
  finishedAt?: Date;
  output?: string;
  error?: string;
  details?: string;
}

interface Computer {
  id: string;
  registeredAt: Date;
  lastSeen: Date;
  taskQueue: Task[];
  activeTasks: Map<string, Task>;
}

const computers = new Map<string, Computer>();
const allTasks = new Map<string, Task>();

// Task timeout in seconds (default 5 minutes)
const DEFAULT_TASK_TIMEOUT = 300;

// Clean up old sessions (older than 24 hours)
const cleanupOldSessions = (): void => {
  const cutoffTime = new Date(Date.now() - 24 * 60 * 60 * 1000); // 24 hours ago
  for (const [userId, session] of userSessions.entries()) {
    if (session.lastActivity < cutoffTime) {
      userSessions.delete(userId);
    }
  }
};

// Task Management Functions
const checkTaskTimeouts = (): void => {
  const now = new Date();
  
  for (const computer of computers.values()) {
    for (const [taskId, task] of computer.activeTasks.entries()) {
      if (task.startedAt) {
        const timeout = (task.expectedDuration || DEFAULT_TASK_TIMEOUT) * 1000;
        const elapsed = now.getTime() - task.startedAt.getTime();
        
        if (elapsed > timeout) {
          console.log(`Task ${taskId} timed out on computer ${computer.id}`);
          
          // Mark task as timed out
          task.status = 'timeout';
          task.finishedAt = now;
          task.error = 'Task execution timeout';
          task.details = `Task exceeded expected duration of ${task.expectedDuration || DEFAULT_TASK_TIMEOUT} seconds`;
          
          // Remove from active tasks
          computer.activeTasks.delete(taskId);
          
          // Re-queue the task with higher priority
          const requeuedTask: Task = {
            id: uuidv4(),
            program: task.program,
            parameters: task.parameters,
            status: 'queued',
            priority: (task.priority || 0) + 1,
            createdAt: now,
            ...(task.expectedDuration && { expectedDuration: task.expectedDuration })
          };
          
          computer.taskQueue.unshift(requeuedTask); // Add to front of queue
          allTasks.set(requeuedTask.id, requeuedTask);
        }
      }
    }
  }
};

const cleanupOldComputers = (): void => {
  const cutoffTime = new Date(Date.now() - 60 * 60 * 1000); // 1 hour ago
  
  for (const [computerId, computer] of computers.entries()) {
    if (computer.lastSeen < cutoffTime) {
      console.log(`Removing inactive computer: ${computerId}`);
      
      // Re-queue any active tasks
      for (const task of computer.activeTasks.values()) {
        task.status = 'queued';
        delete task.startedAt;
        delete task.computerId;
        
        // Add back to a general queue or specific computer queue
        // For now, we'll just mark them as available
        allTasks.set(task.id, task);
      }
      
      computers.delete(computerId);
    }
  }
};

const getNextTaskForComputer = (computerId: string): Task | null => {
  const computer = computers.get(computerId);
  if (!computer) return null;
  
  // Sort tasks by priority (higher first) then by creation time
  computer.taskQueue.sort((a, b) => {
    const priorityDiff = (b.priority || 0) - (a.priority || 0);
    if (priorityDiff !== 0) return priorityDiff;
    return a.createdAt.getTime() - b.createdAt.getTime();
  });
  
  return computer.taskQueue.shift() || null;
};

// Run cleanup functions every minute
setInterval(() => {
  cleanupOldSessions();
  checkTaskTimeouts();
  cleanupOldComputers();
}, 60 * 1000);

// Middleware
app.use(cors());
app.use(express.json());

// Authentication middleware
const authenticate = (req: express.Request, res: express.Response, next: express.NextFunction): void => {
  const authHeader = req.headers.authorization;
  
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    res.status(401).json({ error: 'Missing or invalid authentication header' });
    return;
  }
  
  const secret = authHeader.substring(7); // Remove "Bearer " prefix
  
  if (secret !== process.env.AUTH_SECRET) {
    res.status(401).json({ error: 'Invalid authentication secret' });
    return;
  }
  
  next();
};

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'OK', timestamp: new Date().toISOString() });
});

// Computer Management Endpoints

// Computer registration
app.post('/computer/hello', authenticate, (req, res): void => {
  const computerId = uuidv4();
  const now = new Date();
  
  const computer: Computer = {
    id: computerId,
    registeredAt: now,
    lastSeen: now,
    taskQueue: [],
    activeTasks: new Map()
  };
  
  computers.set(computerId, computer);
  
  console.log(`Computer registered: ${computerId}`);
  
  res.json({
    computerId,
    registeredAt: now.toISOString(),
    message: 'Computer registered successfully'
  });
});

// Poll for tasks
app.get('/computer/:computerId/poll', authenticate, (req, res): void => {
  const { computerId } = req.params;
  
  if (!computerId) {
    res.status(400).json({ error: 'Computer ID is required' });
    return;
  }
  
  const computer = computers.get(computerId);
  if (!computer) {
    res.status(404).json({ error: 'Computer not found' });
    return;
  }
  
  // Update last seen
  computer.lastSeen = new Date();
  
  // Get next task
  const task = getNextTaskForComputer(computerId);
  
  if (task) {
    res.json({
      id: task.id,
      program: task.program,
      parameters: task.parameters,
      expectedDuration: task.expectedDuration
    });
  } else {
    res.json({ message: 'No tasks available' });
  }
});

// Report task start
app.post('/computer/:computerId/start/:taskId', authenticate, (req, res): void => {
  const { computerId, taskId } = req.params;
  
  if (!computerId || !taskId) {
    res.status(400).json({ error: 'Computer ID and Task ID are required' });
    return;
  }
  
  const computer = computers.get(computerId);
  if (!computer) {
    res.status(404).json({ error: 'Computer not found' });
    return;
  }
  
  const task = allTasks.get(taskId);
  if (!task) {
    res.status(404).json({ error: 'Task not found' });
    return;
  }
  
  // Update task status
  task.status = 'in-progress';
  task.startedAt = new Date();
  task.computerId = computerId;
  
  // Add to computer's active tasks
  computer.activeTasks.set(taskId, task);
  computer.lastSeen = new Date();
  
  console.log(`Task ${taskId} started on computer ${computerId}`);
  
  res.json({
    taskId,
    status: 'started',
    startedAt: task.startedAt.toISOString()
  });
});

// Report task completion
app.post('/computer/:computerId/finish/:taskId', authenticate, (req, res): void => {
  const { computerId, taskId } = req.params;
  const { output } = req.body;
  
  if (!computerId || !taskId) {
    res.status(400).json({ error: 'Computer ID and Task ID are required' });
    return;
  }
  
  const computer = computers.get(computerId);
  if (!computer) {
    res.status(404).json({ error: 'Computer not found' });
    return;
  }
  
  const task = computer.activeTasks.get(taskId);
  if (!task) {
    res.status(404).json({ error: 'Active task not found' });
    return;
  }
  
  // Update task status
  task.status = 'completed';
  task.finishedAt = new Date();
  task.output = output || '';
  
  // Remove from active tasks
  computer.activeTasks.delete(taskId);
  computer.lastSeen = new Date();
  
  console.log(`Task ${taskId} completed on computer ${computerId}`);
  
  res.json({
    taskId,
    status: 'completed',
    finishedAt: task.finishedAt.toISOString(),
    duration: task.startedAt ? 
      (task.finishedAt.getTime() - task.startedAt.getTime()) / 1000 : 0
  });
});

// Report task failure
app.post('/computer/:computerId/failure/:taskId', authenticate, (req, res): void => {
  const { computerId, taskId } = req.params;
  const { error, details, timestamp } = req.body;
  
  if (!computerId || !taskId) {
    res.status(400).json({ error: 'Computer ID and Task ID are required' });
    return;
  }
  
  const computer = computers.get(computerId);
  if (!computer) {
    res.status(404).json({ error: 'Computer not found' });
    return;
  }
  
  const task = computer.activeTasks.get(taskId);
  if (!task) {
    res.status(404).json({ error: 'Active task not found' });
    return;
  }
  
  // Update task status
  task.status = 'failed';
  task.finishedAt = new Date();
  task.error = error || 'Unknown error';
  task.details = details || '';
  
  // Remove from active tasks
  computer.activeTasks.delete(taskId);
  computer.lastSeen = new Date();
  
  console.log(`Task ${taskId} failed on computer ${computerId}: ${task.error}`);
  
  res.json({
    taskId,
    status: 'failed',
    error: task.error,
    details: task.details,
    finishedAt: task.finishedAt.toISOString()
  });
});

// Queue a new task
app.post('/computer/:computerId/queue', authenticate, (req, res): void => {
  const { computerId } = req.params;
  const { program, parameters, expectedDuration, priority } = req.body;
  
  if (!computerId) {
    res.status(400).json({ error: 'Computer ID is required' });
    return;
  }
  
  if (!program) {
    res.status(400).json({ error: 'Program name is required' });
    return;
  }
  
  const computer = computers.get(computerId);
  if (!computer) {
    res.status(404).json({ error: 'Computer not found' });
    return;
  }
  
  const taskId = uuidv4();
  const task: Task = {
    id: taskId,
    program: program,
    parameters: parameters || [],
    expectedDuration: expectedDuration || DEFAULT_TASK_TIMEOUT,
    priority: priority || 0,
    createdAt: new Date(),
    status: 'queued'
  };
  
  // Add to computer's task queue
  computer.taskQueue.push(task);
  allTasks.set(taskId, task);
  
  console.log(`Task ${taskId} queued for computer ${computerId}: ${program}`);
  
  res.json({
    taskId,
    status: 'queued',
    program,
    parameters: task.parameters,
    expectedDuration: task.expectedDuration,
    priority: task.priority,
    queuePosition: computer.taskQueue.length,
    createdAt: task.createdAt.toISOString()
  });
});

// Get computer status and queue
app.get('/computer/:computerId/status', authenticate, (req, res): void => {
  const { computerId } = req.params;
  
  if (!computerId) {
    res.status(400).json({ error: 'Computer ID is required' });
    return;
  }
  
  const computer = computers.get(computerId);
  if (!computer) {
    res.status(404).json({ error: 'Computer not found' });
    return;
  }
  
  const activeTasks = Array.from(computer.activeTasks.values()).map(task => ({
    id: task.id,
    program: task.program,
    status: task.status,
    startedAt: task.startedAt?.toISOString(),
    runningFor: task.startedAt ? 
      Math.floor((new Date().getTime() - task.startedAt.getTime()) / 1000) : 0
  }));
  
  const queuedTasks = computer.taskQueue.map(task => ({
    id: task.id,
    program: task.program,
    priority: task.priority,
    createdAt: task.createdAt.toISOString()
  }));
  
  res.json({
    computerId,
    registeredAt: computer.registeredAt.toISOString(),
    lastSeen: computer.lastSeen.toISOString(),
    activeTasks,
    queuedTasks,
    queueLength: computer.taskQueue.length
  });
});

// Get all computers
app.get('/computers', authenticate, (req, res): void => {
  const now = new Date();
  const cutoffTime = new Date(now.getTime() - 60 * 60 * 1000); // 1 hour ago
  
  const computerList = Array.from(computers.values()).map(computer => {
    const isActive = computer.lastSeen > cutoffTime;
    const activeTaskCount = computer.activeTasks.size;
    const queueLength = computer.taskQueue.length;
    
    return {
      id: computer.id,
      registeredAt: computer.registeredAt.toISOString(),
      lastSeen: computer.lastSeen.toISOString(),
      isActive,
      activeTaskCount,
      queueLength,
      totalTasks: activeTaskCount + queueLength,
      lastSeenAgo: Math.floor((now.getTime() - computer.lastSeen.getTime()) / 1000)
    };
  });
  
  // Sort by last seen (most recent first)
  computerList.sort((a, b) => b.lastSeenAgo - a.lastSeenAgo);
  
  const activeComputers = computerList.filter(c => c.isActive);
  const inactiveComputers = computerList.filter(c => !c.isActive);
  
  res.json({
    total: computerList.length,
    active: activeComputers.length,
    inactive: inactiveComputers.length,
    computers: computerList,
    summary: {
      totalActiveTasks: activeComputers.reduce((sum, c) => sum + c.activeTaskCount, 0),
      totalQueuedTasks: activeComputers.reduce((sum, c) => sum + c.queueLength, 0),
      lastUpdate: now.toISOString()
    }
  });
});

// Get tasks received by computer
app.get('/computer/:computerId/tasks/received', authenticate, (req, res): void => {
  const { computerId } = req.params;
  
  if (!computerId) {
    res.status(400).json({ error: 'Computer ID is required' });
    return;
  }
  
  const computer = computers.get(computerId);
  if (!computer) {
    res.status(404).json({ error: 'Computer not found' });
    return;
  }
  
  // Update last seen
  computer.lastSeen = new Date();
  
  // Get all tasks (queued and active) that the computer should have
  const queuedTasks = computer.taskQueue.map(task => ({
    id: task.id,
    program: task.program,
    parameters: task.parameters,
    priority: task.priority,
    expectedDuration: task.expectedDuration,
    status: task.status,
    createdAt: task.createdAt.toISOString()
  }));
  
  const activeTasks = Array.from(computer.activeTasks.values()).map(task => ({
    id: task.id,
    program: task.program,
    parameters: task.parameters,
    priority: task.priority,
    expectedDuration: task.expectedDuration,
    status: task.status,
    createdAt: task.createdAt.toISOString(),
    startedAt: task.startedAt?.toISOString()
  }));
  
  res.json({
    computerId,
    queuedTasks,
    activeTasks,
    totalTasks: queuedTasks.length + activeTasks.length,
    lastSyncedAt: new Date().toISOString()
  });
});

// Sync tasks received by computer (computer reports its current queue state)
app.post('/computer/:computerId/tasks/received', authenticate, (req, res): void => {
  const { computerId } = req.params;
  const { queuedTasks, activeTasks, localQueueState } = req.body;
  
  if (!computerId) {
    res.status(400).json({ error: 'Computer ID is required' });
    return;
  }
  
  const computer = computers.get(computerId);
  if (!computer) {
    res.status(404).json({ error: 'Computer not found' });
    return;
  }
  
  // Update last seen
  computer.lastSeen = new Date();
  
  // Validate input
  if (!Array.isArray(queuedTasks) && !Array.isArray(activeTasks)) {
    res.status(400).json({ error: 'queuedTasks or activeTasks must be provided as arrays' });
    return;
  }
  
  const reportedQueuedTasks = queuedTasks || [];
  const reportedActiveTasks = activeTasks || [];
  
  // Get current server state
  const serverQueuedTasks = computer.taskQueue.map(t => t.id);
  const serverActiveTasks = Array.from(computer.activeTasks.keys());
  
  // Analyze sync status
  const analysis = {
    queuedTasks: {
      reportedCount: reportedQueuedTasks.length,
      serverCount: serverQueuedTasks.length,
      reportedIds: reportedQueuedTasks.map((t: any) => t.id || t).filter(Boolean),
      serverIds: serverQueuedTasks,
      missingOnClient: serverQueuedTasks.filter(id => 
        !reportedQueuedTasks.some((t: any) => (t.id || t) === id)
      ),
      extraOnClient: reportedQueuedTasks
        .map((t: any) => t.id || t)
        .filter((id: string) => id && !serverQueuedTasks.includes(id))
    },
    activeTasks: {
      reportedCount: reportedActiveTasks.length,
      serverCount: serverActiveTasks.length,
      reportedIds: reportedActiveTasks.map((t: any) => t.id || t).filter(Boolean),
      serverIds: serverActiveTasks,
      missingOnClient: serverActiveTasks.filter(id => 
        !reportedActiveTasks.some((t: any) => (t.id || t) === id)
      ),
      extraOnClient: reportedActiveTasks
        .map((t: any) => t.id || t)
        .filter((id: string) => id && !serverActiveTasks.includes(id))
    }
  };
  
  const syncIssues = analysis.queuedTasks.missingOnClient.length > 0 ||
                    analysis.queuedTasks.extraOnClient.length > 0 ||
                    analysis.activeTasks.missingOnClient.length > 0 ||
                    analysis.activeTasks.extraOnClient.length > 0;
  
  console.log(`Task sync report from computer ${computerId}: ${syncIssues ? 'ISSUES DETECTED' : 'IN SYNC'}`);
  if (syncIssues) {
    console.log('Sync analysis:', JSON.stringify(analysis, null, 2));
  }
  
  res.json({
    syncStatus: syncIssues ? 'out-of-sync' : 'in-sync',
    receivedAt: new Date().toISOString(),
    analysis,
    recommendations: syncIssues ? {
      shouldRefreshQueue: analysis.queuedTasks.missingOnClient.length > 0,
      shouldReportMissingTasks: analysis.activeTasks.extraOnClient.length > 0,
      message: 'Queue state mismatch detected. Computer should poll for latest tasks.'
    } : {
      message: 'Queue state is synchronized.'
    }
  });
});

// Get conversation history for a user
app.get('/chat/:user/history', authenticate, (req, res): void => {
  const { user } = req.params;
  
  if (!user) {
    res.status(400).json({ error: 'User is required' });
    return;
  }
  
  const session = userSessions.get(user);
  if (!session) {
    res.json({ 
      user,
      messages: [],
      conversationLength: 0
    });
    return;
  }
  
  res.json({
    user,
    messages: session.messages,
    conversationLength: session.messages.length,
    lastActivity: session.lastActivity
  });
});

// Clear conversation history for a user
app.delete('/chat/:user/history', authenticate, (req, res): void => {
  const { user } = req.params;
  
  if (!user) {
    res.status(400).json({ error: 'User is required' });
    return;
  }
  
  const hadSession = userSessions.has(user);
  userSessions.delete(user);
  
  res.json({
    user,
    cleared: hadSession,
    message: hadSession ? 'Conversation history cleared' : 'No conversation history found'
  });
});

// Chat endpoint
app.post('/chat', authenticate, async (req, res): Promise<void> => {
  try {
    const { user, message, model = 'claude-sonnet-4-20250514', max_tokens = 1000 } = req.body;
    
    if (!user) {
      res.status(400).json({ error: 'User is required' });
      return;
    }
    
    if (!message) {
      res.status(400).json({ error: 'Message is required' });
      return;
    }
    
    if (typeof user !== 'string') {
      res.status(400).json({ error: 'User must be a string' });
      return;
    }
    
    if (typeof message !== 'string') {
      res.status(400).json({ error: 'Message must be a string' });
      return;
    }
    
    // Get or create user session
    let session = userSessions.get(user);
    if (!session) {
      session = {
        messages: [],
        lastActivity: new Date()
      };
      userSessions.set(user, session);
    }
    
    // Add user's message to conversation history
    session.messages.push({
      role: 'user',
      content: message
    });
    
    // Update last activity
    session.lastActivity = new Date();
    
    // Call Claude API with conversation history
    const response = await anthropic.messages.create({
      model,
      max_tokens,
      messages: session.messages.map(msg => ({
        role: msg.role,
        content: msg.content
      }))
    });
    
    // Extract the text content from Claude's response
    const responseText = response.content
      .filter((block: any) => block.type === 'text')
      .map((block: any) => block.text)
      .join('');
    
    // Add Claude's response to conversation history
    session.messages.push({
      role: 'assistant',
      content: responseText
    });
    
    res.json({
      response: responseText,
      model: response.model,
      usage: response.usage,
      conversationLength: session.messages.length
    });
    
  } catch (error: unknown) {
    console.error('Error calling Claude API:', error);
    
    if (error instanceof Anthropic.APIError) {
      res.status(error.status || 500).json({
        error: 'Claude API error',
        message: error.message
      });
    } else if (error instanceof Error) {
      res.status(500).json({
        error: 'Internal server error',
        message: error.message
      });
    } else {
      res.status(500).json({
        error: 'Internal server error',
        message: 'An unexpected error occurred'
      });
    }
  }
});

// Start server
app.listen(PORT, () => {
  console.log(`Task Management & Claude API Server running on port ${PORT}`);
  console.log('\n=== Health & Chat Endpoints ===');
  console.log(`Health check: http://localhost:${PORT}/health`);
  console.log(`Chat endpoint: POST http://localhost:${PORT}/chat`);
  console.log(`Get history: GET http://localhost:${PORT}/chat/:user/history`);
  console.log(`Clear history: DELETE http://localhost:${PORT}/chat/:user/history`);
  
  console.log('\n=== Task Management Endpoints ===');
  console.log(`Computer registration: POST http://localhost:${PORT}/computer/hello`);
  console.log(`Poll for tasks: GET http://localhost:${PORT}/computer/:computerId/poll`);
  console.log(`Report task start: POST http://localhost:${PORT}/computer/:computerId/start/:taskId`);
  console.log(`Report task completion: POST http://localhost:${PORT}/computer/:computerId/finish/:taskId`);
  console.log(`Report task failure: POST http://localhost:${PORT}/computer/:computerId/failure/:taskId`);
  console.log(`Queue new task: POST http://localhost:${PORT}/computer/:computerId/queue`);
  console.log(`Get computer status: GET http://localhost:${PORT}/computer/:computerId/status`);
  console.log(`Get all computers: GET http://localhost:${PORT}/computers`);
  console.log(`Get received tasks: GET http://localhost:${PORT}/computer/:computerId/tasks/received`);
  console.log(`Sync queue state: POST http://localhost:${PORT}/computer/:computerId/tasks/received`);
  
  // Validate required environment variables
  if (!process.env.CLAUDE_API_KEY) {
    console.warn('\nWarning: CLAUDE_API_KEY environment variable not set');
  }
  if (!process.env.AUTH_SECRET) {
    console.warn('Warning: AUTH_SECRET environment variable not set');
  }
  
  console.log('\n=== Task Management System Active ===');
  console.log('Monitoring for task timeouts and computer activity...');
});

export default app; 