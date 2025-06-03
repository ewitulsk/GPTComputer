# TypeScript Server

A TypeScript Node.js server project.

## Getting Started

### Installation

```bash
npm install
```

### Development

Run the development server with hot reloading:

```bash
npm run dev
```

### Building

Compile TypeScript to JavaScript:

```bash
npm run build
```

### Production

Start the compiled server:

```bash
npm start
```

### Scripts

- `npm run dev` - Start development server with hot reloading
- `npm run build` - Compile TypeScript to JavaScript
- `npm run start` - Start the compiled server
- `npm run clean` - Remove the dist directory
- `npm test` - Run tests (not configured yet)

## Project Structure

```
server/
├── src/           # TypeScript source files
│   └── index.ts   # Main entry point
├── dist/          # Compiled JavaScript (generated)
├── package.json   # Project dependencies and scripts
├── tsconfig.json  # TypeScript configuration
└── README.md      # This file
```

## TypeScript Configuration

The project uses a strict TypeScript configuration with:
- ES2020 target
- CommonJS modules
- Strict type checking
- Source maps for debugging
- Declaration files generation 