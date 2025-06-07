#!/usr/bin/env ruby

require 'json'
require 'open3'

# Test exact JSON structure that MCP expects

api_key = ARGV[0]
shared_secret = ARGV[1]

unless api_key && shared_secret
  puts "Usage: #{$0} [api-key] [shared-secret]"
  exit 1
end

# Test with both versions
["./rtm-mcp.rb", "./rtm-mcp-v2.rb"].each do |server_path|
  puts "\n=== Testing #{server_path} ==="
  
  stdin, stdout, stderr, wait_thr = Open3.popen3("#{server_path} #{api_key} #{shared_secret}")
  
  sleep 0.5
  
  # Test initialize
  request = {"jsonrpc" => "2.0", "method" => "initialize", "params" => {}, "id" => 1}
  stdin.puts(JSON.generate(request))
  stdin.flush
  
  response_line = stdout.gets
  if response_line
    response = JSON.parse(response_line)
    puts "Initialize response keys: #{response.keys.sort.join(', ')}"
    
    if response["result"]
      puts "Result keys: #{response["result"].keys.sort.join(', ')}"
      if response["result"]["capabilities"]
        puts "Capabilities keys: #{response["result"]["capabilities"].keys.sort.join(', ')}"
      end
    end
  end
  
  # Test tools/list
  request = {"jsonrpc" => "2.0", "method" => "tools/list", "params" => {}, "id" => 2}
  stdin.puts(JSON.generate(request))
  stdin.flush
  
  response_line = stdout.gets
  if response_line
    response = JSON.parse(response_line)
    puts "\nTools/list response keys: #{response.keys.sort.join(', ')}"
    
    if response["result"] && response["result"]["tools"] && response["result"]["tools"].first
      tool = response["result"]["tools"].first
      puts "First tool keys: #{tool.keys.sort.join(', ')}"
      if tool["inputSchema"]
        puts "InputSchema keys: #{tool["inputSchema"].keys.sort.join(', ')}"
      end
    end
  end
  
  stdin.close
  stdout.close
  stderr.close
  wait_thr.kill
end