#!/usr/bin/env ruby

require_relative 'rtm-mcp'
require 'json'

# Test the enhanced create_task functionality
begin
  api_key = ENV['RTM_API_KEY']
  shared_secret = ENV['RTM_SHARED_SECRET']
  
  unless api_key && shared_secret
    puts "Error: Missing RTM_API_KEY or RTM_SHARED_SECRET environment variables"
    exit 1
  end
  
  # Get RTM client directly
  rtm_client = RTMClient.new(api_key, shared_secret)
  
  # Test 1: Basic task creation via direct API
  puts "=== Test 1: Basic Task Creation via Direct API ==="
  result1 = rtm_client.call_method('rtm.tasks.add', {
    name: 'Test basic from script',
    list_id: '51175519'
  })
  puts "Basic result:"
  puts JSON.pretty_generate(result1)
  puts
  
  # Test 2: Enhanced task creation with all metadata via direct API
  puts "=== Test 2: Enhanced Task Creation via Direct API ==="
  result2 = rtm_client.call_method('rtm.tasks.add', {
    name: 'Test enhanced from script',
    list_id: '51175519',
    due: 'tomorrow',
    priority: '1',
    tags: 'script,test',
    parse: '1'
  })
  puts "Enhanced result:"
  puts JSON.pretty_generate(result2)
  
rescue => e
  puts "Error: #{e.message}"
  puts e.backtrace
end
