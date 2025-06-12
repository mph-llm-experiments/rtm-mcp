#!/usr/bin/env ruby

# Test specific RTM authentication calls with timeouts
require 'timeout'
require_relative '../rtm-mcp'

puts "🔍 Test Specific RTM Auth Calls"
puts "=" * 40

def test_with_timeout(description, timeout_seconds = 10)
  puts "\n#{description}"
  start_time = Time.now
  
  begin
    result = Timeout::timeout(timeout_seconds) do
      yield
    end
    elapsed = Time.now - start_time
    puts "✅ SUCCESS: #{elapsed.round(3)}s"
    puts "   Result: #{result.inspect[0..200]}#{'...' if result.inspect.length > 200}"
    result
  rescue Timeout::Error
    elapsed = Time.now - start_time
    puts "❌ TIMEOUT: #{elapsed.round(3)}s - HUNG!"
    nil
  rescue => e
    elapsed = Time.now - start_time
    puts "❌ ERROR: #{elapsed.round(3)}s - #{e.class}: #{e.message}"
    puts "   #{e.backtrace.first(2).join("\n   ")}" if e.backtrace
    nil
  end
end

# Load config
config_path = File.expand_path('~/.config/rtm-mcp/config')
config = {}
File.readlines(config_path).each do |line|
  line = line.strip
  next if line.empty? || line.start_with?('#')
  key, value = line.split('=', 2)
  config[key] = value if key && value
end

api_key = config['RTM_API_KEY']
shared_secret = config['RTM_SHARED_SECRET']

puts "Creating RTMClient..."
client = RTMClient.new(api_key, shared_secret)

# Test 1: Basic echo (we know this works)
test_with_timeout("Test 1: rtm.test.echo") do
  client.call_method('rtm.test.echo', {'test' => 'hello'})
end

# Test 2: Login check (this might hang)
test_with_timeout("Test 2: rtm.test.login", 15) do
  client.call_method('rtm.test.login')
end

# Test 3: If login works, try listing lists
test_with_timeout("Test 3: rtm.lists.getList", 15) do
  client.call_method('rtm.lists.getList')
end

# Test 4: Test the MCP server context (this might hang)
puts "\n" + "-" * 40
puts "Testing MCP Server Context:"

server = test_with_timeout("Test 4: Create RTMMCPServer", 10) do
  RTMMCPServer.new
end

if server
  test_with_timeout("Test 5: MCP test_connection", 10) do
    server.handle_tool_call({'name' => 'test_connection'})
  end
  
  test_with_timeout("Test 6: MCP list_all_lists", 15) do
    server.handle_tool_call({'name' => 'list_all_lists'})
  end
end

puts "\n" + "=" * 40
puts "🎯 ANALYSIS:"
puts "- If Test 1 works but Test 2 hangs: rtm.test.login is the issue"
puts "- If Tests 1-3 work but Test 4 hangs: MCP server creation is the issue"
puts "- If Tests 1-4 work but Test 5-6 hang: MCP tool calls are the issue"
