#!/usr/bin/env ruby

# RTM Authentication Setup
# This script handles the OAuth-style flow to get an auth token
# Usage: ./rtm-auth-setup.rb [api-key] [shared-secret]

require_relative 'rtm-mcp'

unless ARGV.length == 2
  puts "Usage: #{$0} [api-key] [shared-secret]"
  exit 1
end

api_key = ARGV[0]
shared_secret = ARGV[1]

puts "RTM Authentication Setup"
puts "========================"
puts "API Key: #{api_key[0..8]}..."
puts

rtm = RTMClient.new(api_key, shared_secret)

# Step 1: Get a frob
puts "Step 1: Getting frob..."
frob_result = rtm.call_method('rtm.auth.getFrob')

if frob_result['error']
  puts "❌ Failed to get frob: #{frob_result['error']}"
  exit 1
end

frob = frob_result.dig('rsp', 'frob')
if !frob
  puts "❌ No frob in response: #{frob_result}"
  exit 1
end

puts "✅ Got frob: #{frob}"

# Step 2: Generate authorization URL
puts "\nStep 2: User authorization required"
puts "======================================="

# Build auth URL with signature
auth_params = {
  api_key: api_key,
  perms: 'delete',  # Request full permissions (read, write, delete)
  frob: frob
}

# Generate signature for auth URL
sorted_params = auth_params.sort.map { |k, v| "#{k}#{v}" }.join
signature_string = shared_secret + sorted_params
api_sig = Digest::MD5.hexdigest(signature_string)

auth_url = "https://www.rememberthemilk.com/services/auth/?" + 
           "api_key=#{api_key}&perms=delete&frob=#{frob}&api_sig=#{api_sig}"

puts "Please visit this URL to authorize the application:"
puts auth_url
puts
puts "After authorizing, press Enter to continue..."
STDIN.gets

# Step 3: Get the auth token
puts "\nStep 3: Getting auth token..."
token_result = rtm.call_method('rtm.auth.getToken', { frob: frob })

if token_result['error']
  puts "❌ Failed to get token: #{token_result['error']}"
  puts "Make sure you completed the authorization step above."
  exit 1
end

auth_token = token_result.dig('rsp', 'auth', 'token')
if !auth_token
  puts "❌ No token in response: #{token_result}"
  exit 1
end

puts "✅ Got auth token: #{auth_token}"

# Step 4: Save the token
token_file = File.join(__dir__, '.rtm_auth_token')
File.write(token_file, auth_token)
puts "✅ Saved token to #{token_file}"

# Step 5: Test the token
puts "\nStep 5: Testing auth token..."
test_result = rtm.call_method('rtm.test.login', { auth_token: auth_token })

if test_result['error']
  puts "❌ Token test failed: #{test_result['error']}"
else
  user = test_result.dig('rsp', 'user')
  puts "✅ Authentication successful!"
  puts "   User: #{user['username']} (#{user['fullname']})"
  puts "   ID: #{user['id']}"
end

puts "\n🎉 RTM authentication setup complete!"
puts "You can now use RTM MCP tools with your auth token."
