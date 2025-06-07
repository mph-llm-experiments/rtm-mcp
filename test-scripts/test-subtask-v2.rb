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

puts "=== Testing setParentTask with API v2 ==="
puts

# Get timeline
timeline_result = rtm_request('rtm.timelines.create')
timeline = timeline_result.dig('rsp', 'timeline')
puts "Timeline: #{timeline}"
puts

# Find parent task
puts "1. Finding parent task..."
parent_result = rtm_request('rtm.tasks.getList', {
  'filter' => 'name:"Add subtask support"',
  'list_id' => '51175519'
})

parent_task = nil
if parent_result['rsp']['stat'] == 'ok' && parent_result['rsp']['tasks']['list']
  list = parent_result['rsp']['tasks']['list']
  list = [list] unless list.is_a?(Array)
  
  list.each do |l|
    next unless l['taskseries']
    taskseries = l['taskseries']
    taskseries = [taskseries] unless taskseries.is_a?(Array)
    
    taskseries.each do |ts|
      if ts['name'] == 'Add subtask support'
        task = ts['task']
        task = [task] unless task.is_a?(Array)
        
        parent_task = {
          list_id: l['id'],
          taskseries_id: ts['id'],
          task_id: task[0]['id']
        }
        puts "   Found: #{ts['name']}"
      end
    end
  end
end

puts

# Create tasks to be subtasks
subtasks_to_create = [
  'Research RTM subtask API',
  'Implement subtask tools'
]

created_tasks = []

subtasks_to_create.each do |task_name|
  puts "2. Creating task: #{task_name}..."
  sleep 1
  
  create_result = rtm_request('rtm.tasks.add', {
    'timeline' => timeline,
    'list_id' => parent_task[:list_id],
    'name' => task_name
  })
  
  if create_result['rsp']['stat'] == 'ok'
    new_task = create_result['rsp']['list']['taskseries']
    new_task = [new_task] unless new_task.is_a?(Array)
    new_task = new_task[0]
    
    task = new_task['task']
    task = [task] unless task.is_a?(Array)
    
    created_task = {
      name: task_name,
      list_id: create_result['rsp']['list']['id'],
      taskseries_id: new_task['id'],
      task_id: task[0]['id']
    }
    
    created_tasks << created_task
    puts "   ✅ Created"
  end
end

puts

# Try setParentTask with v=2
created_tasks.each do |subtask|
  puts "3. Setting '#{subtask[:name]}' as subtask with v=2..."
  sleep 1
  
  set_parent_result = rtm_request('rtm.tasks.setParentTask', {
    'v' => '2',  # API version 2
    'timeline' => timeline,
    'list_id' => subtask[:list_id],
    'taskseries_id' => subtask[:taskseries_id],
    'task_id' => subtask[:task_id],
    'parent_task_id' => parent_task[:task_id]
  })
  
  if set_parent_result['rsp']['stat'] == 'ok'
    puts "   ✅ Success! Task is now a subtask"
    puts "   Response:"
    puts JSON.pretty_generate(set_parent_result['rsp'])
  else
    puts "   ❌ Error: #{set_parent_result['rsp']['err']['msg'] if set_parent_result['rsp']['err']}"
  end
end

puts
puts "4. Checking task list with v=2 to see parent_task_id..."
sleep 1

check_result = rtm_request('rtm.tasks.getList', {
  'v' => '2',
  'list_id' => '51175519',
  'filter' => 'status:incomplete'
})

if check_result['rsp']['stat'] == 'ok' && check_result['rsp']['tasks']['list']
  list = check_result['rsp']['tasks']['list']
  list = [list] unless list.is_a?(Array)
  
  puts "   Looking for parent_task_id fields..."
  found_subtasks = false
  
  list.each do |l|
    next unless l['taskseries']
    taskseries = l['taskseries']
    taskseries = [taskseries] unless taskseries.is_a?(Array)
    
    taskseries.each do |ts|
      if ts['parent_task_id'] && ts['parent_task_id'] != '' && ts['parent_task_id'] != '0'
        found_subtasks = true
        puts "   🎯 Found subtask: #{ts['name']}"
        puts "      parent_task_id: #{ts['parent_task_id']}"
      end
    end
  end
  
  if !found_subtasks
    puts "   No parent_task_id fields found even with v=2"
  end
end
