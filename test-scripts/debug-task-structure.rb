#!/usr/bin/env ruby

require_relative 'rtm-mcp'
require 'json'

api_key = 'f59d4ff4d57a5e3420a164abbee086c8'
shared_secret = '589e10346b802001'

rtm = RTMClient.new(api_key, shared_secret)

# Create a basic task and inspect the response
result = rtm.call_method('rtm.tasks.add', {
  name: 'Debug task structure',
  list_id: '51175519'
})

puts "=== Task Creation Result ==="
puts JSON.pretty_generate(result)

# Extract task details like the create_task method does
if result['rsp'] && result['rsp']['stat'] == 'ok'
  list = result.dig('rsp', 'list')
  taskseries = list&.dig('taskseries')
  
  if taskseries.is_a?(Array)
    task = taskseries.first
  else
    task = taskseries
  end
  
  puts "\n=== Extracted Task Info ==="
  puts "List ID: #{list['id']}"
  puts "Task series ID: #{task['id']}"
  puts "Task object: #{task['task']}"
  
  task_obj = task['task']
  if task_obj.is_a?(Array)
    puts "Task ID: #{task_obj[0]['id']}"
  else
    puts "Task ID: #{task_obj['id']}"
  end
end
