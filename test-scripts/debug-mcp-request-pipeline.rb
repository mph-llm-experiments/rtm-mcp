#!/usr/bin/env ruby

# Debug script to test the proper MCP request handling pipeline
# This tests the public methods and actual JSON-RPC request flow

require_relative '../rtm-mcp.rb'
require 'timeout'
require 'json'

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
      puts "📤 Result type: #{result.class}"
      puts "📤 Result: #{result.inspect}" if result.to_s.length < 200
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

puts "🚀 Starting MCP Request Pipeline Investigation"
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

# Create server instance
server = test_with_timeout("MCP Server Creation", 5) do
  RTMMCPServer.new(api_key, shared_secret)
end

if server == :timeout || server == :error
  puts "\n🚨 CRITICAL: Can't create MCP server instance!"
  exit 1
end

puts "✅ MCP Server created successfully"

# Test 1: Check available public methods
puts "\n🔍 Investigating available public methods..."
public_methods = server.public_methods(false).sort
puts "📋 Public methods: #{public_methods.join(', ')}"

# Test 2: Try handle_request (the likely public entry point)
if server.respond_to?(:handle_request)
  puts "\n🎯 Testing handle_request method..."
  
  # Create a proper MCP request for test_connection
  test_connection_request = {
    "method" => "tools/call",
    "params" => {
      "name" => "test_connection"
    }
  }
  
  result = test_with_timeout("handle_request - test_connection", 30) do
    server.handle_request(test_connection_request)
  end
  
  if result == :timeout
    puts "🚨 CONFIRMED: handle_request hangs on test_connection!"
    puts "🎯 This is the actual hanging issue location"
  elsif result == :error
    puts "🤔 handle_request failed - might need different request format"
  else
    puts "✅ handle_request worked - investigating further..."
    
    # Try create_task if test_connection worked
    create_task_request = {
      "method" => "tools/call", 
      "params" => {
        "name" => "create_task",
        "arguments" => {
          "name" => "Debug Test - MCP Request Pipeline",
          "list_id" => "51175710"
        }
      }
    }
    
    create_result = test_with_timeout("handle_request - create_task", 30) do
      server.handle_request(create_task_request)
    end
    
    if create_result == :timeout
      puts "🚨 create_task hangs but test_connection works"
    end
  end
else
  puts "❌ handle_request method not available"
end

# Test 3: Test other potential entry points
potential_methods = ['call', 'process_request', 'execute', 'run']
potential_methods.each do |method_name|
  if server.respond_to?(method_name)
    puts "\n🧪 Found potential entry point: #{method_name}"
    
    test_result = test_with_timeout("#{method_name} - test_connection", 15) do
      case method_name
      when 'call'
        server.call('test_connection')
      when 'process_request'
        server.process_request({'name' => 'test_connection'})
      when 'execute'
        server.execute('test_connection')
      when 'run'
        server.run({'name' => 'test_connection'})
      end
    end
    
    if test_result == :timeout
      puts "🔥 #{method_name} also hangs!"
    end
  end
end

# Test 4: Try accessing the private method via send (for comparison)
puts "\n🔬 Testing private method access via send..."
send_result = test_with_timeout("send(:handle_tool_call) - test_connection", 15) do
  server.send(:handle_tool_call, {'name' => 'test_connection'})
end

if send_result != :timeout && send_result != :error
  puts "✅ Private method works via send - confirms issue is in public interface"
elsif send_result == :timeout
  puts "🚨 Private method also hangs - issue is deeper in the method itself"
end

# Test 5: Direct method testing (if possible)
puts "\n🧪 Testing direct RTM method calls..."
direct_test_result = test_with_timeout("Direct test_connection method", 15) do
  server.send(:test_connection)
end

if direct_test_result != :timeout && direct_test_result != :error
  puts "✅ Direct method call works - confirms framework issue"
end

puts "\n" + "="*60
puts "🏁 MCP REQUEST PIPELINE DEBUG COMPLETE"
puts "="*60

# Summary of findings
puts "\n🔍 INVESTIGATION SUMMARY:"
puts "   - MCP Server Creation: ✅"
puts "   - Public Methods Found: #{public_methods.any? ? '✅' : '❌'}"

if server.respond_to?(:handle_request)
  puts "   - handle_request Available: ✅"
else
  puts "   - handle_request Available: ❌"
end

puts "\n🎯 KEY FINDINGS:"
puts "   This investigation reveals the proper MCP request entry points"
puts "   and whether the hanging occurs in the public interface or deeper"

puts "\n📝 Next steps depend on which methods hang vs work"
