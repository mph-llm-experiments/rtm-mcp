#!/usr/bin/env ruby
require_relative 'rtm-mcp'

# Read credentials from files
api_key = File.read('.rtm_api_key').strip
shared_secret = File.read('.rtm_shared_secret').strip

# Pass credentials as ARGV
ARGV[0] = api_key
ARGV[1] = shared_secret

# Test the MCP server create_subtask functionality
server = RTMMCPServer.new

puts "=== Testing Create Subtask MCP Tool ==="
puts

# First, let's find the parent task
puts "1. Finding parent task 'Add subtask support'..."
list_request = {
  'jsonrpc' => '2.0',
  'id' => 1,
  'method' => 'tools/call',
  'params' => {
    'name' => 'list_tasks',
    'arguments' => {
      'list_id' => '51175519',
      'filter' => 'name:"Add subtask support"'
    }
  }
}

result = server.handle_request(list_request)
if result[:content]
  text = result[:content][0][:text]
  puts "   Output:"
  puts text
  
  # Extract the IDs from the output (this is what a user would need to do)
  # In a real scenario, we'd parse this from the debug output or have a separate tool
  parent_info = {
    list_id: '51175519',
    taskseries_id: '576923558',
    task_id: '1136721772'
  }
else
  puts "   ❌ Failed: #{result.inspect}"
  exit 1
end

puts
puts "2. Creating subtask 'Test MCP subtask creation'..."

create_subtask_request = {
  'jsonrpc' => '2.0',
  'id' => 2,
  'method' => 'tools/call',
  'params' => {
    'name' => 'create_subtask',
    'arguments' => {
      'name' => 'Test MCP subtask creation',
      'parent_list_id' => parent_info[:list_id],
      'parent_taskseries_id' => parent_info[:taskseries_id],
      'parent_task_id' => parent_info[:task_id]
    }
  }
}

result = server.handle_request(create_subtask_request)
if result[:content]
  text = result[:content][0][:text]
  puts "   ✅ Response:"
  puts text
else
  puts "   ❌ Failed: #{result.inspect}"
end

puts
puts "3. List tasks to verify subtask indicator..."
sleep 1

verify_request = {
  'jsonrpc' => '2.0',
  'id' => 3,
  'method' => 'tools/call',
  'params' => {
    'name' => 'list_tasks',
    'arguments' => {
      'list_id' => '51175519',
      'filter' => 'status:incomplete'
    }
  }
}

result = server.handle_request(verify_request)
if result[:content]
  text = result[:content][0][:text]
  # Show just the relevant tasks
  lines = text.split("\n")
  puts "   Relevant tasks:"
  lines.each do |line|
    if line.include?("Add subtask support") || line.include?("Test MCP subtask")
      puts "   #{line}"
    end
  end
else
  puts "   ❌ Failed: #{result.inspect}"
end
