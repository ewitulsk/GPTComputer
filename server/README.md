# Claude API Wrapper Server

A TypeScript Express server that provides a simple wrapper around Anthropic's Claude API with Bearer token authentication.

## Features

- RESTful `/chat` endpoint for Claude API interaction
- Bearer token authentication using a shared secret
- CORS support for cross-origin requests
- Health check endpoint
- Docker support
- TypeScript with proper error handling

## Getting Started

### Prerequisites

- Node.js 18+ 
- npm or yarn
- Claude API key from Anthropic

### Installation

1. Install dependencies:
   ```bash
   npm install
   ```

2. Set up environment variables:
   ```bash
   cp env.example .env
   ```
   
   Edit `.env` and add your actual values:
   ```
   CLAUDE_API_KEY=sk-ant-api03-your-actual-api-key
   AUTH_SECRET=your-secure-secret
   PORT=3000
   ```

3. Build the project:
   ```bash
   npm run build
   ```

4. Start the server:
   ```bash
   npm start
   ```

   For development with hot reload:
   ```bash
   npm run dev
   ```

## API Usage

### Authentication

All requests to `/chat` require authentication via the `Authorization` header:

```
Authorization: Bearer your-secret-here
```

### Endpoints

#### Health Check
```
GET /health
```
Returns server status and timestamp.

#### Chat with Claude
```
POST /chat
Content-Type: application/json
Authorization: Bearer your-secret-here

{
  "message": "Hello, Claude!",
  "model": "claude-3-sonnet-20240229",
  "max_tokens": 1000
}
```

**Parameters:**
- `message` (required): The message to send to Claude
- `model` (optional): Claude model to use (defaults to claude-3-sonnet-20240229)
- `max_tokens` (optional): Maximum tokens in response (defaults to 1000)

**Response:**
```json
{
  "response": "Hello! How can I help you today?",
  "model": "claude-3-sonnet-20240229",
  "usage": {
    "input_tokens": 10,
    "output_tokens": 8
  }
}
```

### Example with curl

```bash
curl -X POST http://localhost:3000/chat \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer your-secret-here" \
  -d '{"message": "What is the capital of France?"}'
```

## Docker

### Build and run with Docker

```bash
# Build the image
docker build -t claude-api-wrapper .

# Run the container
docker run -p 3000:3000 --env-file .env claude-api-wrapper
```

### Using environment variables with Docker

```bash
docker run -p 3000:3000 \
  -e CLAUDE_API_KEY=your-api-key \
  -e AUTH_SECRET=your-secret \
  claude-api-wrapper
```

## Scripts

- `npm run build` - Build the TypeScript project
- `npm run start` - Start the production server
- `npm run dev` - Start the development server with hot reload
- `npm run clean` - Clean the build output

## Project Structure

```
src/
  index.ts      # Main server with Express app and Claude API integration
dist/           # Built output (generated)
Dockerfile      # Docker configuration
env.example     # Environment variables template
```

## Error Handling

The API returns appropriate HTTP status codes:

- `200` - Success
- `400` - Bad request (missing or invalid message)
- `401` - Unauthorized (missing or invalid authentication)
- `500` - Server error (Claude API errors or internal errors)

## Security

- Bearer token authentication using a shared secret
- Non-root user in Docker container
- CORS enabled for cross-origin requests
- Input validation for required fields

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `CLAUDE_API_KEY` | Yes | Your Anthropic Claude API key |
| `AUTH_SECRET` | Yes | Secret for basic authentication |
| `PORT` | No | Server port (default: 3000) 