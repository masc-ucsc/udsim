#!/usr/bin/env ruby

require_relative '../lib/Design'
require_relative '../lib/Job'
require_relative '../lib/TaskPlan'
require_relative '../lib/TaskTypeConfig'
require_relative '../lib/WorkScheduler'
require_relative '../lib/TaskManager'

# Test script for complete Design workflow with WorkScheduler simulation

# Mock some global variables that the existing code expects
$op_verbose = true
$op_debug = false
$op_cyclo = true  # Use cyclomatic complexity for calculations
$op_coding_style = 1.0
$op_instant_partition = false

# Mock Person class for single worker
class MockPerson
  attr_accessor :name, :current_task, :effectiveness

  def initialize(name)
    @name = name
    @current_task = nil
    @effectiveness = 1.0
  end

  def do_work(task)
    return 0 unless task

    # Simulate 1 hour of work
    work_done = 1.0 * @effectiveness
    task.hours += work_done

    puts "  #{@name} worked 1 hour on #{task.name} for #{task.sub_project.name} (#{task.hours}/#{task.required_hours})"
    work_done
  end

  def task_schedule(task)
    puts "  #{@name} scheduled to work on #{task.name} for #{task.sub_project.name}"
  end

  def task_finish(task)
    puts "  #{@name} finished #{task.name} for #{task.sub_project.name}"
  end
end

# Mock People class for single worker
class MockPeople
  @@worker = MockPerson.new("Alice")

  def self.all_people
    [@@worker]
  end

  def self.worker
    @@worker
  end
end

# Mock global $people
$people = MockPeople

puts "=== Testing Complete Design Workflow with WorkScheduler ==="

# Step 1: Load configuration files
puts "\n1. Loading configuration files..."
task_xml_content = File.read('test/task.xml')
task_config = UDSim::TaskTypeConfig.new
task_config.parse!(task_xml_content)
puts "TaskTypeConfig loaded with #{task_config.task_names.length} task types"

project_xml_content = File.read('test/project.xml')
design = UDSim::Design.new("test_project")
design.parse!(project_xml_content)
puts "Design loaded with #{design.job_count} jobs"

# Step 2: Initialize WorkScheduler
puts "\n2. Initializing WorkScheduler..."
work_scheduler = UDSim::WorkScheduler.instance
work_scheduler.class.reset_gantt_data  # Reset for clean test

# Step 3: Create initial TaskPlans and add to scheduler
puts "\n3. Creating initial TaskPlans..."
initial_taskplans = design.create_initial_taskplans(task_config)
initial_taskplans.each do |taskplan|
  work_scheduler.add_task(taskplan)
  puts "Added TaskPlan: #{taskplan.source_job.name}.#{taskplan.task_name} (#{taskplan.required_hours} hours)"
end

# Step 4: Run simulation
puts "\n4. Running WorkScheduler simulation..."
puts "Initial stats: #{work_scheduler.work_stats}"

hour = 0
max_hours = 1000  # Safety limit

while work_scheduler.has_work_remaining? && hour < max_hours do
  hour += 1
  puts "\n--- Hour #{hour} ---"

  work_completed = work_scheduler.process_work_hour
  stats = work_scheduler.work_stats

  puts "Hour #{hour}: #{work_completed} work units completed"
  puts "Stats: pending=#{stats[:pending]}, active=#{stats[:active]}, completed=#{stats[:completed]}"

  # Break if no progress (safety check)
  if work_completed == 0 && stats[:active] == 0 && stats[:pending] > 0
    puts "Warning: No progress made and tasks still pending. Breaking simulation."
    break
  end
end

# Step 5: Final results
puts "\n5. Simulation Results:"
final_stats = work_scheduler.work_stats
puts "Final stats: pending=#{final_stats[:pending]}, active=#{final_stats[:active]}, completed=#{final_stats[:completed]}"
puts "Total simulation time: #{hour} hours"

if final_stats[:pending] == 0
  puts "✅ All tasks completed successfully!"
else
  puts "⚠️  #{final_stats[:pending]} tasks still pending"
end

# Step 6: Generate Gantt chart
puts "\n6. Generating Gantt chart..."
gantt_filename = "test_design_gantt.html"
work_scheduler.class.plot_gantt_chart(gantt_filename)
puts "Gantt chart saved to: #{gantt_filename}"

puts "\n=== Test Complete ==="
