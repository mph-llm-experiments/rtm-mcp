#!/usr/bin/env ruby
require 'net/http'
require 'uri'
require 'json'
require 'digest/md5'

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

# Find the due date tools task
result = rtm_request('rtm.tasks.getList', {
  'filter' => 'name:"Add due date tools"',
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
      if ts['name'].include?('due date tools')
        task = ts['task']
        task = [task] unless task.is_a?(Array)
        
        puts "Found: #{ts['name']}"
        puts "IDs: list=#{l['id']}, series=#{ts['id']}, task=#{task[0]['id']}"
        puts "Priority: #{ts['priority'] || 'none'}"
        
        # Show existing notes
        if ts['notes'] && ts['notes'].is_a?(Hash) && ts['notes']['note']
          notes = ts['notes']['note']
          notes = [notes] unless notes.is_a?(Array)
          puts "\nExisting notes:"
          notes.each do |note|
            puts "Note ID: #{note['id']}"
            puts "Content: #{note['$t'][0..200]}..."
          end
        end
      end
    end
  end
end
