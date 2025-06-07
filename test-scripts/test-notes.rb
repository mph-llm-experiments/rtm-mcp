#!/usr/bin/env ruby

require 'net/http'
require 'uri'
require 'json'
require 'digest/md5'

# Test script for RTM notes functionality using stored credentials
# Tests adding, editing, and deleting notes on tasks

# Load credentials with fallback hierarchy:
# 1. Files (.rtm_api_key, .rtm_shared_secret)
# 2. Command line arguments
# 3. Environment variables
def load_credentials
  api_key = nil
  shared_secret = nil
  
  # Try loading from files first
  begin
    api_key = File.read('.rtm_api_key').strip
    puts "Loaded API key from .rtm_api_key"
  rescue => e
    # Fall back to command line or env
    api_key = ARGV[0] || ENV['RTM_API_KEY']
  end
  
  begin
    shared_secret = File.read('.rtm_shared_secret').strip
    puts "Loaded shared secret from .rtm_shared_secret"
  rescue => e
    # Fall back to command line or env
    shared_secret = ARGV[1] || ENV['RTM_SHARED_SECRET']
  end
  
  if !api_key || !shared_secret || api_key.include?('YOUR_') || shared_secret.include?('YOUR_')
    puts "Error: Missing or invalid credentials"
    puts ""
    puts "Please set up your RTM credentials in one of these ways:"
    puts "1. Add your credentials to .rtm_api_key and .rtm_shared_secret files"
    puts "2. Run with: #{$0} API_KEY SHARED_SECRET"
    puts "3. Set RTM_API_KEY and RTM_SHARED_SECRET environment variables"
    exit 1
  end
  
  [api_key, shared_secret]
end

# Load credentials
api_key, shared_secret = load_credentials

# Load auth token from file
begin
  auth_token = File.read('.rtm_auth_token').strip
  puts "Loaded auth token from .rtm_auth_token"
rescue => e
  puts "Error loading auth token: #{e.message}"
  puts "Make sure you have authenticated and have a .rtm_auth_token file"
  exit 1
end

# RTM API helper methods
def rtm_sign(params, shared_secret)
  sorted_params = params.sort.map { |k, v| "#{k}#{v}" }.join
  Digest::MD5.hexdigest("#{shared_secret}#{sorted_params}")
end

def rtm_request(method, params, api_key, shared_secret, auth_token)
  params = params.merge(
    'api_key' => api_key,
    'auth_token' => auth_token,
    'method' => method,
    'format' => 'json'
  )
  params['api_sig'] = rtm_sign(params, shared_secret)
  
  uri = URI('https://api.rememberthemilk.com/services/rest/')
  uri.query = URI.encode_www_form(params)
  
  puts "Making request: #{method}"
  sleep 1  # Rate limiting
  
  response = Net::HTTP.get_response(uri)
  JSON.parse(response.body)
end

puts "=== RTM Notes API Test ==="
puts

# Get timeline for write operations
timeline_resp = rtm_request('rtm.timelines.create', {}, api_key, shared_secret, auth_token)
if timeline_resp['rsp']['stat'] != 'ok'
  puts "Error getting timeline: #{timeline_resp['rsp']['err']['msg']}"
  exit 1
end
timeline = timeline_resp['rsp']['timeline']
puts "Got timeline: #{timeline}"
puts

# Create a test task
puts "1. Creating test task..."
create_resp = rtm_request('rtm.tasks.add', {
  'timeline' => timeline,
  'list_id' => '51175519',  # RTM MCP Development list
  'name' => 'Test task for notes API',
  'parse' => '1'
}, api_key, shared_secret, auth_token)

if create_resp['rsp']['stat'] == 'ok'
  list = create_resp['rsp']['list']
  
  # Handle taskseries as array (RTM always returns it as array)
  taskseries_array = list['taskseries']
  taskseries_array = [taskseries_array] unless taskseries_array.is_a?(Array)
  taskseries = taskseries_array.first
  
  # Handle both taskseries and task as arrays
  task_array = taskseries['task']
  task_array = [task_array] unless task_array.is_a?(Array)
  task = task_array.first
  
  list_id = list['id']
  taskseries_id = taskseries['id']
  task_id = task['id']
  
  puts "Created task: #{taskseries['name']}"
  puts "  List ID: #{list_id}"
  puts "  Taskseries ID: #{taskseries_id}"
  puts "  Task ID: #{task_id}"
  puts
  
  # Test adding a note
  puts "2. Adding a note to the task..."
  note_resp = rtm_request('rtm.tasks.notes.add', {
    'timeline' => timeline,
    'list_id' => list_id,
    'taskseries_id' => taskseries_id,
    'task_id' => task_id,
    'note_title' => 'Implementation Details',
    'note_text' => "This task requires:\n- API endpoint integration\n- Error handling\n- Response parsing"
  }, api_key, shared_secret, auth_token)
  
  puts "Note add response structure:"
  puts JSON.pretty_generate(note_resp['rsp']) if note_resp['rsp']['stat'] == 'ok'
  
  if note_resp['rsp']['stat'] == 'ok'
    note = note_resp['rsp']['note']
    puts "Added note successfully!"
    puts "  Note ID: #{note['id']}"
    puts "  Title: #{note['title']}"
    puts "  Text: #{note['$t']}"
    puts "  Created: #{note['created']}"
    puts "  Modified: #{note['modified']}"
    puts
    
    # Test editing a note
    puts "3. Editing the note..."
    edit_resp = rtm_request('rtm.tasks.notes.edit', {
      'timeline' => timeline,
      'note_id' => note['id'],
      'note_title' => 'Updated Implementation Details',
      'note_text' => "Updated requirements:\n- API endpoint integration ✓\n- Error handling ✓\n- Response parsing ✓\n- Added: Rate limiting support"
    }, api_key, shared_secret, auth_token)
    
    if edit_resp['rsp']['stat'] == 'ok'
      edited_note = edit_resp['rsp']['note']
      puts "Note edited successfully!"
      puts "  Title: #{edited_note['title']}"
      puts "  Text: #{edited_note['$t']}"
      puts "  Modified: #{edited_note['modified']}"
      puts
    else
      puts "Error editing note: #{edit_resp['rsp']['err']['msg']}"
    end
    
    # List task to see complete note structure
    puts "4. Fetching task to see notes structure..."
    list_resp = rtm_request('rtm.tasks.getList', {
      'list_id' => list_id,
      'filter' => "status:incomplete"
    }, api_key, shared_secret, auth_token)
    
    if list_resp['rsp']['stat'] == 'ok'
      lists = list_resp['rsp']['tasks']['list']
      lists = [lists] unless lists.is_a?(Array)
      
      lists.each do |lst|
        next unless lst['taskseries']
        taskseries_array = lst['taskseries']
        taskseries_array = [taskseries_array] unless taskseries_array.is_a?(Array)
        
        taskseries_array.each do |ts|
          if ts['id'] == taskseries_id
            puts "Found task: #{ts['name']}"
            
            if ts['notes']
              puts "  Notes structure: #{ts['notes'].class}"
              notes_data = ts['notes']
              
              # Handle different note formats
              if notes_data.is_a?(Hash) && notes_data['note']
                note_array = notes_data['note']
                note_array = [note_array] unless note_array.is_a?(Array)
                
                puts "  Total notes: #{note_array.length}"
                note_array.each_with_index do |n, i|
                  puts "  Note #{i + 1}:"
                  puts "    ID: #{n['id']}"
                  puts "    Title: #{n['title']}"
                  puts "    Text: #{n['$t']}"
                  puts "    Created: #{n['created']}"
                  puts "    Modified: #{n['modified']}"
                end
              elsif notes_data.is_a?(Array)
                puts "  Notes returned as array (#{notes_data.length} notes)"
              end
            else
              puts "  No notes found"
            end
            break
          end
        end
      end
    end
    puts
    
    # Clean up - complete the test task
    puts "5. Completing test task..."
    complete_resp = rtm_request('rtm.tasks.complete', {
      'timeline' => timeline,
      'list_id' => list_id,
      'taskseries_id' => taskseries_id,
      'task_id' => task_id
    }, api_key, shared_secret, auth_token)
    
    if complete_resp['rsp']['stat'] == 'ok'
      puts "Test task completed!"
    else
      puts "Error completing task: #{complete_resp['rsp']['err']['msg']}"
    end
    
  else
    puts "Error adding note: #{note_resp['rsp']['err']['msg']}"
  end
  
else
  puts "Error creating task: #{create_resp['rsp']['err']['msg']}"
end

puts "\nTest complete!"
