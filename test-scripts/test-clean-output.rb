#!/usr/bin/env ruby

# Set environment variables from files
ENV['RTM_API_KEY'] = File.read('.rtm_api_key').strip
ENV['RTM_SHARED_SECRET'] = File.read('.rtm_shared_secret').strip

require_relative 'rtm-mcp'

# Create server instance
server = RTMMCPServer.new

# Simulate list_tasks request
request = {
  'method' => 'tools/call',
  'params' => {
    'name' => 'list_tasks',
    'arguments' => {
      'list_id' => '51175519',
      'filter' => 'status:incomplete'
    }
  }
}

result = server.handle_request(request)
puts result[:content][0][:text]
