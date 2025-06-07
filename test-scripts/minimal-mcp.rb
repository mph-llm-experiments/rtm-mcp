#!/usr/bin/env ruby

require 'json'

# Minimal MCP server to test protocol compliance

class MinimalMCPServer
  def run
    STDERR.puts "Minimal MCP Server starting..."
    
    loop do
      begin
        line = STDIN.readline
        request = JSON.parse(line)
        
        response = case request['method']
        when 'initialize'
          {
            "jsonrpc" => "2.0",
            "result" => {
              "protocolVersion" => "2024-11-05",
              "capabilities" => {
                "tools" => {}
              },
              "serverInfo" => {
                "name" => "minimal-mcp",
                "version" => "0.1.0"
              }
            },
            "id" => request['id']
          }
        when 'tools/list'
          {
            "jsonrpc" => "2.0",
            "result" => {
              "tools" => [
                {
                  "name" => "test_tool",
                  "description" => "A test tool",
                  "inputSchema" => {
                    "type" => "object",
                    "properties" => {}
                  }
                }
              ]
            },
            "id" => request['id']
          }
        else
          {
            "jsonrpc" => "2.0",
            "error" => {
              "code" => -32601,
              "message" => "Method not found"
            },
            "id" => request['id']
          }
        end
        
        puts JSON.generate(response)
        STDOUT.flush
        
      rescue EOFError
        break
      rescue => e
        STDERR.puts "Error: #{e.message}"
      end
    end
  end
end

# Start the server
if __FILE__ == $0
  server = MinimalMCPServer.new
  server.run
end
