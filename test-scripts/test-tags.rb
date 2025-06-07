#!/usr/bin/env ruby

require_relative 'rtm-mcp'

# Test script for RTM tags functionality
# RTM supports multiple tags per task

api_key = ARGV[0] || ENV['RTM_API_KEY']
shared_secret = ARGV[1] || ENV['RTM_SHARED_SECRET']

if !api_key || !shared_secret
  puts "Usage: #{$0} API_KEY SHARED_SECRET"
  exit 1
end

client = RTMClient.new(api_key, shared_secret)

puts "=== RTM Tags Test ==="
puts "Testing add/remove tags functionality"
puts

# First, list tasks to find one to test with
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
list = list.first if list.is_a?(Array)

if list && list['taskseries']
  taskseries = list['taskseries']
  taskseries = [taskseries] unless taskseries.is_a?(Array)
  
  taskseries.each do |ts|
    task = ts['task']
    task = task.first if task.is_a?(Array)
    
    # Extract tags - they can be in different formats
    tags = []
    if ts['tags']
      if ts['tags'].is_a?(Array)
        tags = ts['tags']
      elsif ts['tags'].is_a?(Hash) && ts['tags']['tag']
        tag_data = ts['tags']['tag']
        tags = tag_data.is_a?(Array) ? tag_data : [tag_data]
      end
    end
    
    tasks << {
      name: ts['name'],
      list_id: list['id'],
      taskseries_id: ts['id'],
      task_id: task['id'],
      tags: tags
    }
  end
end

if tasks.empty?
  puts "No tasks found!"
  exit 1
end

puts "\nFound #{tasks.length} tasks:"
tasks.each_with_index do |task, i|
  tag_display = task[:tags].empty? ? "none" : task[:tags].join(", ")
  puts "#{i+1}. #{task[:name]} - Tags: #{tag_display}"
end

# Test with the first task
test_task = tasks.first
puts "\n2. Testing tag operations on: #{test_task[:name]}"

# Test adding tags
test_tags = ['rtm-mcp', 'testing', 'priority-high']
puts "\n   Adding tags: #{test_tags.join(', ')}"

result = client.call_method('rtm.tasks.addTags', {
  list_id: test_task[:list_id],
  taskseries_id: test_task[:taskseries_id],
  task_id: test_task[:task_id],
  tags: test_tags.join(',')
})

if result.dig('rsp', 'stat') == 'ok'
  puts "   ✅ Tags added successfully!"
  
  # Show updated tags from response
  list_data = result.dig('rsp', 'list')
  if list_data
    list_data = list_data.first if list_data.is_a?(Array)
    
    ts = list_data['taskseries']
    if ts
      ts = ts.first if ts.is_a?(Array)
      
      tags = []
      if ts['tags']
        if ts['tags'].is_a?(Array)
          tags = ts['tags']
        elsif ts['tags'].is_a?(Hash) && ts['tags']['tag']
          tag_data = ts['tags']['tag']
          tags = tag_data.is_a?(Array) ? tag_data : [tag_data]
        end
      end
      
      puts "   Current tags: #{tags.join(', ')}"
    end
  end
else
  puts "   ❌ Error: #{result}"
end

# Test removing a tag
puts "\n   Removing tag: testing"
sleep 1  # Rate limiting

result = client.call_method('rtm.tasks.removeTags', {
  list_id: test_task[:list_id],
  taskseries_id: test_task[:taskseries_id],
  task_id: test_task[:task_id],
  tags: 'testing'
})

if result.dig('rsp', 'stat') == 'ok'
  puts "   ✅ Tag removed successfully!"
else
  puts "   ❌ Error: #{result}"
end

# Final verification
puts "\n3. Final verification - listing task again..."
sleep 1

result = client.call_method('rtm.tasks.getList', { 
  list_id: test_task[:list_id],
  filter: "status:incomplete"
})

if result.dig('rsp', 'stat') == 'ok'
  list = result.dig('rsp', 'tasks', 'list')
  list = list.first if list.is_a?(Array)
  
  if list && list['taskseries']
    taskseries = list['taskseries']
    taskseries = [taskseries] unless taskseries.is_a?(Array)
    
    target = taskseries.find { |ts| ts['id'] == test_task[:taskseries_id] }
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
    end
  end
end

puts "\nTags test complete!"
