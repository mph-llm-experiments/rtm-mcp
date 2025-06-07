#!/usr/bin/env ruby
require 'net/http'
require 'uri'
require 'json'
require 'digest/md5'

# Read credentials from files
API_KEY = File.read('.rtm_api_key').strip
SHARED_SECRET = File.read('.rtm_shared_secret').strip
AUTH_TOKEN = File.read('.rtm_auth_token').strip

def generate_sig(params)
  sorted = params.sort.map { |k, v| "#{k}#{v}" }.join
  Digest::MD5.hexdigest("#{SHARED_SECRET}#{sorted}")
end

def rtm_request(method, additional_params = {})
  params = {
    'method' => method,
    'api_key' => API_KEY,
    'auth_token' => AUTH_TOKEN,
    'format' => 'json'
  }.merge(additional_params)
  
  params['api_sig'] = generate_sig(params)
  
  uri = URI('https://api.rememberthemilk.com/services/rest/')
  uri.query = URI.encode_www_form(params)
  
  response = Net::HTTP.get_response(uri)
  JSON.parse(response.body)
end

# Get timeline
timeline_result = rtm_request('rtm.timelines.create')
timeline = timeline_result.dig('rsp', 'timeline')

# Find the research subtask
result = rtm_request('rtm.tasks.getList', {
  'filter' => 'name:"Research RTM due date API"',
  'list_id' => '51175519'
})

if result['rsp']['stat'] == 'ok' && result['rsp']['tasks']['list']
  list = result['rsp']['tasks']['list']
  list = [list] unless list.is_a?(Array)
  
  list.each do |l|
    next unless l['taskseries']
    taskseries = l['taskseries']
    taskseries = [taskseries] unless taskseries.is_a?(Array)
    
    taskseries.each do |ts|
      if ts['name'].include?('Research RTM due date API')
        task = ts['task']
        task = [task] unless task.is_a?(Array)
        
        puts "Found: #{ts['name']}"
        task_info = {
          list_id: l['id'],
          taskseries_id: ts['id'],
          task_id: task[0]['id']
        }
        
        # Add implementation note
        note_text = <<~NOTE
        Research Plan for RTM Due Date API:

        1. **API Methods to Test**
           - rtm.tasks.setDueDate - Set a due date
           - rtm.tasks.removeDueDate - Clear a due date
           - Test date format handling

        2. **Date Format Research**
           - ISO 8601 format: 2025-06-08T10:00:00Z
           - RTM natural language: "tomorrow", "next friday", "june 15"
           - Time zones and UTC handling
           - All-day vs specific time

        3. **Test Script Structure**
           ```ruby
           # test-due-dates.rb
           # 1. Create test task
           # 2. Test various date formats with setDueDate
           # 3. Verify date was set correctly
           # 4. Test removeDueDate
           # 5. Test error cases (invalid dates)
           ```

        4. **Questions to Answer**
           - Does RTM accept natural language dates via API?
           - What's the exact parameter name? (due? due_date?)
           - How are timezones handled?
           - What format does RTM return dates in?

        5. **Expected Tool Interface**
           ```ruby
           set_due_date(list_id, taskseries_id, task_id, due_date)
           # due_date could be: "2025-06-08", "tomorrow", "next friday 3pm"
           
           clear_due_date(list_id, taskseries_id, task_id)
           ```

        6. **Success Criteria**
           - Understand all date format options
           - Handle both date-only and date-time
           - Clear error messages for invalid dates
           - Natural language support if possible
        NOTE
        
        add_note_result = rtm_request('rtm.tasks.notes.add', {
          'timeline' => timeline,
          'list_id' => task_info[:list_id],
          'taskseries_id' => task_info[:taskseries_id],
          'task_id' => task_info[:task_id],
          'note_title' => 'Research Plan',
          'note_text' => note_text
        })
        
        if add_note_result['rsp']['stat'] == 'ok'
          puts "✅ Added implementation note to subtask"
        else
          puts "❌ Error: #{add_note_result.dig('rsp', 'err', 'msg')}"
        end
        
        break
      end
    end
  end
end
