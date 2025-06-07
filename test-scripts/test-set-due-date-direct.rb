#!/usr/bin/env ruby

# Direct test of set_due_date tool
# This bypasses MCP protocol and calls methods directly

require_relative 'rtm-mcp'

# Load credentials
api_key = File.read('.rtm_api_key').strip
shared_secret = File.read('.rtm_shared_secret').strip

# Pass credentials to ARGV for the server
ARGV[0] = api_key
ARGV[1] = shared_secret

# Create server instance and access private methods for testing
server = RTMMCPServer.new

puts "🧪 Testing set_due_date implementation..."
puts "=" * 40

# Use send to call private methods for testing
puts "\nCreating test task..."
result = server.send(:create_task, "Test due date - #{Time.now.strftime('%H:%M:%S')}", '51175519')
puts result

# Extract IDs - let me see what the result actually contains
puts "\nResult was: #{result.inspect}"
if result =~ /list=(\d+), series=(\d+), task=(\d+)/ || result =~ /IDs: list=(\d+), series=(\d+), task=(\d+)/
  list_id = $1
  series_id = $2
  task_id = $3
  
  puts "Extracted IDs: list=#{list_id}, series=#{series_id}, task=#{task_id}"
  
  # Test 1: Set due date to tomorrow
  puts "\n1️⃣ Setting due date to 'tomorrow'..."
  result = server.send(:set_due_date, list_id, series_id, task_id, 'tomorrow')
  puts result
  
  sleep 1
  
  # Test 2: Set due date with time
  puts "\n2️⃣ Setting due date to 'Friday at 3pm'..."
  result = server.send(:set_due_date, list_id, series_id, task_id, 'Friday at 3pm')
  puts result
  
  sleep 1
  
  # Test 3: Clear due date
  puts "\n3️⃣ Clearing due date..."
  result = server.send(:set_due_date, list_id, series_id, task_id, '')
  puts result
  
  sleep 1
  
  # Clean up
  puts "\n🧹 Cleaning up..."
  server.send(:complete_task, list_id, series_id, task_id)
  puts "✅ Test task completed"
else
  puts "❌ Failed to extract task IDs"
end

puts "\n" + "=" * 40
puts "Test complete!"
