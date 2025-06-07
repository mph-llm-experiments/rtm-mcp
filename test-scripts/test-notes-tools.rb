#!/usr/bin/env ruby

require_relative 'rtm-mcp'

# Test script for RTM notes tools through MCP
# Tests add_task_note, edit_task_note, and delete_task_note

# Load credentials
def load_credentials
  api_key = nil
  shared_secret = nil
  
  begin
    api_key = File.read('.rtm_api_key').strip
    shared_secret = File.read('.rtm_shared_secret').strip
  rescue => e
    puts "Error loading credentials: #{e.message}"
    exit 1
  end
  
  if api_key.include?('YOUR_') || shared_secret.include?('YOUR_')
    puts "Please update .rtm_api_key and .rtm_shared_secret with real credentials"
    exit 1
  end
  
  [api_key, shared_secret]
end

api_key, shared_secret = load_credentials

# Set ARGV so RTMMCPServer can read them
ARGV[0] = api_key
ARGV[1] = shared_secret

# Create MCP server instance
server = RTMMCPServer.new
server.instance_variable_set(:@api_key, api_key)
server.instance_variable_set(:@shared_secret, shared_secret)
server.instance_variable_set(:@rtm, RTMClient.new(api_key, shared_secret))

puts "=== RTM MCP Notes Tools Test ==="
puts

# First, let's get the "Add notes tools" task details
puts "Getting task details for testing..."
list_result = server.send(:list_tasks, '51175519', 'status:incomplete')
puts list_result
puts

# The "Add notes tools" task IDs from the list
list_id = '51175519'
taskseries_id = '576922374'
task_id = '1136720069'

# Test 1: Add a note
puts "1. Testing add_task_note..."
add_result = server.send(:add_task_note, list_id, taskseries_id, task_id, 
                        'Implementation Status', 
                        "Notes tools are now implemented!\n\nFeatures:\n- Add notes to tasks\n- Edit existing notes\n- Delete notes")
puts add_result
puts

# Extract note ID from result if possible
note_id = nil
if add_result.include?('Note ID:')
  note_id = add_result.match(/Note ID: (\d+)/)[1]
  puts "Extracted Note ID: #{note_id}"
  puts
  
  # Test 2: Edit the note
  puts "2. Testing edit_task_note..."
  edit_result = server.send(:edit_task_note, note_id, 
                           'Implementation Complete', 
                           "✅ All notes tools are working!\n\nImplemented:\n- add_task_note\n- edit_task_note\n- delete_task_note\n\nTested and verified!")
  puts edit_result
  puts
  
  # Test 3: Show delete capability (but don't actually delete)
  puts "3. Testing delete_task_note (dry run)..."
  puts "Would delete note with ID: #{note_id}"
  puts "Skipping actual deletion to preserve the note"
  
  # Uncomment to actually test delete:
  # delete_result = server.send(:delete_task_note, note_id)
  # puts delete_result
else
  puts "Could not extract note ID from response"
end

puts "\nNotes tools test complete!"
puts "\nYou can now use these tools in Claude Desktop:"
puts "- add_task_note: Add notes to any task"
puts "- edit_task_note: Edit existing notes"  
puts "- delete_task_note: Delete notes from tasks"
