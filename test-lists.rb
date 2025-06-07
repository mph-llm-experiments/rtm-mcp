#!/usr/bin/env ruby

# Test script for RTM list management
# Usage: ./test-lists.rb [api-key] [shared-secret]

require_relative 'rtm-mcp'

unless ARGV.length == 2
  puts "Usage: #{$0} [api-key] [shared-secret]"
  exit 1
end

api_key = ARGV[0]
shared_secret = ARGV[1]

puts "Testing RTM List Management..."
puts "API Key: #{api_key[0..8]}..."
puts

rtm = RTMClient.new(api_key, shared_secret)

# Test getting all lists
puts "Testing rtm.lists.getList..."
result = rtm.call_method('rtm.lists.getList')

if result['error']
  puts "❌ Failed to get lists: #{result['error']}"
  exit 1
else
  puts "✅ Successfully retrieved lists!"
  lists = result.dig('rsp', 'lists', 'list') || []
  lists = [lists] unless lists.is_a?(Array)
  
  puts "\n📝 Current Lists:"
  lists.each do |list|
    status = []
    status << "archived" if list['archived'] == '1'
    status << "smart" if list['smart'] == '1'
    status_text = status.empty? ? "" : " [#{status.join(', ')}]"
    puts "  • #{list['name']} (ID: #{list['id']})#{status_text}"
  end
end

# Test creating a new list
puts "\n" + "="*50
puts "Testing rtm.lists.add..."
test_list_name = "RTM MCP Test List #{Time.now.to_i}"

result = rtm.call_method('rtm.lists.add', { name: test_list_name })

if result['error']
  puts "❌ Failed to create list: #{result['error']}"
else
  puts "✅ Successfully created list!"
  puts "  Full response: #{JSON.pretty_generate(result)}"
  list = result.dig('rsp', 'list')
  if list
    puts "  Created: #{list['name']} (ID: #{list['id']})"
  else
    puts "  List created but couldn't parse response structure"
  end
end

puts "\nList management tests complete!"
