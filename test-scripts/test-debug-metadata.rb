#!/usr/bin/env ruby
require_relative 'rtm-mcp'

# Test the bug in enhanced create_task metadata setting
puts "🔍 Testing metadata bug in enhanced create_task"
puts "=" * 50

# First, let's create a basic server instance to test the flow
begin
  # Load credentials from files
  api_key = File.read('.rtm_api_key').strip
  shared_secret = File.read('.rtm_shared_secret').strip
  
  unless api_key && shared_secret
    puts "❌ Missing credential files"
    exit 1
  end
  
  server = RTMMCPServer.new(api_key, shared_secret)
  
  puts "✅ Server initialized"
  
  # Test the enhanced create_task with metadata using MCP interface
  puts "\n📝 Testing enhanced create_task with metadata..."
  
  request = {
    'jsonrpc' => '2.0',
    'id' => 1,
    'method' => 'tools/call',
    'params' => {
      'name' => 'create_task',
      'arguments' => {
        'name' => 'DEBUG: Metadata test task',
        'list_id' => '51175519',
        'due' => 'tomorrow',
        'priority' => '1',
        'tags' => 'debug,test'
      }
    }
  }
  
  response = server.handle_request(request)
  
  puts "\n📋 Result:"
  puts response[:result] if response[:result]
  puts response[:error] if response[:error]
  
  puts "\n🔍 Expected to see:"
  puts "✅ Created task: DEBUG: Metadata test task in RTM MCP Development"
  puts "   IDs: list=51175519, series=..., task=..."
  puts "📅 Due date set"
  puts "Priority: 🔴 High"
  puts "🏷️ Tags: debug,test"
  
  puts "\n💡 If you only see the basic task creation line, the bug is confirmed!"
  
rescue => e
  puts "❌ Error: #{e.message}"
  puts e.backtrace.first(5)
end
