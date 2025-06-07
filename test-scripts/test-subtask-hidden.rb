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

puts "=== Looking for Hidden Subtasks ==="
puts

# Get ALL tasks and check for parent indicators
puts "1. Getting ALL tasks to find potential subtasks..."
result = rtm_request('rtm.tasks.getList', {
  'list_id' => '51175519'  # Include completed tasks too
})

all_tasks = []

if result['rsp']['stat'] == 'ok' && result['rsp']['tasks']['list']
  list = result['rsp']['tasks']['list']
  list = [list] unless list.is_a?(Array)
  
  list.each do |l|
    next unless l['taskseries']
    
    taskseries = l['taskseries']
    taskseries = [taskseries] unless taskseries.is_a?(Array)
    
    taskseries.each do |ts|
      task_info = {
        name: ts['name'],
        taskseries_id: ts['id'],
        created: ts['created'],
        list_id: l['id']
      }
      
      # Check for any parent-related fields we might have missed
      ts.each do |key, value|
        if key.include?('parent') || key.include?('child') || key.include?('subtask')
          task_info[key] = value
          puts "   Found #{key} field in task '#{ts['name']}': #{value}"
        end
      end
      
      # Check task object too
      if ts['task']
        task = ts['task']
        task = [task] unless task.is_a?(Array)
        
        task.each do |t|
          t.each do |key, value|
            if key.include?('parent') || key.include?('child') || key.include?('subtask')
              task_info["task_#{key}"] = value
              puts "   Found #{key} in task object for '#{ts['name']}': #{value}"
            end
          end
        end
      end
      
      all_tasks << task_info
    end
  end
  
  puts "   Total tasks found: #{all_tasks.length}"
end

puts

# Based on the notes, user mentioned creating subtasks like:
# "Research RTM subtask API" and "Implement subtask tools"
puts "2. Looking for tasks that might be the subtasks mentioned in notes..."
puts "   (Research RTM subtask API, Implement subtask tools)"

potential_subtasks = all_tasks.select do |t|
  t[:name].downcase.include?('research') || 
  t[:name].downcase.include?('implement') ||
  t[:name].downcase.include?('subtask')
end

if potential_subtasks.any?
  puts "   Found potential subtasks:"
  potential_subtasks.each do |t|
    puts "   - #{t[:name]} (created: #{t[:created]})"
  end
else
  puts "   No obvious subtask candidates found"
end

puts

# Try a different approach - get method info
puts "3. Getting detailed method info for setParentTask..."
sleep 1

method_info = rtm_request('rtm.reflection.getMethodInfo', {
  'method_name' => 'rtm.tasks.setParentTask'
})

if method_info['rsp']['stat'] == 'ok'
  puts "   Method info retrieved:"
  puts JSON.pretty_generate(method_info['rsp'])
else
  puts "   Error: #{method_info['rsp']['err']['msg'] if method_info['rsp']['err']}"
end

puts

# Summary
puts "4. Current findings:"
puts "   - hasSubtasks:true filter works (finds parent tasks)"
puts "   - setParentTask exists but requires newer API version"
puts "   - Subtasks don't appear in standard getList responses"
puts "   - No parent/child fields visible in task data"
puts
puts "   Hypothesis: Subtasks might be:"
puts "   a) Only accessible via newer API version (v2?)"
puts "   b) Hidden from standard API calls"
puts "   c) Available through undocumented parameters"
puts
puts "   Recommendation: Try using RTM web interface to see how"
puts "   subtasks are created/displayed there, then reverse engineer"
