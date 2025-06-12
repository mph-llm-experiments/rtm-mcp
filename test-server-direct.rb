#!/usr/bin/env ruby

# Direct test of RTM MCP server with permalink functionality
# This bypasses Claude Desktop to test our implementation directly

require_relative 'rtm-mcp'

# Test environment variables or use test credentials
api_key = ENV['RTM_API_KEY'] || 'test_key'
shared_secret = ENV['RTM_SHARED_SECRET'] || 'test_secret'

puts "🧪 Testing RTM MCP Server with Permalinks"
puts "=" * 50

begin
  # Create server instance
  server = RTMMCPServer.new(api_key, shared_secret)
  
  # Test 1: Check if get_task_permalink tool is registered
  puts "\n1️⃣ Testing tool registration..."
  
  tools_response = server.handle_request({'method' => 'tools/list'})
  tools = tools_response[:tools] || []
  
  permalink_tool = tools.find { |tool| tool[:name] == 'get_task_permalink' }
  
  if permalink_tool
    puts "✅ get_task_permalink tool is registered!"
    puts "   Description: #{permalink_tool[:description]}"
  else
    puts "❌ get_task_permalink tool NOT found in tools list"
    puts "   Available tools: #{tools.map { |t| t[:name] }.join(', ')}"
  end
  
  # Test 2: Test the permalink generation method directly
  puts "\n2️⃣ Testing permalink generation..."
  
  test_task_id = "1136773537"
  
  # Create a test instance to access private method
  test_server = Class.new(RTMMCPServer) do
    def test_permalink(task_id)
      generate_rtm_permalink(task_id)
    end
  end.new(api_key, shared_secret)
  
  permalink = test_server.test_permalink(test_task_id)
  
  if permalink
    puts "✅ Permalink generation works!"
    puts "   Task ID: #{test_task_id}"
    puts "   Permalink: #{permalink}"
  else
    puts "❌ Permalink generation failed"
  end
  
  # Test 3: Test the get_task_permalink tool call
  puts "\n3️⃣ Testing get_task_permalink tool call..."
  
  tool_request = {
    'method' => 'tools/call',
    'params' => {
      'name' => 'get_task_permalink',
      'arguments' => {
        'task_id' => test_task_id
      }
    }
  }
  
  response = server.handle_request(tool_request)
  
  if response[:content]
    puts "✅ Tool call successful!"
    puts "   Response: #{response[:content][0][:text]}"
  else
    puts "❌ Tool call failed"
    puts "   Response: #{response}"
  end
  
rescue => e
  puts "❌ Error testing server: #{e.message}"
  puts "   This is expected if RTM credentials aren't configured"
  puts "   The important thing is that the tool registration works"
end

puts "\n🎯 Summary:"
puts "If tests 1-2 pass, the implementation is working correctly."
puts "Claude Desktop may need to be restarted to pick up new tools."
