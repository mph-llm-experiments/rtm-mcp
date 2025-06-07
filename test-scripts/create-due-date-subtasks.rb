#!/usr/bin/env ruby
require_relative 'rtm-mcp'

# Read credentials from files
api_key = File.read('.rtm_api_key').strip
shared_secret = File.read('.rtm_shared_secret').strip

# Pass credentials as ARGV
ARGV[0] = api_key
ARGV[1] = shared_secret

# Create subtasks for due date tools implementation
server = RTMMCPServer.new

parent_info = {
  list_id: '51175519',
  taskseries_id: '576922378',
  task_id: '1136720073'
}

subtasks_to_create = [
  "Research RTM due date API - create test-due-dates.rb",
  "Implement set_due_date tool",
  "Implement clear_due_date tool", 
  "Add natural language date parsing",
  "Test due date tools with Claude Desktop",
  "Update documentation and continuity note"
]

puts "=== Creating Subtasks for Due Date Tools ==="
puts

subtasks_to_create.each_with_index do |subtask_name, index|
  puts "#{index + 1}. Creating: #{subtask_name}"
  
  request = {
    'jsonrpc' => '2.0',
    'id' => index + 1,
    'method' => 'tools/call',
    'params' => {
      'name' => 'create_subtask',
      'arguments' => {
        'name' => subtask_name,
        'parent_list_id' => parent_info[:list_id],
        'parent_taskseries_id' => parent_info[:taskseries_id],
        'parent_task_id' => parent_info[:task_id]
      }
    }
  }
  
  result = server.handle_request(request)
  if result[:content]
    text = result[:content][0][:text]
    puts "   #{text.split("\n").first}"
  else
    puts "   ❌ Failed: #{result.inspect}"
  end
  
  sleep 1  # Rate limiting
end

puts
puts "✅ Subtasks created! Use list_tasks to see the organized structure."
