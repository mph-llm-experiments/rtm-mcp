#!/usr/bin/env ruby

require 'json'
require 'time'

# Debug wrapper for RTM MCP server

# Create a log file
log_file = File.open("/tmp/rtm-mcp-debug.log", "a")
log_file.sync = true

def log_message(log_file, direction, data)
  timestamp = Time.now.iso8601
  log_file.puts "#{timestamp} [#{direction}] #{data}"
end

# Get the path to the actual rtm-mcp.rb
rtm_mcp_path = File.join(File.dirname(__FILE__), "rtm-mcp.rb")

# Start the actual server as a subprocess
require 'open3'
stdin, stdout, stderr, wait_thr = Open3.popen3("ruby", rtm_mcp_path, *ARGV)

# Forward stdin to the subprocess and log
stdin_thread = Thread.new do
  loop do
    begin
      line = STDIN.readline
      log_message(log_file, "REQUEST", line.strip)
      stdin.puts(line)
      stdin.flush
    rescue EOFError
      break
    end
  end
end

# Forward stdout from the subprocess and log
stdout_thread = Thread.new do
  loop do
    begin
      line = stdout.readline
      log_message(log_file, "RESPONSE", line.strip)
      puts line
      STDOUT.flush
    rescue EOFError
      break
    end
  end
end

# Forward stderr
stderr_thread = Thread.new do
  loop do
    begin
      line = stderr.readline
      STDERR.puts line
      STDERR.flush
    rescue EOFError
      break
    end
  end
end

# Wait for threads
stdin_thread.join
stdout_thread.join
stderr_thread.join
wait_thr.join

log_file.close
