#!/usr/bin/env ruby

require 'json'
require 'net/http'
require 'uri'
require 'digest'
require 'time'
require 'optparse'

# HTTP server mode uses WEBrick (always available in Ruby)
HTTP_AVAILABLE = true

# Rate limiter to respect RTM's API limits
class RateLimiter
  def initialize(requests_per_second: 1, burst: 3)
    @requests_per_second = requests_per_second
    @burst = burst
    @min_interval = 1.0 / @requests_per_second
    @request_times = []
  end
  
  def wait_if_needed
    now = Time.now.to_f
    
    # Remove requests older than 1 second
    @request_times.reject! { |t| now - t > 1.0 }
    
    # If we've made burst requests in the last second, wait
    if @request_times.size >= @burst
      oldest_in_window = @request_times.first
      wait_time = (oldest_in_window + 1.0) - now
      if wait_time > 0
        STDERR.puts "[Rate limit] Waiting #{wait_time.round(2)}s..."
        sleep(wait_time)
      end
    end
    
    # Record this request
    @request_times << Time.now.to_f
  end
end

class RTMClient
  BASE_URL = 'https://api.rememberthemilk.com/services/rest/'
  
  def initialize(api_key, shared_secret)
    @api_key = api_key
    @shared_secret = shared_secret
    @rate_limiter = RateLimiter.new(requests_per_second: 1, burst: 3)
  end
  
  def call_method(method, params = {})
    # Add required parameters
    params[:method] = method
    params[:api_key] = @api_key
    params[:format] = 'json'
    
    # Add auth token if available and not an auth method
    unless method.start_with?('rtm.auth.') || method == 'rtm.test.echo'
      auth_token = load_auth_token
      params[:auth_token] = auth_token if auth_token
    end
    
    # Add timeline for write operations
    if requires_timeline?(method)
      timeline = get_timeline
      params[:timeline] = timeline if timeline
    end
    
    # Generate API signature
    params[:api_sig] = generate_signature(params)
    
    # Make request
    uri = URI(BASE_URL)
    uri.query = URI.encode_www_form(params)
    
    # Apply rate limiting
    @rate_limiter.wait_if_needed
    
    response = Net::HTTP.get_response(uri)
    
    if response.code == '200'
      JSON.parse(response.body)
    else
      { 'error' => "HTTP #{response.code}: #{response.message}" }
    end
  rescue => e
    { 'error' => "Request failed: #{e.message}" }
  end
  
  private
  
  def requires_timeline?(method)
    # Write operations that modify data require a timeline
    write_methods = %w[
      rtm.lists.add rtm.lists.archive rtm.lists.delete rtm.lists.setDefaultList 
      rtm.lists.setName rtm.lists.unarchive rtm.tasks.add rtm.tasks.addTags 
      rtm.tasks.complete rtm.tasks.delete rtm.tasks.movePriority rtm.tasks.moveTo 
      rtm.tasks.notes.add rtm.tasks.notes.delete rtm.tasks.notes.edit 
      rtm.tasks.postpone rtm.tasks.removeTags rtm.tasks.setDueDate 
      rtm.tasks.setEstimate rtm.tasks.setLocation rtm.tasks.setName 
      rtm.tasks.setParentTask rtm.tasks.setPriority rtm.tasks.setRecurrence 
      rtm.tasks.setStartDate rtm.tasks.setTags rtm.tasks.setURL rtm.tasks.uncomplete
    ]
    write_methods.include?(method)
  end
  
  def get_timeline
    return @timeline if @timeline
    
    # Get a new timeline
    result = call_method_without_timeline('rtm.timelines.create')
    @timeline = result.dig('rsp', 'timeline')
    @timeline
  end
  
  def call_method_without_timeline(method, params = {})
    # Internal method that doesn't add timeline (to avoid infinite recursion)
    params[:method] = method
    params[:api_key] = @api_key
    params[:format] = 'json'
    
    # Add auth token if available and not an auth method
    unless method.start_with?('rtm.auth.') || method == 'rtm.test.echo'
      auth_token = load_auth_token
      params[:auth_token] = auth_token if auth_token
    end
    
    # Generate API signature
    params[:api_sig] = generate_signature(params)
    
    # Make request
    uri = URI(BASE_URL)
    uri.query = URI.encode_www_form(params)
    
    # Apply rate limiting
    @rate_limiter.wait_if_needed
    
    response = Net::HTTP.get_response(uri)
    
    if response.code == '200'
      JSON.parse(response.body)
    else
      { 'error' => "HTTP #{response.code}: #{response.message}" }
    end
  rescue => e
    { 'error' => "Request failed: #{e.message}" }
  end
  
  def load_auth_token
    # First try environment variable (for containerized deployment)
    if ENV['RTM_AUTH_TOKEN'] && !ENV['RTM_AUTH_TOKEN'].empty?
      return ENV['RTM_AUTH_TOKEN'].strip
    end
    
    # Fall back to file-based token (for local development)
    token_file = File.join(__dir__, '.rtm_auth_token')
    return nil unless File.exist?(token_file)
    File.read(token_file).strip
  rescue
    nil
  end
  
  def generate_signature(params)
    # Sort parameters alphabetically and create signature string
    sorted_params = params.sort.map { |k, v| "#{k}#{v}" }.join
    signature_string = @shared_secret + sorted_params
    Digest::MD5.hexdigest(signature_string)
  end
end

class RTMMCPServer
  def initialize(api_key, shared_secret)
    @api_key = api_key
    @shared_secret = shared_secret
    
    unless @api_key && @shared_secret
      raise "Missing RTM API credentials"
    end
    
    @rtm = RTMClient.new(@api_key, @shared_secret)
    @list_cache = nil  # Cache for list information
    @tools = [
      {
        name: 'test_connection',
        description: 'Test basic connectivity to RTM API',
        inputSchema: {
          type: 'object',
          properties: {},
          required: []
        }
      },
      {
        name: 'list_all_lists',
        description: 'Get all RTM lists',
        inputSchema: {
          type: 'object',
          properties: {},
          required: []
        }
      },
      {
        name: 'create_list',
        description: 'Create a new RTM list',
        inputSchema: {
          type: 'object',
          properties: {
            name: {
              type: 'string',
              description: 'Name of the new list'
            }
          },
          required: ['name']
        }
      },
      {
        name: 'list_tasks',
        description: 'Get tasks from RTM with optional filtering',
        inputSchema: {
          type: 'object',
          properties: {
            list_id: {
              type: 'string',
              description: 'Filter by specific list ID (optional)'
            },
            filter: {
              type: 'string',
              description: 'RTM search filter (e.g., \'status:incomplete\', \'dueWithin:"1 week"\')'
            },
            show_ids: {
              type: 'boolean',
              description: 'Show task IDs for operations (default: false)'
            }
          },
          required: []
        }
      },
      {
        name: 'create_task',
        description: 'Create a new task in RTM with optional due date, priority, and tags',
        inputSchema: {
          type: 'object',
          properties: {
            name: {
              type: 'string',
              description: 'Task name'
            },
            list_id: {
              type: 'string',
              description: 'List ID to create task in (optional, uses default list if not specified)'
            },
            due: {
              type: 'string',
              description: 'Due date (optional, e.g., "today", "tomorrow", "next week", "June 15", "2025-06-20", "3pm", "tomorrow at 2pm")'
            },
            priority: {
              type: 'string',
              description: 'Priority level: 1 (High), 2 (Medium), 3 (Low), or empty string (None) (optional)',
              enum: ['1', '2', '3', '']
            },
            tags: {
              type: 'string',
              description: 'Comma-separated list of tags to add (optional)'
            }
          },
          required: ['name']
        }
      },
      {
        name: 'complete_task',
        description: 'Mark a task as complete',
        inputSchema: {
          type: 'object',
          properties: {
            list_id: {
              type: 'string',
              description: 'List ID containing the task'
            },
            taskseries_id: {
              type: 'string',
              description: 'Task series ID'
            },
            task_id: {
              type: 'string',
              description: 'Task ID'
            }
          },
          required: ['list_id', 'taskseries_id', 'task_id']
        }
      },
      {
        name: 'delete_task',
        description: 'Permanently delete a task (stops recurrence, unlike complete_task)',
        inputSchema: {
          type: 'object',
          properties: {
            list_id: {
              type: 'string',
              description: 'List ID containing the task'
            },
            taskseries_id: {
              type: 'string',
              description: 'Task series ID'
            },
            task_id: {
              type: 'string',
              description: 'Task ID'
            }
          },
          required: ['list_id', 'taskseries_id', 'task_id']
        }
      },
      {
        name: 'set_task_priority',
        description: 'Set the priority of a task',
        inputSchema: {
          type: 'object',
          properties: {
            list_id: {
              type: 'string',
              description: 'List ID containing the task'
            },
            taskseries_id: {
              type: 'string',
              description: 'Task series ID'
            },
            task_id: {
              type: 'string',
              description: 'Task ID'
            },
            priority: {
              type: 'string',
              description: 'Priority level: 1 (High), 2 (Medium), 3 (Low), or empty string (None)',
              enum: ['1', '2', '3', '']
            }
          },
          required: ['list_id', 'taskseries_id', 'task_id', 'priority']
        }
      },
      {
        name: 'add_task_tags',
        description: 'Add tags to a task',
        inputSchema: {
          type: 'object',
          properties: {
            list_id: {
              type: 'string',
              description: 'List ID containing the task'
            },
            taskseries_id: {
              type: 'string',
              description: 'Task series ID'
            },
            task_id: {
              type: 'string',
              description: 'Task ID'
            },
            tags: {
              type: 'string',
              description: 'Comma-separated list of tags to add'
            }
          },
          required: ['list_id', 'taskseries_id', 'task_id', 'tags']
        }
      },
      {
        name: 'remove_task_tags',
        description: 'Remove tags from a task',
        inputSchema: {
          type: 'object',
          properties: {
            list_id: {
              type: 'string',
              description: 'List ID containing the task'
            },
            taskseries_id: {
              type: 'string',
              description: 'Task series ID'
            },
            task_id: {
              type: 'string',
              description: 'Task ID'
            },
            tags: {
              type: 'string',
              description: 'Comma-separated list of tags to remove'
            }
          },
          required: ['list_id', 'taskseries_id', 'task_id', 'tags']
        }
      },
      {
        name: 'set_due_date',
        description: 'Set or update the due date of a task',
        inputSchema: {
          type: 'object',
          properties: {
            list_id: {
              type: 'string',
              description: 'List ID containing the task'
            },
            taskseries_id: {
              type: 'string',
              description: 'Task series ID'
            },
            task_id: {
              type: 'string',
              description: 'Task ID'
            },
            due: {
              type: 'string',
              description: 'Due date (e.g., "today", "tomorrow", "next week", "June 15", "2025-06-20", "3pm", "tomorrow at 2pm"). Use empty string to clear.'
            }
          },
          required: ['list_id', 'taskseries_id', 'task_id', 'due']
        }
      },
      {
        name: 'set_task_start_date',
        description: 'Set or update the start date of a task',
        inputSchema: {
          type: 'object',
          properties: {
            list_id: {
              type: 'string',
              description: 'List ID containing the task'
            },
            taskseries_id: {
              type: 'string',
              description: 'Task series ID'
            },
            task_id: {
              type: 'string',
              description: 'Task ID'
            },
            start: {
              type: 'string',
              description: 'Start date (e.g., "today", "tomorrow", "next week", "June 15", "2025-06-20", "3pm", "tomorrow at 2pm"). Use empty string to clear.'
            }
          },
          required: ['list_id', 'taskseries_id', 'task_id', 'start']
        }
      },
      {
        name: 'set_task_recurrence',
        description: 'Set or update recurrence rules for a task',
        inputSchema: {
          type: 'object',
          properties: {
            list_id: {
              type: 'string',
              description: 'List ID containing the task'
            },
            taskseries_id: {
              type: 'string',
              description: 'Task series ID'
            },
            task_id: {
              type: 'string',
              description: 'Task ID'
            },
            repeat: {
              type: 'string',
              description: 'Recurrence pattern (e.g., "every day", "every 2 weeks", "every month", "every monday", "every weekday", "after 1 week")'
            }
          },
          required: ['list_id', 'taskseries_id', 'task_id', 'repeat']
        }
      },
      {
        name: 'clear_task_recurrence',
        description: 'Clear/remove recurrence from a task',
        inputSchema: {
          type: 'object',
          properties: {
            list_id: {
              type: 'string',
              description: 'List ID containing the task'
            },
            taskseries_id: {
              type: 'string',
              description: 'Task series ID'
            },
            task_id: {
              type: 'string',
              description: 'Task ID'
            }
          },
          required: ['list_id', 'taskseries_id', 'task_id']
        }
      },
      {
        name: 'archive_list',
        description: 'Archive an RTM list',
        inputSchema: {
          type: 'object',
          properties: {
            list_id: {
              type: 'string',
              description: 'ID of the list to archive'
            }
          },
          required: ['list_id']
        }
      },
      {
        name: 'add_task_note',
        description: 'Add a note to a task',
        inputSchema: {
          type: 'object',
          properties: {
            list_id: {
              type: 'string',
              description: 'List ID containing the task'
            },
            taskseries_id: {
              type: 'string',
              description: 'Task series ID'
            },
            task_id: {
              type: 'string',
              description: 'Task ID'
            },
            text: {
              type: 'string',
              description: 'Note text content'
            },
            title: {
              type: 'string',
              description: 'Note title (optional)'
            }
          },
          required: ['list_id', 'taskseries_id', 'task_id', 'text']
        }
      },
      {
        name: 'edit_task_note',
        description: 'Edit an existing note on a task',
        inputSchema: {
          type: 'object',
          properties: {
            note_id: {
              type: 'string',
              description: 'Note ID to edit'
            },
            text: {
              type: 'string',
              description: 'New note text content'
            },
            title: {
              type: 'string',
              description: 'New note title (optional)'
            }
          },
          required: ['note_id', 'text']
        }
      },
      {
        name: 'delete_task_note',
        description: 'Delete a note from a task',
        inputSchema: {
          type: 'object',
          properties: {
            note_id: {
              type: 'string',
              description: 'Note ID to delete'
            }
          },
          required: ['note_id']
        }
      },
      {
        name: 'read_task_notes',
        description: 'Read all notes attached to a task',
        inputSchema: {
          type: 'object',
          properties: {
            list_id: {
              type: 'string',
              description: 'List ID containing the task'
            },
            taskseries_id: {
              type: 'string',
              description: 'Task series ID'
            },
            task_id: {
              type: 'string',
              description: 'Task ID'
            }
          },
          required: ['list_id', 'taskseries_id', 'task_id']
        }
      },
      {
        name: 'create_subtask',
        description: 'Create a new task as a subtask of an existing task (requires Pro account)',
        inputSchema: {
          type: 'object',
          properties: {
            name: {
              type: 'string',
              description: 'Name of the subtask'
            },
            parent_list_id: {
              type: 'string',
              description: 'List ID of the parent task'
            },
            parent_taskseries_id: {
              type: 'string',
              description: 'Task series ID of the parent task'
            },
            parent_task_id: {
              type: 'string',
              description: 'Task ID of the parent task'
            }
          },
          required: ['name', 'parent_list_id', 'parent_taskseries_id', 'parent_task_id']
        }
      },
      {
        name: 'list_subtasks',
        description: 'List all subtasks of a parent task (limited functionality - see output for details)',
        inputSchema: {
          type: 'object',
          properties: {
            parent_list_id: {
              type: 'string',
              description: 'List ID of the parent task'
            },
            parent_taskseries_id: {
              type: 'string',
              description: 'Task series ID of the parent task'
            },
            parent_name: {
              type: 'string',
              description: 'Name of the parent task (optional, helps identify subtasks)'
            }
          },
          required: ['parent_list_id', 'parent_taskseries_id']
        }
      },
      {
        name: 'move_task',
        description: 'Move a task to a different list',
        inputSchema: {
          type: 'object',
          properties: {
            list_id: {
              type: 'string',
              description: 'List ID containing the task'
            },
            taskseries_id: {
              type: 'string',
              description: 'Task series ID'
            },
            task_id: {
              type: 'string',
              description: 'Task ID'
            },
            to_list_id: {
              type: 'string',
              description: 'Destination list ID to move the task to'
            }
          },
          required: ['list_id', 'taskseries_id', 'task_id', 'to_list_id']
        }
      },
      {
        name: 'postpone_task',
        description: 'Postpone a task (delays the due date)',
        inputSchema: {
          type: 'object',
          properties: {
            list_id: {
              type: 'string',
              description: 'List ID containing the task'
            },
            taskseries_id: {
              type: 'string',
              description: 'Task series ID'
            },
            task_id: {
              type: 'string',
              description: 'Task ID'
            }
          },
          required: ['list_id', 'taskseries_id', 'task_id']
        }
      },
      {
        name: 'set_task_estimate',
        description: 'Set or clear the time estimate for a task',
        inputSchema: {
          type: 'object',
          properties: {
            list_id: {
              type: 'string',
              description: 'List ID containing the task'
            },
            taskseries_id: {
              type: 'string',
              description: 'Task series ID'
            },
            task_id: {
              type: 'string',
              description: 'Task ID'
            },
            estimate: {
              type: 'string',
              description: 'Time estimate (e.g., "30 minutes", "2 hours", "1 day", "30m", "2h", "1d") or empty string to clear'
            }
          },
          required: ['list_id', 'taskseries_id', 'task_id', 'estimate']
        }
      },
      {
        name: 'set_task_name',
        description: 'Rename a task',
        inputSchema: {
          type: 'object',
          properties: {
            list_id: {
              type: 'string',
              description: 'List ID containing the task'
            },
            taskseries_id: {
              type: 'string',
              description: 'Task series ID'
            },
            task_id: {
              type: 'string',
              description: 'Task ID'
            },
            name: {
              type: 'string',
              description: 'New name for the task'
            }
          },
          required: ['list_id', 'taskseries_id', 'task_id', 'name']
        }
      }
    ]
  end  
  def handle_request(request)
    case request['method']
    when 'initialize'
      # Get CF team domain from environment
      cf_team = ENV['CF_ACCESS_TEAM_DOMAIN'] || 'your-team.cloudflareaccess.com'
      
      # Return auth requirements per MCP spec
      { 
        protocolVersion: '2024-11-20',
        capabilities: { 
          tools: {}
        },
        serverInfo: { 
          name: 'rtm-mcp', 
          version: '0.1.0'
        },
        # Auth info at top level of response
        auth: {
          type: "oauth2",
          authorization_url: "https://#{cf_team}/cdn-cgi/access/authorize",
          token_url: "https://#{cf_team}/cdn-cgi/access/token",
          scopes: ["email"]
        }
      }
    when 'tools/list'
      { tools: @tools }
    when 'tools/call'
      handle_tool_call(request['params'])
    when 'notifications/initialized'
      # Client notification that initialization is complete
      nil
    else
      { error: { code: -32601, message: 'Method not found' } }
    end
  end
  
  private
  
  def handle_tool_call(params)
    tool_name = params['name']
    args = params['arguments'] || {}
    
    result = case tool_name
    when 'test_connection'
      test_connection
    when 'list_all_lists'
      list_all_lists
    when 'create_list'
      create_list(args['name'])
    when 'list_tasks'
      list_tasks(args['list_id'], args['filter'], args['show_ids'])
    when 'create_task'
      create_task(args['name'], args['list_id'], args['due'], args['priority'], args['tags'])
    when 'complete_task'
      complete_task(args['list_id'], args['taskseries_id'], args['task_id'])
    when 'delete_task'
      delete_task(args['list_id'], args['taskseries_id'], args['task_id'])
    when 'set_task_priority'
      set_task_priority(args['list_id'], args['taskseries_id'], args['task_id'], args['priority'])
    when 'add_task_tags'
      add_task_tags(args['list_id'], args['taskseries_id'], args['task_id'], args['tags'])
    when 'remove_task_tags'
      remove_task_tags(args['list_id'], args['taskseries_id'], args['task_id'], args['tags'])
    when 'set_due_date'
      set_due_date(args['list_id'], args['taskseries_id'], args['task_id'], args['due'])
    when 'set_task_start_date'
      set_task_start_date(args['list_id'], args['taskseries_id'], args['task_id'], args['start'])
    when 'set_task_recurrence'
      set_task_recurrence(args['list_id'], args['taskseries_id'], args['task_id'], args['repeat'])
    when 'clear_task_recurrence'
      clear_task_recurrence(args['list_id'], args['taskseries_id'], args['task_id'])
    when 'archive_list'
      archive_list(args['list_id'])
    when 'add_task_note'
      add_task_note(args['list_id'], args['taskseries_id'], args['task_id'], args['text'], args['title'])
    when 'edit_task_note'
      edit_task_note(args['note_id'], args['text'], args['title'])
    when 'delete_task_note'
      delete_task_note(args['note_id'])
    when 'read_task_notes'
      read_task_notes(args['list_id'], args['taskseries_id'], args['task_id'])
    when 'create_subtask'
      create_subtask(args['name'], args['parent_list_id'], args['parent_taskseries_id'], args['parent_task_id'])
    when 'list_subtasks'
      list_subtasks(args['parent_list_id'], args['parent_taskseries_id'], args['parent_name'])
    when 'move_task'
      move_task(args['list_id'], args['taskseries_id'], args['task_id'], args['to_list_id'])
    when 'postpone_task'
      postpone_task(args['list_id'], args['taskseries_id'], args['task_id'])
    when 'set_task_estimate'
      set_task_estimate(args['list_id'], args['taskseries_id'], args['task_id'], args['estimate'])
    when 'set_task_name'
      set_task_name(args['list_id'], args['taskseries_id'], args['task_id'], args['name'])
    else
      return { error: { code: -32602, message: "Unknown tool: #{tool_name}" } }
    end
    
    { content: [{ type: 'text', text: result }] }
  end
  
  def test_connection
    result = @rtm.call_method('rtm.test.echo', { test: 'hello' })
    
    if result['error'] || result.dig('rsp', 'stat') == 'fail'
      error_msg = result['error'] || result.dig('rsp', 'err', 'msg') || 'Unknown error'
      "❌ RTM API Error: #{error_msg}"
    else
      "✅ RTM API connection successful!\n\nResponse: #{JSON.pretty_generate(result)}"
    end
  end
  
  def list_all_lists
    result = @rtm.call_method('rtm.lists.getList')
    
    if result['error'] || result.dig('rsp', 'stat') == 'fail'
      error_msg = result['error'] || result.dig('rsp', 'err', 'msg') || 'Unknown error'
      "❌ RTM API Error: #{error_msg}"
    else
      lists = result.dig('rsp', 'lists', 'list') || []
      lists = [lists] unless lists.is_a?(Array)  # Handle single list case
      
      list_text = lists.map do |list|
        "• #{list['name']} (ID: #{list['id']})" + 
        (list['archived'] == '1' ? ' [archived]' : '') +
        (list['smart'] == '1' ? ' [smart]' : '')
      end.join("\n")
      
      "📝 RTM Lists:\n\n#{list_text}"
    end
  end
  
  def create_list(name)
    return "Error: List name is required" unless name && !name.empty?
    
    result = @rtm.call_method('rtm.lists.add', { name: name })
    
    if result['error'] || result.dig('rsp', 'stat') == 'fail'
      error_msg = result['error'] || result.dig('rsp', 'err', 'msg') || 'Unknown error'
      "❌ RTM API Error: #{error_msg}"
    else
      list = result.dig('rsp', 'list')
      if list
        "✅ Created list: #{list['name']} (ID: #{list['id']})"
      else
        "❌ List created but couldn't parse response"
      end
    end
  end
  
  def list_tasks(list_id = nil, filter = nil, show_ids = false)
    params = { v: '2' }  # Use API v2 to get parent_task_id fields
    params[:list_id] = list_id if list_id
    params[:filter] = filter if filter && !filter.empty?
    
    result = @rtm.call_method('rtm.tasks.getList', params)
    
    if result['error'] || result.dig('rsp', 'stat') == 'fail'
      error_msg = result['error'] || result.dig('rsp', 'err', 'msg') || 'Unknown error'
      "❌ RTM API Error: #{error_msg}"
    else
      # Check if we have any results
      lists = result.dig('rsp', 'tasks', 'list')
      has_results = false
      task_count = 0
      
      if lists
        lists_array = lists.is_a?(Array) ? lists : [lists]
        lists_array.each do |list|
          if list['taskseries']
            taskseries = list['taskseries']
            taskseries = [taskseries] unless taskseries.is_a?(Array)
            task_count += taskseries.length
            has_results = true
          end
        end
      end
      
      # If no results and we had a filter, try auto-expanding
      if !has_results && filter && !filter.empty?
        # Try different expansion strategies
        expanded_filter = nil
        original_filter = filter
        
        # Strategy 1: If filter has AND conditions, try removing restrictive parts
        if filter.include?(' AND ')
          # Try keeping only status:incomplete if present
          if filter.include?('status:incomplete')
            expanded_filter = 'status:incomplete'
          else
            # Otherwise just take the first condition
            expanded_filter = filter.split(' AND ').first
          end
        # Strategy 2: If searching by tag, try removing tag filter
        elsif filter.start_with?('tag:')
          expanded_filter = 'status:incomplete'
        # Strategy 3: For other filters, try showing all incomplete tasks
        elsif filter != 'status:incomplete'
          expanded_filter = 'status:incomplete'
        end
        
        # If we have an expanded filter different from original, try it
        if expanded_filter && expanded_filter != original_filter
          expanded_params = { v: '2' }
          expanded_params[:list_id] = list_id if list_id
          expanded_params[:filter] = expanded_filter
          
          expanded_result = @rtm.call_method('rtm.tasks.getList', expanded_params)
          
          if expanded_result.dig('rsp', 'stat') == 'ok'
            # Get list of parent task IDs with expanded search
            parent_task_ids = get_parent_task_ids(list_id, expanded_filter)
            
            # Format with auto-expand note
            expanded_lists = expanded_result.dig('rsp', 'tasks', 'list')
            if expanded_lists
              # Check if expanded search has results
              expanded_task_count = 0
              expanded_lists_array = expanded_lists.is_a?(Array) ? expanded_lists : [expanded_lists]
              expanded_lists_array.each do |list|
                if list['taskseries']
                  taskseries = list['taskseries']
                  taskseries = [taskseries] unless taskseries.is_a?(Array)
                  expanded_task_count += taskseries.length
                end
              end
              
              if expanded_task_count > 0
                expanded_output = format_tasks(expanded_result, parent_task_ids, show_ids)
                return "📋 **Auto-expanded search**\n" +
                       "No tasks matched filter: `#{original_filter}`\n" +
                       "Showing results for: `#{expanded_filter}`\n\n" +
                       expanded_output
              end
            end
          end
        end
      end
      
      # Get list of parent task IDs (tasks that have subtasks)
      parent_task_ids = get_parent_task_ids(list_id, filter)
      format_tasks(result, parent_task_ids, show_ids)
    end
  end
  
  # Helper method to get list name by ID with caching
  def get_list_name(list_id)
    return "Default List" if list_id.nil? || list_id.empty?
    
    # Load list cache if not already loaded
    if @list_cache.nil?
      result = @rtm.call_method('rtm.lists.getList')
      
      if result['error'] || result.dig('rsp', 'stat') == 'fail'
        return "Unknown List"
      else
        lists = result.dig('rsp', 'lists', 'list') || []
        lists = [lists] unless lists.is_a?(Array)  # Handle single list case
        
        # Create a hash for fast lookup: list_id -> list_name
        @list_cache = {}
        lists.each { |list| @list_cache[list['id']] = list['name'] }
      end
    end
    
    # Look up the list name in cache
    @list_cache[list_id] || "Unknown List"
  rescue
    "Unknown List"
  end
  
  def create_task(name, list_id = nil, due = nil, priority = nil, tags = nil)
    return "Error: Task name is required" unless name && !name.empty?
    
    # Build Smart Add text with all metadata in one string
    smart_add_text = name.dup
    
    # Add due date to Smart Add text
    if due && !due.empty?
      smart_add_text += " ^#{due}"
    end
    
    # Add priority to Smart Add text  
    if priority && !priority.empty?
      case priority
      when '1'
        smart_add_text += " !1"
      when '2' 
        smart_add_text += " !2"
      when '3'
        smart_add_text += " !3"
      end
    end
    
    # Add tags to Smart Add text
    if tags && !tags.empty?
      tag_list = tags.split(',').map(&:strip)
      tag_list.each { |tag| smart_add_text += " ##{tag}" }
    end
    
    # Create task using Smart Add with parse=1
    params = { 
      name: smart_add_text,
      parse: 1  # Enable Smart Add parsing (integer, not string)
    }
    params[:list_id] = list_id if list_id && !list_id.empty?
    
    result = @rtm.call_method('rtm.tasks.add', params)
    
    if result['error'] || result.dig('rsp', 'stat') == 'fail'
      error_msg = result['error'] || result.dig('rsp', 'err', 'msg') || 'Unknown error'
      return "❌ RTM API Error: #{error_msg}"
    end
    
    # Extract the created task info
    list = result.dig('rsp', 'list')
    taskseries = list&.dig('taskseries')
    
    # Handle case where taskseries is an array
    if taskseries.is_a?(Array)
      task = taskseries.first
    else
      task = taskseries
    end
    
    if !task
      return "❌ Task created but couldn't parse response"
    end
    
    task_name = task['name'] || name
    actual_list_id = list['id']
    list_name = get_list_name(actual_list_id)
    task_obj = task['task']
    task_id = task_obj.is_a?(Array) ? task_obj[0]['id'] : task_obj['id']
    taskseries_id = task['id']
    
    # Build response showing what was applied
    response_parts = ["✅ Created task: #{task_name} in #{list_name}"]
    response_parts << "   IDs: list=#{actual_list_id}, series=#{taskseries_id}, task=#{task_id}"
    
    # Show applied metadata by inspecting the created task
    metadata_applied = []
    
    # Check if due date was applied
    if task_obj.is_a?(Array)
      first_task = task_obj[0]
    else
      first_task = task_obj
    end
    
    if first_task['due'] && !first_task['due'].empty?
      has_time = first_task['has_due_time'] == '1'
      time_info = has_time ? " (includes time)" : " (date only)"
      metadata_applied << "📅 Due: #{first_task['due']}#{time_info}"
    end
    
    # Check if priority was applied
    if first_task['priority'] && !first_task['priority'].empty? && first_task['priority'] != 'N'
      priority_display = case first_task['priority']
      when '1' then '🔴 High'
      when '2' then '🟡 Medium'
      when '3' then '🔵 Low'
      else first_task['priority']
      end
      metadata_applied << "Priority: #{priority_display}"
    end
    
    # Check if tags were applied
    if task['tags'] && task['tags']['tag']
      applied_tags = task['tags']['tag']
      applied_tags = [applied_tags] unless applied_tags.is_a?(Array)
      if applied_tags.any?
        metadata_applied << "🏷️ Tags: #{applied_tags.join(', ')}"
      end
    end
    
    # Add metadata info to response
    if metadata_applied.any?
      response_parts.concat(metadata_applied)
    end
    
    response_parts.join("\n")
  end
  
  def complete_task(list_id, taskseries_id, task_id)
    unless list_id && taskseries_id && task_id
      return "Error: list_id, taskseries_id, and task_id are required"
    end
    
    params = {
      list_id: list_id,
      taskseries_id: taskseries_id,
      task_id: task_id
    }
    
    result = @rtm.call_method('rtm.tasks.complete', params)
    
    if result['error'] || result.dig('rsp', 'stat') == 'fail'
      error_msg = result['error'] || result.dig('rsp', 'err', 'msg') || 'Unknown error'
      "❌ RTM API Error: #{error_msg}"
    else
      "✅ Task completed successfully!"
    end
  end
  
  def delete_task(list_id, taskseries_id, task_id)
    unless list_id && taskseries_id && task_id
      return "Error: list_id, taskseries_id, and task_id are required"
    end
    
    params = {
      list_id: list_id,
      taskseries_id: taskseries_id,
      task_id: task_id
    }
    
    result = @rtm.call_method('rtm.tasks.delete', params)
    
    if result['error'] || result.dig('rsp', 'stat') == 'fail'
      error_msg = result['error'] || result.dig('rsp', 'err', 'msg') || 'Unknown error'
      "❌ RTM API Error: #{error_msg}"
    else
      "✅ Task deleted permanently!"
    end
  end
  
  def set_task_priority(list_id, taskseries_id, task_id, priority)
    unless list_id && taskseries_id && task_id && priority != nil
      return "Error: list_id, taskseries_id, task_id, and priority are required"
    end
    
    # Validate priority value
    unless ['1', '2', '3', ''].include?(priority)
      return "Error: Priority must be '1' (High), '2' (Medium), '3' (Low), or '' (None)"
    end
    
    params = {
      list_id: list_id,
      taskseries_id: taskseries_id,
      task_id: task_id,
      priority: priority
    }
    
    result = @rtm.call_method('rtm.tasks.setPriority', params)
    
    if result['error'] || result.dig('rsp', 'stat') == 'fail'
      error_msg = result['error'] || result.dig('rsp', 'err', 'msg') || 'Unknown error'
      "❌ RTM API Error: #{error_msg}"
    else
      # Extract priority from response
      list_data = result.dig('rsp', 'list')
      if list_data
        list_data = list_data.first if list_data.is_a?(Array)
        
        taskseries = list_data['taskseries']
        if taskseries
          taskseries = taskseries.first if taskseries.is_a?(Array)
          task = taskseries['task']
          task = task.first if task.is_a?(Array)
          
          priority_display = case task['priority']
          when '1' then '🔴 High'
          when '2' then '🟡 Medium'
          when '3' then '🔵 Low'
          when 'N' then 'None'
          else task['priority']
          end
          
          "✅ Task priority set to: #{priority_display}"
        else
          "✅ Task priority updated successfully!"
        end
      else
        "✅ Task priority updated successfully!"
      end
    end
  end
  
  def add_task_tags(list_id, taskseries_id, task_id, tags)
    unless list_id && taskseries_id && task_id && tags && !tags.empty?
      return "Error: list_id, taskseries_id, task_id, and tags are required"
    end
    
    params = {
      list_id: list_id,
      taskseries_id: taskseries_id,
      task_id: task_id,
      tags: tags
    }
    
    result = @rtm.call_method('rtm.tasks.addTags', params)
    
    if result['error'] || result.dig('rsp', 'stat') == 'fail'
      error_msg = result['error'] || result.dig('rsp', 'err', 'msg') || 'Unknown error'
      "❌ RTM API Error: #{error_msg}"
    else
      # Extract tags from response
      list_data = result.dig('rsp', 'list')
      if list_data
        list_data = list_data.first if list_data.is_a?(Array)
        
        taskseries = list_data['taskseries']
        if taskseries
          taskseries = taskseries.first if taskseries.is_a?(Array)
          
          tags_data = []
          if taskseries['tags']
            if taskseries['tags'].is_a?(Array)
              tags_data = taskseries['tags']
            elsif taskseries['tags'].is_a?(Hash) && taskseries['tags']['tag']
              tag_array = taskseries['tags']['tag']
              tags_data = tag_array.is_a?(Array) ? tag_array : [tag_array]
            end
          end
          
          tag_display = tags_data.empty? ? "none" : tags_data.join(", ")
          "✅ Tags added! Current tags: #{tag_display}"
        else
          "✅ Tags added successfully!"
        end
      else
        "✅ Tags added successfully!"
      end
    end
  end
  
  def remove_task_tags(list_id, taskseries_id, task_id, tags)
    unless list_id && taskseries_id && task_id && tags && !tags.empty?
      return "Error: list_id, taskseries_id, task_id, and tags are required"
    end
    
    params = {
      list_id: list_id,
      taskseries_id: taskseries_id,
      task_id: task_id,
      tags: tags
    }
    
    result = @rtm.call_method('rtm.tasks.removeTags', params)
    
    if result['error'] || result.dig('rsp', 'stat') == 'fail'
      error_msg = result['error'] || result.dig('rsp', 'err', 'msg') || 'Unknown error'
      "❌ RTM API Error: #{error_msg}"
    else
      # Extract remaining tags from response
      list_data = result.dig('rsp', 'list')
      if list_data
        list_data = list_data.first if list_data.is_a?(Array)
        
        taskseries = list_data['taskseries']
        if taskseries
          taskseries = taskseries.first if taskseries.is_a?(Array)
          
          tags_data = []
          if taskseries['tags']
            if taskseries['tags'].is_a?(Array)
              tags_data = taskseries['tags']
            elsif taskseries['tags'].is_a?(Hash) && taskseries['tags']['tag']
              tag_array = taskseries['tags']['tag']
              tags_data = tag_array.is_a?(Array) ? tag_array : [tag_array]
            end
          end
          
          tag_display = tags_data.empty? ? "none" : tags_data.join(", ")
          "✅ Tags removed! Current tags: #{tag_display}"
        else
          "✅ Tags removed successfully!"
        end
      else
        "✅ Tags removed successfully!"
      end
    end
  end
  
  def set_due_date(list_id, taskseries_id, task_id, due)
    unless list_id && taskseries_id && task_id && due != nil
      return "Error: list_id, taskseries_id, task_id, and due are required"
    end
    
    params = {
      list_id: list_id,
      taskseries_id: taskseries_id,
      task_id: task_id,
      due: due,
      parse: '1'  # Enable natural language parsing
    }
    
    result = @rtm.call_method('rtm.tasks.setDueDate', params)
    
    if result['error'] || result.dig('rsp', 'stat') == 'fail'
      error_msg = result.dig('rsp', 'err', 'msg') || result['error'] || 'Unknown error'
      return "Error setting due date: #{error_msg}"
    end
    
    # Extract updated task info
    list = result.dig('rsp', 'list')
    taskseries = list&.dig('taskseries')
    
    if taskseries
      # Handle taskseries being an array
      ts = taskseries.is_a?(Array) ? taskseries[0] : taskseries
      task = ts['task']
      task = task.is_a?(Array) ? task[0] : task
      
      task_name = ts['name']
      
      if due.empty?
        "✅ Due date cleared for: #{task_name}"
      else
        due_value = task['due']
        has_time = task['has_due_time'] == '1'
        
        if due_value && !due_value.empty?
          time_info = has_time ? " (includes time)" : " (date only)"
          "✅ Due date set for: #{task_name}\n📅 Due: #{due_value}#{time_info}"
        else
          "✅ Due date updated for: #{task_name}"
        end
      end
    else
      if due.empty?
        "✅ Due date cleared successfully!"
      else
        "✅ Due date set successfully!"
      end
    end
  end
  
  def set_task_start_date(list_id, taskseries_id, task_id, start)
    unless list_id && taskseries_id && task_id && start != nil
      return "Error: list_id, taskseries_id, task_id, and start are required"
    end
    
    params = {
      list_id: list_id,
      taskseries_id: taskseries_id,
      task_id: task_id,
      start: start,
      parse: '1',  # Enable natural language parsing
      v: '2'       # API version 2 required for setStartDate
    }
    
    result = @rtm.call_method('rtm.tasks.setStartDate', params)
    
    if result['error'] || result.dig('rsp', 'stat') == 'fail'
      error_msg = result.dig('rsp', 'err', 'msg') || result['error'] || 'Unknown error'
      return "Error setting start date: #{error_msg}"
    end
    
    # Extract updated task info
    list = result.dig('rsp', 'list')
    taskseries = list&.dig('taskseries')
    
    if taskseries
      # Handle taskseries being an array
      ts = taskseries.is_a?(Array) ? taskseries[0] : taskseries
      task = ts['task']
      task = task.is_a?(Array) ? task[0] : task
      
      task_name = ts['name']
      
      if start.empty?
        "✅ Start date cleared for: #{task_name}"
      else
        start_value = task['start']
        has_time = task['has_start_time'] == '1'
        
        if start_value && !start_value.empty?
          time_info = has_time ? " (includes time)" : " (date only)"
          "✅ Start date set for: #{task_name}\n🏁 Start: #{start_value}#{time_info}"
        else
          "✅ Start date updated for: #{task_name}"
        end
      end
    else
      if start.empty?
        "✅ Start date cleared successfully!"
      else
        "✅ Start date set successfully!"
      end
    end
  end
  
  def set_task_estimate(list_id, taskseries_id, task_id, estimate)
    unless list_id && taskseries_id && task_id && estimate != nil
      return "Error: list_id, taskseries_id, task_id, and estimate are required"
    end
    
    params = {
      list_id: list_id,
      taskseries_id: taskseries_id,
      task_id: task_id,
      estimate: estimate
    }
    
    result = @rtm.call_method('rtm.tasks.setEstimate', params)
    
    if result['error'] || result.dig('rsp', 'stat') == 'fail'
      error_msg = result.dig('rsp', 'err', 'msg') || result['error'] || 'Unknown error'
      return "Error setting estimate: #{error_msg}"
    end
    
    # Extract updated task info
    list = result.dig('rsp', 'list')
    taskseries = list&.dig('taskseries')
    
    if taskseries
      # Handle taskseries being an array
      ts = taskseries.is_a?(Array) ? taskseries[0] : taskseries
      task = ts['task']
      task = task.is_a?(Array) ? task[0] : task
      
      task_name = ts['name']
      
      if estimate.empty?
        "✅ Estimate cleared for: #{task_name}"
      else
        estimate_value = task['estimate']
        "✅ Estimate set for: #{task_name}\n⏱️ Estimate: #{estimate_value}"
      end
    else
      if estimate.empty?
        "✅ Estimate cleared successfully!"
      else
        "✅ Estimate set successfully!"
      end
    end
  end

  def set_task_name(list_id, taskseries_id, task_id, name)
    unless list_id && taskseries_id && task_id && name
      return "Error: list_id, taskseries_id, task_id, and name are required"
    end
    
    params = {
      list_id: list_id,
      taskseries_id: taskseries_id,
      task_id: task_id,
      name: name
    }
    
    result = @rtm.call_method('rtm.tasks.setName', params)
    
    if result['error'] || result.dig('rsp', 'stat') == 'fail'
      error_msg = result.dig('rsp', 'err', 'msg') || result['error'] || 'Unknown error'
      return "Error renaming task: #{error_msg}"
    end
    
    # Extract updated task info
    list = result.dig('rsp', 'list')
    taskseries = list&.dig('taskseries')
    
    if taskseries
      # Handle taskseries being an array
      ts = taskseries.is_a?(Array) ? taskseries[0] : taskseries
      new_name = ts['name']
      
      "✅ Task renamed to: #{new_name}"
    else
      "✅ Task renamed successfully!"
    end
  end

  def set_task_recurrence(list_id, taskseries_id, task_id, repeat)
    unless list_id && taskseries_id && task_id && repeat
      return "Error: list_id, taskseries_id, task_id, and repeat pattern are required"
    end
    
    params = {
      list_id: list_id,
      taskseries_id: taskseries_id,
      task_id: task_id,
      repeat: repeat
    }
    
    result = @rtm.call_method('rtm.tasks.setRecurrence', params)
    
    if result['error'] || result.dig('rsp', 'stat') == 'fail'
      error_msg = result.dig('rsp', 'err', 'msg') || result['error'] || 'Unknown error'
      return "Error setting recurrence: #{error_msg}"
    end
    
    # Extract updated task info
    list = result.dig('rsp', 'list')
    taskseries = list&.dig('taskseries')
    
    if taskseries
      # Handle taskseries being an array
      ts = taskseries.is_a?(Array) ? taskseries[0] : taskseries
      task_name = ts['name']
      rrule = ts['rrule']
      
      if rrule && rrule['$t']
        every_value = rrule['every']
        if every_value == '0'
          "✅ Recurrence set for: #{task_name}\n🔄 Pattern: #{repeat} (after completion)\n📋 RRULE: #{rrule['$t']}"
        else
          "✅ Recurrence set for: #{task_name}\n🔄 Pattern: #{repeat}\n📋 RRULE: #{rrule['$t']}"
        end
      else
        "✅ Recurrence updated for: #{task_name}"
      end
    else
      "✅ Recurrence set successfully!"
    end
  end
  
  def clear_task_recurrence(list_id, taskseries_id, task_id)
    unless list_id && taskseries_id && task_id
      return "Error: list_id, taskseries_id, and task_id are required"
    end
    
    params = {
      list_id: list_id,
      taskseries_id: taskseries_id,
      task_id: task_id
    }
    
    result = @rtm.call_method('rtm.tasks.setRecurrence', params)
    
    if result['error'] || result.dig('rsp', 'stat') == 'fail'
      error_msg = result.dig('rsp', 'err', 'msg') || result['error'] || 'Unknown error'
      return "Error clearing recurrence: #{error_msg}"
    end
    
    # Extract updated task info
    list = result.dig('rsp', 'list')
    taskseries = list&.dig('taskseries')
    
    if taskseries
      # Handle taskseries being an array
      ts = taskseries.is_a?(Array) ? taskseries[0] : taskseries
      task_name = ts['name']
      rrule = ts['rrule']
      
      if rrule && rrule['$t'] && !rrule['$t'].empty?
        "❌ Recurrence still active for: #{task_name}\n📋 RRULE: #{rrule['$t']}"
      else
        "✅ Recurrence cleared for: #{task_name}"
      end
    else
      "✅ Recurrence cleared successfully!"
    end
  end
  
  def archive_list(list_id)
    return "Error: List ID is required" unless list_id && !list_id.empty?
    
    result = @rtm.call_method('rtm.lists.archive', { list_id: list_id })
    
    if result['error'] || result.dig('rsp', 'stat') == 'fail'
      error_msg = result['error'] || result.dig('rsp', 'err', 'msg') || 'Unknown error'
      "❌ RTM API Error: #{error_msg}"
    else
      list = result.dig('rsp', 'list')
      if list
        "✅ Archived list: #{list['name']} (ID: #{list['id']})"
      else
        "✅ List archived successfully!"
      end
    end
  end
  
  def add_task_note(list_id, taskseries_id, task_id, text, title = nil)
    return "Error: List ID, taskseries ID, task ID and text are required" unless list_id && taskseries_id && task_id && text
    
    params = {
      list_id: list_id,
      taskseries_id: taskseries_id,
      task_id: task_id,
      note_text: text
    }
    params[:note_title] = title if title && !title.empty?
    
    result = @rtm.call_method('rtm.tasks.notes.add', params)
    
    if result['error'] || result.dig('rsp', 'stat') == 'fail'
      error_msg = result['error'] || result.dig('rsp', 'err', 'msg') || 'Unknown error'
      "❌ RTM API Error: #{error_msg}"
    else
      note = result.dig('rsp', 'note')
      if note
        title_display = note['title'] && !note['title'].empty? ? note['title'] : '(No title)'
        text_preview = note['$t'] ? note['$t'].split("\n").first[0..50] : ''
        text_preview += '...' if note['$t'] && note['$t'].length > 50
        
        "✅ Note added successfully!\n📝 Title: #{title_display}\n📄 Text: #{text_preview}\n🆔 Note ID: #{note['id']}"
      else
        "✅ Note added successfully!"
      end
    end
  end
  
  def edit_task_note(note_id, text, title = nil)
    return "Error: Note ID and text are required" unless note_id && text
    
    params = {
      note_id: note_id,
      note_text: text
    }
    params[:note_title] = title if title && !title.empty?
    
    result = @rtm.call_method('rtm.tasks.notes.edit', params)
    
    if result['error'] || result.dig('rsp', 'stat') == 'fail'
      error_msg = result['error'] || result.dig('rsp', 'err', 'msg') || 'Unknown error'
      "❌ RTM API Error: #{error_msg}"
    else
      note = result.dig('rsp', 'note')
      if note
        title_display = note['title'] && !note['title'].empty? ? note['title'] : '(No title)'
        text_preview = note['$t'] ? note['$t'].split("\n").first[0..50] : ''
        text_preview += '...' if note['$t'] && note['$t'].length > 50
        
        "✅ Note updated successfully!\n📝 Title: #{title_display}\n📄 Text: #{text_preview}"
      else
        "✅ Note updated successfully!"
      end
    end
  end
  
  def delete_task_note(note_id)
    return "Error: Note ID is required" unless note_id && !note_id.empty?
    
    result = @rtm.call_method('rtm.tasks.notes.delete', { note_id: note_id })
    
    if result['error'] || result.dig('rsp', 'stat') == 'fail'
      error_msg = result['error'] || result.dig('rsp', 'err', 'msg') || 'Unknown error'
      "❌ RTM API Error: #{error_msg}"
    else
      "✅ Note deleted successfully!"
    end
  end
  
  def read_task_notes(list_id, taskseries_id, task_id)
    return "Error: Task IDs are required" unless list_id && taskseries_id && task_id
    
    # Get task details to retrieve notes
    resp = @rtm.call_method('rtm.tasks.getList', {
      list_id: list_id,
      filter: ""  # Empty filter to get all tasks
    })
    
    # Find the specific task
    taskseries = nil
    task = nil
    
    # Check for the rsp wrapper
    task_data = resp.dig('rsp', 'tasks') || resp['tasks']
    
    if task_data && task_data["list"]
      lists = ensure_array(task_data["list"])
      lists.each do |list|
        next unless list["id"] == list_id
        series_array = ensure_array(list["taskseries"])
        series_array.each do |series|
          if series["id"] == taskseries_id
            taskseries = series
            tasks = ensure_array(series["task"])
            task = tasks.find { |t| t["id"] == task_id }
            break
          end
        end
      end
    end
    
    return "Task not found" unless taskseries && task
    
    # Extract notes
    if taskseries["notes"] && taskseries["notes"]["note"]
      notes = ensure_array(taskseries["notes"]["note"])
      
      if notes.empty?
        return "No notes found for this task"
      end
      
      # Format notes for display
      output = ["📝 **Notes for task: #{taskseries["name"]}**", ""]
      
      notes.each_with_index do |note, index|
        output << "**Note #{index + 1}** (ID: #{note["id"]})"
        output << "Title: #{note["title"]}" if note["title"] && !note["title"].empty?
        output << "Created: #{format_time(note["created"])}"
        output << "Modified: #{format_time(note["modified"])}" if note["modified"] != note["created"]
        output << ""
        output << note["$t"]  # Note content
        output << ""
        output << "---" if index < notes.length - 1
        output << ""
      end
      
      return output.join("\n").strip
    else
      return "No notes found for this task"
    end
  end
  
  def ensure_array(obj)
    return [] if obj.nil?
    obj.is_a?(Array) ? obj : [obj]
  end
  
  def format_time(time_str)
    return "" unless time_str
    Time.parse(time_str).strftime("%Y-%m-%d %H:%M")
  rescue
    time_str
  end
  
  def create_subtask(name, parent_list_id, parent_taskseries_id, parent_task_id)
    return "Error: Subtask name is required" unless name && !name.empty?
    return "Error: Parent task IDs are required" unless parent_list_id && parent_taskseries_id && parent_task_id
    
    # Step 1: Create the task
    create_params = { name: name, list_id: parent_list_id }
    create_result = @rtm.call_method('rtm.tasks.add', create_params)
    
    if create_result['error'] || create_result.dig('rsp', 'stat') == 'fail'
      error_msg = create_result['error'] || create_result.dig('rsp', 'err', 'msg') || 'Unknown error'
      return "❌ Error creating task: #{error_msg}"
    end
    
    # Extract the created task info
    list = create_result.dig('rsp', 'list')
    taskseries = list&.dig('taskseries')
    taskseries = [taskseries] unless taskseries.is_a?(Array)
    new_task = taskseries.first
    
    if !new_task
      return "❌ Task created but couldn't parse response"
    end
    
    task = new_task['task']
    task = [task] unless task.is_a?(Array)
    
    new_task_info = {
      list_id: list['id'],
      taskseries_id: new_task['id'],
      task_id: task[0]['id'],
      name: new_task['name']
    }
    
    # Step 2: Set it as a subtask
    set_parent_params = {
      v: '2',  # Required for subtask operations
      list_id: new_task_info[:list_id],
      taskseries_id: new_task_info[:taskseries_id],
      task_id: new_task_info[:task_id],
      parent_task_id: parent_task_id
    }
    
    set_parent_result = @rtm.call_method('rtm.tasks.setParentTask', set_parent_params)
    
    if set_parent_result['error'] || set_parent_result.dig('rsp', 'stat') == 'fail'
      error_msg = set_parent_result['error'] || set_parent_result.dig('rsp', 'err', 'msg') || 'Unknown error'
      
      # Task was created but couldn't be made a subtask
      return "⚠️ Task created but couldn't set as subtask: #{error_msg}\n" +
             "Created task: #{new_task_info[:name]}\n" +
             "IDs: list=#{new_task_info[:list_id]}, series=#{new_task_info[:taskseries_id]}, task=#{new_task_info[:task_id]}"
    end
    
    # Success!
    "✅ Created subtask: #{new_task_info[:name]}\n" +
    "IDs: list=#{new_task_info[:list_id]}, series=#{new_task_info[:taskseries_id]}, task=#{new_task_info[:task_id]}"
  end
  
  def list_subtasks(parent_list_id, parent_taskseries_id, parent_name = nil)
    # Note: RTM API doesn't provide parent_task_id field in responses even with v=2
    # This is a workaround implementation
    
    output = []
    output << "📋 **Subtasks Listing (Limited Functionality)**\n"
    output << "**Note**: RTM API doesn't expose parent-child relationships in task lists."
    output << "This tool shows a workaround approach.\n"
    
    if parent_name
      output << "Parent task: #{parent_name}"
    end
    output << "Parent IDs: list=#{parent_list_id}, series=#{parent_taskseries_id}\n"
    
    # Strategy 1: Check if parent has subtasks
    params = {
      list_id: parent_list_id,
      filter: 'hasSubtasks:true'
    }
    
    result = @rtm.call_method('rtm.tasks.getList', params)
    
    if result.dig('rsp', 'stat') == 'ok'
      lists = result.dig('rsp', 'tasks', 'list')
      if lists
        lists = [lists] unless lists.is_a?(Array)
        
        parent_found = false
        lists.each do |list|
          next unless list['taskseries']
          taskseries = list['taskseries']
          taskseries = [taskseries] unless taskseries.is_a?(Array)
          
          taskseries.each do |ts|
            if ts['id'] == parent_taskseries_id
              parent_found = true
              output << "✅ Parent task confirmed to have subtasks\n"
              break
            end
          end
        end
        
        if !parent_found
          output << "⚠️ This task doesn't appear to have any subtasks\n"
          return output.join("\n")
        end
      end
    end
    
    # Strategy 2: List all tasks and suggest manual identification
    output << "\n**Workaround**: Here are all incomplete tasks in the list."
    output << "Subtasks typically appear after their parent in RTM:\n"
    
    all_params = {
      list_id: parent_list_id,
      filter: 'status:incomplete'
    }
    
    all_result = @rtm.call_method('rtm.tasks.getList', all_params)
    
    if all_result.dig('rsp', 'stat') == 'ok'
      lists = all_result.dig('rsp', 'tasks', 'list')
      if lists
        lists = [lists] unless lists.is_a?(Array)
        
        found_parent = false
        task_count = 0
        
        lists.each do |list|
          next unless list['taskseries']
          taskseries = list['taskseries']
          taskseries = [taskseries] unless taskseries.is_a?(Array)
          
          taskseries.each do |ts|
            task = ts['task']
            task = [task] unless task.is_a?(Array)
            
            task.each do |t|
              next if t['completed'] && !t['completed'].empty?
              
              if ts['id'] == parent_taskseries_id
                found_parent = true
                output << "\n**→ Parent: #{ts['name']}** ⬇️"
              elsif found_parent && task_count < 10  # Show next 10 tasks after parent
                status = "🔲"
                output << "  #{status} #{ts['name']}"
                task_count += 1
              end
            end
          end
        end
        
        if task_count > 0
          output << "\n(Showing up to 10 tasks after parent - subtasks typically appear here)"
        end
      end
    end
    
    output << "\n\n💡 **Tip**: Use the RTM website or app to see proper subtask hierarchy."
    output.join("\n")
  end
  
  def move_task(list_id, taskseries_id, task_id, to_list_id)
    unless list_id && taskseries_id && task_id && to_list_id
      return "Error: list_id, taskseries_id, task_id, and to_list_id are required"
    end
    
    params = {
      from_list_id: list_id,
      taskseries_id: taskseries_id,
      task_id: task_id,
      to_list_id: to_list_id
    }
    
    result = @rtm.call_method('rtm.tasks.moveTo', params)
    
    if result['error'] || result.dig('rsp', 'stat') == 'fail'
      error_msg = result['error'] || result.dig('rsp', 'err', 'msg') || 'Unknown error'
      "❌ RTM API Error: #{error_msg}"
    else
      # Get the destination list name for a friendly response
      to_list_name = get_list_name(to_list_id)
      
      # Extract task name from response if available
      list_data = result.dig('rsp', 'list')
      task_name = "Task"
      
      if list_data
        list_data = list_data.first if list_data.is_a?(Array)
        taskseries = list_data['taskseries']
        if taskseries
          taskseries = taskseries.first if taskseries.is_a?(Array)
          task_name = taskseries['name'] if taskseries['name']
        end
      end
      
      "✅ Task '#{task_name}' moved to #{to_list_name}"
    end
  end
  
  def postpone_task(list_id, taskseries_id, task_id)
    unless list_id && taskseries_id && task_id
      return "Error: list_id, taskseries_id, and task_id are required"
    end
    
    params = {
      list_id: list_id,
      taskseries_id: taskseries_id,
      task_id: task_id
    }
    
    result = @rtm.call_method('rtm.tasks.postpone', params)
    
    if result['error'] || result.dig('rsp', 'stat') == 'fail'
      error_msg = result['error'] || result.dig('rsp', 'err', 'msg') || 'Unknown error'
      "❌ RTM API Error: #{error_msg}"
    else
      # Extract task name and new due date from response
      list_data = result.dig('rsp', 'list')
      task_name = "Task"
      new_due_date = nil
      
      if list_data
        list_data = list_data.first if list_data.is_a?(Array)
        taskseries = list_data['taskseries']
        if taskseries
          taskseries = taskseries.first if taskseries.is_a?(Array)
          task_name = taskseries['name'] if taskseries['name']
          
          # Get due date from task
          task = taskseries['task']
          if task
            task = task.first if task.is_a?(Array)
            new_due_date = task['due'] if task['due'] && !task['due'].empty?
          end
        end
      end
      
      if new_due_date
        "✅ Task '#{task_name}' postponed to #{new_due_date}"
      else
        "✅ Task '#{task_name}' postponed"
      end
    end
  end

  private
  
  def get_parent_task_ids(list_id = nil, original_filter = nil)
    # Build filter to find tasks with subtasks
    parent_filter = 'hasSubtasks:true'
    
    # Add status:incomplete if the original filter had it
    if original_filter && original_filter.include?('status:incomplete')
      parent_filter += ' AND status:incomplete'
    end
    
    params = { filter: parent_filter }
    params[:list_id] = list_id if list_id
    
    result = @rtm.call_method('rtm.tasks.getList', params)
    
    parent_ids = []
    if result.dig('rsp', 'stat') == 'ok'
      lists = result.dig('rsp', 'tasks', 'list')
      lists = [lists] unless lists.is_a?(Array) || lists.nil?
      
      lists&.each do |list|
        next unless list['taskseries']
        taskseries = list['taskseries']
        taskseries = [taskseries] unless taskseries.is_a?(Array)
        
        taskseries.each do |ts|
          parent_ids << ts['id']
        end
      end
    end
    
    parent_ids
  end
  
  def format_tasks(result, parent_task_ids = [], show_ids = false)
    lists = result.dig('rsp', 'tasks', 'list')
    return "📋 No tasks found." unless lists
    
    lists = [lists] unless lists.is_a?(Array)
    task_count = 0
    output = []
    
    lists.each do |list|
      next unless list['taskseries']
      
      list_name = list['name'] || "List #{list['id']}"
      taskseries = list['taskseries']
      taskseries = [taskseries] unless taskseries.is_a?(Array)
      
      list_tasks = []
      taskseries.each do |ts|
        task = ts['task']
        task = [task] unless task.is_a?(Array)
        
        task.each do |t|
          next if t['completed'] && !t['completed'].empty?  # Skip completed tasks
          
          status = "🔲"
          priority = case ts['priority']
                   when '1' then " 🔴"
                   when '2' then " 🟡"  
                   when '3' then " 🔵"
                   else ""
                   end
          
          due_text = t['due'] && !t['due'].empty? ? " (due: #{t['due']})" : ""
          
          # Add start date display
          start_text = t['start'] && !t['start'].empty? ? " 🏁#{t['start']}" : ""
          
          # Add estimate display
          estimate_text = t['estimate'] && !t['estimate'].empty? ? " ⏱️#{t['estimate']}" : ""
          
          # Check if this task has subtasks
          subtask_indicator = parent_task_ids.include?(ts['id']) ? " [has subtasks]" : ""
          
          list_tasks << "#{status} #{ts['name']}#{priority}#{due_text}#{start_text}#{estimate_text}#{subtask_indicator}"
          
          # Add IDs if requested
          if show_ids
            list_tasks << "   IDs: list=#{list['id']}, series=#{ts['id']}, task=#{t['id']}"
          end
          
          # Add notes if present
          if ts['notes'] && ts['notes'].is_a?(Hash) && ts['notes']['note']
            notes = ts['notes']['note']
            notes = [notes] unless notes.is_a?(Array)
            
            notes.each do |note|
              next unless note.is_a?(Hash)  # Skip if note isn't a hash
              note_text = note['$t'] || note['text'] || ''
              next if note_text.empty?
              
              # Truncate long notes and clean up newlines
              if note_text.length > 80
                note_text = note_text[0..77].gsub(/\n/, ' ') + "..."
              else
                note_text = note_text.gsub(/\n/, ' ')
              end
              list_tasks << "   📝 #{note_text}"
            end
          end
          
          task_count += 1
        end
      end
      
      if list_tasks.any?
        output.concat(list_tasks)
      end
    end
    
    if output.empty?
      "📋 No incomplete tasks found."
    else
      "📋 **Tasks** (#{task_count} total):\n\n" + output.join("\n")
    end
  end
end

def run_stdio_server(server)
  STDERR.puts "RTM MCP Server starting in stdio mode..."
  STDERR.flush
  
  while line = STDIN.gets
    begin
      request = JSON.parse(line)
      
      # Handle notifications (no response needed)
      if request['method'] && request['method'].start_with?('notifications/')
        server.handle_request(request)
        next
      end
      
      result = server.handle_request(request)
      
      # Only send response for requests with an id
      if request['id']
        response = {
          jsonrpc: '2.0',
          id: request['id']
        }
        
        if result && result[:error]
          response[:error] = result[:error]
        elsif result
          response[:result] = result
        else
          response[:result] = {}
        end
        
        puts JSON.generate(response)
        STDOUT.flush
      end
    rescue JSON::ParserError => e
      STDERR.puts "Parse error: #{e.message}"
      if request && request['id']
        puts JSON.generate({
          jsonrpc: '2.0',
          id: request['id'],
          error: { code: -32700, message: 'Parse error' }
        })
        STDOUT.flush
      end
    rescue => e
      STDERR.puts "Error: #{e.message}"
      STDERR.puts e.backtrace
      if request && request['id']
        puts JSON.generate({
          jsonrpc: '2.0',
          id: request['id'],
          error: { code: -32603, message: "Internal error: #{e.message}" }
        })
        STDOUT.flush
      end
    end
  end
end

# Helper function for bearer token authentication
def check_bearer_auth(request)
  # NEW: Accept Cloudflare's authentication
  cf_jwt = request['Cf-Access-Jwt-Assertion']
  return { valid: true } if cf_jwt && !cf_jwt.empty?
  
  auth_token = ENV['RTM_MCP_AUTH_TOKEN']
  
  # If no auth token configured, allow all requests (backward compatibility)
  return { valid: true } if !auth_token || auth_token.empty?
  
  # Check for Authorization header (WEBrick uses different access method)
  auth_header = request['Authorization']
  if !auth_header || auth_header.empty?
    return { 
      valid: false, 
      status: 401,
      error: 'Missing Authorization header',
      www_authenticate: 'Bearer realm="RTM MCP Server"'
    }
  end
  
  # Parse Authorization header
  if !auth_header.start_with?('Bearer ')
    return { 
      valid: false, 
      status: 401,
      error: 'Invalid authorization scheme. Expected Bearer token',
      www_authenticate: 'Bearer realm="RTM MCP Server"'
    }
  end
  
  # Extract token
  provided_token = auth_header[7..-1]  # Remove "Bearer " prefix
  if provided_token.nil? || provided_token.empty?
    return { 
      valid: false, 
      status: 401,
      error: 'Missing bearer token',
      www_authenticate: 'Bearer realm="RTM MCP Server"'
    }
  end
  
  # Validate token
  if provided_token != auth_token
    return { 
      valid: false, 
      status: 401,
      error: 'Invalid bearer token',
      www_authenticate: 'Bearer realm="RTM MCP Server"'
    }
  end
  
  # Token is valid
  { valid: true }
end

def run_http_server(server, port)
  unless HTTP_AVAILABLE
    STDERR.puts "Error: HTTP transport not available"
    STDERR.puts "Install rack gem or use stdio mode"
    exit 1
  end
  
  # Check for bearer token authentication
  auth_token = ENV['RTM_MCP_AUTH_TOKEN']
  if auth_token && !auth_token.empty?
    STDERR.puts "RTM MCP Server starting in HTTP mode on port #{port} with authentication..."
  else
    STDERR.puts "RTM MCP Server starting in HTTP mode on port #{port} without authentication..."
  end
  STDERR.flush
  
  # Set global variable for the HTTP handler
  $rtm_server = server
  
  # Use WEBrick directly (always available in Ruby)
  require 'webrick'
  require 'json'
  
  webrick_server = WEBrick::HTTPServer.new(
    Port: port.to_i,
    BindAddress: '0.0.0.0',
    Logger: WEBrick::Log.new(STDERR, WEBrick::Log::ERROR),
    AccessLog: []
  )
  
  # Root endpoint
  webrick_server.mount_proc '/' do |req, res|
    res['Content-Type'] = 'text/plain; charset=utf-8'
    res['Access-Control-Allow-Origin'] = '*'
    res.body = "RTM MCP Server\nConnect to /sse for MCP over Server-Sent Events\nAuthentication: Authentication required - use Authorization: Bearer <token> header"
  end
  
  # Health check endpoint for Docker
  webrick_server.mount_proc '/health' do |req, res|
    res['Content-Type'] = 'application/json'
    res['Access-Control-Allow-Origin'] = '*'
    res.status = 200
    res.body = JSON.generate({
      status: 'ok',
      timestamp: Time.now.iso8601,
      server: 'RTM MCP Server'
    })
  end
  
  # OAuth discovery endpoint (no auth required)
  webrick_server.mount_proc '/mcp-discovery' do |req, res|
    res['Content-Type'] = 'application/json'
    res['Access-Control-Allow-Origin'] = '*'
    res.status = 200
    
    cf_team = ENV['CF_ACCESS_TEAM_DOMAIN'] || 'your-team.cloudflareaccess.com'
    
    res.body = JSON.generate({
      mcp_endpoint: '/sse',
      auth: {
        type: "oauth2",
        authorization_url: "https://#{cf_team}/cdn-cgi/access/authorize",
        token_url: "https://#{cf_team}/cdn-cgi/access/token",
        scopes: ["email"]
      }
    })
  end
  
  # MCP JSON-RPC endpoint
  webrick_server.mount_proc '/sse' do |req, res|
    res['Access-Control-Allow-Origin'] = '*'
    res['Access-Control-Allow-Methods'] = 'POST, OPTIONS'
    res['Access-Control-Allow-Headers'] = 'Content-Type, Authorization'
    
    if req.request_method == 'OPTIONS'
      # CORS preflight
      res.status = 200
      res.body = ''
      next
    end
    
    if req.request_method != 'POST'
      res.status = 405
      res['Content-Type'] = 'text/plain'
      res.body = 'Method Not Allowed'
      next
    end
    
    begin
      request_body = req.body
      STDERR.puts "Received HTTP request: #{request_body}"
      
      request_data = JSON.parse(request_body)
      
      # Allow initialize method without authentication so Web Claude can discover OAuth
      if request_data['method'] != 'initialize'
        # Check bearer token authentication for all other methods
        auth_result = check_bearer_auth(req)
        unless auth_result[:valid]
          res.status = auth_result[:status]
          res['Content-Type'] = 'application/json'
          res['WWW-Authenticate'] = auth_result[:www_authenticate] if auth_result[:www_authenticate]
          res.body = JSON.generate({
            jsonrpc: '2.0',
            id: request_data['id'],
            error: { 
              code: -32600, 
              message: auth_result[:error] 
            }
          })
          next
        end
      end
      result = $rtm_server.handle_request(request_data)
      response = {
        jsonrpc: '2.0',
        id: request_data['id']
      }
      
      if result && result[:error]
        response[:error] = result[:error]
      elsif result
        response[:result] = result
      else
        response[:result] = {}
      end
      
      res['Content-Type'] = 'application/json'
      res.status = 200
      res.body = JSON.generate(response)
      
    rescue JSON::ParserError => e
      res['Content-Type'] = 'application/json'
      res.status = 400
      res.body = JSON.generate({
        jsonrpc: '2.0',
        id: nil,
        error: { code: -32700, message: 'Parse error' }
      })
    rescue => e
      STDERR.puts "HTTP error: #{e.message}"
      res['Content-Type'] = 'application/json'
      res.status = 500
      res.body = JSON.generate({
        jsonrpc: '2.0',
        id: nil,
        error: { code: -32603, message: "Internal error: #{e.message}" }
      })
    end
  end
  
  # Graceful shutdown
  trap('INT') { webrick_server.shutdown }
  trap('TERM') { webrick_server.shutdown }
  
  STDERR.puts "WEBrick server starting on port #{port}..."
  webrick_server.start
end

# Parse command line arguments
def parse_arguments
  options = {
    transport: 'stdio',
    port: 8733
  }
  
  OptionParser.new do |opts|
    opts.banner = "Usage: #{$0} [options] [api_key shared_secret]"
    
    opts.on('--transport TRANSPORT', ['stdio', 'http'], 
            "Transport mode: stdio or http (default: stdio)#{HTTP_AVAILABLE ? '' : ' [http unavailable - install sinatra]'}") do |t|
      options[:transport] = t
    end
    
    opts.on('--port PORT', Integer, 
            'HTTP port (default: 8733, only used with http transport)') do |p|
      options[:port] = p
    end
    
    opts.on('-h', '--help', 'Show this help message') do
      puts opts
      puts "\nCredentials can be provided via:"
      puts "  Command line: #{$0} [options] api_key shared_secret"
      puts "  Environment variables: RTM_API_KEY, RTM_SHARED_SECRET"
      exit
    end
  end.parse!
  
  # Get API credentials from command line or environment variables
  if ARGV.length >= 2
    options[:api_key] = ARGV[0]
    options[:shared_secret] = ARGV[1]
  elsif ENV['RTM_API_KEY'] && ENV['RTM_SHARED_SECRET']
    options[:api_key] = ENV['RTM_API_KEY']
    options[:shared_secret] = ENV['RTM_SHARED_SECRET']
  else
    STDERR.puts "Error: Missing API credentials"
    STDERR.puts "Provide via command line: #{$0} [options] api_key shared_secret"
    STDERR.puts "Or environment variables: RTM_API_KEY, RTM_SHARED_SECRET"
    exit 1
  end
  
  options
end
# Main entry point
if __FILE__ == $0
  begin
    options = parse_arguments
    
    # Initialize RTM server with credentials
    server = RTMMCPServer.new(options[:api_key], options[:shared_secret])
    
    case options[:transport]
    when 'stdio'
      run_stdio_server(server)
    when 'http'
      run_http_server(server, options[:port])
    else
      STDERR.puts "Unknown transport mode: #{options[:transport]}"
      exit 1
    end
    
  rescue => e
    STDERR.puts "Fatal error: #{e.message}"
    STDERR.puts e.backtrace
    exit 1
  end
end
