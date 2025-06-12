#!/usr/bin/env ruby

# Test format_tasks method with permalink functionality

require_relative 'rtm-mcp'

puts "🔍 Testing format_tasks with permalinks"
puts "=" * 50

# Create mock task data that mimics RTM API response
mock_result = {
  'rsp' => {
    'stat' => 'ok',
    'tasks' => {
      'list' => {
        'id' => '51175519',
        'name' => 'RTM MCP Development',
        'taskseries' => {
          'id' => '576963123',
          'name' => 'Add permalinks to RTM MCP list',
          'priority' => '2',
          'task' => {
            'id' => '1136773537',
            'completed' => '',
            'due' => '',
            'start' => '',
            'estimate' => ''
          }
        }
      }
    }
  }
}

# Test environment
api_key = ENV['RTM_API_KEY'] || 'test_key'
shared_secret = ENV['RTM_SHARED_SECRET'] || 'test_secret'

begin
  server = RTMMCPServer.new(api_key, shared_secret)
  
  # Access format_tasks method through a test wrapper
  test_server = Class.new(RTMMCPServer) do
    def test_format_tasks(result, parent_task_ids = [], show_ids = false)
      format_tasks(result, parent_task_ids, show_ids)
    end
  end.new(api_key, shared_secret)
  
  puts "🧪 Testing format_tasks with mock data..."
  formatted_output = test_server.test_format_tasks(mock_result, [], false)
  
  puts "\n📋 Formatted Output:"
  puts formatted_output
  
  # Check if permalink is included
  if formatted_output.include?('🔗 https://www.rememberthemilk.com/app/#tasks/1136773537')
    puts "\n✅ SUCCESS: Permalink is included in formatted output!"
  else
    puts "\n❌ ISSUE: Permalink not found in formatted output"
    puts "Looking for: 🔗 https://www.rememberthemilk.com/app/#tasks/1136773537"
  end
  
  # Test with show_ids = true
  puts "\n🔍 Testing with show_ids=true..."
  formatted_with_ids = test_server.test_format_tasks(mock_result, [], true)
  puts formatted_with_ids
  
rescue => e
  puts "❌ Error testing format_tasks: #{e.message}"
  puts e.backtrace.first(5)
end
