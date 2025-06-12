#!/usr/bin/env ruby

# Test script for RTM MCP permalinks functionality
# This tests the permalink generation logic before implementation

require_relative 'rtm-mcp'
require 'json'

def test_permalink_generation
  # Test permalink generation with sample task IDs
  test_task_ids = [
    "1136773537",  # From issue #4 description
    "1234567890",  # Sample ID
    ""             # Edge case: empty ID
  ]
  
  puts "🔗 Testing RTM Permalink Generation"
  puts "=" * 50
  
  test_task_ids.each do |task_id|
    if task_id.empty?
      puts "❌ Task ID: (empty) -> No permalink generated"
    else
      permalink = generate_rtm_permalink(task_id)
      puts "✅ Task ID: #{task_id} -> #{permalink}"
    end
  end
  
  puts "\n📋 Testing with Mock Task Data"
  puts "=" * 50
  
  # Mock task data structure like RTM API returns
  mock_task_data = {
    'rsp' => {
      'stat' => 'ok',
      'tasks' => {
        'list' => {
          'id' => '51175519',
          'name' => 'RTM MCP Development',
          'taskseries' => [
            {
              'id' => '576963123',
              'name' => 'Add permalinks to RTM MCP list',
              'priority' => '2',
              'task' => {
                'id' => '1136773537',
                'completed' => '',
                'due' => ''
              }
            }
          ]
        }
      }
    }
  }
  
  # Test formatting with permalink
  test_format_with_permalink(mock_task_data)
end

def generate_rtm_permalink(task_id)
  return nil if task_id.nil? || task_id.empty?
  "https://www.rememberthemilk.com/app/#tasks/#{task_id}"
end

def test_format_with_permalink(result)
  lists = result.dig('rsp', 'tasks', 'list')
  return "📋 No tasks found." unless lists
  
  lists = [lists] unless lists.is_a?(Array)
  
  lists.each do |list|
    next unless list['taskseries']
    
    list_name = list['name'] || "List #{list['id']}"
    puts "\n📁 List: #{list_name}"
    
    taskseries = list['taskseries']
    taskseries = [taskseries] unless taskseries.is_a?(Array)
    
    taskseries.each do |ts|
      task = ts['task']
      task = [task] unless task.is_a?(Array)
      
      task.each do |t|
        next if t['completed'] && !t['completed'].empty?
        
        # Current task formatting
        status = "🔲"
        priority = case ts['priority']
                 when '1' then " 🔴"
                 when '2' then " 🟡"  
                 when '3' then " 🔵"
                 else ""
                 end
        
        # Generate permalink
        permalink = generate_rtm_permalink(t['id'])
        permalink_text = permalink ? " 🔗 #{permalink}" : ""
        
        puts "  #{status} #{ts['name']}#{priority}#{permalink_text}"
        puts "     Task ID: #{t['id']}"
      end
    end
  end
end

# Only run test if this script is executed directly
if __FILE__ == $0
  puts "RTM MCP Permalinks Test Script"
  puts "Testing permalink functionality before implementation\n"
  
  test_permalink_generation
end
