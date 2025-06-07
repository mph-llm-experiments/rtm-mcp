# RTM MCP Server

A Model Context Protocol (MCP) server for Remember The Milk that provides comprehensive task management functionality through Claude Desktop.

## Overview

This MCP server enables Claude to interact with Remember The Milk tasks, lists, and metadata using natural language. It implements most RTM API functionality with user-friendly responses and proper error handling.

## Features

### ✅ Fully Implemented

#### Core Functionality
- **Connection Testing**: Verify API connectivity and auth status
- **List Management**: Create, list, and archive RTM lists
- **Task CRUD**: Create, read, update, delete tasks with full metadata support

#### Task Operations
- **Task Creation**: Create tasks in specific lists with natural language parsing
- **Task Completion**: Mark tasks complete (handles recurring tasks properly)
- **Task Deletion**: Permanently delete tasks (stops recurrence)
- **Task Moving**: Move tasks between lists
- **Task Postponing**: Postpone due dates

#### Task Metadata
- **Priorities**: Set high (1), medium (2), low (3), or no priority
- **Due Dates**: Set/clear due dates with natural language ("tomorrow", "next Friday", etc.)
- **Start Dates**: Set/clear start dates with natural language parsing
- **Time Estimates**: Set/clear time estimates ("30 minutes", "2 hours", etc.)
- **Tags**: Add and remove tags from tasks
- **Task Names**: Rename tasks
- **Notes**: Add, edit, delete, and read task notes

#### Advanced Features
- **Recurrence**: Set and clear recurring task patterns
- **Subtasks**: Create and list subtasks (requires RTM Pro)
- **Search & Filtering**: List tasks with various filters and search criteria

### ⚠️ Partial/Limited Support

#### Subtasks
- **Create Subtask**: ✅ Works (requires RTM Pro account)
- **List Subtasks**: ⚠️ Workaround implementation (RTM API limitation)

#### Missing Features
- Location metadata (not yet implemented)
- URL metadata (not yet implemented)
- Bulk/batch operations (not yet implemented)

## Installation & Setup

### 1. Get RTM API Credentials

1. Visit https://www.rememberthemilk.com/services/api/keys.rtm
2. Request an API key and shared secret
3. Note your API key and shared secret

### 2. Set Up Authentication

Create credential files in your project directory:

```bash
# Store your credentials (these files are gitignored)
echo "your_api_key_here" > .rtm_api_key
echo "your_shared_secret_here" > .rtm_shared_secret
```

**Important**: You'll need to run the authentication setup script once to get your auth token:

```bash
ruby test-scripts/rtm-auth-setup.rb $(cat .rtm_api_key) $(cat .rtm_shared_secret)
```

This will guide you through RTM's OAuth flow and create the `.rtm_auth_token` file.

### 3. Configure Claude Desktop

Add to your Claude Desktop MCP settings (`~/Library/Application Support/Claude/claude_desktop_config.json`):

```json
{
  "mcpServers": {
    "rtm-mcp": {
      "command": "ruby",
      "args": [
        "/path/to/your/rtm-mcp.rb",
        "$(cat /path/to/your/.rtm_api_key)",
        "$(cat /path/to/your/.rtm_shared_secret)"
      ]
    }
  }
}
```

Replace `/path/to/your/` with the actual path to your rtm-mcp directory.

### 4. Restart Claude Desktop

After adding the MCP configuration, restart Claude Desktop to load the RTM tools.

## Usage Examples

Once configured, you can use natural language with Claude:

```
"Create a task to review quarterly reports due next Friday"
"Show me all high priority tasks"
"Add a note to the 'Review Q4 budget' task"
"Set the estimate for 'Write documentation' to 2 hours"
"Move all tasks tagged 'urgent' to my Work list"
"Mark the 'Buy groceries' task as complete"
```

## Security Notes

### Credential Management
- **API credentials are stored in separate files** (`.rtm_api_key`, `.rtm_shared_secret`, `.rtm_auth_token`)
- **All credential files are gitignored** - they won't be committed to version control
- **Never commit API credentials** to any repository
- **Regenerate credentials** if you suspect they've been compromised

### Access Permissions
- The server has **full access** to your RTM account
- It can **create, modify, and delete** any tasks and lists
- **Test carefully** before using with important data

## API Implementation Details

### Rate Limiting
- Implements RTM's required 1 request/second rate limit
- Supports burst of up to 3 requests
- Automatic rate limit enforcement with sleep delays

### Error Handling
- Comprehensive error handling for all RTM API responses
- User-friendly error messages
- Proper handling of edge cases (empty lists, missing tasks, etc.)

### Data Handling
- **Timeline caching**: Avoids repeated timeline API calls
- **List name caching**: Provides user-friendly list names in responses
- **Natural language parsing**: Due dates, start dates, and estimates support human-friendly input
- **Array handling**: Properly handles RTM's array-wrapped single responses

### Technical Requirements
- **Three ID system**: Most task operations require `list_id`, `taskseries_id`, and `task_id`
- **API versioning**: Some features require specific RTM API versions
- **Parameter signing**: All API calls properly signed with MD5 hash

## Known Limitations

### RTM API Limitations
1. **Subtask listing**: RTM API doesn't provide direct subtask enumeration (our implementation uses a workaround)
2. **Bulk operations**: RTM API requires individual calls for each task operation
3. **Pro features**: Some features (like subtasks) require RTM Pro subscription

### Implementation Gaps
1. **Location metadata**: Not yet implemented (RTM supports this)
2. **URL metadata**: Not yet implemented (RTM supports this)
3. **Smart Add parsing**: Uses basic task creation instead of RTM's Smart Add syntax

### MCP Constraints
1. **Tool restart requirement**: New tools require Claude Desktop restart to register
2. **No persistent state**: Each MCP session starts fresh (uses RTM as source of truth)

## Development & Testing

### File Structure
```
rtm-mcp/
├── rtm-mcp.rb              # Main MCP server (production)
├── README.md               # This file
├── .gitignore             # Security configuration
├── .rtm_api_key           # Your API key (gitignored)
├── .rtm_shared_secret     # Your shared secret (gitignored)  
├── .rtm_auth_token        # Generated auth token (gitignored)
└── test-scripts/          # Development and testing scripts
    ├── test-connection.rb # Basic connectivity test
    ├── rtm-auth-setup.rb  # Initial authentication setup
    └── [various other test scripts]
```

### Testing
Run the basic connectivity test:
```bash
ruby test-scripts/test-connection.rb $(cat .rtm_api_key) $(cat .rtm_shared_secret)
```

### Contributing
When adding new features:
1. Create test scripts first
2. Test API functionality outside MCP
3. Implement MCP tool
4. Test via Claude Desktop
5. Update this README

## Troubleshooting

### Common Issues

**"Method not valid for requested version"**
- Some RTM API methods require specific API versions
- Our implementation handles this automatically

**"Timeline required"**  
- RTM write operations need a timeline
- Our implementation caches timelines automatically

**"Tool not found in Claude Desktop"**
- Restart Claude Desktop after configuration changes
- Verify MCP configuration file syntax

**Authentication issues**
- Re-run the auth setup script
- Check that credential files contain correct values
- Verify API key is active at RTM

### Getting Help

1. Check RTM API documentation: https://www.rememberthemilk.com/services/api/
2. Verify your RTM account status and API limits
3. Test basic connectivity with the provided test scripts

## License

This project is for personal use with Remember The Milk's API. Respect RTM's terms of service and API usage guidelines.