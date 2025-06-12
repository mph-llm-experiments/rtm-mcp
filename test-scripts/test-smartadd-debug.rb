#!/usr/bin/env ruby
require_relative 'rtm-mcp'

# Test Smart Add text construction
begin
  puts "🔍 Testing Smart Add text construction"
  puts "=" * 50
  
  name = "Test task"
  due = "tomorrow"
  priority = "1"
  tags = "debug,test"
  
  # Build Smart Add text with all metadata in one string
  smart_add_text = name.dup
  
  # Add due date to Smart Add text
  if due && !due.empty?
    smart_add_text += " ^#{due}"
  end
  
  # Add priority to Smart Add text  
  if priority && !priority.empty?
    case priority
    when '1'
      smart_add_text += " !1"
    when '2' 
      smart_add_text += " !2"
    when '3'
      smart_add_text += " !3"
    end
  end
  
  # Add tags to Smart Add text
  if tags && !tags.empty?
    tag_list = tags.split(',').map(&:strip)
    tag_list.each { |tag| smart_add_text += " ##{tag}" }
  end
  
  puts "Original name: #{name}"
  puts "Due: #{due}"
  puts "Priority: #{priority}"
  puts "Tags: #{tags}"
  puts
  puts "Smart Add text: '#{smart_add_text}'"
  
  # Test with a basic RTM client call
  api_key = File.read('.rtm_api_key').strip
  shared_secret = File.read('.rtm_shared_secret').strip
  
  rtm_client = RTMClient.new(api_key, shared_secret)
  
  params = {
    name: smart_add_text,
    parse: 1,
    list_id: "51175519"
  }
  
  puts "\nAPI call params: #{params}"
  
  result = rtm_client.call_method('rtm.tasks.add', params)
  puts "\nAPI result:"
  puts JSON.pretty_generate(result)
  
rescue => e
  puts "❌ Error: #{e.message}"
  puts e.backtrace.first(5)
end
