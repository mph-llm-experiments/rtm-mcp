#!/usr/bin/env ruby

require 'net/http'
require 'uri'
require 'json'
require 'digest/md5'
require 'time'

# Load auth token
auth_token = File.read('.rtm_auth_token').strip
api_key = 'YOUR_API_KEY' # Will be replaced when you run it

# Simple rate limiter class
class RateLimiter
  def initialize(requests_per_second: 1, burst: 3)
    @requests_per_second = requests_per_second
    @burst = burst
    @min_interval = 1.0 / @requests_per_second
    @request_times = []
  end
  
  def wait_if_needed
    now = Time.now.to_f
    
    # Remove requests older than 1 second
    @request_times.reject! { |t| now - t > 1.0 }
    
    # If we've made burst requests in the last second, wait
    if @request_times.size >= @burst
      oldest_in_window = @request_times.first
      wait_time = (oldest_in_window + 1.0) - now
      if wait_time > 0
        puts "Rate limit: waiting #{wait_time.round(2)}s..."
        sleep(wait_time)
      end
    end
    
    # Record this request
    @request_times << Time.now.to_f
  end
end

# Test the rate limiter
limiter = RateLimiter.new(requests_per_second: 1, burst: 3)

puts "Testing rate limiter with 5 rapid requests..."
puts "RTM allows 1 req/sec with burst of 3"
puts "First 3 should be immediate, then 1/sec"
puts

5.times do |i|
  start = Time.now
  limiter.wait_if_needed
  elapsed = Time.now - start
  puts "Request #{i + 1}: waited #{elapsed.round(3)}s"
  
  # Simulate API call time
  sleep(0.1)
end

puts "\nRate limiter test complete!"
