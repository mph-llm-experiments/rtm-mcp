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

puts "Testing RTM Smart Add Recurrence Syntax"
puts "======================================="
puts

# Test Smart Add recurrence patterns
# RTM uses * prefix for recurrence in Smart Add
smart_add_patterns = [
  'Water plants *daily',
  'Team meeting *weekly',
  'Review budget *monthly',
  'Quarterly report *every 3 months',
  'Exercise *every 2 days',
  'Clean desk *every weekday',
  'Weekend cleanup *every saturday',
  'Monthly review *every month on the 1st',
  'Biweekly sync *every 2 weeks',
  'Annual checkup *yearly',
  'After completion test *after 1 week'
]

puts "Testing Smart Add patterns with * prefix..."
smart_add_patterns.each do |pattern|
  puts "\nTrying: '#{pattern}'"
  params = {
    'timeline' => timeline,
    'name' => pattern,
    'list_id' => '51175519',
    'parse' => '1'
  }
  response = rtm_api_call('rtm.tasks.add', params, api_key, shared_secret, auth_token)
  
  if response['rsp']['stat'] == 'ok'
    task_data = response['rsp']['list']['taskseries'].first
    if task_data['rrule']
      puts "✓ SUCCESS - Recurrence rule: #{task_data['rrule']['$t']}"
      puts "  Task name: #{task_data['name']}"
      puts "  Every: #{task_data['rrule']['every']}" if task_data['rrule']['every']
    else
      puts "✗ No recurrence detected"
      puts "  Task created as: #{task_data['name']}"
    end
  else
    puts "✗ Error: #{response['rsp']['err']['msg']}"
  end
  sleep 1
end

puts "\n\nTesting setRecurrence API patterns..."
puts "======================================"

# Create a task and test various setRecurrence patterns
params = {
  'timeline' => timeline,
  'name' => 'Test task for setRecurrence patterns',
  'list_id' => '51175519',
  'parse' => '1'
}
response = rtm_api_call('rtm.tasks.add', params, api_key, shared_secret, auth_token)
task_data = response['rsp']['list']
list_id = task_data['id']
task_series = task_data['taskseries'].first
taskseries_id = task_series['id']
task_id = task_series['task'].first['id']

# Test patterns that should work with setRecurrence
recurrence_patterns = [
  'every day',
  'every 3 days',
  'every week',
  'every 2 weeks',
  'every month',
  'every 3 months',
  'every year',
  'every monday',
  'every mon, wed, fri',
  'every weekday',
  'every 15th',
  'every 1st and 15th',
  'after 1 week',
  'after 2 days'
]

recurrence_patterns.each do |pattern|
  puts "\nSetting recurrence: '#{pattern}'"
  params = {
    'timeline' => timeline,
    'list_id' => list_id,
    'taskseries_id' => taskseries_id,
    'task_id' => task_id,
    'repeat' => pattern
  }
  response = rtm_api_call('rtm.tasks.setRecurrence', params, api_key, shared_secret, auth_token)
  
  if response['rsp']['stat'] == 'ok'
    task_data = response['rsp']['list']['taskseries'].first
    if task_data['rrule']
      puts "✓ SUCCESS - RRULE: #{task_data['rrule']['$t']}"
    else
      puts "✗ Recurrence cleared"
    end
  else
    puts "✗ Error: #{response['rsp']['err']['msg']}"
  end
  sleep 1
end

puts "\n\nRecurrence pattern testing complete!"
