require 'singleton'
require_relative 'TaskManager'

module UDSim
  # WorkScheduler - Single point for work coordination
  # Manages people working on tasks and simulation advancement
  class WorkScheduler
    include Singleton

    # Class variables for gantt chart tracking
    @@gantt_tasks = Hash.new { |h, k| h[k] = Hash.new }  # [task_key][person_name] = {start_hour, end_hour, task_name, project_name}
    @@simulation_hour = 0
    @@simulation_start_time = nil
    
    def initialize
      @task_manager = TaskManager.instance
      if @@simulation_start_time.nil?
        # Fixed date: June 12, 2017 - "Attention Is All You Need" paper release date
        @@simulation_start_time = Time.new(2017, 6, 12, 9, 0, 0) # 9:00 AM on June 12, 2017
        @@simulation_hour = 0
      end
    end

    # Main simulation work processing
    # Returns number of work units completed
    def process_work_hour
      # Increment simulation time
      @@simulation_hour += 1
      
      work_completed = 0

      # First, assign tasks to idle people
      assign_idle_people

      # Then, have everyone with tasks do work
      $people.all_people.each do |person|
        current_task = @task_manager.current_task(person)
        if current_task
          work_result = person.do_work(current_task)
          work_completed += work_result

          # Check if task was completed during this work session
          if current_task.hours >= current_task.required_hours
            handle_task_completion(person, current_task)
          end
        end
      end

      return work_completed
    end

    # Assign available tasks to idle people
    def assign_idle_people
      idle_people = @task_manager.idle_people

      idle_people.each do |person|
        next_task = @task_manager.assign_next_task(person)
        if next_task
          # Initialize the task for this person
          person.current_task = next_task
          person.task_schedule(next_task) if person.respond_to?(:task_schedule)
          
          # Record task start for gantt chart
          record_task_start(person, next_task)
          
          puts "WorkScheduler: #{person.name} starting #{next_task.name} #{next_task.sub_project.name}" if $op_verbose
        end
      end
    end

    # Handle when a person completes their current task
    def handle_task_completion(person, completed_task)
      puts "WorkScheduler: #{person.name} completed #{completed_task.name} #{completed_task.sub_project.name}" if $op_verbose

      # Record task completion for gantt chart
      record_task_end(person, completed_task)

      # Let person handle task completion (gantt charts, etc.)
      person.task_finish(completed_task) if person.respond_to?(:task_finish)

      # Let task handle its completion logic (create subtasks, etc.)
      completed_task.finish_work(person.effectiveness) if completed_task.respond_to?(:finish_work)

      # Clear person's current task
      person.current_task = nil

      # Mark as completed in task manager
      @task_manager.complete_task(person, completed_task)

      # Try to assign next task immediately
      next_task = @task_manager.assign_next_task(person)
      if next_task
        person.current_task = next_task
        person.task_schedule(next_task) if person.respond_to?(:task_schedule)
        
        # Record new task start for gantt chart - this task starts next hour
        record_task_start_next_hour(person, next_task)
        
        puts "WorkScheduler: #{person.name} immediately starting #{next_task.name} #{next_task.sub_project.name}" if $op_verbose
      end
    end

    # Check if simulation should continue (has active or pending work)
    def has_work_remaining?
      stats = @task_manager.stats
      stats[:pending] > 0 || stats[:active] > 0
    end

    # Get current work statistics
    def work_stats
      @task_manager.stats
    end

    # Add a task to be managed (called from Task creation)
    def add_task(task)
      @task_manager.add_task(task)
    end

    # Reset gantt chart data (useful for testing)
    def self.reset_gantt_data
      @@gantt_tasks.clear
      @@simulation_hour = 0
      # Fixed date: June 12, 2017 - "Attention Is All You Need" paper release date
      @@simulation_start_time = Time.new(2017, 6, 12, 9, 0, 0) # 9:00 AM on June 12, 2017
    end

    # Generate HTML gantt chart file
    def self.plot_gantt_chart(filename)
      File.open(filename, "w") do |aFile|
        aFile.puts "<!DOCTYPE html>"
        aFile.puts "<html>"
        aFile.puts "<head>"
        aFile.puts "  <title>WorkScheduler Gantt Chart</title>"
        aFile.puts "  <script type=\"text/javascript\" src=\"https://www.gstatic.com/charts/loader.js\"></script>"
        aFile.puts "  <style>"
        aFile.puts "    body { font-family: Arial, sans-serif; margin: 20px; }"
        aFile.puts "    h1 { color: #333; }"
        aFile.puts "    #gantt_chart { width: 100%; height: 600px; }"
        aFile.puts "  </style>"
        aFile.puts "</head>"
        aFile.puts "<body>"
        aFile.puts "  <h1>Task Timeline</h1>"
        aFile.puts "  <div id=\"gantt_chart\"></div>"
        aFile.puts ""
        aFile.puts "  <script type=\"text/javascript\">"
        aFile.puts "    google.charts.load('current', {'packages':['timeline']});"
        aFile.puts "    google.charts.setOnLoadCallback(drawChart);"
        aFile.puts ""
        aFile.puts "    function drawChart() {"
        aFile.puts "      var container = document.getElementById('gantt_chart');"
        aFile.puts "      var chart = new google.visualization.Timeline(container);"
        aFile.puts "      var dataTable = new google.visualization.DataTable();"
        aFile.puts ""
        aFile.puts "      dataTable.addColumn({ type: 'string', id: 'Person' });"
        aFile.puts "      dataTable.addColumn({ type: 'string', id: 'Task' });"
        aFile.puts "      dataTable.addColumn({ type: 'date', id: 'Start' });"
        aFile.puts "      dataTable.addColumn({ type: 'date', id: 'End' });"
        aFile.puts ""
        aFile.puts "      dataTable.addRows(["

        # Generate timeline data
        tasks_generated = []

        @@gantt_tasks.each do |task_key, person_data|
          person_data.each do |person_name, task_info|
            next unless task_info[:start_hour] && task_info[:end_hour] # Skip incomplete tasks

            # Convert simulation hours to actual times
            start_time = @@simulation_start_time + (task_info[:start_hour] * 3600) # 3600 seconds per hour
            end_time = @@simulation_start_time + (task_info[:end_hour] * 3600)

            # Convert times to JavaScript Date format
            start_js = time_to_js(start_time)
            end_js = time_to_js(end_time)

            # Create display name
            display_task_name = task_info[:task_name] || task_key

            task_data = "        ['#{person_name}', '#{display_task_name}', #{start_js}, #{end_js}]"
            tasks_generated << task_data
          end
        end

        # Write the tasks data
        aFile.puts tasks_generated.join(",\n")

        aFile.puts "      ]);"
        aFile.puts ""
        aFile.puts "      var options = {"
        aFile.puts "        timeline: {"
        aFile.puts "          showRowLabels: true,"
        aFile.puts "          showBarLabels: true,"
        aFile.puts "          groupByRowLabel: true"
        aFile.puts "        },"
        aFile.puts "        backgroundColor: '#fafafa'"
        aFile.puts "      };"
        aFile.puts ""
        aFile.puts "      chart.draw(dataTable, options);"
        aFile.puts "    }"
        aFile.puts "  </script>"
        aFile.puts "</body>"
        aFile.puts "</html>"
      end
    end

    private

    # Record when a task starts
    def record_task_start(person, task)
      task_key = create_task_key(task)
      @@gantt_tasks[task_key][person.name] = {
        start_hour: @@simulation_hour,
        end_hour: nil,
        task_name: task.name,
        project_name: task.sub_project.name
      }
    end

    # Record when a task starts in the next hour (for immediate assignments)
    def record_task_start_next_hour(person, task)
      task_key = create_task_key(task)
      @@gantt_tasks[task_key][person.name] = {
        start_hour: @@simulation_hour + 1,
        end_hour: nil,
        task_name: task.name,
        project_name: task.sub_project.name
      }
    end

    # Record when a task ends
    def record_task_end(person, task)
      task_key = create_task_key(task)
      if @@gantt_tasks[task_key][person.name]
        start_hour = @@gantt_tasks[task_key][person.name][:start_hour]
        # Task completes at the end of the current simulation hour
        # But ensure end time is always after start time (minimum 1 hour duration)
        end_hour = [@@simulation_hour, start_hour + 1].max
        @@gantt_tasks[task_key][person.name][:end_hour] = end_hour
      end
    end

    # Create a unique key for a task
    def create_task_key(task)
      "#{task.sub_project.name}_#{task.name}"
    end

    # Convert Time to JavaScript Date constructor format
    def self.time_to_js(time)
      return "new Date(#{time.year}, #{time.month - 1}, #{time.day}, #{time.hour}, #{time.min}, #{time.sec})"
    end
  end
end
