#!/usr/bin/env ruby
require_relative 'rtm-mcp'

# Simulate the MCP server initialization
api_key = File.read('.rtm_api_key').strip
shared_secret = File.read('.rtm_shared_secret').strip
rtm = RTMClient.new(api_key, shared_secret)

# Debug: Get all tasks
resp = rtm.call_method('rtm.tasks.getList', {
  list_id: "51175519",
  filter: ""
})

def ensure_array(obj)
  return [] if obj.nil?
  obj.is_a?(Array) ? obj : [obj]
end

puts "Debug: Raw response structure"
puts JSON.pretty_generate(resp) if resp
puts ""

if resp && resp["tasks"] && resp["tasks"]["list"]
  lists = ensure_array(resp["tasks"]["list"])
  puts "Found #{lists.length} lists"
  
  lists.each do |list|
    puts "List ID: #{list["id"]}"
    if list["taskseries"]
      series_array = ensure_array(list["taskseries"])
      puts "  Contains #{series_array.length} task series"
      
      # Just show first few for debugging
      series_array.first(3).each do |series|
        puts "  - Series ID: #{series["id"]}, Name: #{series["name"]}"
        if series["task"]
          tasks = ensure_array(series["task"])
          tasks.each do |task|
            puts "    - Task ID: #{task["id"]}"
          end
        end
        if series["notes"] && series["notes"]["note"]
          notes = ensure_array(series["notes"]["note"])
          puts "    - Has #{notes.length} note(s)"
        end
      end
    end
  end
else
  puts "No task data found in response"
end
