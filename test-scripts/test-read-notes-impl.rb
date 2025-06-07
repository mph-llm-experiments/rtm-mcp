#!/usr/bin/env ruby
require_relative 'rtm-mcp'

# Simulate the MCP server initialization
api_key = File.read('.rtm_api_key').strip
shared_secret = File.read('.rtm_shared_secret').strip
rtm = RTMClient.new(api_key, shared_secret)

# Create an instance with the required methods
class TestHandler
  def initialize(rtm)
    @rtm = rtm
  end
  
  def ensure_array(obj)
    return [] if obj.nil?
    obj.is_a?(Array) ? obj : [obj]
  end
  
  def format_time(time_str)
    return "" unless time_str
    Time.parse(time_str).strftime("%Y-%m-%d %H:%M")
  rescue
    time_str
  end
  
  def read_task_notes(list_id, taskseries_id, task_id)
    return "Error: Task IDs are required" unless list_id && taskseries_id && task_id
    
    # Get task details to retrieve notes
    resp = @rtm.call_method('rtm.tasks.getList', {
      list_id: list_id,
      filter: ""  # Empty filter to get all tasks
    })
    
    # Find the specific task
    taskseries = nil
    task = nil
    
    # Check for the rsp wrapper
    task_data = resp.dig('rsp', 'tasks') || resp['tasks']
    
    if task_data && task_data["list"]
      lists = ensure_array(task_data["list"])
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
    
    return "Task not found" unless taskseries && task
    
    # Extract notes
    if taskseries["notes"] && taskseries["notes"]["note"]
      notes = ensure_array(taskseries["notes"]["note"])
      
      if notes.empty?
        return "No notes found for this task"
      end
      
      # Format notes for display
      output = ["📝 **Notes for task: #{taskseries["name"]}**", ""]
      
      notes.each_with_index do |note, index|
        output << "**Note #{index + 1}** (ID: #{note["id"]})"
        output << "Title: #{note["title"]}" if note["title"] && !note["title"].empty?
        output << "Created: #{format_time(note["created"])}"
        output << "Modified: #{format_time(note["modified"])}" if note["modified"] != note["created"]
        output << ""
        output << note["$t"]  # Note content
        output << ""
        output << "---" if index < notes.length - 1
        output << ""
      end
      
      return output.join("\n").strip
    else
      return "No notes found for this task"
    end
  end
end

# Test the function
handler = TestHandler.new(rtm)

puts "Testing read_task_notes implementation..."
puts ""

# Test with task that has notes
result = handler.read_task_notes("51175519", "576922378", "1136720073")
puts result
puts ""
puts "=" * 60
puts ""

# Test with the read_task_notes task itself
puts "Testing with 'Add read_task_notes tool' task:"
result = handler.read_task_notes("51175519", "576957661", "1136764738")
puts result
