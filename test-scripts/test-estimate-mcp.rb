#!/usr/bin/env ruby

require 'json'

class MCPTestClient
  def initialize
    @message_id = 1
  end

  def send_message(method, params = {})
    message = {
      jsonrpc: '2.0',
      id: @message_id,
      method: method,
      params: params
    }
    
    puts "📤 Sending: #{JSON.generate(message)}"
    puts JSON.generate(message)
    STDOUT.flush
    
    response = STDIN.gets
    parsed = JSON.parse(response) if response
    puts "📥 Received: #{parsed}"
    
    @message_id += 1
    parsed
  end

  def test_estimates
    puts "🧪 Testing RTM MCP Estimate Tools"
    puts "=" * 50
    
    # Initialize
    puts "\n1️⃣ Initializing..."
    init_response = send_message('initialize', {
      protocolVersion: '2024-11-05',
      capabilities: { tools: {} },
      clientInfo: { name: 'test-client', version: '1.0.0' }
    })
    
    # List tools to verify estimate tool is available
    puts "\n2️⃣ Listing tools..."
    tools_response = send_message('tools/list')
    
    estimate_tool = tools_response&.dig('result', 'tools')&.find { |t| t['name'] == 'set_task_estimate' }
    
    if estimate_tool
      puts "✅ Found set_task_estimate tool!"
      puts "   Description: #{estimate_tool['description']}"
    else
      puts "❌ set_task_estimate tool not found!"
      return
    end
    
    # Test with actual task
    puts "\n3️⃣ Testing estimate functionality..."
    
    # Get test tasks first
    list_response = send_message('tools/call', {
      name: 'list_tasks',
      arguments: { list_id: '51175710', show_ids: true }  # Test Task Project
    })
    
    puts "Task list response: #{list_response}"
    
    # If we have a task, test estimate setting
    if list_response&.dig('result', 'content', 0, 'text')&.include?('IDs:')
      task_text = list_response['result']['content'][0]['text']
      
      # Extract IDs from response
      if task_text =~ /IDs: list=(\d+), series=(\d+), task=(\d+)/
        list_id = $1
        series_id = $2
        task_id = $3
        
        puts "   Found task: list=#{list_id}, series=#{series_id}, task=#{task_id}"
        
        # Test setting estimate
        puts "\n4️⃣ Setting estimate to '2 hours'..."
        estimate_response = send_message('tools/call', {
          name: 'set_task_estimate',
          arguments: {
            list_id: list_id,
            taskseries_id: series_id,
            task_id: task_id,
            estimate: '2 hours'
          }
        })
        
        puts "Estimate response: #{estimate_response}"
        
        # List tasks again to see estimate display
        puts "\n5️⃣ Checking task display with estimate..."
        updated_list_response = send_message('tools/call', {
          name: 'list_tasks',
          arguments: { list_id: '51175710' }
        })
        
        puts "Updated task list: #{updated_list_response}"
        
        # Clear estimate
        puts "\n6️⃣ Clearing estimate..."
        clear_response = send_message('tools/call', {
          name: 'set_task_estimate',
          arguments: {
            list_id: list_id,
            taskseries_id: series_id,
            task_id: task_id,
            estimate: ''
          }
        })
        
        puts "Clear response: #{clear_response}"
        
      else
        puts "❌ Could not extract task IDs from response"
      end
    else
      puts "❌ No tasks found in test list"
    end
  end
end

client = MCPTestClient.new
client.test_estimates
