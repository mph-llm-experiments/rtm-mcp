#!/usr/bin/env ruby
require_relative 'rtm-mcp'

# Direct test to understand what's happening with the metadata calls
puts "🔍 Direct test of metadata setting methods"
puts "=" * 50

begin
  # Load credentials from files
  api_key = File.read('.rtm_api_key').strip
  shared_secret = File.read('.rtm_shared_secret').strip
  
  server = RTMMCPServer.new(api_key, shared_secret)
  
  # First create a basic task to get IDs
  puts "📝 Creating a basic task to get IDs..."
  
  # Use MCP interface to call create_task with basic parameters only
  basic_request = {
    'jsonrpc' => '2.0',
    'id' => 1,
    'method' => 'tools/call',
    'params' => {
      'name' => 'create_task',
      'arguments' => {
        'name' => 'DEBUG: Test metadata setting',
        'list_id' => '51175519'
      }
    }
  }
  
  basic_response = server.handle_request(basic_request)
  puts "Basic task creation result:"
  puts basic_response[:result] if basic_response[:result]
  puts basic_response[:error] if basic_response[:error]
  
  # Now try to manually test the metadata methods
  # We'll need to extract the IDs from a recent task
  
rescue => e
  puts "❌ Error: #{e.message}"
  puts e.backtrace.first(5)
end
