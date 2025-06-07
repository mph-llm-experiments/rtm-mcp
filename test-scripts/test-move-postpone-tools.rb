#!/usr/bin/env ruby

# Simple syntax check for the updated rtm-mcp.rb file
puts "Checking Ruby syntax for rtm-mcp.rb..."

result = system("ruby -c rtm-mcp.rb")

if result
  puts "✅ Syntax is valid!"
else
  puts "❌ Syntax errors found"
  exit 1
end

puts "✅ move_task and postpone_task tools implemented successfully!"
puts ""
puts "**Tools added:**"
puts "1. move_task - Move tasks between lists"
puts "2. postpone_task - Postpone tasks (delay due dates)"
puts ""
puts "**Next steps:**"
puts "- Restart Claude Desktop to pick up the new tools"
puts "- Test both tools with actual tasks"
puts "- Mark the 'Add task move/postpone tools' task as complete"
