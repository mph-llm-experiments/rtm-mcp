#!/usr/bin/env ruby

# Debug the "comparison of Array with Array failed" error
require_relative '../rtm-mcp'

puts "🔍 Debug Array Comparison Error"
puts "=" * 40

# Load config
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

puts "Creating RTMClient..."
client = RTMClient.new(api_key, shared_secret)

# Let's trace exactly where the array comparison fails
puts "\nTesting rtm.test.echo with detailed tracing..."

begin
  # Call the method directly on RTMClient to see the full stack trace
  result = client.call_method('rtm.test.echo', {'test' => 'hello'})
  puts "Raw result: #{result.inspect}"
rescue => e
  puts "❌ ERROR: #{e.class}: #{e.message}"
  puts "Full backtrace:"
  puts e.backtrace.join("\n")
end

puts "\n" + "=" * 40
puts "🎯 ANALYSIS:"
puts "The 'comparison of Array with Array failed' error is happening"
puts "in the RTM client code. This suggests there's still an array"
puts "handling bug that needs to be fixed before we can test auth."
