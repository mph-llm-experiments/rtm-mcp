#!/usr/bin/env ruby
require_relative 'rtm-mcp'

# Patch the RTMMCPServer class to add debugging
class RTMMCPServer
  def debug_create_task(name, list_id = nil, due = nil, priority = nil, tags = nil)
    return "Error: Task name is required" unless name && !name.empty?
    
    puts "🔍 DEBUG: Starting enhanced create_task"
    puts "   name: #{name}"
    puts "   list_id: #{list_id}"
    puts "   due: #{due}"
    puts "   priority: #{priority}"
    puts "   tags: #{tags}"
    
    # Step 1: Create the basic task
    params = { name: name }
    params[:list_id] = list_id if list_id && !list_id.empty?
    
    puts "\n📝 Creating basic task..."
    result = @rtm.call_method('rtm.tasks.add', params)
    
    if result['error'] || result.dig('rsp', 'stat') == 'fail'
      error_msg = result['error'] || result.dig('rsp', 'err', 'msg') || 'Unknown error'
      return "❌ RTM API Error: #{error_msg}"
    end
    
    puts "✅ Basic task created successfully"
    
    # Extract the created task info
    list = result.dig('rsp', 'list')
    taskseries = list&.dig('taskseries')
    
    puts "\n🔍 Parsing response structure..."
    puts "   list ID: #{list['id'] if list}"
    puts "   taskseries type: #{taskseries.class}"
    puts "   taskseries content: #{taskseries}"
    
    # Handle case where taskseries is an array
    if taskseries.is_a?(Array)
      task = taskseries.first
      puts "   taskseries is array, using first element"
    else
      task = taskseries
      puts "   taskseries is single object"
    end
    
    if !task
      return "❌ Task created but couldn't parse response"
    end
    
    puts "   task object: #{task}"
    
    task_name = task['name'] || name
    actual_list_id = list['id']
    list_name = get_list_name(actual_list_id)
    task_obj = task['task']
    
    puts "\n🔍 Extracting IDs..."
    puts "   task_obj type: #{task_obj.class}"
    puts "   task_obj content: #{task_obj}"
    
    task_id = task_obj.is_a?(Array) ? task_obj[0]['id'] : task_obj['id']
    
    puts "   final IDs:"
    puts "     actual_list_id: #{actual_list_id}"
    puts "     taskseries_id (task['id']): #{task['id']}"
    puts "     task_id: #{task_id}"
    
    # Step 2: Set metadata via separate API calls if provided
    metadata_results = []
    
    # Set due date
    if due && !due.empty?
      puts "\n📅 Setting due date..."
      sleep 1  # Rate limiting
      
      begin
        due_result = set_due_date(actual_list_id, task['id'], task_id, due)
        puts "   due_result: #{due_result}"
        
        if due_result.start_with?("✅")
          metadata_results << "📅 Due date set"
          puts "   ✅ Due date setting succeeded"
        else
          metadata_results << "⚠️ Due date failed: #{due_result}"
          puts "   ❌ Due date setting failed: #{due_result}"
        end
      rescue => e
        error_msg = "Exception in due date setting: #{e.message}"
        metadata_results << "⚠️ Due date exception: #{error_msg}"
        puts "   💥 #{error_msg}"
        puts "   Backtrace: #{e.backtrace.first(3)}"
      end
    else
      puts "\n📅 Skipping due date (empty)"
    end
    
    # Set priority
    if priority && !priority.empty?
      puts "\n🎯 Setting priority..."
      sleep 1  # Rate limiting
      
      begin
        priority_result = set_task_priority(actual_list_id, task['id'], task_id, priority)
        puts "   priority_result: #{priority_result}"
        
        if priority_result.start_with?("✅")
          priority_display = case priority
          when '1' then '🔴 High'
          when '2' then '🟡 Medium'  
          when '3' then '🔵 Low'
          else priority
          end
          metadata_results << "Priority: #{priority_display}"
          puts "   ✅ Priority setting succeeded"
        else
          metadata_results << "⚠️ Priority failed: #{priority_result}"
          puts "   ❌ Priority setting failed: #{priority_result}"
        end
      rescue => e
        error_msg = "Exception in priority setting: #{e.message}"
        metadata_results << "⚠️ Priority exception: #{error_msg}"
        puts "   💥 #{error_msg}"
        puts "   Backtrace: #{e.backtrace.first(3)}"
      end
    else
      puts "\n🎯 Skipping priority (empty)"
    end
    
    # Set tags
    if tags && !tags.empty?
      puts "\n🏷️ Setting tags..."
      sleep 1  # Rate limiting
      
      begin
        tags_result = add_task_tags(actual_list_id, task['id'], task_id, tags)
        puts "   tags_result: #{tags_result}"
        
        if tags_result.start_with?("✅")
          metadata_results << "🏷️ Tags: #{tags}"
          puts "   ✅ Tags setting succeeded"
        else
          metadata_results << "⚠️ Tags failed: #{tags_result}"
          puts "   ❌ Tags setting failed: #{tags_result}"
        end
      rescue => e
        error_msg = "Exception in tags setting: #{e.message}"
        metadata_results << "⚠️ Tags exception: #{error_msg}"
        puts "   💥 #{error_msg}"
        puts "   Backtrace: #{e.backtrace.first(3)}"
      end
    else
      puts "\n🏷️ Skipping tags (empty)"
    end
    
    # Build response
    response = "✅ Created task: #{task_name} in #{list_name}\n   IDs: list=#{actual_list_id}, series=#{task['id']}, task=#{task_id}"
    
    puts "\n📋 Building final response..."
    puts "   metadata_results count: #{metadata_results.length}"
    puts "   metadata_results: #{metadata_results}"
    
    if metadata_results.any?
      response += "\n" + metadata_results.join("\n")
      puts "   ✅ Added metadata to response"
    else
      puts "   ⚠️ No metadata results to add"
    end
    
    puts "\n🎯 Final response:"
    puts response
    puts "\n" + "="*50
    
    response
  end
end

# Test the debug version
begin
  # Load credentials from files
  api_key = File.read('.rtm_api_key').strip
  shared_secret = File.read('.rtm_shared_secret').strip
  
  server = RTMMCPServer.new(api_key, shared_secret)
  
  puts "🔍 Testing DEBUG enhanced create_task with metadata"
  puts "=" * 50
  
  result = server.debug_create_task(
    "DEBUG: Trace metadata bug", 
    "51175519",   # RTM MCP Development list
    "tomorrow",   # due date
    "1",         # priority (high)
    "debug,trace" # tags
  )
  
rescue => e
  puts "❌ Error: #{e.message}"
  puts e.backtrace.first(5)
end
