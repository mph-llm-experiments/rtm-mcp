#!/usr/bin/env ruby

# Simple step-by-step auth debug with timeouts
require 'timeout'

puts "🔍 Simple Auth Debug with Timeouts"
puts "=" * 50

def test_step(description, timeout_seconds = 3)
  puts "\n#{description}"
  start_time = Time.now
  
  begin
    result = Timeout::timeout(timeout_seconds) do
      yield
    end
    elapsed = Time.now - start_time
    puts "✅ SUCCESS: #{elapsed.round(3)}s"
    result
  rescue Timeout::Error
    elapsed = Time.now - start_time
    puts "❌ TIMEOUT: #{elapsed.round(3)}s - HUNG!"
    nil
  rescue => e
    elapsed = Time.now - start_time
    puts "❌ ERROR: #{elapsed.round(3)}s - #{e.class}: #{e.message}"
    nil
  end
end

# Step 1: Basic file operations
config_path = test_step("Step 1: Check config file path") do
  File.expand_path('~/.config/rtm-mcp/config')
end

config_exists = test_step("Step 2: Check if config exists") do
  File.exist?(config_path)
end

# Step 3: Read config file
config_lines = test_step("Step 3: Read config file") do
  File.readlines(config_path) if config_exists
end

# Step 4: Parse config
config = test_step("Step 4: Parse config") do
  parsed = {}
  if config_lines
    config_lines.each do |line|
      line = line.strip
      next if line.empty? || line.start_with?('#')
      key, value = line.split('=', 2)
      parsed[key] = value if key && value
    end
  end
  parsed
end

puts "\nConfig loaded: #{config.keys.join(', ')}" if config

# Step 5: Load RTM file (this might hang)
rtm_loaded = test_step("Step 5: Load rtm-mcp.rb file", 5) do
  require_relative '../rtm-mcp'
  true
end

exit 1 unless rtm_loaded

# Step 6: Create RTMClient (this might hang) 
api_key = config['RTM_API_KEY'] if config
shared_secret = config['RTM_SHARED_SECRET'] if config

if api_key && shared_secret
  client = test_step("Step 6: Create RTMClient", 5) do
    RTMClient.new(api_key, shared_secret)
  end
  
  if client
    # Step 7: Test API call (this might hang)
    test_step("Step 7: Test RTM API call", 10) do
      client.call_method('rtm.test.echo', {'test' => 'hello'})
    end
  end
else
  puts "❌ Missing API credentials, skipping RTMClient creation"
end

puts "\n" + "=" * 50
puts "🎯 HANG LOCATION: Look for the LAST successful step"
puts "- If Step 5 hangs: Loading rtm-mcp.rb file is the issue"
puts "- If Step 6 hangs: RTMClient creation is the issue"  
puts "- If Step 7 hangs: RTM API calls are the issue"
