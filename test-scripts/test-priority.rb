#!/usr/bin/env ruby

require_relative 'rtm-mcp'

# Test script for setting task priorities
# RTM priorities: 1 (high), 2 (medium), 3 (low), N (none)

api_key = ARGV[0] || ENV['RTM_API_KEY']
shared_secret = ARGV[1] || ENV['RTM_SHARED_SECRET']

if !api_key || !shared_secret
  puts "Usage: #{$0} API_KEY SHARED_SECRET"
  exit 1
end

client = RTMClient.new(api_key, shared_secret)

puts "=== RTM Priority Test ==="
puts "RTM uses: 1=High, 2=Medium, 3=Low, N=None"
puts

# First, list tasks to find one to update
puts "1. Listing tasks in RTM MCP Development list..."
result = client.call_method('rtm.tasks.getList', { 
  list_id: '51175519',
  filter: 'status:incomplete'
})

if result.dig('rsp', 'stat') != 'ok'
  puts "Error listing tasks: #{result}"
  exit 1
end

# Find a task to test with
tasks = []
list = result.dig('rsp', 'tasks', 'list')

# Debug: see what we got
puts "DEBUG: list type = #{list.class}, content = #{list.inspect[0..200]}..."

# Handle list being an array (happens with filters)
if list
  list = list.first if list.is_a?(Array)
  
  if list && list['taskseries']
    taskseries = list['taskseries']
    taskseries = [taskseries] unless taskseries.is_a?(Array)
    
    taskseries.each do |ts|
      task = ts['task']
      task = task.first if task.is_a?(Array)
      
      tasks << {
        name: ts['name'],
        list_id: list['id'],
        taskseries_id: ts['id'],
        task_id: task['id'],
        priority: task['priority']
      }
    end
  end
end

if tasks.empty?
  puts "No tasks found!"
  exit 1
end

puts "\nFound #{tasks.length} tasks:"
tasks.each_with_index do |task, i|
  priority_display = case task[:priority]
  when '1' then '🔴 High'
  when '2' then '🟡 Medium'  
  when '3' then '🔵 Low'
  when 'N' then 'None'
  when 'none' then 'None'
  when '', nil then 'None'
  else "Unknown (#{task[:priority].inspect})"
  end
  puts "#{i+1}. #{task[:name]} - Priority: #{priority_display}"
end

# Test setting priority on the first task
test_task = tasks.first
puts "\n2. Testing priority changes on: #{test_task[:name]}"

# Test each priority level
['1', '2', '3', ''].each do |priority|
  priority_name = case priority
  when '1' then '🔴 High'
  when '2' then '🟡 Medium'
  when '3' then '🔵 Low'
  when '' then 'None (empty string)'
  else 'None'
  end
  
  puts "\n   Setting priority to #{priority_name}..."
  
  result = client.call_method('rtm.tasks.setPriority', {
    list_id: test_task[:list_id],
    taskseries_id: test_task[:taskseries_id],
    task_id: test_task[:task_id],
    priority: priority
  })
  
  puts "   DEBUG: Response structure = #{result.dig('rsp').keys.inspect}" if result.dig('rsp')
  
  if result.dig('rsp', 'stat') == 'ok'
    puts "   ✅ Success!"
    
    # Show the updated task info if available
    # The response structure varies - sometimes it's an array
    list_data = result.dig('rsp', 'list')
    if list_data
      list_data = list_data.first if list_data.is_a?(Array)
      
      taskseries = list_data['taskseries']
      if taskseries
        taskseries = taskseries.first if taskseries.is_a?(Array)
        task = taskseries['task']
        task = task.first if task.is_a?(Array)
        puts "   Task priority is now: #{task['priority'].inspect}"
      end
    end
  else
    puts "   ❌ Error: #{result}"
  end
  
  # Rate limiting will automatically apply
  puts "   (Rate limiter will enforce 1 req/sec)"
end

puts "\n3. Final verification - listing task again..."
sleep 1  # Extra safety

result = client.call_method('rtm.tasks.getList', { 
  list_id: test_task[:list_id],
  filter: "status:incomplete"
})

if result.dig('rsp', 'stat') == 'ok'
  list = result.dig('rsp', 'tasks', 'list')
  
  # Handle list being an array
  if list
    list = list.first if list.is_a?(Array)
    
    if list && list['taskseries']
      taskseries = list['taskseries']
      taskseries = [taskseries] unless taskseries.is_a?(Array)
      
      target = taskseries.find { |ts| ts['id'] == test_task[:taskseries_id] }
      if target
        task = target['task']
        task = task.first if task.is_a?(Array)
        
        final_priority = case task['priority']
        when '1' then '🔴 High'
        when '2' then '🟡 Medium'  
        when '3' then '🔵 Low'
        when 'N' then 'None'
        when 'none' then 'None'
        when '', nil then 'None'
        else "Unknown (#{task['priority'].inspect})"
        end
        
        puts "Final priority: #{final_priority}"
      end
    end
  end
end

puts "\nPriority test complete!"
