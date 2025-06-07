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

puts "=== RTM Subtask Investigation - Clean Up & Alternative Approaches ==="
puts

# Get timeline
timeline_result = rtm_request('rtm.timelines.create')
timeline = timeline_result.dig('rsp', 'timeline')

# First, clean up test tasks
puts "1. Cleaning up test tasks..."
result = rtm_request('rtm.tasks.getList', {
  'filter' => 'name:"Test subtask for discovery"',
  'list_id' => '51175519'
})

if result['rsp']['stat'] == 'ok' && result['rsp']['tasks']['list']
  list = result['rsp']['tasks']['list']
  list = [list] unless list.is_a?(Array)
  
  list.each do |l|
    next unless l['taskseries']
    taskseries = l['taskseries']
    taskseries = [taskseries] unless taskseries.is_a?(Array)
    
    taskseries.each do |ts|
      if ts['name'].include?('Test subtask')
        puts "   Deleting: #{ts['name']}"
        delete_result = rtm_request('rtm.tasks.delete', {
          'timeline' => timeline,
          'list_id' => l['id'],
          'taskseries_id' => ts['id'],
          'task_id' => ts['task'][0]['id']
        })
        sleep 1
      end
    end
  end
end

puts

# Check API version info
puts "2. Checking API version capabilities..."
sleep 1

# Try the echo method to see version info
echo_result = rtm_request('rtm.test.echo', {
  'api_version' => '2'
})
puts "   Echo with api_version=2: #{echo_result['rsp']['stat']}"

# Try with different version parameters
sleep 1
echo_result2 = rtm_request('rtm.test.echo', {
  'version' => '2.0'
})
puts "   Echo with version=2.0: #{echo_result2['rsp']['stat']}"

puts

# Look for subtasks in existing data
puts "3. Checking if RTM web/app created subtasks are visible..."
sleep 1

# Get all tasks and look for any parent/child indicators
result = rtm_request('rtm.tasks.getList', {
  'filter' => 'status:incomplete',
  'list_id' => '51175519'
})

if result['rsp']['stat'] == 'ok'
  puts "   Analyzing task structure for hidden subtask fields..."
  
  list = result['rsp']['tasks']['list']
  list = [list] unless list.is_a?(Array)
  
  list.each do |l|
    next unless l['taskseries']
    
    taskseries = l['taskseries']
    taskseries = [taskseries] unless taskseries.is_a?(Array)
    
    taskseries.each do |ts|
      # Look for the "Add subtask support" task specifically
      if ts['name'] == 'Add subtask support'
        puts
        puts "   'Add subtask support' task structure:"
        puts "   Taskseries keys: #{ts.keys.sort.join(', ')}"
        
        if ts['task']
          task = ts['task']
          task = [task] unless task.is_a?(Array)
          
          task.each_with_index do |t, i|
            puts "   Task[#{i}] keys: #{t.keys.sort.join(', ')}"
            
            # Check each field for interesting values
            t.each do |key, value|
              if value && value != "" && value != "0" && key != 'id'
                puts "     #{key}: #{value}"
              end
            end
          end
        end
        
        # Check if there are multiple task objects (might indicate subtasks)
        if ts['task'].is_a?(Array) && ts['task'].length > 1
          puts "   ⚠️  Multiple task objects found! Count: #{ts['task'].length}"
        end
      end
    end
  end
end

puts

# Try alternative parent/child syntax
puts "4. Testing alternative subtask query approaches..."
sleep 1

# Try hasSubtasks filter
puts "   a) Trying hasSubtasks:true filter..."
result = rtm_request('rtm.tasks.getList', {
  'filter' => 'hasSubtasks:true',
  'list_id' => '51175519'
})

if result['rsp']['stat'] == 'ok'
  if result['rsp']['tasks'] && result['rsp']['tasks']['list']
    puts "      Found tasks with subtasks!"
  else
    puts "      No tasks with hasSubtasks:true"
  end
else
  puts "      Filter not recognized or no results"
end

sleep 1

# Try isSubtask filter
puts "   b) Trying isSubtask:true filter..."
result = rtm_request('rtm.tasks.getList', {
  'filter' => 'isSubtask:true',
  'list_id' => '51175519'
})

if result['rsp']['stat'] == 'ok'
  if result['rsp']['tasks'] && result['rsp']['tasks']['list']
    puts "      Found subtasks!"
  else
    puts "      No tasks with isSubtask:true"
  end
else
  puts "      Filter not recognized or no results"
end

puts
puts "5. Summary of findings:"
puts "   - rtm.tasks.setParentTask exists but requires newer API version"
puts "   - Need to investigate if subtasks are:"
puts "     a) Only available in newer API versions"
puts "     b) Visible through special parameters we haven't found"
puts "     c) Stored in a way we haven't discovered yet"
puts
puts "   Next steps: Check RTM developer docs or try creating subtasks"
puts "   via web interface to see how they appear in API"
