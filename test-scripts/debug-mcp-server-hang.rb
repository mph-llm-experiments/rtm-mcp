#!/usr/bin/env ruby

# Debug script to investigate the MCP server hanging issue
# This script will test handle_tool_call() method step by step

require_relative '../rtm-mcp.rb'
require 'timeout'

def load_config
  config = {}
  config_paths = [
    File.expand_path('~/.config/rtm-mcp/config'),
    '.rtm_config'
  ]
  
  config_paths.each do |path|
    if File.exist?(path)
      File.readlines(path).each do |line|
        line = line.strip
        next if line.empty? || line.start_with?('#')
        key, value = line.split('=', 2)
        config[key.strip] = value.strip if key && value
      end
      break
    end
  end
  
  config
end

def test_with_timeout(test_name, timeout_seconds = 15)
  puts "\n" + "="*60
  puts "🧪 Testing: #{test_name}"
  puts "⏱️  Timeout: #{timeout_seconds} seconds"
  puts "-" * 60
  
  start_time = Time.now
  result = nil
  
  begin
    Timeout::timeout(timeout_seconds) do
      result = yield
      elapsed = Time.now - start_time
      puts "✅ SUCCESS (#{elapsed.round(3)}s): #{test_name}"
      puts "📤 Result: #{result.inspect}" if result
      return result
    end
  rescue Timeout::Error
    elapsed = Time.now - start_time
    puts "❌ TIMEOUT (#{elapsed.round(3)}s): #{test_name}"
    puts "🔥 HANGING DETECTED - This is where the issue occurs!"
    return :timeout
  rescue => e
    elapsed = Time.now - start_time
    puts "💥 ERROR (#{elapsed.round(3)}s): #{test_name}"
    puts "🐛 Exception: #{e.class}: #{e.message}"
    puts "📍 Backtrace: #{e.backtrace.first(3).join(' -> ')}"
    return :error
  end
end

puts "🚀 Starting MCP Server Hanging Issue Investigation"
puts "📍 Location: #{Dir.pwd}"
puts "🕐 Time: #{Time.now}"

# Load credentials
config = load_config
api_key = config['RTM_API_KEY'] || ENV['RTM_API_KEY']
shared_secret = config['RTM_SHARED_SECRET'] || ENV['RTM_SHARED_SECRET']

unless api_key && shared_secret
  puts "❌ Missing RTM credentials"
  exit 1
end

puts "✅ Credentials loaded successfully"

# Test 1: Create MCP Server Instance
server = test_with_timeout("MCP Server Creation", 5) do
  RTMMCPServer.new(api_key, shared_secret)
end

if server == :timeout || server == :error
  puts "\n🚨 CRITICAL: Can't even create MCP server instance!"
  exit 1
end

puts "✅ MCP Server created successfully"

# Test 2: Test the simplest tool call - test_connection
puts "\n🎯 Now testing the actual hanging issue..."

test_connection_result = test_with_timeout("handle_tool_call - test_connection", 30) do
  server.handle_tool_call({
    'name' => 'test_connection'
  })
end

if test_connection_result == :timeout
  puts "\n🚨 CONFIRMED: handle_tool_call hangs on test_connection!"
  puts "🔍 This confirms the issue is in the MCP server framework"
  
  # Let's try to debug deeper - what happens if we call the underlying method directly?
  puts "\n🔬 Testing underlying test_connection method directly..."
  
  direct_result = test_with_timeout("Direct server.test_connection", 15) do
    # Try to call the private method directly via send
    server.send(:test_connection)
  end
  
  if direct_result != :timeout && direct_result != :error
    puts "✅ Direct method call works fine!"
    puts "🎯 CONCLUSION: The hang is specifically in handle_tool_call() framework"
  else
    puts "❌ Direct method call also hangs/errors"
    puts "🤔 The issue might be deeper in the RTM client or server initialization"
  end
  
else
  puts "🤯 UNEXPECTED: handle_tool_call worked!"
  puts "📤 Result: #{test_connection_result.inspect}"
end

# Test 3: If test_connection worked, try create_task
if test_connection_result != :timeout && test_connection_result != :error
  puts "\n🧪 Testing create_task through handle_tool_call..."
  
  create_task_result = test_with_timeout("handle_tool_call - create_task", 30) do
    server.handle_tool_call({
      'name' => 'create_task',
      'arguments' => {
        'name' => 'Debug Test Task - MCP Server Investigation',
        'list_id' => '51175710'  # Test Task Project list
      }
    })
  end
  
  if create_task_result == :timeout
    puts "🚨 create_task hangs but test_connection works"
    puts "🎯 Issue might be specific to certain tool calls"
  end
end

puts "\n" + "="*60
puts "🏁 DEBUG SESSION COMPLETE"
puts "="*60

if test_connection_result == :timeout
  puts "\n🔥 CRITICAL FINDINGS:"
  puts "   - MCP Server instance creation: ✅ WORKS"
  puts "   - handle_tool_call('test_connection'): ❌ HANGS"
  puts "   - This confirms the hanging is in the MCP framework"
  puts "\n🎯 NEXT STEPS:"
  puts "   1. Debug handle_tool_call() method line by line"
  puts "   2. Check for blocking I/O or infinite loops in the framework"
  puts "   3. Investigate parameter processing before tool execution"
  puts "   4. Check if there are threading/concurrency issues"
else
  puts "\n🤔 UNEXPECTED RESULTS:"
  puts "   - handle_tool_call seems to work in this context"
  puts "   - The hanging might be specific to container/MCP environment"
  puts "   - Or there might be timing/race conditions involved"
end

puts "\n📝 Debug session logged for continuity"
