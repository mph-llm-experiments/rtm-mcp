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

puts "=== Creating and Finding Subtasks ==="
puts

# Get timeline
timeline_result = rtm_request('rtm.timelines.create')
timeline = timeline_result.dig('rsp', 'timeline')
puts "Timeline: #{timeline}"
puts

# Find the parent task
puts "1. Finding 'Add subtask support' parent task..."
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
        puts "   IDs: #{parent_task.inspect}"
      end
    end
  end
end

puts

if parent_task
  # Create a subtask
  puts "2. Creating subtask 'Research RTM subtask API'..."
  sleep 1
  
  create_result = rtm_request('rtm.tasks.add', {
    'timeline' => timeline,
    'list_id' => parent_task[:list_id],
    'name' => 'Research RTM subtask API',
    'parse' => '0'  # Don't parse smart add syntax
  })
  
  if create_result['rsp']['stat'] == 'ok'
    new_task = create_result['rsp']['list']['taskseries']
    new_task = [new_task] unless new_task.is_a?(Array)
    new_task = new_task[0]
    
    task = new_task['task']
    task = [task] unless task.is_a?(Array)
    
    subtask = {
      list_id: create_result['rsp']['list']['id'],
      taskseries_id: new_task['id'],
      task_id: task[0]['id']
    }
    
    puts "   Created: #{new_task['name']}"
    puts "   IDs: #{subtask.inspect}"
    
    puts
    
    # Try to set it as a subtask with different parameter names
    puts "3. Attempting to set parent task..."
    sleep 1
    
    # Try the documented parameters
    set_parent_result = rtm_request('rtm.tasks.setParentTask', {
      'timeline' => timeline,
      'list_id' => subtask[:list_id],
      'taskseries_id' => subtask[:taskseries_id],
      'task_id' => subtask[:task_id],
      'parent_task_id' => parent_task[:task_id]  # Try just parent_task_id
    })
    
    if set_parent_result['rsp']['stat'] == 'ok'
      puts "   ✅ Success! Task is now a subtask"
      
      # Check the response structure
      puts "   Response structure:"
      puts JSON.pretty_generate(set_parent_result['rsp'])
    else
      puts "   ❌ Error: #{set_parent_result['rsp']['err']['msg'] if set_parent_result['rsp']['err']}"
      
      # Try alternative parameter format
      puts
      puts "4. Trying alternative parameter format..."
      sleep 1
      
      set_parent_result2 = rtm_request('rtm.tasks.setParentTask', {
        'timeline' => timeline,
        'list_id' => subtask[:list_id],
        'taskseries_id' => subtask[:taskseries_id],
        'task_id' => subtask[:task_id],
        'parent_list_id' => parent_task[:list_id],
        'parent_taskseries_id' => parent_task[:taskseries_id],
        'parent_task_id' => parent_task[:task_id]
      })
      
      if set_parent_result2['rsp']['stat'] == 'ok'
        puts "   ✅ Success with full parent IDs!"
        puts JSON.pretty_generate(set_parent_result2['rsp'])
      else
        puts "   ❌ Still error: #{set_parent_result2['rsp']['err']['msg'] if set_parent_result2['rsp']['err']}"
      end
    end
    
    puts
    puts "5. Checking task structure after parent setting..."
    sleep 1
    
    # Get the task again to see if parent_task_id appears
    check_result = rtm_request('rtm.tasks.getList', {
      'filter' => 'name:"Research RTM subtask API"',
      'list_id' => '51175519'
    })
    
    if check_result['rsp']['stat'] == 'ok' && check_result['rsp']['tasks']['list']
      list = check_result['rsp']['tasks']['list']
      list = [list] unless list.is_a?(Array)
      
      list.each do |l|
        next unless l['taskseries']
        taskseries = l['taskseries']
        taskseries = [taskseries] unless taskseries.is_a?(Array)
        
        taskseries.each do |ts|
          if ts['name'] == 'Research RTM subtask API'
            puts "   Task structure:"
            puts JSON.pretty_generate(ts)
          end
        end
      end
    end
  end
end
