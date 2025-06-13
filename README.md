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
- **Locations**: Set/clear locations from predefined RTM locations with 📍 display
- **URLs**: Set/clear task URLs with 🌐 display
- **Permalinks**: Generate RTM web interface links for tasks

#### Advanced Features
- **Recurrence**: Set and clear recurring task patterns
- **Subtasks**: Create and list subtasks (requires RTM Pro)
- **Search & Filtering**: List tasks with various filters and search criteria
- **Location Management**: List predefined locations and set task locations
- **Bulk Operations**: Move tasks between lists, batch tag operations

### ⚠️ Known Limitations

#### Subtasks
- **Create Subtask**: ✅ Works (requires RTM Pro account)
- **List Subtasks**: ⚠️ Workaround implementation (RTM API limitation)

## Implementation Status

The RTM MCP server now implements **comprehensive RTM functionality** including:
- ✅ All core task operations (CRUD, metadata, search)
- ✅ Location support with predefined location management
- ✅ URL and permalink functionality  
- ✅ Advanced features (recurrence, subtasks, bulk operations)
- ✅ Comprehensive error handling and user-friendly responses

The server provides nearly complete coverage of RTM's API functionality suitable for daily task management through Claude Desktop.

## Quick Setup

```bash
# 1. Get RTM API credentials from https://www.rememberthemilk.com/services/api/keys.rtm

# 2. Set up config
mkdir -p ~/.config/rtm-mcp
cp config.example ~/.config/rtm-mcp/config
# Edit ~/.config/rtm-mcp/config with your credentials

# 3. Get auth token
ruby test-scripts/rtm-auth-setup.rb your_api_key your_shared_secret
# Add the returned auth token to your config file

# 4. Add to Claude Desktop config
# See detailed instructions below
```

## Installation & Setup

### 1. Get RTM API Credentials

1. Visit https://www.rememberthemilk.com/services/api/keys.rtm
2. Request an API key and shared secret
3. Note your API key and shared secret

### 2. Set Up Authentication

Create your configuration file:

```bash
# Create config directory
mkdir -p ~/.config/rtm-mcp

# Copy template and edit with your credentials
cp config.example ~/.config/rtm-mcp/config
```

Edit `~/.config/rtm-mcp/config` with your RTM credentials:

```bash
# RTM MCP Configuration File

# RTM API Credentials  
# Get these from https://www.rememberthemilk.com/services/api/keys.rtm
RTM_API_KEY=your_rtm_api_key_here
RTM_SHARED_SECRET=your_rtm_shared_secret_here

# RTM Authentication Token
# This is generated after OAuth authentication with RTM
RTM_AUTH_TOKEN=your_rtm_auth_token_here
```

**Important**: You'll need to run the authentication setup script once to get your auth token:

```bash
ruby test-scripts/rtm-auth-setup.rb your_api_key your_shared_secret
```

This will guide you through RTM's OAuth flow and show you the auth token to add to your config file.

### 3. Configure Claude Desktop

Add to your Claude Desktop MCP settings (`~/Library/Application Support/Claude/claude_desktop_config.json`):

```json
{
  "mcpServers": {
    "rtm-mcp": {
      "command": "ruby",
      "args": ["/path/to/your/rtm-mcp.rb"]
    }
  }
}
```

Replace `/path/to/your/` with the actual path to your rtm-mcp directory.

**Note**: Credentials are automatically loaded from `~/.config/rtm-mcp/config` - no need to specify them in the Claude config.

### 4. Restart Claude Desktop

After adding the MCP configuration, restart Claude Desktop to load the RTM tools.

## Usage Examples

Once configured, you can use natural language with Claude:

```
"Create a task to review quarterly reports due next Friday"
"Show me all high priority tasks"
"Add a note to the 'Review Q4 budget' task"
"Set the estimate for 'Write documentation' to 2 hours"
"Set the location of 'Meet with client' to Downtown Office"
"Add the URL https://github.com/myproject to the 'Code review' task"
"Move all tasks tagged 'urgent' to my Work list"
"Mark the 'Buy groceries' task as complete"
"Show me what locations are available in RTM"
"Get a permalink for the 'Important meeting' task"
```

## Security Notes

### Credential Management
- **Configuration stored in** `~/.config/rtm-mcp/config` (standard user config location)
- **Config file permissions**: Ensure only you can read it (`chmod 600 ~/.config/rtm-mcp/config`)
- **Never commit API credentials** to any repository
- **Regenerate credentials** if you suspect they've been compromised
- **Alternative**: Use environment variables (`RTM_API_KEY`, `RTM_SHARED_SECRET`, `RTM_AUTH_TOKEN`) for deployment scenarios

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
2. **Pro features**: Some features (like subtasks) require RTM Pro subscription

### Minor Implementation Gaps
1. **Smart Add parsing**: Uses standard task creation instead of RTM's Smart Add syntax
2. **Contacts/Sharing**: RTM's contact and task sharing features not implemented
3. **Groups**: RTM group functionality not implemented

## Development & Testing

### File Structure
```
rtm-mcp/
├── rtm-mcp.rb              # Main MCP server (production)
├── README.md               # This file
├── config.example          # Configuration template
├── .gitignore             # Security configuration
└── test-scripts/          # Development and testing scripts
    ├── test-connection.rb # Basic connectivity test
    ├── rtm-auth-setup.rb  # Initial authentication setup
    ├── test-config-simple.rb # Test config loading
    └── [various other test scripts]

# User configuration (created by you)
~/.config/rtm-mcp/config   # Your RTM credentials
```

### Testing
Test your configuration and connectivity:
```bash
# Test config loading
ruby test-scripts/test-config-simple.rb

# Test RTM connectivity
ruby test-scripts/test-connection.rb
```

For environment variable testing:
```bash
RTM_API_KEY=your_key RTM_SHARED_SECRET=your_secret ruby test-scripts/test-config-simple.rb
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
- Check config file exists: `ls -la ~/.config/rtm-mcp/config`
- Test config loading: `ruby test-scripts/test-config-simple.rb`
- Re-run the auth setup script to get a fresh auth token
- Verify API key is active at RTM
- Try environment variables as alternative: `RTM_API_KEY=... RTM_SHARED_SECRET=... ./rtm-mcp.rb`

### Getting Help

1. Check RTM API documentation: https://www.rememberthemilk.com/services/api/
2. Verify your RTM account status and API limits
3. Test basic connectivity with the provided test scripts

## License

This project is for personal use with Remember The Milk's API. Respect RTM's terms of service and API usage guidelines.