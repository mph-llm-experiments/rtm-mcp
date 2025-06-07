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

puts "=== Testing Subtask Indicators ==="
puts

# First get tasks with subtasks
puts "1. Finding tasks with subtasks..."
parent_result = rtm_request('rtm.tasks.getList', {
  'filter' => 'hasSubtasks:true AND status:incomplete',
  'list_id' => '51175519'
})

parent_ids = []
if parent_result['rsp']['stat'] == 'ok' && parent_result['rsp']['tasks']['list']
  list = parent_result['rsp']['tasks']['list']
  list = [list] unless list.is_a?(Array)
  
  list.each do |l|
    next unless l['taskseries']
    taskseries = l['taskseries']
    taskseries = [taskseries] unless taskseries.is_a?(Array)
    
    taskseries.each do |ts|
      parent_ids << ts['id']
      puts "   📋 #{ts['name']} (has subtasks)"
    end
  end
end

puts

# Now get all tasks and mark which ones have subtasks
puts "2. All tasks with subtask indicators..."
sleep 1

all_result = rtm_request('rtm.tasks.getList', {
  'filter' => 'status:incomplete',
  'list_id' => '51175519'
})

if all_result['rsp']['stat'] == 'ok' && all_result['rsp']['tasks']['list']
  list = all_result['rsp']['tasks']['list']
  list = [list] unless list.is_a?(Array)
  
  list.each do |l|
    next unless l['taskseries']
    taskseries = l['taskseries']
    taskseries = [taskseries] unless taskseries.is_a?(Array)
    
    taskseries.each do |ts|
      # Check priority
      priority = ''
      if ts['task'] && ts['task'][0]
        case ts['task'][0]['priority']
        when '1' then priority = ' 🔴'
        when '2' then priority = ' 🟡'
        when '3' then priority = ' 🔵'
        end
      end
      
      # Check if has subtasks
      if parent_ids.include?(ts['id'])
        puts "   🔲 #{ts['name']}#{priority} [has subtasks]"
      else
        puts "   🔲 #{ts['name']}#{priority}"
      end
      
      # Show notes preview if any
      if ts['notes'] && ts['notes'].is_a?(Hash) && ts['notes']['note']
        notes = ts['notes']['note']
        notes = [notes] unless notes.is_a?(Array)
        
        first_note = notes.first
        if first_note && first_note['$t']
          preview = first_note['$t'].gsub(/\n/, ' ').strip[0..60]
          preview += '...' if first_note['$t'].length > 60
          puts "      📝 #{preview}"
        end
      end
    end
  end
end

puts
puts "Note: Subtasks require RTM Pro account. Currently we can detect"
puts "      parent tasks but cannot access the actual subtasks via API."
