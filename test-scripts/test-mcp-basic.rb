#!/usr/bin/env ruby
require_relative 'rtm-mcp'

# Read credentials from files
api_key = File.read('.rtm_api_key').strip
shared_secret = File.read('.rtm_shared_secret').strip

# Pass credentials as ARGV
ARGV[0] = api_key
ARGV[1] = shared_secret

# Test the MCP server basic functionality
server = RTMMCPServer.new

puts "=== Testing MCP Server Basic Operations ==="
puts

# Test 1: Tools list
puts "1. Testing tools/list..."
test_request = {
  'jsonrpc' => '2.0',
  'id' => 1,
  'method' => 'tools/list'
}

result = server.handle_request(test_request)
if result[:tools]
  puts "   ✅ Success! Found #{result[:tools].length} tools"
else
  puts "   ❌ Failed: #{result.inspect}"
end

puts

# Test 2: Test connection
puts "2. Testing test_connection..."
test_request = {
  'jsonrpc' => '2.0',
  'id' => 2,
  'method' => 'tools/call',
  'params' => {
    'name' => 'test_connection',
    'arguments' => {}
  }
}

result = server.handle_request(test_request)
if result[:content]
  puts "   ✅ Success!"
  puts "   Response: #{result[:content][0][:text][0..100]}..."
else
  puts "   ❌ Failed: #{result.inspect}"
end

puts

# Test 3: List tasks (this will test v2 API and format_tasks)
puts "3. Testing list_tasks..."
test_request = {
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

result = server.handle_request(test_request)
if result[:content]
  text = result[:content][0][:text]
  puts "   ✅ Success!"
  puts "   Output preview:"
  puts text.split("\n")[0..5].join("\n")
else
  puts "   ❌ Failed: #{result.inspect}"
end
