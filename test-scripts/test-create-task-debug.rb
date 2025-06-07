#!/usr/bin/env ruby

require_relative 'rtm-mcp'

# Test creating a task to see the actual API response structure
def test_create_task_response
  puts "=== Testing create_task API response structure ==="
  
  # Initialize client
  api_key = File.read('.rtm_api_key').strip
  shared_secret = File.read('.rtm_shared_secret').strip
  auth_token = File.read('.rtm_auth_token').strip
  
  client = RTMClient.new(api_key, shared_secret)
  
  # Create a task in the Test Task Project list (ID: 51175710)
  test_list_id = "51175710"
  task_name = "Debug Test Task #{Time.now.to_i}"
  
  puts "\nCreating task: #{task_name}"
  puts "In list ID: #{test_list_id}"
  
  # Call the raw API method to see the response
  params = { name: task_name, list_id: test_list_id }
  result = client.call_method('rtm.tasks.add', params)
  
  puts "\n=== Raw API Response ==="
  puts JSON.pretty_generate(result)
  
  # Now test our create_task method
  puts "\n=== Our create_task method result ==="
  response = client.create_task(task_name + " (method test)", test_list_id)
  puts response
end

test_create_task_response
