#!/usr/bin/env ruby
require_relative 'rtm-mcp'

# Read credentials from files
api_key = File.read('.rtm_api_key').strip
shared_secret = File.read('.rtm_shared_secret').strip

# Pass credentials as ARGV
ARGV[0] = api_key
ARGV[1] = shared_secret

# Test the updated server with subtask display
server = RTMMCPServer.new

puts "=== Testing Subtask Display in RTM MCP ==="
puts

# Test list_tasks
test_request = {
  'jsonrpc' => '2.0',
  'id' => 1,
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
  puts result[:content][0][:text]
else
  puts "Error: #{result}"
end
