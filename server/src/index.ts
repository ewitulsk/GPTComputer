import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import Anthropic from '@anthropic-ai/sdk';

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

// Clean up old sessions (older than 24 hours)
const cleanupOldSessions = (): void => {
  const cutoffTime = new Date(Date.now() - 24 * 60 * 60 * 1000); // 24 hours ago
  for (const [userId, session] of userSessions.entries()) {
    if (session.lastActivity < cutoffTime) {
      userSessions.delete(userId);
    }
  }
};

// Run cleanup every hour
setInterval(cleanupOldSessions, 60 * 60 * 1000);

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
  console.log(`Claude API wrapper server running on port ${PORT}`);
  console.log(`Health check: http://localhost:${PORT}/health`);
  console.log(`Chat endpoint: POST http://localhost:${PORT}/chat`);
  console.log(`Get history: GET http://localhost:${PORT}/chat/:user/history`);
  console.log(`Clear history: DELETE http://localhost:${PORT}/chat/:user/history`);
  
  // Validate required environment variables
  if (!process.env.CLAUDE_API_KEY) {
    console.warn('Warning: CLAUDE_API_KEY environment variable not set');
  }
  if (!process.env.AUTH_SECRET) {
    console.warn('Warning: AUTH_SECRET environment variable not set');
  }
});

export default app; 