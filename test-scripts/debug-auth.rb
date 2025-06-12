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

# Try to load config and create RTMClient properly
begin
  puts "Loading config..."
  
  # Load config the way RTMMCPServer does it
  config = {}
  if File.exist?(config_path)
    File.readlines(config_path).each do |line|
      line = line.strip
      next if line.empty? || line.start_with?('#')
      key, value = line.split('=', 2)
      config[key] = value if key && value
    end
  end
  
  api_key = config['RTM_API_KEY'] || ENV['RTM_API_KEY']
  shared_secret = config['RTM_SHARED_SECRET'] || ENV['RTM_SHARED_SECRET']
  
  puts "API Key: #{api_key ? '[SET]' : '[MISSING]'}"
  puts "Shared Secret: #{shared_secret ? '[SET]' : '[MISSING]'}"
  
  if !api_key || !shared_secret
    puts "❌ Missing required credentials (API key or shared secret)"
    exit 1
  end
  
  puts "Creating RTMClient with loaded credentials..."
  client = RTMClient.new(api_key, shared_secret)
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
    
    # Check if auth token might be expired
    if result && result['rsp'] && result['rsp']['err']
      error_code = result['rsp']['err']['code']
      error_msg = result['rsp']['err']['msg']
      puts "  Error Code: #{error_code}"
      puts "  Error Message: #{error_msg}"
      
      if error_code == '98' || error_msg.include?('Invalid auth token')
        puts "\n💡 SOLUTION: Your auth token has expired."
        puts "   Run: ruby test-scripts/rtm-auth-setup.rb"
        puts "   This will generate a new auth token."
      end
    end
  end
  
rescue => e
  puts "❌ Error: #{e.class}: #{e.message}"
  puts e.backtrace.first(3).join("\n")
end
