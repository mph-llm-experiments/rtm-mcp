#!/usr/bin/env ruby
require 'json'
require 'net/http'
require 'uri'
require 'digest'
require 'time'

# Simple RTM API client for testing
class RTMClient
  BASE_URL = 'https://api.rememberthemilk.com/services/rest/'
  
  def initialize(api_key, shared_secret)
    @api_key = api_key
    @shared_secret = shared_secret
  end
  
  def call_method(method, params = {})
    params[:method] = method
    params[:api_key] = @api_key
    params[:format] = 'json'
    
    # Auth token if available
    if File.exist?('.rtm_auth_token')
      params[:auth_token] = File.read('.rtm_auth_token').strip
    end
    
    # Generate signature
    sig_params = params.sort.map { |k, v| "#{k}#{v}" }.join
    params[:api_sig] = Digest::MD5.hexdigest(@shared_secret + sig_params)
    
    # Make request
    uri = URI(BASE_URL)
    uri.query = URI.encode_www_form(params)
    
    response = Net::HTTP.get_response(uri)
    result = JSON.parse(response.body)
    
    if result['rsp']['stat'] == 'fail'
      raise "RTM API Error: #{result['rsp']['err']['msg']} (#{result['rsp']['err']['code']})"
    end
    
    result['rsp']
  end
end

# Load credentials
api_key = File.read('.rtm_api_key').strip
shared_secret = File.read('.rtm_shared_secret').strip

rtm = RTMClient.new(api_key, shared_secret)

# Test with the task that has notes
list_id = "51175519"
taskseries_id = "576922378"  # "Add due date tools" task
task_id = "1136720073"

puts "Testing read_task_notes functionality..."
puts "Task IDs: list=#{list_id}, series=#{taskseries_id}, task=#{task_id}"
puts ""

# Get the task details
resp = rtm.call_method('rtm.tasks.getList', 
  list_id: list_id,
  filter: "status:incomplete OR status:completed"
)

# Helper to ensure arrays
def ensure_array(obj)
  return [] if obj.nil?
  obj.is_a?(Array) ? obj : [obj]
end

# Find the specific task
taskseries = nil
task = nil

if resp && resp["tasks"] && resp["tasks"]["list"]
  lists = ensure_array(resp["tasks"]["list"])
  lists.each do |list|
    next unless list["id"] == list_id
    series_array = ensure_array(list["taskseries"])
    series_array.each do |series|
      if series["id"] == taskseries_id
        taskseries = series
        tasks = ensure_array(series["task"])
        task = tasks.find { |t| t["id"] == task_id }
        break
      end
    end
  end
end

if taskseries && task
  puts "Found task: #{taskseries["name"]}"
  puts ""
  
  # Extract notes
  if taskseries["notes"] && taskseries["notes"]["note"]
    notes = ensure_array(taskseries["notes"]["note"])
    
    if notes.empty?
      puts "No notes found for this task"
    else
      puts "📝 **Notes for task: #{taskseries["name"]}**"
      puts ""
      
      notes.each_with_index do |note, index|
        puts "**Note #{index + 1}** (ID: #{note["id"]})"
        puts "Title: #{note["title"]}" if note["title"] && !note["title"].empty?
        puts "Created: #{Time.parse(note["created"]).strftime("%Y-%m-%d %H:%M")}"
        if note["modified"] != note["created"]
          puts "Modified: #{Time.parse(note["modified"]).strftime("%Y-%m-%d %H:%M")}"
        end
        puts ""
        puts note["$t"]  # Note content
        puts ""
        puts "---" if index < notes.length - 1
        puts ""
      end
    end
  else
    puts "No notes found for this task"
  end
else
  puts "Task not found"
end
