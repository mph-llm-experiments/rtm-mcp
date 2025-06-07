#!/usr/bin/env ruby

require_relative 'rtm-mcp'
require 'time'

# Load credentials from command line or environment
api_key = ARGV[0] || ENV['RTM_API_KEY']
shared_secret = ARGV[1] || ENV['RTM_SHARED_SECRET']

if !api_key || !shared_secret
  puts "Usage: #{$0} API_KEY SHARED_SECRET"
  puts "Or set RTM_API_KEY and RTM_SHARED_SECRET environment variables"
  exit 1
end

puts "Testing RTM rate limiting with live API calls..."
puts "Making 5 calls to rtm.test.echo"
puts "First 3 should be immediate (burst), then 1/sec"
puts

client = RTMClient.new(api_key, shared_secret)
request_times = []

5.times do |i|
  start = Time.now
  request_times << start
  
  # Make a simple echo call
  result = client.call_method('rtm.test.echo', { 
    test_param: "rate_test_#{i + 1}",
    timestamp: start.to_f
  })
  
  elapsed = Time.now - start
  
  # Show timing info
  if i > 0
    gap = start - request_times[i-1]
    puts "Request #{i + 1}: gap=#{gap.round(3)}s, call_time=#{elapsed.round(3)}s"
  else
    puts "Request #{i + 1}: call_time=#{elapsed.round(3)}s (first request)"
  end
  
  # Show result status
  if result['rsp'] && result['rsp']['stat'] == 'ok'
    puts "  ✓ Success"
  else
    puts "  ✗ Error: #{result.inspect}"
  end
end

puts "\nSummary:"
puts "Expected: First 3 requests immediate, then ~1s gaps"
puts "Actual gaps between requests:"
request_times.each_with_index do |time, i|
  if i > 0
    gap = time - request_times[i-1]
    expected = i < 3 ? "< 0.1s (burst)" : "~1.0s (throttled)"
    actual = gap.round(3)
    status = if i < 3
      gap < 0.2 ? "✓" : "✗"
    else
      gap >= 0.9 && gap <= 1.1 ? "✓" : "✗"
    end
    puts "  #{i} → #{i+1}: #{actual}s #{status} (expected #{expected})"
  end
end
