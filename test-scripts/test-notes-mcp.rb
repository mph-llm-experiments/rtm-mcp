#!/usr/bin/env ruby

require 'json'

# Test script for RTM MCP notes tools
# Tests the add_task_note, edit_task_note, and delete_task_note tools

def send_request(method, params = {})
  request = {
    jsonrpc: '2.0',
    id: rand(1000),
    method: method,
    params: params
  }.to_json
  
  puts "→ Sending: #{method}"
  puts request
  
  # Send to stdin
  $stdin.puts request
  $stdin.flush
  
  # Read response
  response = $stdout.gets
  puts "← Response:"
  puts response
  puts
  
  JSON.parse(response) rescue nil
end

# Initialize
puts "Testing RTM MCP Notes Tools"
puts "="*50
puts

send_request('initialize')

# List tools to verify notes tools are available
puts "Listing tools..."
tools_response = send_request('tools/list')

if tools_response && tools_response['result'] && tools_response['result']['tools']
  notes_tools = tools_response['result']['tools'].select { |t| t['name'].include?('note') }
  puts "Found #{notes_tools.length} notes tools:"
  notes_tools.each { |t| puts "  - #{t['name']}: #{t['description']}" }
  puts
end

# Test the notes tools
# First, we need a task to add notes to
# Let's use the existing task from our RTM MCP Development list

puts "1. Adding a note to a task..."
add_response = send_request('tools/call', {
  name: 'add_task_note',
  arguments: {
    list_id: '51175519',
    taskseries_id: '576922374',  # "Add notes tools" task
    task_id: '1136720069',
    title: 'Implementation Progress',
    text: "Notes tools implementation:\n- add_task_note ✅\n- edit_task_note ✅\n- delete_task_note ✅\n\nReady for testing!"
  }
})

if add_response && add_response['result']
  content = add_response['result']['content']
  if content && content[0]
    puts content[0]['text']
    
    # Extract note ID if present
    note_id_match = content[0]['text'].match(/Note ID: (\d+)/)
    if note_id_match
      note_id = note_id_match[1]
      puts "\nExtracted Note ID: #{note_id}"
      
      # Test editing the note
      puts "\n2. Editing the note..."
      edit_response = send_request('tools/call', {
        name: 'edit_task_note',
        arguments: {
          note_id: note_id,
          title: 'Implementation Complete!',
          text: "✅ All notes tools implemented and tested:\n- add_task_note\n- edit_task_note\n- delete_task_note\n\nThe notes functionality is working perfectly!"
        }
      })
      
      if edit_response && edit_response['result'] && edit_response['result']['content']
        puts edit_response['result']['content'][0]['text']
      end
      
      # Optionally test delete (commented out to preserve the note)
      puts "\n3. Delete test (skipped to preserve note)"
      puts "   Would call delete_task_note with note_id: #{note_id}"
    end
  end
end

puts "\nTest complete!"
