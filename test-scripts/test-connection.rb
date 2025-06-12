#!/usr/bin/env ruby

# Basic connectivity test for RTM API
# Usage: ./test-connection.rb

require_relative '../rtm-mcp'

# Load credentials from config file or environment
def load_config
  config = {}
  
  # First try config file
  config_file = File.expand_path('~/.config/rtm-mcp/config')
  if File.exist?(config_file)
    File.readlines(config_file).each do |line|
      line = line.strip
      next if line.empty? || line.start_with?('#')
      
      if line.include?('=')
        key, value = line.split('=', 2)
        config[key.strip] = value.strip
      end
    end
  end
  
  # Environment variables override config file
  config['RTM_API_KEY'] = ENV['RTM_API_KEY'] if ENV['RTM_API_KEY'] && !ENV['RTM_API_KEY'].empty?
  config['RTM_SHARED_SECRET'] = ENV['RTM_SHARED_SECRET'] if ENV['RTM_SHARED_SECRET'] && !ENV['RTM_SHARED_SECRET'].empty?
  config['RTM_AUTH_TOKEN'] = ENV['RTM_AUTH_TOKEN'] if ENV['RTM_AUTH_TOKEN'] && !ENV['RTM_AUTH_TOKEN'].empty?
  
  config
rescue => e
  puts "Error loading config: #{e.message}"
  {}
end

config = load_config

unless config['RTM_API_KEY'] && config['RTM_SHARED_SECRET']
  puts "❌ Missing RTM API credentials"
  puts ""
  puts "Set up credentials:"
  puts "1. mkdir -p ~/.config/rtm-mcp"
  puts "2. cp config.example ~/.config/rtm-mcp/config"  
  puts "3. Edit ~/.config/rtm-mcp/config with your RTM credentials"
  puts ""
  puts "Or use environment variables:"
  puts "RTM_API_KEY=xxx RTM_SHARED_SECRET=yyy #{$0}"
  exit 1
end

api_key = config['RTM_API_KEY']
shared_secret = config['RTM_SHARED_SECRET']

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
