#!/usr/bin/env ruby

require 'net/http'
require 'uri'
require 'json'
require 'digest/md5'

# Load credentials
api_key = File.read('.rtm_api_key').strip
shared_secret = File.read('.rtm_shared_secret').strip
auth_token = File.read('.rtm_auth_token').strip

# RTM API helper
def rtm_api_call(method, params, api_key, shared_secret, auth_token)
  base_url = 'https://api.rememberthemilk.com/services/rest/'
  
  # Add required params
  params['method'] = method
  params['api_key'] = api_key
  params['auth_token'] = auth_token
  params['format'] = 'json'
  
  # Generate signature
  sorted_params = params.sort.map { |k, v| "#{k}#{v}" }.join
  params['api_sig'] = Digest::MD5.hexdigest("#{shared_secret}#{sorted_params}")
  
  # Make request
  uri = URI(base_url)
  uri.query = URI.encode_www_form(params)
  
  response = Net::HTTP.get_response(uri)
  JSON.parse(response.body)
end

# Get timeline for mutations
timeline_response = rtm_api_call('rtm.timelines.create', {}, api_key, shared_secret, auth_token)
timeline = timeline_response['rsp']['timeline']

puts "Testing RTM Recurrence Rules"
puts "============================"
puts

# Test 1: Create a task with recurrence
puts "1. Creating task with 'every day' recurrence..."
params = {
  'timeline' => timeline,
  'name' => 'Test recurring task (every day)',
  'list_id' => '51175519',
  'parse' => '1'
}
response = rtm_api_call('rtm.tasks.add', params, api_key, shared_secret, auth_token)
puts "Response: #{JSON.pretty_generate(response)}"
puts
sleep 1

# Test 2: Set recurrence on existing task
puts "2. Creating a regular task first..."
params = {
  'timeline' => timeline,
  'name' => 'Test task for recurrence update',
  'list_id' => '51175519',
  'parse' => '1'
}
response = rtm_api_call('rtm.tasks.add', params, api_key, shared_secret, auth_token)
task_data = response['rsp']['list']
list_id = task_data['id']
task_series = task_data['taskseries'].first
taskseries_id = task_series['id']
task_id = task_series['task'].first['id']
puts "Created task - list: #{list_id}, series: #{taskseries_id}, task: #{task_id}"
sleep 1

puts "Now setting recurrence to 'every week'..."
params = {
  'timeline' => timeline,
  'list_id' => list_id,
  'taskseries_id' => taskseries_id,
  'task_id' => task_id,
  'repeat' => 'every week'
}
response = rtm_api_call('rtm.tasks.setRecurrence', params, api_key, shared_secret, auth_token)
puts "Response: #{JSON.pretty_generate(response)}"
puts
sleep 1

# Test 3: Try different recurrence patterns
patterns = [
  'every 2 days',
  'every monday',
  'every month on the 15th',
  'after 3 days',
  'every weekday'
]

puts "3. Testing various recurrence patterns..."
patterns.each do |pattern|
  puts "\nTrying pattern: '#{pattern}'"
  params = {
    'timeline' => timeline,
    'name' => "Test: #{pattern}",
    'list_id' => '51175519',
    'parse' => '1'
  }
  response = rtm_api_call('rtm.tasks.add', params, api_key, shared_secret, auth_token)
  
  if response['rsp']['stat'] == 'ok'
    task_data = response['rsp']['list']['taskseries'].first
    if task_data['rrule']
      puts "✓ Created with recurrence rule: #{task_data['rrule']}"
    else
      puts "✗ Created but no recurrence detected"
    end
  else
    puts "✗ Error: #{response['rsp']['err']['msg']}"
  end
  sleep 1
end

puts "\n4. Checking if recurrence is included in task name..."
# Let's see if RTM parses recurrence from the task name itself
test_names = [
  'Water plants ^every 3 days',
  'Team meeting *weekly',
  'Pay bills every month'
]

test_names.each do |name|
  puts "\nTrying task name: '#{name}'"
  params = {
    'timeline' => timeline,
    'name' => name,
    'list_id' => '51175519',
    'parse' => '1'
  }
  response = rtm_api_call('rtm.tasks.add', params, api_key, shared_secret, auth_token)
  
  if response['rsp']['stat'] == 'ok'
    task_data = response['rsp']['list']['taskseries'].first
    if task_data['rrule']
      puts "✓ Recurrence detected: #{task_data['rrule']}"
      puts "  Task name became: #{task_data['name']}"
    else
      puts "✗ No recurrence detected"
    end
  end
  sleep 1
end

puts "\nRecurrence testing complete!"
