#!/usr/bin/env ruby

# Direct test of auto-expand functionality

# Set up ARGV for the server
ARGV[0] = File.read('.rtm_api_key').strip
ARGV[1] = File.read('.rtm_shared_secret').strip

require_relative 'rtm-mcp'

server = RTMMCPServer.new

puts "Testing auto-expand functionality..."
puts "=" * 50

# Test 1: Filter that should have results
puts "\n1. Testing with filter that has results:"
result1 = server.send(:list_tasks, '51175519', 'status:incomplete', false)
puts result1.lines.first(3).join

# Test 2: Filter that should have NO results and trigger auto-expand
puts "\n2. Testing with filter that has NO results (should auto-expand):"
result2 = server.send(:list_tasks, '51175519', 'tag:nonexistent-tag-xyz123', false)
puts result2.lines.first(6).join

# Test 3: Complex filter with AND
puts "\n3. Testing with complex filter (AND condition):"
result3 = server.send(:list_tasks, '51175519', 'tag:nonexistent AND status:incomplete', false)
puts result3.lines.first(6).join

puts "\n✅ Test complete!"
