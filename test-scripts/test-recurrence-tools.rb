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

puts "Testing RTM MCP Recurrence Tools"
puts "==============================="
puts

# First, create a test task
puts "1. Creating a test task..."
params = {
  'timeline' => timeline,
  'name' => 'Test recurrence functionality',
  'list_id' => '51175519'
}
response = rtm_api_call('rtm.tasks.add', params, api_key, shared_secret, auth_token)

if response['rsp']['stat'] == 'ok'
  task_data = response['rsp']['list']
  list_id = task_data['id']
  task_series = task_data['taskseries'].first
  taskseries_id = task_series['id']
  task_id = task_series['task'].first['id']
  task_name = task_series['name']
  
  puts "✓ Created task: #{task_name}"
  puts "  IDs: list=#{list_id}, series=#{taskseries_id}, task=#{task_id}"
  puts
  
  # Test setting recurrence
  recurrence_patterns = [
    'every day',
    'every 2 weeks',
    'every monday',
    'every weekday',
    'after 1 week'
  ]
  
  recurrence_patterns.each do |pattern|
    puts "2. Testing recurrence pattern: '#{pattern}'"
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
      rrule = task_data['rrule']
      if rrule && rrule['$t']
        puts "✓ SUCCESS - RRULE: #{rrule['$t']}"
        puts "  Every: #{rrule['every']}"
      else
        puts "✗ No recurrence rule found"
      end
    else
      puts "✗ Error: #{response['rsp']['err']['msg']}"
    end
    puts
    sleep 1
  end
  
  # Test clearing recurrence
  puts "3. Testing clear recurrence..."
  params = {
    'timeline' => timeline,
    'list_id' => list_id,
    'taskseries_id' => taskseries_id,
    'task_id' => task_id
  }
  response = rtm_api_call('rtm.tasks.setRecurrence', params, api_key, shared_secret, auth_token)
  
  if response['rsp']['stat'] == 'ok'
    task_data = response['rsp']['list']['taskseries'].first
    rrule = task_data['rrule']
    if rrule && rrule['$t'] && !rrule['$t'].empty?
      puts "✗ Recurrence still active: #{rrule['$t']}"
    else
      puts "✓ Recurrence cleared successfully"
    end
  else
    puts "✗ Error: #{response['rsp']['err']['msg']}"
  end
  puts
  
  # Clean up - delete the test task
  puts "4. Cleaning up test task..."
  params = {
    'timeline' => timeline,
    'list_id' => list_id,
    'taskseries_id' => taskseries_id,
    'task_id' => task_id
  }
  response = rtm_api_call('rtm.tasks.delete', params, api_key, shared_secret, auth_token)
  
  if response['rsp']['stat'] == 'ok'
    puts "✓ Test task deleted"
  else
    puts "✗ Error deleting task: #{response['rsp']['err']['msg']}"
  end
  
else
  puts "✗ Failed to create test task: #{response['rsp']['err']['msg']}"
end

puts "\nRecurrence tools test complete!"
