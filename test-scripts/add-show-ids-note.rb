#!/usr/bin/env ruby
require 'net/http'
require 'uri'
require 'json'
require 'digest/md5'

# Read credentials from files
API_KEY = File.read('.rtm_api_key').strip
SHARED_SECRET = File.read('.rtm_shared_secret').strip
AUTH_TOKEN = File.read('.rtm_auth_token').strip

def generate_sig(params)
  sorted = params.sort.map { |k, v| "#{k}#{v}" }.join
  Digest::MD5.hexdigest("#{SHARED_SECRET}#{sorted}")
end

def rtm_request(method, additional_params = {})
  params = {
    'method' => method,
    'api_key' => API_KEY,
    'auth_token' => AUTH_TOKEN,
    'format' => 'json'
  }.merge(additional_params)
  
  params['api_sig'] = generate_sig(params)
  
  uri = URI('https://api.rememberthemilk.com/services/rest/')
  uri.query = URI.encode_www_form(params)
  
  response = Net::HTTP.get_response(uri)
  JSON.parse(response.body)
end

# Get timeline
timeline_result = rtm_request('rtm.timelines.create')
timeline = timeline_result.dig('rsp', 'timeline')

# Find the new task
result = rtm_request('rtm.tasks.getList', {
  'filter' => 'name:"Add show_ids flag to list_tasks tool"',
  'list_id' => '51175519'
})

if result['rsp']['stat'] == 'ok' && result['rsp']['tasks']['list']
  list = result['rsp']['tasks']['list']
  list = [list] unless list.is_a?(Array)
  
  list.each do |l|
    next unless l['taskseries']
    taskseries = l['taskseries']
    taskseries = [taskseries] unless taskseries.is_a?(Array)
    
    taskseries.each do |ts|
      if ts['name'].include?('show_ids flag')
        task = ts['task']
        task = [task] unless task.is_a?(Array)
        
        puts "Found: #{ts['name']}"
        task_info = {
          list_id: l['id'],
          taskseries_id: ts['id'],
          task_id: task[0]['id']
        }
        
        # Add implementation note
        note_text = <<~NOTE
        Implementation Plan: Add show_ids flag to list_tasks

        ## Overview
        Add an optional show_ids parameter to list_tasks that displays task IDs when needed for operations.

        ## Implementation Details

        1. **Update Tool Schema**
        ```ruby
        # In @tools array, update list_tasks inputSchema:
        properties: {
          list_id: { ... },
          filter: { ... },
          show_ids: {
            type: 'boolean',
            description: 'Show task IDs for operations (default: false)'
          }
        }
        ```

        2. **Update handle_tool_call**
        ```ruby
        when 'list_tasks'
          list_tasks(args['list_id'], args['filter'], args['show_ids'])
        ```

        3. **Update list_tasks method signature**
        ```ruby
        def list_tasks(list_id = nil, filter = nil, show_ids = false)
          # ... existing code ...
          # Pass show_ids to format_tasks
          format_tasks(result, parent_task_ids, show_ids)
        end
        ```

        4. **Update format_tasks method**
        ```ruby
        def format_tasks(result, parent_task_ids = [], show_ids = false)
          # ... existing formatting code ...
          
          # After task name line, conditionally add IDs:
          if show_ids
            list_tasks << "   IDs: list=\#{l['id']}, series=\#{ts['id']}, task=\#{t['id']}"
          end
          
          # Continue with notes display...
        ```

        5. **Expected Output Examples**

        Without flag (default - clean for planning):
        ```
        🔲 Add due date tools [has subtasks]
           📝 Implementation Plan...
        ```

        With show_ids=true (for operations):
        ```
        🔲 Add due date tools [has subtasks]
           IDs: list=51175519, series=576922378, task=1136720073
           📝 Implementation Plan...
        ```

        ## Benefits
        - No extra API calls (uses existing data)
        - Backwards compatible (default behavior unchanged)
        - Solves the "script writing" problem
        - Makes all task operations accessible via MCP

        ## Testing
        1. Test default behavior (no IDs shown)
        2. Test with show_ids=true
        3. Verify IDs are correct for operations
        4. Test with filters and show_ids together
        NOTE
        
        add_note_result = rtm_request('rtm.tasks.notes.add', {
          'timeline' => timeline,
          'list_id' => task_info[:list_id],
          'taskseries_id' => task_info[:taskseries_id],
          'task_id' => task_info[:task_id],
          'note_title' => 'Implementation Plan',
          'note_text' => note_text
        })
        
        if add_note_result['rsp']['stat'] == 'ok'
          puts "✅ Added implementation note"
          puts "Task IDs: list=#{task_info[:list_id]}, series=#{task_info[:taskseries_id]}, task=#{task_info[:task_id]}"
        else
          puts "❌ Error: #{add_note_result.dig('rsp', 'err', 'msg')}"
        end
        
        break
      end
    end
  end
end
