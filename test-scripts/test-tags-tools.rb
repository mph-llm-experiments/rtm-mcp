#!/usr/bin/env ruby

require_relative 'rtm-mcp'

# Test the add_task_tags and remove_task_tags MCP tools

api_key = ARGV[0] || ENV['RTM_API_KEY']
shared_secret = ARGV[1] || ENV['RTM_SHARED_SECRET']

if !api_key || !shared_secret
  puts "Usage: #{$0} API_KEY SHARED_SECRET"
  exit 1
end

client = RTMClient.new(api_key, shared_secret)

puts "=== Testing Tags MCP Tools ==="
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

# Find the "Add tags tools" task to test with
task = nil
list = result.dig('rsp', 'tasks', 'list')
list = list.first if list.is_a?(Array)

if list && list['taskseries']
  taskseries = list['taskseries']
  taskseries = [taskseries] unless taskseries.is_a?(Array)
  
  # Find the tags task
  ts = taskseries.find { |t| t['name'].include?('Add tags tools') }
  if ts
    t = ts['task']
    t = t.first if t.is_a?(Array)
    
    # Extract current tags
    tags = []
    if ts['tags']
      if ts['tags'].is_a?(Array)
        tags = ts['tags']
      elsif ts['tags'].is_a?(Hash) && ts['tags']['tag']
        tag_data = ts['tags']['tag']
        tags = tag_data.is_a?(Array) ? tag_data : [tag_data]
      end
    end
    
    task = {
      name: ts['name'],
      list_id: list['id'],
      taskseries_id: ts['id'],
      task_id: t['id'],
      tags: tags
    }
  end
end

if !task
  puts "Couldn't find the 'Add tags tools' task!"
  exit 1
end

tag_display = task[:tags].empty? ? "none" : task[:tags].join(", ")
puts "Found task: #{task[:name]}"
puts "Current tags: #{tag_display}"
puts

# Test adding tags via direct API (simulating MCP tool call)
puts "2. Testing add_task_tags functionality..."
puts "   Adding tags: 'mcp-tool', 'implemented', 'ruby'"

# Simulate the tool call by calling the method directly
result = client.call_method('rtm.tasks.addTags', {
  list_id: task[:list_id],
  taskseries_id: task[:taskseries_id],
  task_id: task[:task_id],
  tags: 'mcp-tool,implemented,ruby'
})

if result.dig('rsp', 'stat') == 'ok'
  puts "   ✅ Tags added successfully!"
else
  puts "   ❌ Error: #{result}"
end

# Wait for rate limiting
sleep 1

# Test removing tags
puts "\n3. Testing remove_task_tags functionality..."
puts "   Removing tag: 'ruby'"

result = client.call_method('rtm.tasks.removeTags', {
  list_id: task[:list_id],
  taskseries_id: task[:taskseries_id],
  task_id: task[:task_id],
  tags: 'ruby'
})

if result.dig('rsp', 'stat') == 'ok'
  puts "   ✅ Tag removed successfully!"
else
  puts "   ❌ Error: #{result}"
end

# Wait for rate limiting
sleep 1

# Final verification
puts "\n4. Final verification - checking tags..."
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
      tags = []
      if target['tags']
        if target['tags'].is_a?(Array)
          tags = target['tags']
        elsif target['tags'].is_a?(Hash) && target['tags']['tag']
          tag_data = target['tags']['tag']
          tags = tag_data.is_a?(Array) ? tag_data : [tag_data]
        end
      end
      
      tag_display = tags.empty? ? "none" : tags.join(", ")
      puts "Final tags: #{tag_display}"
      puts "Expected: 'implemented, mcp-tool' (without 'ruby')"
    end
  end
end

puts "\nTags MCP tools test complete!"
