#!/usr/bin/env ruby

# Test script for RTM task operations
# Usage: ./test-tasks.rb [api-key] [shared-secret]

require_relative 'rtm-mcp'

unless ARGV.length == 2
  puts "Usage: #{$0} [api-key] [shared-secret]"
  exit 1
end

api_key = ARGV[0]
shared_secret = ARGV[1]

puts "Testing RTM Task Operations..."
puts "API Key: #{api_key[0..8]}..."
puts

rtm = RTMClient.new(api_key, shared_secret)

# Test getting tasks
puts "Testing rtm.tasks.getList..."
result = rtm.call_method('rtm.tasks.getList')

if result['error']
  puts "❌ Failed to get tasks: #{result['error']}"
else
  puts "✅ Successfully retrieved tasks!"
  puts "Response structure: #{result.dig('rsp', 'tasks').keys if result.dig('rsp', 'tasks')}"
end

# Test creating a task
puts "\n" + "="*50
puts "Testing rtm.tasks.add..."
test_task_name = "RTM MCP Test Task #{Time.now.to_i}"

result = rtm.call_method('rtm.tasks.add', { name: test_task_name })

if result['error']
  puts "❌ Failed to create task: #{result['error']}"
else
  puts "✅ Successfully created task!"
  puts "Full response: #{JSON.pretty_generate(result)}"
end

puts "\nTask operations tests complete!"
