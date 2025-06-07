#!/usr/bin/env ruby

require 'json'
require 'open3'

# Test the MCP server protocol compliance

api_key = ARGV[0]
shared_secret = ARGV[1]

unless api_key && shared_secret
  puts "Usage: #{$0} [api-key] [shared-secret]"
  exit 1
end

puts "Starting MCP server test..."

# Start the MCP server
cmd = "./rtm-mcp.rb #{api_key} #{shared_secret}"
stdin, stdout, stderr, wait_thr = Open3.popen3(cmd)

# Give it a moment to start
sleep 1

# Test 1: Initialize
puts "\n=== Test 1: Initialize ==="
request = {
  jsonrpc: "2.0",
  method: "initialize",
  params: {},
  id: 1
}
puts "Request: #{JSON.pretty_generate(request)}"
stdin.puts(JSON.generate(request))
stdin.flush

response = stdout.gets
if response
  puts "Response: #{response}"
  parsed = JSON.parse(response)
  puts "Parsed: #{JSON.pretty_generate(parsed)}"
else
  puts "No response received"
end

# Test 2: Tools list
puts "\n=== Test 2: Tools List ==="
request = {
  jsonrpc: "2.0",
  method: "tools/list",
  params: {},
  id: 2
}
puts "Request: #{JSON.pretty_generate(request)}"
stdin.puts(JSON.generate(request))
stdin.flush

response = stdout.gets
if response
  puts "Response: #{response}"
  parsed = JSON.parse(response)
  puts "Parsed: #{JSON.pretty_generate(parsed)}"
else
  puts "No response received"
end

# Test 3: Call a tool
puts "\n=== Test 3: Test Connection Tool ==="
request = {
  jsonrpc: "2.0",
  method: "tools/call",
  params: {
    name: "test_connection",
    arguments: {}
  },
  id: 3
}
puts "Request: #{JSON.pretty_generate(request)}"
stdin.puts(JSON.generate(request))
stdin.flush

response = stdout.gets
if response
  puts "Response: #{response}"
  parsed = JSON.parse(response)
  puts "Parsed: #{JSON.pretty_generate(parsed)}"
else
  puts "No response received"
end

# Clean up
stdin.close
stdout.close
stderr.close
wait_thr.kill

puts "\nTest complete."
