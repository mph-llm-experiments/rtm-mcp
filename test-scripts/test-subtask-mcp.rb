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

class RTMClient
  def initialize(api_key, shared_secret, auth_token)
    @api_key = api_key
    @shared_secret = shared_secret
    @auth_token = auth_token
  end
  
  def call_method(method, params = {})
    all_params = {
      'method' => method,
      'api_key' => @api_key,
      'auth_token' => @auth_token,
      'format' => 'json'
    }.merge(params)
    
    all_params['api_sig'] = generate_sig(all_params)
    
    uri = URI('https://api.rememberthemilk.com/services/rest/')
    uri.query = URI.encode_www_form(all_params)
    
    response = Net::HTTP.get_response(uri)
    JSON.parse(response.body)
  end
  
  private
  
  def generate_sig(params)
    sorted = params.sort.map { |k, v| "#{k}#{v}" }.join
    Digest::MD5.hexdigest("#{@shared_secret}#{sorted}")
  end
end

# Test create_subtask functionality
rtm = RTMClient.new(API_KEY, SHARED_SECRET, AUTH_TOKEN)

puts "=== Testing Create Subtask MCP Tool ==="
puts

# Get timeline
timeline_result = rtm.call_method('rtm.timelines.create')
timeline = timeline_result.dig('rsp', 'timeline')
puts "Timeline: #{timeline}"
puts

# Find parent task
puts "1. Finding parent task 'Add subtask support'..."
parent_result = rtm.call_method('rtm.tasks.getList', {
  'v' => '2',
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
          task_id: task[0]['id'],
          name: ts['name']
        }
        puts "   ✅ Found: #{ts['name']}"
        puts "   IDs: list=#{parent_task[:list_id]}, series=#{parent_task[:taskseries_id]}, task=#{parent_task[:task_id]}"
      end
    end
  end
end

if parent_task
  puts
  puts "2. Creating subtask 'Implement create_subtask tool'..."
  
  # Step 1: Create the task
  create_result = rtm.call_method('rtm.tasks.add', {
    'timeline' => timeline,
    'list_id' => parent_task[:list_id],
    'name' => 'Implement create_subtask tool'
  })
  
  if create_result['rsp']['stat'] == 'ok'
    list = create_result['rsp']['list']
    taskseries = list['taskseries']
    taskseries = [taskseries] unless taskseries.is_a?(Array)
    taskseries = taskseries[0]
    
    task = taskseries['task']
    task = [task] unless task.is_a?(Array)
    
    new_task = {
      list_id: list['id'],
      taskseries_id: taskseries['id'],
      task_id: task[0]['id'],
      name: taskseries['name']
    }
    
    puts "   ✅ Task created: #{new_task[:name]}"
    
    puts
    puts "3. Setting as subtask of '#{parent_task[:name]}'..."
    sleep 1
    
    # Step 2: Set parent task
    set_parent_result = rtm.call_method('rtm.tasks.setParentTask', {
      'v' => '2',
      'timeline' => timeline,
      'list_id' => new_task[:list_id],
      'taskseries_id' => new_task[:taskseries_id],
      'task_id' => new_task[:task_id],
      'parent_task_id' => parent_task[:task_id]
    })
    
    if set_parent_result['rsp']['stat'] == 'ok'
      puts "   ✅ Success! Task is now a subtask"
      
      # The response should be formatted for MCP
      puts
      puts "4. MCP tool response would be:"
      puts "   ✅ Created subtask: #{new_task[:name]}"
      puts "   Parent: #{parent_task[:name]}"
      puts "   IDs: list=#{new_task[:list_id]}, series=#{new_task[:taskseries_id]}, task=#{new_task[:task_id]}"
    else
      error = set_parent_result.dig('rsp', 'err')
      puts "   ❌ Error setting parent: #{error['msg']} (code: #{error['code']})"
    end
  else
    error = create_result.dig('rsp', 'err')
    puts "   ❌ Error creating task: #{error['msg']}"
  end
else
  puts "   ❌ Parent task not found"
end

puts
puts "5. Verifying subtask relationship..."
sleep 1

verify_result = rtm.call_method('rtm.tasks.getList', {
  'v' => '2',
  'list_id' => '51175519',
  'filter' => 'status:incomplete'
})

if verify_result['rsp']['stat'] == 'ok' && verify_result['rsp']['tasks']['list']
  list = verify_result['rsp']['tasks']['list']
  list = [list] unless list.is_a?(Array)
  
  found_parent = false
  found_subtask = false
  
  list.each do |l|
    next unless l['taskseries']
    taskseries = l['taskseries']
    taskseries = [taskseries] unless taskseries.is_a?(Array)
    
    taskseries.each do |ts|
      if ts['name'] == 'Add subtask support'
        found_parent = true
      elsif ts['name'] == 'Implement create_subtask tool' && ts['parent_task_id'] && ts['parent_task_id'] != '0'
        found_subtask = true
        puts "   ✅ Verified: '#{ts['name']}' has parent_task_id=#{ts['parent_task_id']}"
      end
    end
  end
  
  if found_parent && found_subtask
    puts "   ✅ Subtask relationship confirmed!"
  end
end
