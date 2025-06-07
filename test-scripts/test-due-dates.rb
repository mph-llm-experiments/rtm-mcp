#!/usr/bin/env ruby

require 'net/http'
require 'uri'
require 'json'
require 'digest/md5'
require 'date'

# Test script to explore RTM due date API

class RTMClient
  BASE_URL = 'https://api.rememberthemilk.com/services/rest/'
  
  def initialize(api_key, shared_secret)
    @api_key = api_key
    @shared_secret = shared_secret
    @timeline = nil
  end
  
  def make_request(method, params = {})
    # Add API key and format
    params['api_key'] = @api_key
    params['format'] = 'json'
    params['method'] = method
    
    # Generate signature
    params['api_sig'] = sign_request(params)
    
    # Make request
    uri = URI(BASE_URL)
    uri.query = URI.encode_www_form(params)
    
    response = Net::HTTP.get_response(uri)
    JSON.parse(response.body)
  end
  
  def sign_request(params)
    # Sort parameters by key
    sorted_params = params.sort.to_h
    
    # Create parameter string (exclude api_sig)
    param_string = sorted_params.reject { |k,v| k == 'api_sig' }
                                .map { |k,v| "#{k}#{v}" }
                                .join('')
    
    # Sign with shared secret
    Digest::MD5.hexdigest(@shared_secret + param_string)
  end
  
  def get_timeline(auth_token)
    @timeline ||= begin
      result = make_request('rtm.timelines.create', { 'auth_token' => auth_token })
      result.dig('rsp', 'timeline')
    end
  end
end

# Load credentials
api_key = File.read('.rtm_api_key').strip
shared_secret = File.read('.rtm_shared_secret').strip
auth_token = File.read('.rtm_auth_token').strip

client = RTMClient.new(api_key, shared_secret)

puts "🔬 RTM Due Date API Research"
puts "=" * 40

# Test 1: Get a task to see due date fields
puts "\n1️⃣ Examining task structure for due date fields..."
result = client.make_request('rtm.tasks.getList', {
  'auth_token' => auth_token,
  'list_id' => '51175519',
  'filter' => 'status:incomplete'
})

if result['rsp']['stat'] == 'ok'
  tasks = result.dig('rsp', 'tasks')
  if tasks && tasks['list']
    list = tasks['list']
    # Handle list being an array
    list = list[0] if list.is_a?(Array)
    
    if list && list['taskseries']
      taskseries = list['taskseries']
      taskseries = [taskseries] unless taskseries.is_a?(Array)
    
    # Show structure of first task for debugging
    if taskseries[0]
      puts "\nTask structure (first task):"
      puts JSON.pretty_generate(taskseries[0])
    end
    
    # Find first task with a due date
    task_with_due = nil
    taskseries.each do |ts|
      task = ts['task']
      if task.is_a?(Array)
        task.each do |t|
          if t['due'] && t['due'] != ""
            task_with_due = { series: ts, task: t }
            break
          end
        end
      elsif task['due'] && task['due'] != ""
        task_with_due = { series: ts, task: task }
      end
      break if task_with_due
    end
    
    if task_with_due
      puts "\nFound task with due date: #{task_with_due[:series]['name']}"
      puts "Due date info:"
      puts "  - due: #{task_with_due[:task]['due']}"
      puts "  - has_due_time: #{task_with_due[:task]['has_due_time']}"
      puts "  - added: #{task_with_due[:task]['added']}"
      puts "  - completed: #{task_with_due[:task]['completed']}"
      puts "  - deleted: #{task_with_due[:task]['deleted']}"
      puts "  - priority: #{task_with_due[:task]['priority']}"
      puts "  - postponed: #{task_with_due[:task]['postponed']}"
      puts "  - estimate: #{task_with_due[:task]['estimate']}"
    else
      puts "No tasks with due dates found. Will create one for testing..."
    end
    end
  end
end

# Test 2: Set due date on a task
puts "\n2️⃣ Testing rtm.tasks.setDueDate..."
puts "\nFirst, let's create a test task..."

timeline = client.get_timeline(auth_token)
puts "Got timeline: #{timeline}"

result = client.make_request('rtm.tasks.add', {
  'auth_token' => auth_token,
  'timeline' => timeline,
  'list_id' => '51175519',
  'name' => "Test due date task - #{Time.now.strftime('%H:%M:%S')}"
})

if result['rsp']['stat'] == 'ok'
  list = result.dig('rsp', 'list')
  taskseries = list['taskseries']
  taskseries = [taskseries] unless taskseries.is_a?(Array)
  ts = taskseries[0]
  task = ts['task'].is_a?(Array) ? ts['task'][0] : ts['task']
  
  puts "✅ Created task: #{ts['name']}"
  puts "   IDs: list=#{list['id']}, series=#{ts['id']}, task=#{task['id']}"
  
  # Test different due date formats
  test_dates = [
    { value: 'today', desc: 'Today' },
    { value: 'tomorrow', desc: 'Tomorrow' },
    { value: 'next week', desc: 'Next week' },
    { value: '2025-06-15', desc: 'Specific date (2025-06-15)' },
    { value: 'Friday', desc: 'Day name (Friday)' },
    { value: 'June 20', desc: 'Month and day (June 20)' },
    { value: '3pm', desc: 'Time only (3pm)' },
    { value: 'tomorrow at 2pm', desc: 'Date and time (tomorrow at 2pm)' }
  ]
  
  test_dates.each_with_index do |test, i|
    if i > 0
      puts "\n   Waiting 1 second (rate limit)..."
      sleep 1
    end
    
    puts "\n   Testing: #{test[:desc]}"
    puts "   Setting due date to: '#{test[:value]}'"
    
    result = client.make_request('rtm.tasks.setDueDate', {
      'auth_token' => auth_token,
      'timeline' => timeline,
      'list_id' => list['id'],
      'taskseries_id' => ts['id'],
      'task_id' => task['id'],
      'due' => test[:value],
      'parse' => '1'  # Enable natural language parsing
    })
    
    if result['rsp']['stat'] == 'ok'
      updated_list = result.dig('rsp', 'list')
      updated_ts = updated_list['taskseries']
      updated_ts = [updated_ts] unless updated_ts.is_a?(Array)
      updated_task = updated_ts[0]['task'].is_a?(Array) ? updated_ts[0]['task'][0] : updated_ts[0]['task']
      
      puts "   ✅ Success!"
      puts "   - due: #{updated_task['due']}"
      puts "   - has_due_time: #{updated_task['has_due_time']}"
    else
      puts "   ❌ Error: #{result}"
    end
  end
  
  # Test 3: Clear due date
  puts "\n3️⃣ Testing clearing due date..."
  sleep 1
  
  result = client.make_request('rtm.tasks.setDueDate', {
    'auth_token' => auth_token,
    'timeline' => timeline,
    'list_id' => list['id'],
    'taskseries_id' => ts['id'],
    'task_id' => task['id'],
    'due' => ''  # Empty string to clear
  })
  
  if result['rsp']['stat'] == 'ok'
    updated_list = result.dig('rsp', 'list')
    updated_ts = updated_list['taskseries']
    updated_ts = [updated_ts] unless updated_ts.is_a?(Array)
    updated_task = updated_ts[0]['task'].is_a?(Array) ? updated_ts[0]['task'][0] : updated_ts[0]['task']
    
    puts "✅ Due date cleared!"
    puts "   - due: '#{updated_task['due']}' (should be empty)"
    puts "   - has_due_time: #{updated_task['has_due_time']}"
  else
    puts "❌ Error clearing due date: #{result}"
  end
  
  # Clean up - complete the test task
  puts "\n🧹 Cleaning up test task..."
  sleep 1
  
  client.make_request('rtm.tasks.complete', {
    'auth_token' => auth_token,
    'timeline' => timeline,
    'list_id' => list['id'],
    'taskseries_id' => ts['id'],
    'task_id' => task['id']
  })
  puts "✅ Test task completed"
  
else
  puts "❌ Failed to create test task: #{result}"
end

puts "\n" + "=" * 40
puts "Research complete!"
puts "\nKey findings:"
puts "- Use rtm.tasks.setDueDate with 'due' parameter"
puts "- Set 'parse' => '1' to enable natural language parsing"
puts "- Use empty string ('') to clear due date"
puts "- Response includes 'due' and 'has_due_time' fields"
