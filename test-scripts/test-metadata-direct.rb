#!/usr/bin/env ruby
require_relative 'rtm-mcp'

# Test just the metadata setting part
begin
  # Load credentials from files
  api_key = File.read('.rtm_api_key').strip
  shared_secret = File.read('.rtm_shared_secret').strip
  
  server = RTMMCPServer.new(api_key, shared_secret)
  
  puts "🔍 Testing individual metadata methods with exact same params as enhanced create_task"
  puts "=" * 70
  
  # Use the task we just created
  list_id = "51175519"
  taskseries_id = "577314813"  # From the previous test
  task_id = "1137501539"
  
  puts "\n📅 Testing set_due_date..."
  puts "   Calling: set_due_date(#{list_id}, #{taskseries_id}, #{task_id}, 'tomorrow')"
  
  # Use MCP interface to call the method
  request = {
    'jsonrpc' => '2.0',
    'id' => 1,
    'method' => 'tools/call',
    'params' => {
      'name' => 'set_due_date',
      'arguments' => {
        'list_id' => list_id,
        'taskseries_id' => taskseries_id,
        'task_id' => task_id,
        'due' => 'tomorrow'
      }
    }
  }
  
  response = server.handle_request(request)
  due_result = response[:result]
  puts "   Result: #{due_result}"
  puts "   Starts with '✅'? #{due_result&.start_with?('✅')}"
  
  sleep 1
  
  puts "\n🎯 Testing set_task_priority..."
  puts "   Calling: set_task_priority(#{list_id}, #{taskseries_id}, #{task_id}, '2')"
  
  request = {
    'jsonrpc' => '2.0',
    'id' => 2,
    'method' => 'tools/call',
    'params' => {
      'name' => 'set_task_priority',
      'arguments' => {
        'list_id' => list_id,
        'taskseries_id' => taskseries_id,
        'task_id' => task_id,
        'priority' => '2'
      }
    }
  }
  
  response = server.handle_request(request)
  priority_result = response[:result]
  puts "   Result: #{priority_result}"
  puts "   Starts with '✅'? #{priority_result&.start_with?('✅')}"
  
  sleep 1
  
  puts "\n🏷️ Testing add_task_tags..."
  puts "   Calling: add_task_tags(#{list_id}, #{taskseries_id}, #{task_id}, 'direct,test')"
  
  request = {
    'jsonrpc' => '2.0',
    'id' => 3,
    'method' => 'tools/call',
    'params' => {
      'name' => 'add_task_tags',
      'arguments' => {
        'list_id' => list_id,
        'taskseries_id' => taskseries_id,
        'task_id' => task_id,
        'tags' => 'direct,test'
      }
    }
  }
  
  response = server.handle_request(request)
  tags_result = response[:result]
  puts "   Result: #{tags_result}"
  puts "   Starts with '✅'? #{tags_result&.start_with?('✅')}"
  
  puts "\n💡 If all of these start with '✅', then the bug is in the enhanced create_task context"
  
rescue => e
  puts "❌ Error: #{e.message}"
  puts e.backtrace.first(5)
end
