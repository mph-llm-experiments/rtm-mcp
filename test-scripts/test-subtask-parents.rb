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

puts "=== RTM Tasks with Subtasks Discovery ==="
puts

# Find tasks that have subtasks
puts "1. Getting tasks with hasSubtasks:true..."
result = rtm_request('rtm.tasks.getList', {
  'filter' => 'hasSubtasks:true',
  'list_id' => '51175519'
})

parent_tasks = []

if result['rsp']['stat'] == 'ok' && result['rsp']['tasks']['list']
  list = result['rsp']['tasks']['list']
  list = [list] unless list.is_a?(Array)
  
  list.each do |l|
    next unless l['taskseries']
    
    taskseries = l['taskseries']
    taskseries = [taskseries] unless taskseries.is_a?(Array)
    
    taskseries.each do |ts|
      puts "   Found parent task: #{ts['name']}"
      puts "   Taskseries ID: #{ts['id']}"
      
      # Store for later lookup
      parent_tasks << {
        name: ts['name'],
        list_id: l['id'],
        taskseries_id: ts['id'],
        task_id: ts['task'][0]['id']
      }
      
      # Check task structure
      if ts['task']
        task = ts['task']
        task = [task] unless task.is_a?(Array)
        
        puts "   Number of task objects: #{task.length}"
        
        task.each_with_index do |t, i|
          puts "   Task[#{i}]:"
          t.each do |key, value|
            if value && value != "" && value != "0"
              puts "     #{key}: #{value}"
            end
          end
        end
      end
      
      puts
    end
  end
end

puts

# Now try to find the subtasks
puts "2. Looking for subtasks of parent tasks..."

parent_tasks.each do |parent|
  puts "   Searching for subtasks of '#{parent[:name]}'..."
  sleep 1
  
  # Try different filter approaches
  filters = [
    "parentTask:#{parent[:taskseries_id]}",
    "parent:#{parent[:taskseries_id]}",
    "isSubtaskOf:#{parent[:taskseries_id]}"
  ]
  
  filters.each do |filter|
    puts "     Trying filter: #{filter}"
    
    result = rtm_request('rtm.tasks.getList', {
      'filter' => filter,
      'list_id' => '51175519'
    })
    
    if result['rsp']['stat'] == 'ok'
      if result['rsp']['tasks'] && result['rsp']['tasks']['list']
        list = result['rsp']['tasks']['list']
        list = [list] unless list.is_a?(Array)
        
        count = 0
        list.each do |l|
          next unless l['taskseries']
          taskseries = l['taskseries']
          taskseries = [taskseries] unless taskseries.is_a?(Array)
          
          taskseries.each do |ts|
            count += 1
            puts "       ↳ Found: #{ts['name']}"
          end
        end
        
        puts "       Total found: #{count}" if count > 0
      end
    end
  end
  
  puts
end

puts

# Check if subtasks might be in the same response with special fields
puts "3. Re-examining parent tasks for embedded subtask data..."
sleep 1

result = rtm_request('rtm.tasks.getList', {
  'filter' => 'hasSubtasks:true',
  'list_id' => '51175519'
})

if result['rsp']['stat'] == 'ok' && result['rsp']['tasks']['list']
  puts "   Full JSON structure of first parent task:"
  
  list = result['rsp']['tasks']['list']
  list = [list] unless list.is_a?(Array)
  
  if list[0] && list[0]['taskseries']
    taskseries = list[0]['taskseries']
    taskseries = [taskseries] unless taskseries.is_a?(Array)
    
    if taskseries[0]
      puts JSON.pretty_generate(taskseries[0])
    end
  end
end
