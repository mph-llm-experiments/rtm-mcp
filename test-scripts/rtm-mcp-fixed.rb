#!/usr/bin/env ruby

require 'json'
require 'net/http'
require 'uri'
require 'digest'

class RTMClient
  BASE_URL = 'https://api.rememberthemilk.com/services/rest/'
  
  def initialize(api_key, shared_secret)
    @api_key = api_key
    @shared_secret = shared_secret
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
  def initialize(auth_token = nil)
    # Get credentials from command line arguments or environment
    @api_key = ARGV[0] || ENV['RTM_API_KEY']
    @shared_secret = ARGV[1] || ENV['RTM_SHARED_SECRET']
    
    unless @api_key && @shared_secret
      STDERR.puts "Usage: #{$0} [api-key] [shared-secret]"
      STDERR.puts "Or set RTM_API_KEY and RTM_SHARED_SECRET environment variables"
      exit 1
    end
    
    @rtm = RTMClient.new(@api_key, @shared_secret)
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
            }
          },
          required: []
        }
      },
      {
        name: 'create_task',
        description: 'Create a new task in RTM',
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
      }
    ]
  end  
  def handle_request(request)
    case request['method']
    when 'initialize'
      { 
        protocolVersion: '2024-11-05',
        capabilities: { tools: {} },
        serverInfo: { name: 'rtm-mcp', version: '0.1.0' }
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
      list_tasks(args['list_id'], args['filter'])
    when 'create_task'
      create_task(args['name'], args['list_id'])
    when 'complete_task'
      complete_task(args['list_id'], args['taskseries_id'], args['task_id'])
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
  
  def list_tasks(list_id = nil, filter = nil)
    params = {}
    params[:list_id] = list_id if list_id
    params[:filter] = filter if filter && !filter.empty?
    
    result = @rtm.call_method('rtm.tasks.getList', params)
    
    if result['error'] || result.dig('rsp', 'stat') == 'fail'
      error_msg = result['error'] || result.dig('rsp', 'err', 'msg') || 'Unknown error'
      "❌ RTM API Error: #{error_msg}"
    else
      format_tasks(result)
    end
  end
  
  def create_task(name, list_id = nil)
    return "Error: Task name is required" unless name && !name.empty?
    
    params = { name: name }
    params[:list_id] = list_id if list_id
    
    result = @rtm.call_method('rtm.tasks.add', params)
    
    if result['error'] || result.dig('rsp', 'stat') == 'fail'
      error_msg = result['error'] || result.dig('rsp', 'err', 'msg') || 'Unknown error'
      "❌ RTM API Error: #{error_msg}"
    else
      # RTM returns the task in a list structure
      list = result.dig('rsp', 'list')
      task = list&.dig('taskseries')
      
      if task
        task_name = task['name'] || name
        list_name = list['name'] || 'Unknown list'
        "✅ Created task: #{task_name} in #{list_name}"
      else
        "❌ Task created but couldn't parse response"
      end
    end
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
  private
  
  def format_tasks(result)
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
          
          list_tasks << "  #{status} #{ts['name']}#{priority}#{due_text}"
          list_tasks << "    IDs: list=#{list['id']}, series=#{ts['id']}, task=#{t['id']}"
          task_count += 1
        end
      end
      
      if list_tasks.any?
        output << "📝 **#{list_name}**:"
        output.concat(list_tasks)
        output << ""
      end
    end
    
    if output.empty?
      "📋 No incomplete tasks found."
    else
      "📋 **Tasks** (#{task_count} total):\n\n" + output.join("\n")
    end
  end
end

# Only run the server if this file is being executed directly
if __FILE__ == $0
  # Main loop
  server = RTMMCPServer.new
  
  STDERR.puts "RTM MCP Server starting..."
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