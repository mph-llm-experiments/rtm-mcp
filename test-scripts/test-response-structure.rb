#!/usr/bin/env ruby
require_relative 'rtm-mcp'

# Test Smart Add with direct inspection of the response structure
begin
  api_key = File.read('.rtm_api_key').strip
  shared_secret = File.read('.rtm_shared_secret').strip
  
  rtm_client = RTMClient.new(api_key, shared_secret)
  
  smart_add_text = "Debug structure ^tomorrow !1 #debug #structure"
  
  params = {
    name: smart_add_text,
    parse: 1,
    list_id: "51175519"
  }
  
  result = rtm_client.call_method('rtm.tasks.add', params)
  
  if result.dig('rsp', 'stat') == 'ok'
    list = result.dig('rsp', 'list')
    taskseries = list&.dig('taskseries')
    
    # Handle case where taskseries is an array
    if taskseries.is_a?(Array)
      task = taskseries.first
    else
      task = taskseries
    end
    
    task_obj = task['task']
    if task_obj.is_a?(Array)
      first_task = task_obj[0]
    else
      first_task = task_obj
    end
    
    puts "🔍 Response structure analysis:"
    puts "=" * 50
    puts "task (taskseries): #{task.keys}"
    puts "first_task (task): #{first_task.keys}"
    puts
    puts "task['name']: #{task['name']}"
    puts "task['tags']: #{task['tags']}"
    puts "task['priority']: #{task['priority']}"
    puts
    puts "first_task['due']: #{first_task['due']}"
    puts "first_task['priority']: #{first_task['priority']}"
    puts "first_task['has_due_time']: #{first_task['has_due_time']}"
    
    # Test our parsing logic
    puts "\n📋 Testing metadata detection logic:"
    
    metadata_applied = []
    
    # Due date check
    if first_task['due'] && !first_task['due'].empty?
      has_time = first_task['has_due_time'] == '1'
      time_info = has_time ? " (includes time)" : " (date only)"
      metadata_applied << "📅 Due: #{first_task['due']}#{time_info}"
      puts "✅ Due date detected: #{first_task['due']}"
    else
      puts "❌ Due date NOT detected"
    end
    
    # Priority check  
    if first_task['priority'] && !first_task['priority'].empty? && first_task['priority'] != 'N'
      priority_display = case first_task['priority']
      when '1' then '🔴 High'
      when '2' then '🟡 Medium'
      when '3' then '🔵 Low'
      else first_task['priority']
      end
      metadata_applied << "Priority: #{priority_display}"
      puts "✅ Priority detected: #{first_task['priority']}"
    else
      puts "❌ Priority NOT detected"
    end
    
    # Tags check
    if task['tags'] && task['tags']['tag']
      applied_tags = task['tags']['tag']
      applied_tags = [applied_tags] unless applied_tags.is_a?(Array)
      if applied_tags.any?
        metadata_applied << "🏷️ Tags: #{applied_tags.join(', ')}"
        puts "✅ Tags detected: #{applied_tags}"
      else
        puts "❌ Tags array empty"
      end
    else
      puts "❌ Tags NOT detected"
    end
    
    puts "\n🎯 Final metadata_applied array:"
    puts metadata_applied
    
  else
    puts "❌ API call failed"
  end
  
rescue => e
  puts "❌ Error: #{e.message}"
  puts e.backtrace.first(5)
end
