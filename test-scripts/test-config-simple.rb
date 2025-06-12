#!/usr/bin/env ruby

# Simple test for credential loading (no API calls)

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
  puts "Error: #{e.message}"
  {}
end

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
