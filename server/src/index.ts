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

// Chat endpoint
app.post('/chat', authenticate, async (req, res): Promise<void> => {
  try {
    const { message, model = 'claude-3-sonnet-20240229', max_tokens = 1000 } = req.body;
    
    if (!message) {
      res.status(400).json({ error: 'Message is required' });
      return;
    }
    
    if (typeof message !== 'string') {
      res.status(400).json({ error: 'Message must be a string' });
      return;
    }
    
    // Call Claude API
    const response = await anthropic.messages.create({
      model,
      max_tokens,
      messages: [
        {
          role: 'user',
          content: message
        }
      ]
    });
    
    // Extract the text content from Claude's response
    const responseText = response.content
      .filter((block: any) => block.type === 'text')
      .map((block: any) => block.text)
      .join('');
    
    res.json({
      response: responseText,
      model: response.model,
      usage: response.usage
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
  
  // Validate required environment variables
  if (!process.env.CLAUDE_API_KEY) {
    console.warn('Warning: CLAUDE_API_KEY environment variable not set');
  }
  if (!process.env.AUTH_SECRET) {
    console.warn('Warning: AUTH_SECRET environment variable not set');
  }
});

export default app; 