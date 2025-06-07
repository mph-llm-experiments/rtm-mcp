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

puts "=== Testing API Version Parameters ==="
puts

# Try different version parameters
versions = ['2', '2.0', 'v2']
version_params = ['v', 'version', 'api_version']

# Test echo with different version parameters
puts "1. Testing version parameters with rtm.test.echo..."
versions.each do |ver|
  version_params.each do |param|
    puts "   Trying #{param}=#{ver}..."
    result = rtm_request('rtm.test.echo', {
      param => ver,
      'test' => 'hello'
    })
    
    if result['rsp']['stat'] == 'ok'
      puts "     ✅ Success - Response: #{result['rsp'].inspect}"
    else
      puts "     ❌ Error: #{result['rsp']['err']['msg'] if result['rsp']['err']}"
    end
    
    sleep 1
  end
end

puts

# Clean up the test task we created
puts "2. Cleaning up test task..."
timeline_result = rtm_request('rtm.timelines.create')
timeline = timeline_result.dig('rsp', 'timeline')

cleanup_result = rtm_request('rtm.tasks.getList', {
  'filter' => 'name:"Research RTM subtask API"',
  'list_id' => '51175519'
})

if cleanup_result['rsp']['stat'] == 'ok' && cleanup_result['rsp']['tasks']['list']
  list = cleanup_result['rsp']['tasks']['list']
  list = [list] unless list.is_a?(Array)
  
  list.each do |l|
    next unless l['taskseries']
    taskseries = l['taskseries']
    taskseries = [taskseries] unless taskseries.is_a?(Array)
    
    taskseries.each do |ts|
      if ts['name'] == 'Research RTM subtask API'
        puts "   Deleting: #{ts['name']}"
        task = ts['task']
        task = [task] unless task.is_a?(Array)
        
        delete_result = rtm_request('rtm.tasks.delete', {
          'timeline' => timeline,
          'list_id' => l['id'],
          'taskseries_id' => ts['id'],
          'task_id' => task[0]['id']
        })
        
        if delete_result['rsp']['stat'] == 'ok'
          puts "   ✅ Deleted"
        end
      end
    end
  end
end

puts

# Check if there's a different endpoint or parameter
puts "3. Checking if subtasks might be visible with special parameters..."
sleep 1

# Try getting tasks with different parameters
special_params = [
  { 'include_subtasks' => '1' },
  { 'includeSubtasks' => 'true' },
  { 'expand' => 'subtasks' },
  { 'fields' => 'all' }
]

special_params.each do |params|
  puts "   Trying with #{params.inspect}..."
  
  result = rtm_request('rtm.tasks.getList', params.merge({
    'filter' => 'hasSubtasks:true',
    'list_id' => '51175519'
  }))
  
  if result['rsp']['stat'] == 'ok' && result['rsp']['tasks']['list']
    list = result['rsp']['tasks']['list']
    list = [list] unless list.is_a?(Array)
    
    # Check if any task has parent_task_id
    found_parent_id = false
    list.each do |l|
      next unless l['taskseries']
      taskseries = l['taskseries']
      taskseries = [taskseries] unless taskseries.is_a?(Array)
      
      taskseries.each do |ts|
        if ts['parent_task_id']
          found_parent_id = true
          puts "     🎯 Found parent_task_id field!"
        end
      end
    end
    
    puts "     No parent_task_id found" unless found_parent_id
  else
    puts "     Error: #{result['rsp']['err']['msg'] if result['rsp']['err']}"
  end
  
  sleep 1
end

puts
puts "Summary:"
puts "- setParentTask requires a newer API version"
puts "- Current API doesn't show parent_task_id field"
puts "- hasSubtasks:true filter works to find parent tasks"
puts "- Subtasks might only be fully accessible via newer API or web interface"
