#!/usr/bin/env ruby

require 'json'
require 'net/http'
require 'uri'

# Simple test of set_due_date tool

puts "🧪 Testing set_due_date tool..."
puts "=" * 40

# First, let's create a test task
uri = URI('http://localhost:3030')
http = Net::HTTP.new(uri.host, uri.port)

# Create a test task
request = Net::HTTP::Post.new(uri)
request['Content-Type'] = 'application/json'
request.body = {
  method: 'tools/call',
  params: {
    name: 'create_task',
    arguments: {
      name: "Test due date - #{Time.now.strftime('%H:%M:%S')}",
      list_id: '51175519'
    }
  }
}.to_json

response = http.request(request)
result = JSON.parse(response.body)

if result['result'] && result['result']['content'] && result['result']['content'][0]['text'] =~ /IDs: list=(\d+), series=(\d+), task=(\d+)/
  list_id = $1
  series_id = $2
  task_id = $3
  
  puts "✅ Created test task"
  puts "   IDs: list=#{list_id}, series=#{series_id}, task=#{task_id}"
  
  # Test 1: Set due date to tomorrow
  puts "\n1️⃣ Setting due date to 'tomorrow'..."
  request.body = {
    method: 'tools/call',
    params: {
      name: 'set_due_date',
      arguments: {
        list_id: list_id,
        taskseries_id: series_id,
        task_id: task_id,
        due: 'tomorrow'
      }
    }
  }.to_json
  
  response = http.request(request)
  result = JSON.parse(response.body)
  puts result['result']['content'][0]['text']
  
  sleep 1
  
  # Test 2: Set due date with time
  puts "\n2️⃣ Setting due date to 'Friday at 3pm'..."
  request.body = {
    method: 'tools/call',
    params: {
      name: 'set_due_date',
      arguments: {
        list_id: list_id,
        taskseries_id: series_id,
        task_id: task_id,
        due: 'Friday at 3pm'
      }
    }
  }.to_json
  
  response = http.request(request)
  result = JSON.parse(response.body)
  puts result['result']['content'][0]['text']
  
  sleep 1
  
  # Test 3: Clear due date
  puts "\n3️⃣ Clearing due date..."
  request.body = {
    method: 'tools/call',
    params: {
      name: 'set_due_date',
      arguments: {
        list_id: list_id,
        taskseries_id: series_id,
        task_id: task_id,
        due: ''
      }
    }
  }.to_json
  
  response = http.request(request)
  result = JSON.parse(response.body)
  puts result['result']['content'][0]['text']
  
  sleep 1
  
  # Clean up - complete the task
  puts "\n🧹 Cleaning up..."
  request.body = {
    method: 'tools/call',
    params: {
      name: 'complete_task',
      arguments: {
        list_id: list_id,
        taskseries_id: series_id,
        task_id: task_id
      }
    }
  }.to_json
  
  response = http.request(request)
  puts "✅ Test task completed"
  
else
  puts "❌ Failed to create test task"
  puts result
end

puts "\n" + "=" * 40
puts "Test complete!"
