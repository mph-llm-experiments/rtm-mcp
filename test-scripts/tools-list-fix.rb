  def handle_tools_list(request)
    {
      "jsonrpc" => "2.0",
      "result" => {
        "tools" => [
          {
            "name" => "test_connection",
            "description" => "Test basic connectivity to RTM API",
            "inputSchema" => {
              "type" => "object",
              "properties" => {},
              "required" => [],
              "additionalProperties" => false
            }
          },
          {
            "name" => "list_all_lists",
            "description" => "Get all RTM lists",
            "inputSchema" => {
              "type" => "object",
              "properties" => {},
              "required" => [],
              "additionalProperties" => false
            }
          },
          {
            "name" => "create_list",
            "description" => "Create a new RTM list",
            "inputSchema" => {
              "type" => "object",
              "properties" => {
                "name" => {
                  "type" => "string",
                  "description" => "Name of the new list"
                }
              },
              "required" => ["name"],
              "additionalProperties" => false
            }
          },
          {
            "name" => "list_tasks",
            "description" => "Get tasks from RTM with optional filtering",
            "inputSchema" => {
              "type" => "object",
              "properties" => {
                "list_id" => {
                  "type" => "string",
                  "description" => "Filter by specific list ID (optional)"
                },
                "filter" => {
                  "type" => "string",
                  "description" => "RTM search filter (e.g., 'status:incomplete', 'dueWithin:\"1 week\"')"
                }
              },
              "required" => [],
              "additionalProperties" => false
            }
          },
          {
            "name" => "create_task",
            "description" => "Create a new task in RTM",
            "inputSchema" => {
              "type" => "object",
              "properties" => {
                "name" => {
                  "type" => "string",
                  "description" => "Task name"
                },
                "list_id" => {
                  "type" => "string",
                  "description" => "List ID to create task in (optional, uses default list if not specified)"
                }
              },
              "required" => ["name"],
              "additionalProperties" => false
            }
          },
          {
            "name" => "complete_task",
            "description" => "Mark a task as complete",
            "inputSchema" => {
              "type" => "object",
              "properties" => {
                "list_id" => {
                  "type" => "string",
                  "description" => "List ID containing the task"
                },
                "taskseries_id" => {
                  "type" => "string", 
                  "description" => "Task series ID"
                },
                "task_id" => {
                  "type" => "string",
                  "description" => "Task ID"
                }
              },
              "required" => ["list_id", "taskseries_id", "task_id"],
              "additionalProperties" => false
            }
          }
        ]
      },
      "id" => request['id']
    }
  end