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

puts "=== RTM setParentTask Test ==="
puts

# Get timeline
puts "1. Getting timeline..."
timeline_result = rtm_request('rtm.timelines.create')
timeline = timeline_result.dig('rsp', 'timeline')
puts "   Timeline: #{timeline}"

puts

# Find our target parent task
puts "2. Finding 'Add subtask support' task..."
result = rtm_request('rtm.tasks.getList', {
  'filter' => 'name:"Add subtask support"',
  'list_id' => '51175519'
})

parent_task = nil
if result['rsp']['stat'] == 'ok' && result['rsp']['tasks']['list']
  list = result['rsp']['tasks']['list']
  list = [list] unless list.is_a?(Array)
  
  list.each do |l|
    next unless l['taskseries']
    taskseries = l['taskseries']
    taskseries = [taskseries] unless taskseries.is_a?(Array)
    
    taskseries.each do |ts|
      if ts['name'] == 'Add subtask support'
        parent_task = {
          list_id: l['id'],
          taskseries_id: ts['id'],
          task_id: ts['task'][0]['id']
        }
        puts "   Found parent task: #{parent_task.inspect}"
      end
    end
  end
end

puts

# Create a test subtask
puts "3. Creating a test subtask..."
sleep 1
create_result = rtm_request('rtm.tasks.add', {
  'timeline' => timeline,
  'list_id' => '51175519',
  'name' => 'Test subtask for discovery'
})

if create_result['rsp']['stat'] == 'ok'
  new_task = create_result['rsp']['list']['taskseries']
  # Handle taskseries as array
  new_task = [new_task] unless new_task.is_a?(Array)
  new_task = new_task[0]
  
  # Handle task as array
  task = new_task['task']
  task = [task] unless task.is_a?(Array)
  
  subtask = {
    list_id: create_result['rsp']['list']['id'],
    taskseries_id: new_task['id'],
    task_id: task[0]['id']
  }
  puts "   Created task: #{new_task['name']}"
  puts "   IDs: #{subtask.inspect}"
  
  puts
  
  # Set it as a subtask
  puts "4. Setting parent task..."
  sleep 1
  
  set_parent_result = rtm_request('rtm.tasks.setParentTask', {
    'timeline' => timeline,
    'list_id' => subtask[:list_id],
    'taskseries_id' => subtask[:taskseries_id],
    'task_id' => subtask[:task_id],
    'parent_list_id' => parent_task[:list_id],
    'parent_taskseries_id' => parent_task[:taskseries_id],
    'parent_task_id' => parent_task[:task_id]
  })
  
  if set_parent_result['rsp']['stat'] == 'ok'
    puts "   Success! Task is now a subtask"
    
    puts
    
    # Now let's see how it appears in getList
    puts "5. Checking how subtasks appear in getList..."
    sleep 1
    
    # First, regular getList
    puts "   a) Regular getList:"
    list_result = rtm_request('rtm.tasks.getList', {
      'filter' => 'status:incomplete',
      'list_id' => '51175519'
    })
    
    if list_result['rsp']['stat'] == 'ok'
      count = 0
      list = list_result['rsp']['tasks']['list']
      list = [list] unless list.is_a?(Array)
      
      list.each do |l|
        next unless l['taskseries']
        taskseries = l['taskseries']
        taskseries = [taskseries] unless taskseries.is_a?(Array)
        count += taskseries.length
      end
      puts "      Total tasks visible: #{count}"
    end
    
    sleep 1
    
    # Try with parent filter
    puts "   b) Filter by parent:"
    parent_filter_result = rtm_request('rtm.tasks.getList', {
      'filter' => "isSubtaskOf:#{parent_task[:taskseries_id]}",
      'list_id' => '51175519'
    })
    
    if parent_filter_result['rsp']['stat'] == 'ok'
      if parent_filter_result['rsp']['tasks'] && parent_filter_result['rsp']['tasks']['list']
        puts "      Found tasks with parent filter!"
        # Show the structure
        puts JSON.pretty_generate(parent_filter_result['rsp']['tasks'])
      else
        puts "      No tasks found with parent filter"
      end
    else
      puts "      Filter error: #{parent_filter_result['rsp']['err']['msg'] if parent_filter_result['rsp']['err']}"
    end
    
    sleep 1
    
    # Look at the parent task structure now
    puts "   c) Parent task structure after adding subtask:"
    parent_check = rtm_request('rtm.tasks.getList', {
      'filter' => 'name:"Add subtask support"',
      'list_id' => '51175519'
    })
    
    if parent_check['rsp']['stat'] == 'ok' && parent_check['rsp']['tasks']['list']
      list = parent_check['rsp']['tasks']['list']
      list = [list] unless list.is_a?(Array)
      
      list.each do |l|
        next unless l['taskseries']
        taskseries = l['taskseries']
        taskseries = [taskseries] unless taskseries.is_a?(Array)
        
        taskseries.each do |ts|
          if ts['name'] == 'Add subtask support'
            puts "      Parent task details:"
            puts "      - Name: #{ts['name']}"
            puts "      - Task keys: #{ts['task'][0].keys.join(', ')}"
            
            # Check for new fields
            ts['task'][0].each do |key, value|
              if key.include?('subtask') || key == 'has_subtasks'
                puts "      - #{key}: #{value}"
              end
            end
          end
        end
      end
    end
    
  else
    puts "   Error setting parent: #{set_parent_result['rsp']['err']['msg'] if set_parent_result['rsp']['err']}"
  end
else
  puts "   Error creating task: #{create_result['rsp']['err']['msg'] if create_result['rsp']['err']}"
end
