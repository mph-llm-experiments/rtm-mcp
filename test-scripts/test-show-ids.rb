#!/usr/bin/env ruby
require_relative 'rtm-mcp'

# Read credentials from files
api_key = File.read('.rtm_api_key').strip
shared_secret = File.read('.rtm_shared_secret').strip

# Pass credentials as ARGV
ARGV[0] = api_key
ARGV[1] = shared_secret

# Test the show_ids flag functionality
server = RTMMCPServer.new

puts "=== Testing show_ids Flag ==="
puts

# Test 1: Default behavior (no IDs)
puts "1. Testing default behavior (show_ids not specified)..."
request = {
  'jsonrpc' => '2.0',
  'id' => 1,
  'method' => 'tools/call',
  'params' => {
    'name' => 'list_tasks',
    'arguments' => {
      'list_id' => '51175519',
      'filter' => 'name:"Add show_ids flag"'
    }
  }
}

result = server.handle_request(request)
if result[:content]
  text = result[:content][0][:text]
  puts "Output:"
  puts text
  puts
  puts "✅ No IDs shown (as expected)"
else
  puts "❌ Failed: #{result.inspect}"
end

puts
puts "="*50
puts

# Test 2: With show_ids=true
puts "2. Testing with show_ids=true..."
request = {
  'jsonrpc' => '2.0',
  'id' => 2,
  'method' => 'tools/call',
  'params' => {
    'name' => 'list_tasks',
    'arguments' => {
      'list_id' => '51175519',
      'filter' => 'name:"Add show_ids flag"',
      'show_ids' => true
    }
  }
}

result = server.handle_request(request)
if result[:content]
  text = result[:content][0][:text]
  puts "Output:"
  puts text
  puts
  if text.include?("IDs:")
    puts "✅ IDs are shown!"
  else
    puts "❌ IDs not found in output"
  end
else
  puts "❌ Failed: #{result.inspect}"
end

puts
puts "="*50
puts

# Test 3: Multiple tasks with show_ids
puts "3. Testing multiple tasks with show_ids=true..."
request = {
  'jsonrpc' => '2.0',
  'id' => 3,
  'method' => 'tools/call',
  'params' => {
    'name' => 'list_tasks',
    'arguments' => {
      'list_id' => '51175519',
      'filter' => 'name:"due date"',
      'show_ids' => true
    }
  }
}

result = server.handle_request(request)
if result[:content]
  text = result[:content][0][:text]
  puts "Output (first few tasks):"
  lines = text.split("\n")
  lines[0..10].each { |line| puts line }
  puts "..." if lines.length > 10
else
  puts "❌ Failed: #{result.inspect}"
end
