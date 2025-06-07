#!/usr/bin/env ruby

require 'json'
require 'net/http'
require 'uri'
require 'digest/md5'

# Test script to explore listing subtasks of a specific parent

class RTMSubtaskExplorer
  def initialize(api_key, shared_secret)
    @api_key = api_key
    @shared_secret = shared_secret
    @auth_token = File.read('.rtm_auth_token').strip if File.exist?('.rtm_auth_token')
  end
  
  def call_method(method_name, params = {})
    params = params.merge(
      method: method_name,
      api_key: @api_key,
      auth_token: @auth_token,
      format: 'json'
    )
    
    # Generate signature
    sig_string = @shared_secret + params.sort.map { |k, v| "#{k}#{v}" }.join
    params[:api_sig] = Digest::MD5.hexdigest(sig_string)
    
    # Make request
    uri = URI('https://api.rememberthemilk.com/services/rest/')
    response = Net::HTTP.post_form(uri, params)
    
    JSON.parse(response.body)
  end
  
  def explore_subtasks(parent_task_id)
    puts "=== Exploring subtasks of parent task #{parent_task_id} ==="
    
    # Get all tasks with v=2 to see parent_task_id field
    params = {
      v: '2',
      list_id: '51175519',
      filter: 'status:incomplete'
    }
    
    result = call_method('rtm.tasks.getList', params)
    
    if result.dig('rsp', 'stat') == 'ok'
      lists = result.dig('rsp', 'tasks', 'list')
      lists = [lists] unless lists.is_a?(Array)
      
      subtasks = []
      parent_task = nil
      
      lists.each do |list|
        next unless list['taskseries']
        
        taskseries = list['taskseries']
        taskseries = [taskseries] unless taskseries.is_a?(Array)
        
        taskseries.each do |ts|
          task = ts['task']
          task = [task] unless task.is_a?(Array)
          
          task.each do |t|
            # Check if this is the parent task
            if ts['id'] == parent_task_id
              parent_task = { name: ts['name'], task: t, series: ts }
              puts "\nFound parent task: #{ts['name']}"
              puts "Task ID: #{t['id']}"
            end
            
            # Check if this task has the parent_task_id we're looking for
            if t['parent_task_id'] && t['parent_task_id'] == parent_task_id
              subtasks << { name: ts['name'], task: t, series: ts }
            end
          end
        end
      end
      
      if subtasks.any?
        puts "\nFound #{subtasks.length} subtasks:"
        subtasks.each do |st|
          puts "  - #{st[:name]} (task_id: #{st[:task][:id]})"
          if st[:task]['parent_task_id']
            puts "    parent_task_id: #{st[:task]['parent_task_id']}"
          end
        end
      else
        puts "\nNo subtasks found for parent task #{parent_task_id}"
      end
      
      # Let's also check if we can filter by parent_task_id
      puts "\n=== Testing filter by parent_task_id ==="
      puts "Note: RTM may not support filtering by parent_task_id directly"
      
    else
      puts "Error: #{result.dig('rsp', 'err', 'msg')}"
    end
  end
end

# Load credentials
api_key = File.read('.rtm_api_key').strip
shared_secret = File.read('.rtm_shared_secret').strip

explorer = RTMSubtaskExplorer.new(api_key, shared_secret)

# Test with "Add subtask support" task which we know has subtasks
# Task series ID: 576923558
puts "Testing with 'Add subtask support' task..."
explorer.explore_subtasks('576923558')

sleep 1  # Rate limiting

# Also test with a task ID instead of series ID
puts "\n\nTesting with task ID instead of series ID..."
# Add subtask support task ID: 1136721772
explorer.explore_subtasks('1136721772')
