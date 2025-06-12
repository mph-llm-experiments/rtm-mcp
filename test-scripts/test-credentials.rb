#!/usr/bin/env ruby

# Test script for consolidated credential loading

require_relative '../rtm-mcp'

def test_config_loading
  puts "Testing credential loading..."
  
  config = load_config
  
  puts "\nConfig loaded:"
  puts "  RTM_API_KEY: #{config['RTM_API_KEY'] ? '[SET]' : '[MISSING]'}"
  puts "  RTM_SHARED_SECRET: #{config['RTM_SHARED_SECRET'] ? '[SET]' : '[MISSING]'}"
  puts "  RTM_AUTH_TOKEN: #{config['RTM_AUTH_TOKEN'] ? '[SET]' : '[MISSING]'}"
  
  config_file = File.expand_path('~/.config/rtm-mcp/config')
  puts "\nConfig file: #{config_file}"
  puts "  Exists: #{File.exist?(config_file)}"
  
  if config['RTM_API_KEY'] && config['RTM_SHARED_SECRET']
    puts "\n✅ Credentials loaded successfully!"
    
    # Test RTM connection
    puts "\nTesting RTM connection..."
    rtm = RTMClient.new(config['RTM_API_KEY'], config['RTM_SHARED_SECRET'])
    result = rtm.call_method('rtm.test.echo', test: 'credential_test')
    
    if result.dig('rsp', 'stat') == 'ok'
      puts "✅ RTM API connection successful!"
    else
      puts "❌ RTM API connection failed: #{result.inspect}"
    end
  else
    puts "\n❌ Missing credentials"
    puts "\nTo set up credentials:"
    puts "1. mkdir -p ~/.config/rtm-mcp"
    puts "2. cp config.example ~/.config/rtm-mcp/config"
    puts "3. Edit ~/.config/rtm-mcp/config with your RTM credentials"
  end
end

if __FILE__ == $0
  test_config_loading
end
