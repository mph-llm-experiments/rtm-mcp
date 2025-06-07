#!/usr/bin/env ruby

require 'net/http'
require 'uri'
require 'json'
require 'digest'

class RTMTester
  def initialize(api_key, shared_secret)
    @api_key = api_key
    @shared_secret = shared_secret
    @auth_token = File.read('.rtm_auth_token').strip
    @base_url = 'https://api.rememberthemilk.com/services/rest/'
  end

  def call_method(method, params = {})
    puts "\n🔄 Calling #{method}..."
    
    # Add required parameters
    params.merge!({
      method: method,
      api_key: @api_key,
      auth_token: @auth_token,
      format: 'json'
    })

    # Generate signature
    params[:api_sig] = generate_signature(params)

    # Make request
    uri = URI(@base_url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri)
    request.set_form_data(params)

    response = http.request(request)
    result = JSON.parse(response.body)
    
    puts "📡 Response: #{result}"
    
    sleep 1  # Rate limiting
    result
  end

  def generate_signature(params)
    # Sort parameters and concatenate
    sorted_params = params.sort.map { |k, v| "#{k}#{v}" }.join
    signature_base = @shared_secret + sorted_params
    Digest::MD5.hexdigest(signature_base)
  end

  def test_estimates
    puts "🧪 Testing RTM Estimate Functionality"
    puts "=" * 50
    
    # First, get timeline
    timeline_result = call_method('rtm.timelines.create')
    timeline = timeline_result.dig('rsp', 'timeline')
    puts "📅 Timeline: #{timeline}"
    
    # Test Task Project List ID: 51175710
    test_list_id = '51175710'
    
    # Create a test task
    puts "\n1️⃣ Creating test task..."
    task_result = call_method('rtm.tasks.add', {
      timeline: timeline,
      list_id: test_list_id,
      name: "Estimate Test Task #{Time.now.to_i}"
    })
    
    if task_result.dig('rsp', 'stat') == 'ok'
      task_data = task_result.dig('rsp', 'list', 'taskseries')
      task_data = task_data.first if task_data.is_a?(Array)
      
      list_id = task_result.dig('rsp', 'list', 'id')
      taskseries_id = task_data['id']
      task_array = task_data['task']
      task_array = [task_array] unless task_array.is_a?(Array)
      task_id = task_array.first['id']
      
      puts "✅ Task created!"
      puts "   List ID: #{list_id}"
      puts "   Series ID: #{taskseries_id}"  
      puts "   Task ID: #{task_id}"
      task_array = task_data['task']
      task_array = [task_array] unless task_array.is_a?(Array)
      current_estimate = task_array.first['estimate']
      puts "   Current estimate: '#{current_estimate}'"
      
      # Test setting different estimate formats
      estimates_to_test = [
        '30 minutes',
        '1 hour',
        '2 hours',
        '1 day',
        '30m',
        '2h',
        '1d',
        '90 minutes',
        '' # Clear estimate
      ]
      
      estimates_to_test.each_with_index do |estimate, index|
        puts "\n#{index + 2}️⃣ Setting estimate to: '#{estimate}'"
        
        estimate_result = call_method('rtm.tasks.setEstimate', {
          timeline: timeline,
          list_id: list_id,
          taskseries_id: taskseries_id,
          task_id: task_id,
          estimate: estimate
        })
        
        if estimate_result.dig('rsp', 'stat') == 'ok'
          task_data = estimate_result.dig('rsp', 'list', 'taskseries')
          task_data = task_data.first if task_data.is_a?(Array)
          
          task_array = task_data['task']
          task_array = [task_array] unless task_array.is_a?(Array)
          actual_estimate = task_array.first['estimate']
          puts "✅ Estimate set! Result: '#{actual_estimate}'"
        else
          error_msg = estimate_result.dig('rsp', 'err', 'msg')
          puts "❌ Failed: #{error_msg}"
        end
      end
      
      # Test reading the task to see estimate in context
      puts "\n🔍 Reading final task state..."
      list_result = call_method('rtm.tasks.getList', {
        list_id: list_id,
        filter: "id:#{taskseries_id}"
      })
      
      if list_result.dig('rsp', 'stat') == 'ok'
        puts "📋 Final task data:"
        puts JSON.pretty_generate(list_result.dig('rsp', 'tasks', 'list'))
      end
      
    else
      puts "❌ Failed to create test task"
      puts "Error: #{task_result.dig('rsp', 'err', 'msg')}"
    end
  end
end

# Load credentials and run test
if ARGV.length < 2
  puts "Usage: ruby test-estimates.rb <api_key> <shared_secret>"
  exit 1
end

api_key = ARGV[0]
shared_secret = ARGV[1]

tester = RTMTester.new(api_key, shared_secret)
tester.test_estimates
