#!/usr/bin/env ruby

# Absolutely minimal MCP server following exact spec

require 'json'

STDERR.puts "Minimal MCP Server starting..."

loop do
  begin
    line = STDIN.gets
    break unless line
    
    request = JSON.parse(line.chomp)
    
    response = case request["method"]
    when "initialize"
      {
        "jsonrpc" => "2.0",
        "result" => {
          "protocolVersion" => "2024-11-05",
          "capabilities" => {
            "tools" => {}
          },
          "serverInfo" => {
            "name" => "rtm-mcp",
            "version" => "0.1.0"
          }
        },
        "id" => request["id"]
      }
    when "tools/list"
      {
        "jsonrpc" => "2.0",
        "result" => {
          "tools" => []
        },
        "id" => request["id"]
      }
    else
      {
        "jsonrpc" => "2.0",
        "error" => {
          "code" => -32601,
          "message" => "Method not found"
        },
        "id" => request["id"]
      }
    end
    
    puts JSON.generate(response)
    STDOUT.flush
    
  rescue => e
    STDERR.puts "Error: #{e.message}"
  end
end