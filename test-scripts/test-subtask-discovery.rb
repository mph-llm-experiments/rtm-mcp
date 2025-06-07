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

puts "=== RTM Subtask Discovery ==="
puts "Finding tasks with subtasks..."
puts

# Get all incomplete tasks
result = rtm_request('rtm.tasks.getList', {
  'filter' => 'status:incomplete',
  'list_id' => '51175519'  # RTM MCP Development list
})

if result['rsp']['stat'] == 'ok'
  list = result['rsp']['tasks']['list']
  list = [list] unless list.is_a?(Array)
  
  list.each do |l|
    next unless l['taskseries']
    
    taskseries = l['taskseries']
    taskseries = [taskseries] unless taskseries.is_a?(Array)
    
    taskseries.each do |ts|
      puts "Task: #{ts['name']}"
      puts "  ID: #{ts['id']}"
      
      # Check task structure for subtask indicators
      if ts['task']
        task = ts['task']
        task = [task] unless task.is_a?(Array)
        
        task.each do |t|
          puts "  Task object keys: #{t.keys.join(', ')}"
          
          # Look for parent_task_id or has_subtasks fields
          if t['parent_task_id'] && t['parent_task_id'] != '0'
            puts "  🔸 SUBTASK! Parent ID: #{t['parent_task_id']}"
          end
          
          if t['has_subtasks'] && t['has_subtasks'] != '0'
            puts "  📋 HAS SUBTASKS!"
          end
        end
      end
      
      # Check taskseries for any subtask-related fields
      interesting_keys = ts.keys - ['id', 'created', 'modified', 'name', 'source', 'task', 'tags', 'notes', 'participants', 'url']
      if !interesting_keys.empty?
        puts "  Interesting taskseries keys: #{interesting_keys.join(', ')}"
      end
      
      puts
    end
  end
  
  puts "\n=== Fetching task details for 'Add subtask support' ==="
  # Let's specifically look at the subtask support task
  sleep 1
  result2 = rtm_request('rtm.tasks.getList', {
    'filter' => 'name:"Add subtask support"',
    'list_id' => '51175519'
  })
  
  if result2['rsp']['stat'] == 'ok' && result2['rsp']['tasks']['list']
    list = result2['rsp']['tasks']['list']
    list = [list] unless list.is_a?(Array)
    
    list.each do |l|
      next unless l['taskseries']
      taskseries = l['taskseries']
      taskseries = [taskseries] unless taskseries.is_a?(Array)
      
      taskseries.each do |ts|
        puts "\nDetailed structure for '#{ts['name']}':"
        puts JSON.pretty_generate(ts)
      end
    end
  end
else
  puts "Error: #{result['rsp']['err']}"
end
