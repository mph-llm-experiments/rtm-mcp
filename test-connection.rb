#!/usr/bin/env ruby

# Basic connectivity test for RTM API
# Usage: ./test-connection.rb [api-key] [shared-secret]

require_relative 'rtm-mcp'

unless ARGV.length == 2
  puts "Usage: #{$0} [api-key] [shared-secret]"
  exit 1
end

api_key = ARGV[0]
shared_secret = ARGV[1]

puts "Testing RTM API connectivity..."
puts "API Key: #{api_key[0..8]}..."
puts "Shared Secret: #{shared_secret[0..8]}..."
puts

rtm = RTMClient.new(api_key, shared_secret)

# Test basic echo method
puts "Testing rtm.test.echo..."
result = rtm.call_method('rtm.test.echo', { test: 'connectivity_check' })

if result['error']
  puts "❌ Connection failed: #{result['error']}"
  exit 1
else
  puts "✅ Connection successful!"
  puts "Response: #{JSON.pretty_generate(result)}"
end
