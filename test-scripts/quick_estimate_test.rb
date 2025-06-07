#!/usr/bin/env ruby

# Set ARGV for the server to pick up credentials
ARGV[0] = File.read('.rtm_api_key').strip
ARGV[1] = File.read('.rtm_shared_secret').strip

require_relative './rtm-mcp'

server = RTMMCPServer.new

# Test setting an estimate
puts "Testing set_task_estimate..."
result = server.set_task_estimate('51175710', '576961590', '1136771242', '3 hours')
puts "Result: #{result}"

# Test listing tasks to see estimate display
puts "\nTesting list_tasks with estimate display..."
list_result = server.list_tasks('51175710')
puts "List result: #{list_result}"
