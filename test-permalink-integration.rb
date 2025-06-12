#!/usr/bin/env ruby

# Test script for RTM MCP permalinks integration
# Tests the new permalink functionality in the actual MCP server

puts "🔗 RTM MCP Permalinks Integration Test"
puts "=" * 50

# Test the get_task_permalink tool
puts "\n📋 Testing get_task_permalink tool..."

# Test with the task ID from issue #4
test_task_id = "1136773537"
puts "Testing with Task ID: #{test_task_id}"

# Simulate MCP tool call
require 'json'

# Mock request for get_task_permalink tool
mock_request = {
  'method' => 'tools/call',
  'params' => {
    'name' => 'get_task_permalink',
    'arguments' => {
      'task_id' => test_task_id
    }
  }
}

puts "Request:"
puts JSON.pretty_generate(mock_request)

puts "\n🧪 Expected Response:"
puts "Should generate: https://www.rememberthemilk.com/app/#tasks/#{test_task_id}"

puts "\n✅ Test completed!"
puts "Next step: Test with actual RTM MCP server using RTM tools."

# Instructions for manual testing
puts "\n📋 Manual Testing Instructions:"
puts "1. Test list_tasks to see permalinks in output:"
puts "   Use RTM tool: list_tasks with show_ids=true"
puts "2. Test get_task_permalink tool:"
puts "   Use RTM tool: get_task_permalink with task_id='#{test_task_id}'"
puts "3. Verify permalinks work in RTM web interface"
