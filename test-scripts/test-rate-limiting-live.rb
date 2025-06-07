#!/usr/bin/env ruby

require 'json'
require 'time'

# Simple test to verify rate limiting is working in rtm-mcp

puts "Testing RTM MCP rate limiting..."
puts "This will make 5 rapid API calls"
puts "First 3 should be quick (burst), then 1/sec"
puts

# Track timing
start_times = []
end_times = []

5.times do |i|
  start = Time.now
  start_times << start
  
  # Make API call through Claude Desktop (simulated)
  # In practice you'd test through Claude Desktop interface
  puts "Request #{i + 1} started at #{start.strftime('%H:%M:%S.%3N')}"
  
  # Simulate the test_connection call
  cmd = <<~RUBY
    require_relative 'rtm-mcp'
    
    api_key = ARGV[0]
    shared_secret = ARGV[1]
    
    # Initialize server components
    client = RTMClient.new(api_key, shared_secret)
    
    # Make a lightweight API call
    result = client.call_method('rtm.test.echo', { test_param: 'rate_limit_test_#{i + 1}' })
    
    puts JSON.pretty_generate(result)
  RUBY
  
  # Run the command with your actual API credentials
  # You'll need to replace these with your actual values
  system("ruby", "-e", cmd, "YOUR_API_KEY", "YOUR_SHARED_SECRET")
  
  end_time = Time.now
  end_times << end_time
  
  elapsed = end_time - start
  puts "Request #{i + 1} completed in #{elapsed.round(3)}s"
  
  if i > 0
    gap = start - start_times[i-1]
    puts "  Gap from previous request: #{gap.round(3)}s"
  end
  
  puts
end

puts "Summary:"
puts "--------"
start_times.each_with_index do |start_time, i|
  if i > 0
    gap = start_time - start_times[i-1]
    status = if i < 3
      gap < 0.5 ? "✓ BURST" : "✗ SLOW"
    else
      gap >= 0.9 && gap <= 1.1 ? "✓ THROTTLED" : "✗ WRONG TIMING"
    end
    puts "Request #{i+1}: #{gap.round(3)}s gap #{status}"
  end
end

puts "\nRate limiting test complete!"
puts "You should see burst for first 3, then ~1s gaps"
