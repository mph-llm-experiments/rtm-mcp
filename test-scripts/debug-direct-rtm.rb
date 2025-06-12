#!/usr/bin/env ruby

# Debug the array comparison error by bypassing error handling
puts "🔍 Direct RTM Client Debug (Bypass Error Handling)"
puts "=" * 50

# Load the file without requiring it to examine the code
rtm_file_path = File.join(__dir__, '..', 'rtm-mcp.rb')
puts "Reading RTM file: #{rtm_file_path}"

# Load config first
config_path = File.expand_path('~/.config/rtm-mcp/config')
config = {}
File.readlines(config_path).each do |line|
  line = line.strip
  next if line.empty? || line.start_with?('#')
  key, value = line.split('=', 2)
  config[key] = value if key && value
end

api_key = config['RTM_API_KEY']
shared_secret = config['RTM_SHARED_SECRET']

puts "API Key: #{api_key ? '[SET]' : '[MISSING]'}"
puts "Shared Secret: #{shared_secret ? '[SET]' : '[MISSING]'}"

# Now require the file and let any exceptions bubble up
puts "\nLoading rtm-mcp.rb and creating client..."
begin
  require_relative '../rtm-mcp'
  
  puts "Creating RTMClient with credentials..."
  client = RTMClient.new(api_key, shared_secret)
  
  puts "Testing specific method calls step by step..."
  
  # Let's try to isolate where the array comparison happens
  puts "\n1. Testing parameter setup..."
  params = {'test' => 'hello'}
  puts "   Params: #{params.inspect}"
  
  puts "\n2. Calling client.call_method directly..."
  # This should trigger the actual exception with full stack trace
  result = client.call_method('rtm.test.echo', params)
  puts "   Result: #{result.inspect}"
  
rescue => e
  puts "\n❌ EXCEPTION CAUGHT: #{e.class}: #{e.message}"
  puts "\nFull Stack Trace:"
  puts e.backtrace.map { |line| "  #{line}" }.join("\n")
  
  puts "\n🔍 ANALYSIS:"
  puts "Look for lines containing 'rtm-mcp.rb' in the stack trace above."
  puts "The error is likely in signature generation or parameter sorting."
end
