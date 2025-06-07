#!/usr/bin/env ruby

require 'json'

# Test script to validate MCP protocol responses

def test_response(name, response)
  puts "\n=== Testing #{name} ==="
  puts "Response: #{JSON.pretty_generate(response)}"
  
  # Check required fields
  unless response.key?('jsonrpc') && response['jsonrpc'] == '2.0'
    puts "❌ Missing or invalid jsonrpc field"
  end
  
  unless response.key?('id')
    puts "❌ Missing id field"
  end
  
  if response.key?('result') && response.key?('error')
    puts "❌ Response has both result and error (should have only one)"
  end
  
  if !response.key?('result') && !response.key?('error')
    puts "❌ Response missing both result and error (must have exactly one)"
  end
  
  if response.key?('error')
    error = response['error']
    unless error.is_a?(Hash) && error.key?('code') && error.key?('message')
      puts "❌ Invalid error structure"
    end
  end
  
  puts "✅ Valid response structure" if response.key?('jsonrpc') && response.key?('id') && (response.key?('result') ^ response.key?('error'))
end

# Test various response types
test_response("Success response", {
  "jsonrpc" => "2.0",
  "result" => {
    "content" => [
      {
        "type" => "text",
        "text" => "Test successful"
      }
    ]
  },
  "id" => 1
})

test_response("Error response", {
  "jsonrpc" => "2.0",
  "error" => {
    "code" => -32603,
    "message" => "Internal error"
  },
  "id" => 1
})

test_response("Invalid response (both result and error)", {
  "jsonrpc" => "2.0",
  "result" => {},
  "error" => {},
  "id" => 1
})

test_response("Invalid response (neither result nor error)", {
  "jsonrpc" => "2.0",
  "id" => 1
})

test_response("Invalid response (missing id)", {
  "jsonrpc" => "2.0",
  "result" => {}
})

puts "\n=== Testing MCP server responses ==="
puts "Run this to test actual server:"
puts "./rtm-mcp.rb [api-key] [shared-secret]"
puts "Then send: {\"jsonrpc\":\"2.0\",\"method\":\"initialize\",\"params\":{},\"id\":1}"
puts "And: {\"jsonrpc\":\"2.0\",\"method\":\"tools/list\",\"params\":{},\"id\":2}"
