#!/usr/bin/env ruby

require 'net/http'
require 'uri'
require 'json'
require 'digest/md5'

# Load credentials from files
api_key = File.read('.rtm_api_key').strip
shared_secret = File.read('.rtm_shared_secret').strip
auth_token = File.read('.rtm_auth_token').strip

# RTM API base URL
BASE_URL = 'https://api.rememberthemilk.com/services/rest/'

def sign_params(params, shared_secret)
  sorted_params = params.sort.map { |k, v| "#{k}#{v}" }.join
  Digest::MD5.hexdigest(shared_secret + sorted_params)
end

def call_rtm_api(method, params, api_key, shared_secret, auth_token = nil)
  params = params.merge(
    'api_key' => api_key,
    'method' => method,
    'format' => 'json'
  )
  params['auth_token'] = auth_token if auth_token
  params['api_sig'] = sign_params(params, shared_secret)
  
  uri = URI(BASE_URL)
  uri.query = URI.encode_www_form(params)
  
  response = Net::HTTP.get_response(uri)
  JSON.parse(response.body)
end

# Get task details for the subtask support task
# We'll get all incomplete tasks in RTM MCP Development
result = call_rtm_api('rtm.tasks.getList', {
  'list_id' => '51175519',
  'filter' => 'status:incomplete'
}, api_key, shared_secret, auth_token)

if result['rsp']['stat'] == 'fail'
  puts "Error: #{result['rsp']['err']['msg']}"
  exit 1
end

# Find the subtask support task
lists = result['rsp']['tasks']['list']
if lists.nil?
  puts "No tasks found or error in response"
  puts "Full response: #{JSON.pretty_generate(result)}"
  exit 1
end

lists = [lists] unless lists.is_a?(Array)

lists.each do |list|
  next unless list['taskseries']
  
  taskseries = list['taskseries']
  taskseries = [taskseries] unless taskseries.is_a?(Array)
  
  taskseries.each do |ts|
    if ts['name'].include?('subtask support')
      puts "Found subtask support task!"
      puts "=" * 50
      puts "Name: #{ts['name']}"
      puts "Task Series ID: #{ts['id']}"
      
      task = ts['task']
      task = [task] unless task.is_a?(Array)
      puts "Task ID: #{task.first['id']}"
      
      # Check for notes
      if ts['notes'] && ts['notes']['note']
        puts "\nNotes:"
        notes = ts['notes']['note']
        notes = [notes] unless notes.is_a?(Array)
        
        notes.each_with_index do |note, i|
          puts "\nNote #{i + 1}:"
          puts "ID: #{note['id']}"
          puts "Title: #{note['title']}" if note['title'] && !note['title'].empty?
          puts "Content: #{note['$t']}"
          puts "Created: #{note['created']}"
          puts "Modified: #{note['modified']}"
        end
      else
        puts "\nNo notes found on this task."
      end
      
      # Show other task properties
      puts "\nOther properties:"
      puts "Priority: #{ts['priority'] || 'None'}"
      puts "Tags: #{ts['tags'].inspect}" if ts['tags']
      puts "Due: #{task.first['due'] || 'No due date'}"
      puts "URL: #{ts['url']}" if ts['url'] && !ts['url'].empty?
      puts "Location: #{ts['location']}" if ts['location'] && !ts['location'].empty?
      
      puts "\nFull task data (for debugging):"
      puts JSON.pretty_generate(ts)
    end
  end
end
