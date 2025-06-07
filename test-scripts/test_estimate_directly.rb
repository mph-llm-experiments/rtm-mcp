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
    puts "🔄 Calling #{method}..."
    
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
    
    puts "📡 Result: #{result.dig('rsp', 'stat')}"
    
    sleep 1  # Rate limiting
    result
  end

  def generate_signature(params)
    # Sort parameters and concatenate
    sorted_params = params.sort.map { |k, v| "#{k}#{v}" }.join
    signature_base = @shared_secret + sorted_params
    Digest::MD5.hexdigest(signature_base)
  end

  def test_estimate_display
    puts "🧪 Testing RTM Estimate Display"
    puts "=" * 40
    
    # First, get timeline
    timeline_result = call_method('rtm.timelines.create')
    timeline = timeline_result.dig('rsp', 'timeline')
    puts "📅 Timeline: #{timeline}"
    
    # Set estimate on our test task
    puts "\n1️⃣ Setting estimate..."
    estimate_result = call_method('rtm.tasks.setEstimate', {
      timeline: timeline,
      list_id: '51175710',
      taskseries_id: '576961590', 
      task_id: '1136771242',
      estimate: '2 hours'
    })
    
    if estimate_result.dig('rsp', 'stat') == 'ok'
      puts "✅ Estimate set!"
      
      # Now get the task list to see how it displays
      puts "\n2️⃣ Getting task list..."
      list_result = call_method('rtm.tasks.getList', {
        list_id: '51175710'
      })
      
      if list_result.dig('rsp', 'stat') == 'ok'
        tasks = list_result.dig('rsp', 'tasks', 'list')
        if tasks
          puts "\n📋 Tasks with estimates:"
          taskseries = tasks['taskseries']
          taskseries = [taskseries] unless taskseries.is_a?(Array)
          
          taskseries.each do |ts|
            task_array = ts['task']
            task_array = [task_array] unless task_array.is_a?(Array)
            
            task_array.each do |t|
              next if t['completed'] && !t['completed'].empty?
              
              estimate_text = t['estimate'] && !t['estimate'].empty? ? " [#{t['estimate']}]" : ""
              puts "  🔲 #{ts['name']}#{estimate_text}"
            end
          end
        end
      end
    else
      puts "❌ Failed to set estimate"
    end
  end
end

# Load credentials and run test
if ARGV.length < 2
  puts "Usage: ruby test_estimate_directly.rb <api_key> <shared_secret>"
  exit 1
end

api_key = ARGV[0]
shared_secret = ARGV[1]

tester = RTMTester.new(api_key, shared_secret)
tester.test_estimate_display
