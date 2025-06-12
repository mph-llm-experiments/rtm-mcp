# Fix for enhanced create_task metadata bug
# This creates a patched version to replace lines 997-1075 in rtm-mcp.rb

def create_task(name, list_id = nil, due = nil, priority = nil, tags = nil)
  return "Error: Task name is required" unless name && !name.empty?
  
  # Step 1: Create the basic task
  params = { name: name }
  params[:list_id] = list_id if list_id && !list_id.empty?
  
  result = @rtm.call_method('rtm.tasks.add', params)
  
  if result['error'] || result.dig('rsp', 'stat') == 'fail'
    error_msg = result['error'] || result.dig('rsp', 'err', 'msg') || 'Unknown error'
    return "❌ RTM API Error: #{error_msg}"
  end
  
  # Extract the created task info
  list = result.dig('rsp', 'list')
  taskseries = list&.dig('taskseries')
  
  # Handle case where taskseries is an array
  if taskseries.is_a?(Array)
    task = taskseries.first
  else
    task = taskseries
  end
  
  if !task
    return "❌ Task created but couldn't parse response"
  end
  
  task_name = task['name'] || name
  actual_list_id = list['id']
  list_name = get_list_name(actual_list_id)
  task_obj = task['task']
  task_id = task_obj.is_a?(Array) ? task_obj[0]['id'] : task_obj['id']
  taskseries_id = task['id']
  
  # Build basic response first
  basic_response = "✅ Created task: #{task_name} in #{list_name}\n   IDs: list=#{actual_list_id}, series=#{taskseries_id}, task=#{task_id}"
  
  # Step 2: Set metadata via separate API calls if provided
  metadata_results = []
  
  # Set due date
  if due && !due.empty?
    sleep 1  # Rate limiting
    begin
      due_result = set_due_date(actual_list_id, taskseries_id, task_id, due)
      if due_result && due_result.start_with?("✅")
        metadata_results << "📅 Due date set"
      else
        metadata_results << "⚠️ Due date failed: #{due_result || 'Unknown error'}"
      end
    rescue => e
      metadata_results << "⚠️ Due date exception: #{e.message}"
    end
  end
  
  # Set priority
  if priority && !priority.empty?
    sleep 1  # Rate limiting
    begin
      priority_result = set_task_priority(actual_list_id, taskseries_id, task_id, priority)
      if priority_result && priority_result.start_with?("✅")
        priority_display = case priority
        when '1' then '🔴 High'
        when '2' then '🟡 Medium'  
        when '3' then '🔵 Low'
        else priority
        end
        metadata_results << "Priority: #{priority_display}"
      else
        metadata_results << "⚠️ Priority failed: #{priority_result || 'Unknown error'}"
      end
    rescue => e
      metadata_results << "⚠️ Priority exception: #{e.message}"
    end
  end
  
  # Set tags
  if tags && !tags.empty?
    sleep 1  # Rate limiting
    begin
      tags_result = add_task_tags(actual_list_id, taskseries_id, task_id, tags)
      if tags_result && tags_result.start_with?("✅")
        metadata_results << "🏷️ Tags: #{tags}"
      else
        metadata_results << "⚠️ Tags failed: #{tags_result || 'Unknown error'}"
      end
    rescue => e
      metadata_results << "⚠️ Tags exception: #{e.message}"
    end
  end
  
  # Build final response
  if metadata_results.any?
    basic_response + "\n" + metadata_results.join("\n")
  else
    basic_response
  end
end
