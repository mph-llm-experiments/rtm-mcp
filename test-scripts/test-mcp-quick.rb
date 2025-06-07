#!/usr/bin/env ruby

# Quick test to ensure MCP server is responding correctly

require 'json'
require 'open3'

api_key = ARGV[0]
shared_secret = ARGV[1]

unless api_key && shared_secret
  puts "Usage: #{$0} [api-key] [shared-secret]"
  exit 1
end

puts "Testing MCP server protocol compliance..."

# Start the server
stdin, stdout, stderr, wait_thr = Open3.popen3("./rtm-mcp.rb #{api_key} #{shared_secret}")

# Test initialize
request = {
  "jsonrpc" => "2.0",
  "method" => "initialize",
  "params" => {},
  "id" => 1
}

stdin.puts(JSON.generate(request))
stdin.flush

response = stdout.gets
if response
  parsed = JSON.parse(response)
  if parsed["jsonrpc"] == "2.0" && parsed["id"] == 1 && parsed["result"]
    puts "✅ Initialize response is valid"
  else
    puts "❌ Initialize response is invalid: #{response}"
  end
else
  puts "❌ No response received"
end

# Clean up
stdin.close
stdout.close
stderr.close
wait_thr.kill

puts "Test complete."
