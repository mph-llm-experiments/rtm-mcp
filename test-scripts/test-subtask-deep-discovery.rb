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

puts "=== RTM Subtask Deep Discovery ==="
puts

# First, let's find the "Add subtask support" task specifically
puts "1. Finding 'Add subtask support' task..."
result = rtm_request('rtm.tasks.getList', {
  'filter' => 'name:"Add subtask support"',
  'list_id' => '51175519'
})

subtask_support_task = nil
if result['rsp']['stat'] == 'ok' && result['rsp']['tasks']['list']
  list = result['rsp']['tasks']['list']
  list = [list] unless list.is_a?(Array)
  
  list.each do |l|
    next unless l['taskseries']
    taskseries = l['taskseries']
    taskseries = [taskseries] unless taskseries.is_a?(Array)
    
    taskseries.each do |ts|
      if ts['name'] == 'Add subtask support'
        subtask_support_task = {
          list_id: l['id'],
          taskseries_id: ts['id'],
          task_id: ts['task'][0]['id']
        }
        puts "   Found! IDs: #{subtask_support_task.inspect}"
      end
    end
  end
end

puts

# Try different filter approaches
puts "2. Testing filter approaches for subtasks..."
sleep 1

# Try filter with parent task
if subtask_support_task
  puts "   a) Trying filter with parent:taskseries_id..."
  result = rtm_request('rtm.tasks.getList', {
    'filter' => "parent:#{subtask_support_task[:taskseries_id]}",
    'list_id' => '51175519'
  })
  puts "      Response stat: #{result['rsp']['stat']}"
  if result['rsp']['stat'] == 'fail'
    puts "      Error: #{result['rsp']['err']['msg']}"
  end
end

sleep 1

# Try includeSubtasks parameter
puts "   b) Trying includeSubtasks parameter..."
result = rtm_request('rtm.tasks.getList', {
  'filter' => 'status:incomplete',
  'list_id' => '51175519',
  'includeSubtasks' => '1'
})
puts "      Response stat: #{result['rsp']['stat']}"
if result['rsp']['stat'] == 'fail'
  puts "      Error: #{result['rsp']['err']['msg']}"
end

sleep 1

# Try include_subtasks parameter (different naming)
puts "   c) Trying include_subtasks parameter..."
result = rtm_request('rtm.tasks.getList', {
  'filter' => 'status:incomplete',
  'list_id' => '51175519',
  'include_subtasks' => 'true'
})
puts "      Response stat: #{result['rsp']['stat']}"

puts

# Test getInfo method if available
if subtask_support_task
  puts "3. Testing rtm.tasks.getInfo..."
  sleep 1
  
  result = rtm_request('rtm.tasks.getInfo', {
    'list_id' => subtask_support_task[:list_id],
    'taskseries_id' => subtask_support_task[:taskseries_id],
    'task_id' => subtask_support_task[:task_id]
  })
  
  if result['rsp']['stat'] == 'ok'
    puts "   Success! Checking for additional fields..."
    puts JSON.pretty_generate(result['rsp'])
  else
    puts "   Error: #{result['rsp']['err']['msg'] if result['rsp']['err']}"
  end
end

puts

# Try getting all methods to see if there are subtask-specific ones
puts "4. Exploring available RTM methods..."
sleep 1
result = rtm_request('rtm.reflection.getMethods')

if result['rsp']['stat'] == 'ok'
  methods = result['rsp']['methods']['method']
  subtask_methods = methods.select { |m| m.downcase.include?('subtask') || m.downcase.include?('child') }
  
  if subtask_methods.any?
    puts "   Found subtask-related methods:"
    subtask_methods.each { |m| puts "   - #{m}" }
  else
    puts "   No obvious subtask methods found"
    
    # Look for task methods that might handle subtasks
    task_methods = methods.select { |m| m.start_with?('rtm.tasks.') }
    puts "   Available rtm.tasks.* methods:"
    task_methods.each { |m| puts "   - #{m}" }
  end
end

puts

# Check if subtasks appear as separate tasks with parent references
puts "5. Looking for tasks that might be subtasks (checking all task fields)..."
sleep 1
result = rtm_request('rtm.tasks.getList', {
  'filter' => 'status:incomplete',
  'list_id' => '51175519'
})

if result['rsp']['stat'] == 'ok'
  list = result['rsp']['tasks']['list']
  list = [list] unless list.is_a?(Array)
  
  found_potential_subtasks = false
  
  list.each do |l|
    next unless l['taskseries']
    
    taskseries = l['taskseries']
    taskseries = [taskseries] unless taskseries.is_a?(Array)
    
    taskseries.each do |ts|
      # Check for any parent-related fields in taskseries
      parent_fields = ts.keys.select { |k| k.include?('parent') || k.include?('child') }
      if parent_fields.any?
        puts "   Task '#{ts['name']}' has parent-related fields: #{parent_fields.join(', ')}"
        found_potential_subtasks = true
      end
      
      # Check task objects
      if ts['task']
        task = ts['task']
        task = [task] unless task.is_a?(Array)
        
        task.each do |t|
          # Look for any field that might indicate parent/child relationship
          relationship_fields = t.keys.select { |k| 
            k.include?('parent') || k.include?('child') || k.include?('subtask')
          }
          
          if relationship_fields.any?
            puts "   Task '#{ts['name']}' has relationship fields in task object: #{relationship_fields.join(', ')}"
            relationship_fields.each do |field|
              puts "     #{field}: #{t[field]}"
            end
            found_potential_subtasks = true
          end
        end
      end
    end
  end
  
  puts "   No parent/child fields found in current tasks" unless found_potential_subtasks
end
