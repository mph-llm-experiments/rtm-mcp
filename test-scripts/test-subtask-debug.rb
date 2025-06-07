#!/usr/bin/env ruby

require 'json'
require 'net/http'
require 'uri'
require 'digest/md5'

# Test script to explore listing subtasks - debug version

class RTMSubtaskDebug
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
  
  def debug_all_tasks
    puts "=== Debugging all tasks to find parent-child relationships ==="
    
    # Get all tasks with v=2 to see parent_task_id field
    params = {
      v: '2',
      list_id: '51175519'
      # No filter - get everything
    }
    
    result = call_method('rtm.tasks.getList', params)
    
    if result.dig('rsp', 'stat') == 'ok'
      lists = result.dig('rsp', 'tasks', 'list')
      lists = [lists] unless lists.is_a?(Array)
      
      tasks_with_parents = []
      all_tasks = []
      
      lists.each do |list|
        next unless list['taskseries']
        
        taskseries = list['taskseries']
        taskseries = [taskseries] unless taskseries.is_a?(Array)
        
        taskseries.each do |ts|
          task = ts['task']
          task = [task] unless task.is_a?(Array)
          
          task.each do |t|
            task_info = {
              name: ts['name'],
              series_id: ts['id'],
              task_id: t['id'],
              completed: !t['completed'].to_s.empty?,
              parent_task_id: t['parent_task_id']
            }
            
            all_tasks << task_info
            
            # Track tasks that have parents
            if t['parent_task_id'] && !t['parent_task_id'].empty?
              tasks_with_parents << task_info
            end
          end
        end
      end
      
      puts "\nTotal tasks found: #{all_tasks.length}"
      puts "Tasks with parent_task_id: #{tasks_with_parents.length}"
      
      if tasks_with_parents.any?
        puts "\nTasks with parents:"
        tasks_with_parents.each do |task|
          puts "\nSubtask: #{task[:name]}"
          puts "  Series ID: #{task[:series_id]}"
          puts "  Task ID: #{task[:task_id]}"
          puts "  Parent Task ID: #{task[:parent_task_id]}"
          puts "  Completed: #{task[:completed]}"
          
          # Find the parent task
          parent = all_tasks.find { |t| t[:task_id] == task[:parent_task_id] }
          if parent
            puts "  Parent: #{parent[:name]} (#{parent[:completed] ? 'completed' : 'incomplete'})"
          else
            puts "  Parent: NOT FOUND in current list"
          end
        end
      else
        puts "\nNo tasks with parent_task_id found!"
        puts "This might mean:"
        puts "1. No subtasks exist in this list"
        puts "2. parent_task_id field is not being returned"
        puts "3. We need different API parameters"
      end
      
      # Also show tasks that might be parents
      puts "\n\nTasks marked with hasSubtasks filter:"
      params2 = {
        list_id: '51175519',
        filter: 'hasSubtasks:true'
      }
      
      result2 = call_method('rtm.tasks.getList', params2)
      if result2.dig('rsp', 'stat') == 'ok'
        lists2 = result2.dig('rsp', 'tasks', 'list')
        if lists2
          lists2 = [lists2] unless lists2.is_a?(Array)
          lists2.each do |list|
            next unless list['taskseries']
            taskseries = list['taskseries']
            taskseries = [taskseries] unless taskseries.is_a?(Array)
            
            taskseries.each do |ts|
              puts "- #{ts['name']} (series: #{ts['id']})"
            end
          end
        end
      end
      
    else
      puts "Error: #{result.dig('rsp', 'err', 'msg')}"
    end
  end
end

# Load credentials
api_key = File.read('.rtm_api_key').strip
shared_secret = File.read('.rtm_shared_secret').strip

debug = RTMSubtaskDebug.new(api_key, shared_secret)
debug.debug_all_tasks
