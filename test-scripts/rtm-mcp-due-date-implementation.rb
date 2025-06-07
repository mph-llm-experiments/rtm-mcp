#!/usr/bin/env ruby

# Implementation for set_due_date tool
# To be added to rtm-mcp.rb

# Tool definition to add after remove_task_tags:
<<-TOOL_DEF
      {
        name: 'set_due_date',
        description: 'Set or update the due date of a task',
        inputSchema: {
          type: 'object',
          properties: {
            list_id: {
              type: 'string',
              description: 'List ID containing the task'
            },
            taskseries_id: {
              type: 'string',
              description: 'Task series ID'
            },
            task_id: {
              type: 'string',
              description: 'Task ID'
            },
            due: {
              type: 'string',
              description: 'Due date (e.g., "today", "tomorrow", "next week", "June 15", "2025-06-20", "3pm", "tomorrow at 2pm"). Use empty string to clear.'
            }
          },
          required: ['list_id', 'taskseries_id', 'task_id', 'due']
        }
      },
TOOL_DEF

# Handler case to add in handle_call_tool_result:
# when 'set_due_date'
#   set_due_date(args['list_id'], args['taskseries_id'], args['task_id'], args['due'])

# Method implementation to add after remove_task_tags:
def set_due_date(list_id, taskseries_id, task_id, due)
  unless list_id && taskseries_id && task_id && due != nil
    return "Error: list_id, taskseries_id, task_id, and due are required"
  end
  
  params = {
    list_id: list_id,
    taskseries_id: taskseries_id,
    task_id: task_id,
    due: due,
    parse: '1'  # Enable natural language parsing
  }
  
  result = @rtm.call_method('rtm.tasks.setDueDate', params)
  
  if result['error'] || result.dig('rsp', 'stat') == 'fail'
    error_msg = result.dig('rsp', 'err', 'msg') || result['error'] || 'Unknown error'
    return "Error setting due date: #{error_msg}"
  end
  
  # Extract updated task info
  list = result.dig('rsp', 'list')
  taskseries = list&.dig('taskseries')
  
  if taskseries
    # Handle taskseries being an array
    ts = taskseries.is_a?(Array) ? taskseries[0] : taskseries
    task = ts['task']
    task = task.is_a?(Array) ? task[0] : task
    
    task_name = ts['name']
    
    if due.empty?
      "✅ Due date cleared for: #{task_name}"
    else
      due_value = task['due']
      has_time = task['has_due_time'] == '1'
      
      if due_value && !due_value.empty?
        time_info = has_time ? " (includes time)" : " (date only)"
        "✅ Due date set for: #{task_name}\n📅 Due: #{due_value}#{time_info}"
      else
        "✅ Due date updated for: #{task_name}"
      end
    end
  else
    if due.empty?
      "✅ Due date cleared successfully!"
    else
      "✅ Due date set successfully!"
    end
  end
end
