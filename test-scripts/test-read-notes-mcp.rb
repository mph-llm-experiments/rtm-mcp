#!/usr/bin/env ruby
require 'json'

# Simple test script for read_task_notes tool
# Run the MCP server first: ./rtm-mcp.rb

# Task with notes: "Add due date tools"
request = {
  jsonrpc: "2.0",
  method: "tools/call",
  params: {
    name: "read_task_notes",
    arguments: {
      list_id: "51175519",
      taskseries_id: "576922378",
      task_id: "1136720073"
    }
  },
  id: 1
}

puts "Testing read_task_notes tool..."
puts "Sending request:"
puts JSON.pretty_generate(request)
puts ""
puts "Response should show the implementation plan note..."
puts ""
puts "To test, run:"
puts "1. In one terminal: ./rtm-mcp.rb"
puts "2. In another terminal: echo '#{request.to_json}' | nc -U /tmp/claude-mcp.sock | jq"
puts ""
puts "Or test in Claude Desktop after restarting it."
