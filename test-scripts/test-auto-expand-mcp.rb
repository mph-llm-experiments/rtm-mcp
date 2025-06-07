#!/usr/bin/env ruby

require 'json'
require 'socket'

# Test script for auto-expand functionality through MCP

def send_request(socket, request)
  json = JSON.generate(request)
  socket.puts json
  socket.flush
  
  response_line = socket.gets
  return nil unless response_line
  
  JSON.parse(response_line)
end

def test_auto_expand
  puts "Testing auto-expand functionality through MCP..."
  puts "=" * 50
  
  # Connect to MCP server
  socket = TCPSocket.new('localhost', 3000)
  
  # Initialize
  puts "\n1. Initializing..."
  init_request = {
    jsonrpc: '2.0',
    id: 1,
    method: 'initialize',
    params: {
      protocolVersion: '2024-11-05',
      capabilities: {},
      clientInfo: { name: 'test-auto-expand', version: '1.0' }
    }
  }
  
  response = send_request(socket, init_request)
  puts "Initialized: #{response['result']['serverInfo']['name']}"
  
  # Test 1: Normal search with results
  puts "\n2. Testing normal search (should find tasks)..."
  normal_request = {
    jsonrpc: '2.0',
    id: 2,
    method: 'tools/call',
    params: {
      name: 'list_tasks',
      arguments: {
        list_id: '51175519',
        filter: 'status:incomplete'
      }
    }
  }
  
  response = send_request(socket, normal_request)
  content = response.dig('result', 'content', 0, 'text')
  puts "Result preview: #{content.lines.first(3).join}"
  
  # Test 2: Search with no results (should auto-expand)
  puts "\n3. Testing search with no results (should auto-expand)..."
  no_results_request = {
    jsonrpc: '2.0',
    id: 3,
    method: 'tools/call',
    params: {
      name: 'list_tasks',
      arguments: {
        list_id: '51175519',
        filter: 'tag:nonexistent-tag-xyz123 AND status:incomplete'
      }
    }
  }
  
  response = send_request(socket, no_results_request)
  content = response.dig('result', 'content', 0, 'text')
  
  if content.include?("Auto-expanded search")
    puts "✅ Auto-expand worked!"
    puts "Response preview:"
    puts content.lines.first(5).join
  else
    puts "❌ Auto-expand didn't trigger"
    puts "Response: #{content}"
  end
  
  # Test 3: Search by nonexistent tag
  puts "\n4. Testing tag search with no results..."
  tag_request = {
    jsonrpc: '2.0',
    id: 4,
    method: 'tools/call',
    params: {
      name: 'list_tasks',
      arguments: {
        list_id: '51175519',
        filter: 'tag:doesnotexist'
      }
    }
  }
  
  response = send_request(socket, tag_request)
  content = response.dig('result', 'content', 0, 'text')
  
  if content.include?("Auto-expanded search")
    puts "✅ Tag search auto-expanded!"
    puts "Response preview:"
    puts content.lines.first(5).join
  else
    puts "Response: #{content}"
  end
  
  socket.close
  puts "\n✅ Test complete!"
  
rescue => e
  puts "Error: #{e.message}"
  puts e.backtrace
end

# Check if server is running
begin
  test_socket = TCPSocket.new('localhost', 3000)
  test_socket.close
rescue
  puts "⚠️  MCP server not running. Start it with: ruby rtm-mcp.rb"
  exit 1
end

# Run test
test_auto_expand
