#!/usr/bin/env ruby

require 'net/http'
require 'uri'
require 'digest/md5'
require 'cgi'

# Read credentials
api_key = File.read('.rtm_api_key').strip
shared_secret = File.read('.rtm_shared_secret').strip
auth_token = File.read('.rtm_auth_token').strip

def sign_params(params, shared_secret)
  sorted_params = params.sort_by { |k, v| k.to_s }
  param_string = sorted_params.map { |k, v| "#{k}#{v}" }.join
  sig_string = shared_secret + param_string
  Digest::MD5.hexdigest(sig_string)
end

def make_rtm_request(params, api_key, shared_secret)
  base_params = {
    api_key: api_key,
    format: 'json'
  }
  
  all_params = base_params.merge(params)
  all_params[:api_sig] = sign_params(all_params, shared_secret)
  
  query_string = all_params.map { |k, v| "#{k}=#{CGI.escape(v.to_s)}" }.join('&')
  
  uri = URI("https://api.rememberthemilk.com/services/rest/?#{query_string}")
  
  puts "Making request to: #{uri}"
  
  response = Net::HTTP.get_response(uri)
  
  if response.code == '200'
    puts "Response body: #{response.body}"
    JSON.parse(response.body)
  else
    puts "HTTP Error: #{response.code} - #{response.message}"
    puts "Response body: #{response.body}"
    nil
  end
end

# Test task renaming with a test task
# First, let's get a timeline
puts "=== Getting timeline ==="
require 'json'

timeline_response = make_rtm_request({
  method: 'rtm.timelines.create',
  auth_token: auth_token
}, api_key, shared_secret)

if timeline_response && timeline_response['rsp']['stat'] == 'ok'
  timeline = timeline_response['rsp']['timeline']
  puts "Timeline: #{timeline}"
  
  # Create a test task first
  puts "\n=== Creating test task ==="
  sleep 1  # Rate limiting
  
  create_response = make_rtm_request({
    method: 'rtm.tasks.add',
    auth_token: auth_token,
    timeline: timeline,
    list_id: '51175710',  # Test Task Project list
    name: 'Test Rename Task - Original Name',
    parse: '1'
  }, api_key, shared_secret)
  
  if create_response && create_response['rsp']['stat'] == 'ok'
    # RTM returns the task data in the 'list' field when creating tasks
    list_data = create_response['rsp']['list']
    taskseries = list_data['taskseries'].first
    task = taskseries['task'].first
    
    list_id = list_data['id']
    taskseries_id = taskseries['id']
    task_id = task['id']
    
    puts "Created task:"
    puts "  List ID: #{list_id}"
    puts "  TaskSeries ID: #{taskseries_id}"
    puts "  Task ID: #{task_id}"
    puts "  Original name: #{taskseries['name']}"
    
    # Now try to rename it
    puts "\n=== Testing task rename ==="
    sleep 1  # Rate limiting
    
    rename_response = make_rtm_request({
      method: 'rtm.tasks.setName',
      auth_token: auth_token,
      timeline: timeline,
      list_id: list_id,
      taskseries_id: taskseries_id,
      task_id: task_id,
      name: 'Test Rename Task - NEW NAME!'
    }, api_key, shared_secret)
    
    if rename_response
      puts "Rename response: #{rename_response}"
      
      if rename_response['rsp']['stat'] == 'ok'
        puts "✅ Task renamed successfully!"
        
        # Verify the rename by listing the task
        puts "\n=== Verifying rename ==="
        sleep 1  # Rate limiting
        
        list_response = make_rtm_request({
          method: 'rtm.tasks.getList',
          auth_token: auth_token,
          list_id: list_id,
          filter: "id:#{taskseries_id}"
        }, api_key, shared_secret)
        
        if list_response && list_response['rsp']['stat'] == 'ok'
          puts "Verification response: #{list_response}"
          
          if list_response['rsp']['tasks'] && list_response['rsp']['tasks']['list']
            tasks_list = list_response['rsp']['tasks']['list']
            if tasks_list.is_a?(Array)
              tasks_list = tasks_list.first
            end
            
            if tasks_list['taskseries']
              taskseries = tasks_list['taskseries']
              if taskseries.is_a?(Array)
                taskseries = taskseries.first
              end
              
              puts "✅ Verified new name: #{taskseries['name']}"
            end
          end
        else
          puts "❌ Failed to verify rename: #{list_response}"
        end
        
        # Clean up - delete the test task
        puts "\n=== Cleaning up test task ==="
        sleep 1  # Rate limiting
        
        delete_response = make_rtm_request({
          method: 'rtm.tasks.delete',
          auth_token: auth_token,
          timeline: timeline,
          list_id: list_id,
          taskseries_id: taskseries_id,
          task_id: task_id
        }, api_key, shared_secret)
        
        if delete_response && delete_response['rsp']['stat'] == 'ok'
          puts "✅ Test task cleaned up"
        else
          puts "❌ Failed to clean up test task: #{delete_response}"
        end
        
      else
        puts "❌ Failed to rename task: #{rename_response['rsp']['err']['msg']}"
      end
    else
      puts "❌ Failed to make rename request"
    end
    
  else
    puts "❌ Failed to create test task: #{create_response}"
  end
  
else
  puts "❌ Failed to get timeline: #{timeline_response}"
end
