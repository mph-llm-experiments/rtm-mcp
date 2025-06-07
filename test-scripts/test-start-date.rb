#!/usr/bin/env ruby

require 'json'
require 'net/http'
require 'uri'

# Simple test of set_task_start_date tool

puts "🧪 Testing set_task_start_date tool..."
puts "=" * 40

# First, let's create a test task in the Test Task Project list
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
      name: "Test start date - #{Time.now.strftime('%H:%M:%S')}",
      list_id: '51175710'  # Test Task Project list
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
  
  # Test 1: Set start date to today
  puts "\n1️⃣ Setting start date to 'today'..."
  request.body = {
    method: 'tools/call',
    params: {
      name: 'set_task_start_date',
      arguments: {
        list_id: list_id,
        taskseries_id: series_id,
        task_id: task_id,
        start: 'today'
      }
    }
  }.to_json
  
  response = http.request(request)
  result = JSON.parse(response.body)
  puts result['result']['content'][0]['text']
  
  sleep 1
  
  # Test 2: Set start date to next Monday
  puts "\n2️⃣ Setting start date to 'next Monday'..."
  request.body = {
    method: 'tools/call',
    params: {
      name: 'set_task_start_date',
      arguments: {
        list_id: list_id,
        taskseries_id: series_id,
        task_id: task_id,
        start: 'next Monday'
      }
    }
  }.to_json
  
  response = http.request(request)
  result = JSON.parse(response.body)
  puts result['result']['content'][0]['text']
  
  sleep 1
  
  # Test 3: Clear start date
  puts "\n3️⃣ Clearing start date..."
  request.body = {
    method: 'tools/call',
    params: {
      name: 'set_task_start_date',
      arguments: {
        list_id: list_id,
        taskseries_id: series_id,
        task_id: task_id,
        start: ''
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
