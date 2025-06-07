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

puts "=== Finding Subtasks by parent_task_id ==="
puts

# Step 1: Find tasks with subtasks
puts "1. Finding parent tasks (hasSubtasks:true)..."
parent_result = rtm_request('rtm.tasks.getList', {
  'filter' => 'hasSubtasks:true',
  'list_id' => '51175519'
})

parent_tasks = {}
if parent_result['rsp']['stat'] == 'ok' && parent_result['rsp']['tasks']['list']
  list = parent_result['rsp']['tasks']['list']
  list = [list] unless list.is_a?(Array)
  
  list.each do |l|
    next unless l['taskseries']
    taskseries = l['taskseries']
    taskseries = [taskseries] unless taskseries.is_a?(Array)
    
    taskseries.each do |ts|
      # For each parent task, store both taskseries_id and task_id
      if ts['task']
        task = ts['task']
        task = [task] unless task.is_a?(Array)
        
        task.each do |t|
          parent_key = "#{ts['id']}_#{t['id']}"
          parent_tasks[parent_key] = {
            name: ts['name'],
            taskseries_id: ts['id'],
            task_id: t['id'],
            list_id: l['id']
          }
          puts "   Parent: #{ts['name']}"
          puts "     - Taskseries ID: #{ts['id']}"
          puts "     - Task ID: #{t['id']}"
        end
      end
    end
  end
end

puts
sleep 1

# Step 2: Get ALL tasks and look for parent_task_id
puts "2. Getting ALL tasks to find subtasks..."
all_result = rtm_request('rtm.tasks.getList', {
  'list_id' => '51175519'  # Get all tasks, including completed
})

subtasks_found = []

if all_result['rsp']['stat'] == 'ok' && all_result['rsp']['tasks']['list']
  list = all_result['rsp']['tasks']['list']
  list = [list] unless list.is_a?(Array)
  
  list.each do |l|
    next unless l['taskseries']
    
    taskseries = l['taskseries']
    taskseries = [taskseries] unless taskseries.is_a?(Array)
    
    taskseries.each do |ts|
      # Look for parent_task_id in the taskseries
      if ts['parent_task_id'] && ts['parent_task_id'] != '0'
        puts "   🎯 Found subtask with parent_task_id!"
        puts "     - Name: #{ts['name']}"
        puts "     - Parent task ID: #{ts['parent_task_id']}"
        puts "     - This taskseries ID: #{ts['id']}"
        
        # Find which parent this belongs to
        parent_tasks.each do |key, parent|
          if parent[:task_id] == ts['parent_task_id']
            puts "     - Parent is: #{parent[:name]}"
          end
        end
        
        subtasks_found << ts
      end
      
      # Also check in the task objects
      if ts['task']
        task = ts['task']
        task = [task] unless task.is_a?(Array)
        
        task.each do |t|
          if t['parent_task_id'] && t['parent_task_id'] != '0'
            puts "   🎯 Found parent_task_id in task object!"
            puts "     - Task name: #{ts['name']}"
            puts "     - Parent task ID: #{t['parent_task_id']}"
          end
        end
      end
    end
  end
end

if subtasks_found.empty?
  puts "   No subtasks found with parent_task_id field."
  puts
  puts "3. Checking task structure more carefully..."
  
  # Let's look at the raw structure of one task
  if all_result['rsp']['stat'] == 'ok' && all_result['rsp']['tasks']['list']
    list = all_result['rsp']['tasks']['list']
    list = [list] unless list.is_a?(Array)
    
    # Find any task and show its complete structure
    found_example = false
    list.each do |l|
      next unless l['taskseries'] && !found_example
      
      taskseries = l['taskseries']
      taskseries = [taskseries] unless taskseries.is_a?(Array)
      
      taskseries.each do |ts|
        if !found_example && ts['name'].downcase.include?('subtask')
          puts "   Example task that might be a subtask: '#{ts['name']}'"
          puts "   Full structure:"
          puts JSON.pretty_generate(ts)
          found_example = true
          break
        end
      end
    end
  end
else
  puts
  puts "Found #{subtasks_found.length} subtasks!"
end
