#!/usr/bin/env ruby

require 'json'
require 'net/http'
require 'uri'
require 'digest/md5'

# Test script for auto-expand search functionality
# Tests what happens when searching with filters that return no results

class RTMTestClient
  def initialize(api_key, shared_secret)
    @api_key = api_key
    @shared_secret = shared_secret
    @auth_token = File.read('.rtm_auth_token').strip if File.exist?('.rtm_auth_token')
    @timeline = nil
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
  
  def test_filter_with_results
    puts "=== Testing filter that should return results ==="
    params = {
      list_id: '51175519',  # RTM MCP Development list
      filter: 'status:incomplete'
    }
    
    result = call_method('rtm.tasks.getList', params)
    
    if result.dig('rsp', 'stat') == 'ok'
      lists = result.dig('rsp', 'tasks', 'list')
      
      if lists
        # RTM returns list as array or single object
        lists = [lists] unless lists.is_a?(Array)
        
        task_count = 0
        lists.each do |list|
          if list['taskseries']
            taskseries = list['taskseries']
            taskseries = [taskseries] unless taskseries.is_a?(Array)
            task_count += taskseries.length
            
            # Show first few task names
            taskseries[0..2].each do |ts|
              puts "  - #{ts['name']}"
            end
          end
        end
        
        if task_count > 0
          puts "Found #{task_count} tasks with filter: #{params[:filter]}"
        else
          puts "No tasks found (empty result)"
        end
      else
        puts "No tasks found (no list in response)"
      end
    else
      puts "Error: #{result.dig('rsp', 'err', 'msg')}"
    end
    
    puts "\n"
  end
  
  def test_filter_no_results
    puts "=== Testing filter that should return NO results ==="
    params = {
      list_id: '51175519',  # RTM MCP Development list
      filter: 'tag:nonexistent-tag-xyz123'
    }
    
    result = call_method('rtm.tasks.getList', params)
    
    if result.dig('rsp', 'stat') == 'ok'
      lists = result.dig('rsp', 'tasks', 'list')
      
      if lists
        # RTM returns list as array or single object
        lists = [lists] unless lists.is_a?(Array)
        
        task_count = 0
        lists.each do |list|
          if list['taskseries']
            taskseries = list['taskseries']
            taskseries = [taskseries] unless taskseries.is_a?(Array)
            task_count += taskseries.length
          end
        end
        
        if task_count > 0
          puts "Found #{task_count} tasks with filter: #{params[:filter]}"
        else
          puts "No tasks found with filter: #{params[:filter]}"
          puts "Lists structure: #{lists.inspect}"
        end
      else
        puts "No tasks found (no list in response)"
        puts "Tasks structure: #{result.dig('rsp', 'tasks').inspect}"
      end
    else
      puts "Error: #{result.dig('rsp', 'err', 'msg')}"
    end
    
    puts "\n"
  end
  
  def test_auto_expand_logic
    puts "=== Testing auto-expand logic ==="
    
    # First, try with restrictive filter
    filter = 'tag:nonexistent-tag-xyz123 AND status:incomplete'
    params = {
      list_id: '51175519',
      filter: filter
    }
    
    puts "1. Searching with filter: #{filter}"
    result = call_method('rtm.tasks.getList', params)
    
    if result.dig('rsp', 'stat') == 'ok'
      lists = result.dig('rsp', 'tasks', 'list')
      has_results = false
      
      if lists
        lists = [lists] unless lists.is_a?(Array)
        lists.each do |list|
          if list['taskseries']
            has_results = true
            break
          end
        end
      end
      
      if !has_results
        puts "   No results found."
        
        # Auto-expand: remove the restrictive part
        puts "\n2. Auto-expanding search..."
        expanded_filter = 'status:incomplete'
        params[:filter] = expanded_filter
        
        puts "   Searching with expanded filter: #{expanded_filter}"
        sleep 1  # Rate limiting
        result2 = call_method('rtm.tasks.getList', params)
        
        if result2.dig('rsp', 'stat') == 'ok'
          lists2 = result2.dig('rsp', 'tasks', 'list')
          
          if lists2
            lists2 = [lists2] unless lists2.is_a?(Array)
            
            task_count = 0
            lists2.each do |list|
              if list['taskseries']
                taskseries = list['taskseries']
                taskseries = [taskseries] unless taskseries.is_a?(Array)
                task_count += taskseries.length
              end
            end
            
            if task_count > 0
              puts "   Found #{task_count} tasks with expanded search!"
              puts "\n   Note: No tasks matched '#{filter}', showing all incomplete tasks instead."
            end
          end
        end
      else
        puts "   Found results with original filter"
      end
    end
    
    puts "\n"
  end
end

# Load credentials
api_key = File.read('.rtm_api_key').strip
shared_secret = File.read('.rtm_shared_secret').strip

client = RTMTestClient.new(api_key, shared_secret)

# Run tests
client.test_filter_with_results
sleep 1  # Rate limiting
client.test_filter_no_results
sleep 1  # Rate limiting
client.test_auto_expand_logic
