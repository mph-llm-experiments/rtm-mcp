#!/usr/bin/env ruby
require 'net/http'
require 'uri'
require 'json'
require 'digest/md5'
require 'cgi'

# Read credentials from files
API_KEY = File.read('.rtm_api_key').strip
SHARED_SECRET = File.read('.rtm_shared_secret').strip
AUTH_TOKEN = File.read('.rtm_auth_token').strip

def generate_sig(params)
  sorted = params.sort.map { |k, v| "#{k}#{v}" }.join
  Digest::MD5.hexdigest("#{SHARED_SECRET}#{sorted}")
end

def rtm_request(method, additional_params = {})
  params = {
    'method' => method,
    'api_key' => API_KEY,
    'auth_token' => AUTH_TOKEN,
    'format' => 'json'
  }.merge(additional_params)
  
  params['api_sig'] = generate_sig(params)
  
  uri = URI('https://api.rememberthemilk.com/services/rest/')
  uri.query = URI.encode_www_form(params)
  
  response = Net::HTTP.get_response(uri)
  JSON.parse(response.body)
end

puts "=== Testing v2 API Parameter ==="
puts

# First, test without v2
puts "1. Testing WITHOUT v=2 parameter..."
result_v1 = rtm_request('rtm.tasks.getList', {
  'list_id' => '51175519',
  'filter' => 'status:incomplete'
})

if result_v1['rsp']['stat'] == 'ok'
  puts "   Success! Checking for parent_task_id fields..."
  
  found_parent_field = false
  lists = result_v1['rsp']['tasks']['list']
  lists = [lists] unless lists.is_a?(Array) || lists.nil?
  
  lists&.each do |list|
    next unless list['taskseries']
    taskseries = list['taskseries']
    taskseries = [taskseries] unless taskseries.is_a?(Array)
    
    taskseries.each do |ts|
      if ts['parent_task_id']
        found_parent_field = true
        puts "   Found parent_task_id in '#{ts['name']}': #{ts['parent_task_id']}"
      end
    end
  end
  
  puts "   Result: #{found_parent_field ? 'parent_task_id FOUND' : 'NO parent_task_id fields found'}"
else
  puts "   Error: #{result_v1['rsp']['err']['msg']}"
end

puts
sleep 1

# Now test with v2
puts "2. Testing WITH v=2 parameter..."
result_v2 = rtm_request('rtm.tasks.getList', {
  'list_id' => '51175519',
  'filter' => 'status:incomplete',
  'v' => '2'
})

if result_v2['rsp']['stat'] == 'ok'
  puts "   Success! Checking for parent_task_id fields..."
  
  found_parent_field = false
  lists = result_v2['rsp']['tasks']['list']
  lists = [lists] unless lists.is_a?(Array) || lists.nil?
  
  lists&.each do |list|
    next unless list['taskseries']
    taskseries = list['taskseries']
    taskseries = [taskseries] unless taskseries.is_a?(Array)
    
    taskseries.each do |ts|
      if ts['parent_task_id']
        found_parent_field = true
        puts "   Found parent_task_id in '#{ts['name']}': #{ts['parent_task_id']}"
      end
      
      # Also check task keys
      puts "   Task '#{ts['name']}' has keys: #{ts.keys.sort.join(', ')}"
    end
  end
  
  puts "   Result: #{found_parent_field ? 'parent_task_id FOUND!' : 'NO parent_task_id fields found'}"
else
  puts "   Error: #{result_v2['rsp']['err']['msg']}"
end

puts
puts "3. Looking for the specific parent task with subtasks..."
sleep 1

result_parent = rtm_request('rtm.tasks.getList', {
  'list_id' => '51175519',
  'filter' => 'hasSubtasks:true',
  'v' => '2'
})

if result_parent['rsp']['stat'] == 'ok'
  lists = result_parent['rsp']['tasks']['list']
  lists = [lists] unless lists.is_a?(Array) || lists.nil?
  
  lists&.each do |list|
    next unless list['taskseries']
    taskseries = list['taskseries']
    taskseries = [taskseries] unless taskseries.is_a?(Array)
    
    taskseries.each do |ts|
      puts "   Parent task: #{ts['name']}"
      puts "   Full structure:"
      puts JSON.pretty_generate(ts)
    end
  end
end
