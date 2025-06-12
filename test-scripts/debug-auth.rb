#!/usr/bin/env ruby

# Debug script to check RTM authentication status
require_relative '../rtm-mcp'

puts "🔑 RTM Authentication Debug"
puts "=" * 40

# Check if config file exists
config_path = File.expand_path('~/.config/rtm-mcp/config')
puts "Config file: #{config_path}"
puts "Exists: #{File.exist?(config_path)}"

if File.exist?(config_path)
  puts "Contents:"
  File.readlines(config_path).each_with_index do |line, i|
    # Don't show actual token values, just structure
    if line.include?('=')
      key, value = line.strip.split('=', 2)
      puts "  #{key}=#{value.length > 0 ? '[SET]' : '[EMPTY]'}"
    else
      puts "  #{line.strip}"
    end
  end
else
  puts "❌ Config file not found!"
end

puts "\n" + "-" * 40

# Try to create RTMClient and check auth
begin
  puts "Creating RTMClient..."
  client = RTMClient.new
  puts "✅ RTMClient created"
  
  puts "Testing auth with rtm.test.login..."
  result = client.call_method('rtm.test.login')
  puts "Auth result: #{result.inspect}"
  
  if result && result['rsp'] && result['rsp']['stat'] == 'ok'
    puts "✅ Authentication successful!"
    user_info = result['rsp']['user']
    puts "  User ID: #{user_info['id']}"
    puts "  Username: #{user_info['username']}"
    puts "  Full Name: #{user_info['fullname']}"
  else
    puts "❌ Authentication failed"
    puts "  Response: #{result.inspect}"
  end
  
rescue => e
  puts "❌ Error: #{e.class}: #{e.message}"
  puts e.backtrace.first(3).join("\n")
end
