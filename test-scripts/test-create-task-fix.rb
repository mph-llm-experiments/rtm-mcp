#!/usr/bin/env ruby

require_relative 'rtm-mcp'

def test_create_task_fix
  puts "=== Testing create_task fix ==="
  
  # Initialize client  
  api_key = File.read('.rtm_api_key').strip
  shared_secret = File.read('.rtm_shared_secret').strip
  
  client = RTMClient.new(api_key, shared_secret)
  
  # Test creating a task in the Test Task Project list (ID: 51175710)
  test_list_id = "51175710"
  task_name = "Fix Test Task #{Time.now.to_i}"
  
  puts "\nTesting create_task with list_id parameter..."
  puts "Creating task: '#{task_name}'"
  puts "In list ID: #{test_list_id}"
  
  response = client.create_task(task_name, test_list_id)
  puts "\nResponse:"
  puts response
  
  # Also test without list_id (should use default)
  puts "\n" + "="*50
  puts "Testing create_task without list_id (default list)..."
  
  default_task_name = "Default List Fix Test #{Time.now.to_i}"
  puts "Creating task: '#{default_task_name}'"
  
  default_response = client.create_task(default_task_name)
  puts "\nResponse:"
  puts default_response
  
  puts "\n=== Test completed ==="
end

test_create_task_fix
