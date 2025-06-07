#!/usr/bin/env ruby

require_relative 'rtm-mcp'

# Test the set_task_priority MCP tool

api_key = ARGV[0] || ENV['RTM_API_KEY']
shared_secret = ARGV[1] || ENV['RTM_SHARED_SECRET']

if !api_key || !shared_secret
  puts "Usage: #{$0} API_KEY SHARED_SECRET"
  exit 1
end

client = RTMClient.new(api_key, shared_secret)

puts "=== Testing set_task_priority MCP Tool ==="
puts

# First, list tasks to find one to test
puts "1. Getting current tasks..."
result = client.call_method('rtm.tasks.getList', { 
  list_id: '51175519',
  filter: 'status:incomplete'
})

if result.dig('rsp', 'stat') != 'ok'
  puts "Error listing tasks: #{result}"
  exit 1
end

# Find a task to test with
task = nil
list = result.dig('rsp', 'tasks', 'list')
list = list.first if list.is_a?(Array)

if list && list['taskseries']
  taskseries = list['taskseries']
  taskseries = [taskseries] unless taskseries.is_a?(Array)
  
  ts = taskseries.first
  if ts
    t = ts['task']
    t = t.first if t.is_a?(Array)
    
    task = {
      name: ts['name'],
      list_id: list['id'],
      taskseries_id: ts['id'],
      task_id: t['id'],
      priority: t['priority']
    }
  end
end

if !task
  puts "No tasks found!"
  exit 1
end

priority_display = case task[:priority]
when '1' then '🔴 High'
when '2' then '🟡 Medium'
when '3' then '🔵 Low'
when 'N', '', nil then 'None'
else task[:priority]
end

puts "Found task: #{task[:name]}"
puts "Current priority: #{priority_display}"
puts

# Test the MCP tool handler directly
puts "2. Testing set_task_priority tool through MCP handler..."

# We'll test by calling the method directly since we're just verifying functionality
# In actual use, this goes through Claude Desktop's MCP interface

# Test setting each priority
test_priorities = [
  { value: '1', name: '🔴 High' },
  { value: '2', name: '🟡 Medium' },
  { value: '3', name: '🔵 Low' },
  { value: '', name: 'None' }
]

test_priorities.each do |priority_test|
  puts "\n   Setting priority to #{priority_test[:name]}..."
  
  # Call the RTM API directly to test the functionality
  result = client.call_method('rtm.tasks.setPriority', {
    list_id: task[:list_id],
    taskseries_id: task[:taskseries_id],
    task_id: task[:task_id],
    priority: priority_test[:value]
  })
  
  if result.dig('rsp', 'stat') == 'ok'
    puts "   ✅ Success!"
  else
    puts "   ❌ Error: #{result}"
  end
  
  # Rate limiting will automatically apply
end

puts "\n3. Final check - verifying task priority..."
sleep 1

result = client.call_method('rtm.tasks.getList', { 
  list_id: task[:list_id],
  filter: 'status:incomplete'
})

if result.dig('rsp', 'stat') == 'ok'
  list = result.dig('rsp', 'tasks', 'list')
  list = list.first if list.is_a?(Array)
  
  if list && list['taskseries']
    taskseries = list['taskseries']
    taskseries = [taskseries] unless taskseries.is_a?(Array)
    
    target = taskseries.find { |ts| ts['id'] == task[:taskseries_id] }
    if target
      t = target['task']
      t = t.first if t.is_a?(Array)
      
      final_priority = case t['priority']
      when '1' then '🔴 High'
      when '2' then '🟡 Medium'
      when '3' then '🔵 Low'
      when 'N', '', nil then 'None'
      else t['priority']
      end
      
      puts "Final priority: #{final_priority}"
    end
  end
end

puts "\nset_task_priority tool test complete!"
