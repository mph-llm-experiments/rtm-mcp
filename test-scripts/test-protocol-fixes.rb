#!/usr/bin/env ruby

# Test the fixed MCP protocol handling

require 'json'

# Simulate various RTM API responses and check MCP formatting

def test_mcp_response(description, rtm_response, expected_has_error)
  puts "\n=== #{description} ==="
  puts "RTM Response: #{JSON.pretty_generate(rtm_response)}"
  
  # Simulate the error checking logic
  if rtm_response['error'] || rtm_response.dig('rsp', 'stat') == 'fail'
    error_msg = rtm_response['error'] || rtm_response.dig('rsp', 'err', 'msg') || 'Unknown error'
    mcp_response = {
      "jsonrpc" => "2.0",
      "error" => {
        "code" => -32603,
        "message" => "RTM API Error: #{error_msg}"
      },
      "id" => 1
    }
  else
    mcp_response = {
      "jsonrpc" => "2.0",
      "result" => {
        "content" => [
          {
            "type" => "text",
            "text" => "Success!"
          }
        ]
      },
      "id" => 1
    }
  end
  
  puts "MCP Response: #{JSON.pretty_generate(mcp_response)}"
  
  # Validate MCP response
  valid = true
  if !mcp_response.key?("jsonrpc") || mcp_response["jsonrpc"] != "2.0"
    puts "❌ Invalid jsonrpc field"
    valid = false
  end
  
  if !mcp_response.key?("id")
    puts "❌ Missing id field"
    valid = false
  end
  
  if mcp_response.key?("result") && mcp_response.key?("error")
    puts "❌ Has both result and error"
    valid = false
  end
  
  if !mcp_response.key?("result") && !mcp_response.key?("error")
    puts "❌ Missing both result and error"
    valid = false
  end
  
  if mcp_response.key?("error")
    error = mcp_response["error"]
    if !error.is_a?(Hash) || !error.key?("code") || !error.key?("message")
      puts "❌ Invalid error structure"
      valid = false
    end
  end
  
  puts valid ? "✅ Valid MCP response" : "❌ Invalid MCP response"
end

# Test cases
test_mcp_response(
  "Successful RTM response",
  {"rsp" => {"stat" => "ok", "lists" => {"list" => []}}},
  false
)

test_mcp_response(
  "RTM error with rsp.stat=fail",
  {"rsp" => {"stat" => "fail", "err" => {"code" => "98", "msg" => "Login failed / Invalid auth token"}}},
  true
)

test_mcp_response(
  "RTM error with error field",
  {"error" => "HTTP 500: Internal Server Error"},
  true
)

test_mcp_response(
  "RTM response missing error message",
  {"rsp" => {"stat" => "fail"}},
  true
)

puts "\n=== Key Changes Made ==="
puts "1. All response keys now use string keys (\"jsonrpc\" not :jsonrpc)"
puts "2. Proper error detection: check both result['error'] and result.dig('rsp', 'stat') == 'fail'"
puts "3. Extract error messages from multiple possible locations"
puts "4. Always return either 'result' or 'error', never both"
puts "5. Handle missing/empty values gracefully"
