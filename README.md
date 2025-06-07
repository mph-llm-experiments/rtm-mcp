# RTM MCP Server

A Model Context Protocol (MCP) server for Remember The Milk task management.

## Setup

1. Get your RTM API credentials:
   - API Key from https://www.rememberthemilk.com/services/api/keys.rtm
   - Shared Secret (provided with API key)

2. Configure Claude Desktop:
   ```json
   {
     "mcpServers": {
       "rtm-mcp": {
         "command": "/Users/mph/code/rtm-mcp/rtm-mcp.rb",
         "args": ["YOUR_API_KEY", "YOUR_SHARED_SECRET"]
       }
     }
   }
   ```

## Testing

```bash
# Basic connectivity test
./test-connection.rb [api-key] [shared-secret]

# Authentication verification
./test-auth.rb [api-key] [shared-secret]
```

## Features

- List management (create, read, update, delete)
- Task operations (CRUD with full metadata)
- Tags, priorities, due dates
- Search and filtering
- Notes and attachments

## API Reference

Based on Remember The Milk API: https://www.rememberthemilk.com/services/api/
