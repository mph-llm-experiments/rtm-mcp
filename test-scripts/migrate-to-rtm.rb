#!/usr/bin/env ruby

# RTM MCP Migration Script
# Creates RTM project list and migrates tasks from Things
# Usage: ./migrate-to-rtm.rb [api-key] [shared-secret]

require_relative 'rtm-mcp'

unless ARGV.length == 2
  puts "Usage: #{$0} [api-key] [shared-secret]"
  exit 1
end

api_key = ARGV[0]
shared_secret = ARGV[1]

puts "RTM MCP Project Migration"
puts "========================="
puts

rtm = RTMClient.new(api_key, shared_secret)

# Step 1: Create the project list
puts "Step 1: Creating 'RTM MCP Development' list..."
result = rtm.call_method('rtm.lists.add', { name: 'RTM MCP Development' })

if result['error']
  puts "❌ Failed to create list: #{result['error']}"
  exit 1
else
  list = result.dig('rsp', 'list')
  project_list_id = list['id']
  puts "✅ Created list: #{list['name']} (ID: #{project_list_id})"
end

# Step 2: Migrate tasks from Things project
puts "\nStep 2: Migrating tasks from Things..."

# Current open tasks from Things (based on our last check)
things_tasks = [
  "Add task metadata tools",
  "Test RTM MCP tools via Claude Desktop"
]

completed_tasks = [
  "Establish Project Instructions and project context and working preferences doc",
  "Create initial project structure", 
  "Set up basic Ruby MCP framework",
  "Create connectivity test script",
  "Implement authentication verification",
  "Implement list management tools",
  "Implement core task operations",
  "Implement RTM authentication flow"
]

puts "\nMigrating open tasks:"
things_tasks.each do |task_name|
  puts "  Creating: #{task_name}"
  result = rtm.call_method('rtm.tasks.add', { 
    name: task_name, 
    list_id: project_list_id 
  })
  
  if result['error']
    puts "    ❌ Failed: #{result['error']}"
  else
    puts "    ✅ Created successfully"
  end
end

puts "\nMigrating completed tasks (for reference):"
completed_tasks.each do |task_name|
  puts "  Creating: #{task_name}"
  result = rtm.call_method('rtm.tasks.add', { 
    name: task_name, 
    list_id: project_list_id 
  })
  
  if result['error']
    puts "    ❌ Failed: #{result['error']}"
  else
    task_data = result.dig('rsp', 'list', 'taskseries')
    puts "    Debug - task_data structure: #{task_data.class} - #{task_data}"
    
    if task_data
      # Handle case where taskseries might be an array
      if task_data.is_a?(Array)
        ts = task_data[0]
      else
        ts = task_data
      end
      
      # Handle task ID extraction more safely
      tasks = ts['task']
      if tasks.is_a?(Array)
        task_id = tasks[0]['id']
      else
        task_id = tasks['id']
      end
      
      complete_result = rtm.call_method('rtm.tasks.complete', {
        list_id: project_list_id,
        taskseries_id: ts['id'],
        task_id: task_id
      })
      
      if complete_result['error']
        puts "    ✅ Created, ❌ Failed to complete: #{complete_result['error']}"
      else
        puts "    ✅ Created and marked complete"
      end
    else
      puts "    ✅ Created (couldn't auto-complete)"
    end
  end
end

# Step 3: List all tasks to verify
puts "\nStep 3: Verifying migration..."
result = rtm.call_method('rtm.tasks.getList', { list_id: project_list_id })

if result['error']
  puts "❌ Failed to list tasks: #{result['error']}"
else
  puts "✅ Migration verification complete!"
  
  # Count tasks
  list_data = result.dig('rsp', 'tasks', 'list')
  if list_data
    # Handle case where list might be an array
    if list_data.is_a?(Array)
      list_info = list_data[0]
    else
      list_info = list_data
    end
    
    if list_info && list_info['taskseries']
    taskseries = list_info['taskseries']
    taskseries = [taskseries] unless taskseries.is_a?(Array)
    
    incomplete_count = 0
    complete_count = 0
    
    taskseries.each do |ts|
      tasks = ts['task']
      tasks = [tasks] unless tasks.is_a?(Array)
      
      tasks.each do |task|
        if task['completed'] && !task['completed'].empty?
          complete_count += 1
        else
          incomplete_count += 1
        end
      end
    end
    
    puts "  📊 Summary: #{incomplete_count} open tasks, #{complete_count} completed tasks"
  end
end

puts "\n🎉 RTM MCP project migration complete!"
puts "List ID: #{project_list_id}"
puts "\nNext steps:"
puts "1. Configure Claude Desktop to use RTM MCP"
puts "2. Test tools via Claude interface" 
puts "3. Start managing project in RTM!"
