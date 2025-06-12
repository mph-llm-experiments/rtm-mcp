#!/usr/bin/env ruby

# Debug script to isolate MCP server tool call hanging
# Based on continuity note findings that hang occurs in MCP server context

require 'timeout'
require_relative '../rtm-mcp'

puts "🔍 DEBUG: MCP Tool Call Hanging Investigation"
puts "=" * 60

def test_with_timeout(description, timeout_seconds = 5)
  puts "\n#{description}"
  start_time = Time.now
  
  begin
    result = Timeout::timeout(timeout_seconds) do
      yield
    end
    elapsed = Time.now - start_time
    puts "✅ SUCCESS: #{elapsed.round(3)}s - #{result.inspect}"
    result
  rescue Timeout::Error
    elapsed = Time.now - start_time
    puts "❌ TIMEOUT: #{elapsed.round(3)}s - HUNG!"
    nil
  rescue => e
    elapsed = Time.now - start_time
    puts "❌ ERROR: #{elapsed.round(3)}s - #{e.class}: #{e.message}"
    puts "   #{e.backtrace.first(3).join("\n   ")}" if e.backtrace
    nil
  end
end

# Step 1: Test RTMClient creation in isolation (should work)
client = test_with_timeout("Step 1: Creating RTMClient in isolation") do
  RTMClient.new
end

if client.nil?
  puts "❌ FAILED: Can't even create RTMClient - basic setup issue"
  exit 1
end

# Step 2: Test basic RTM API call (should work)
test_with_timeout("Step 2: Basic RTM API call") do
  client.call_method('rtm.test.echo', {'test' => 'hello'})
end

# Step 3: Test RTMMCPServer creation (might hang here?)
server = test_with_timeout("Step 3: Creating RTMMCPServer instance") do
  RTMMCPServer.new
end

if server.nil?
  puts "❌ FAILED: RTMMCPServer creation hangs"
  exit 1
end

# Step 4: Test simple tool call that should work quickly
test_with_timeout("Step 4: handle_tool_call - test_connection", 10) do
  server.handle_tool_call({'name' => 'test_connection'})
end

# Step 5: Test list_all_lists (might hang here?)
test_with_timeout("Step 5: handle_tool_call - list_all_lists", 10) do
  server.handle_tool_call({'name' => 'list_all_lists'})
end

# Step 6: Test the problematic create_task call
test_with_timeout("Step 6: handle_tool_call - create_task", 15) do
  server.handle_tool_call({
    'name' => 'create_task',
    'arguments' => {
      'name' => 'Debug test task',
      'list_id' => '51175710'  # Test Task Project list
    }
  })
end

puts "\n" + "=" * 60
puts "🎯 DEBUG SUMMARY:"
puts "- If Step 1-2 work but Step 3 hangs: RTMMCPServer creation issue"
puts "- If Step 3 works but Step 4 hangs: MCP tool dispatch issue"  
puts "- If Step 4-5 work but Step 6 hangs: create_task specific issue"
puts "- Look for the LAST successful step to narrow down hang location"
