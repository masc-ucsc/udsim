#!/usr/bin/env ruby

require_relative '../lib/Design'
require_relative '../lib/Job'
require_relative '../lib/TaskPlan'
require_relative '../lib/TaskTypeConfig'
require_relative '../lib/WorkScheduler'
require_relative '../lib/TaskManager'

# Test script for Design, Job, TaskPlan, and TaskTypeConfig integration

# Mock some global variables that the existing code expects
$op_verbose = true
$op_debug = false
$op_cyclo = false
$op_coding_style = 1.0
$op_instant_partition = false

# Mock People class for compatibility
class MockPeople
  def self.all_people
    []
  end
end

# Mock global $people
$people = MockPeople

puts "=== Testing Design, Job, TaskPlan, TaskTypeConfig Integration ==="

# Test 1: Parse TaskTypeConfig
puts "\n1. Testing TaskTypeConfig parsing..."
task_xml_content = File.read('test/task.xml')
task_config = UDSim::TaskTypeConfig.new
task_config.parse!(task_xml_content)

puts "Task definitions loaded:"
task_config.each_task do |name, definition|
  puts "  #{name}: effort=#{definition[:skills].first&.[](:effort)}, next=#{definition[:subtasks].first}"
end

# Test 2: Parse Design from project XML
puts "\n2. Testing Design parsing..."
project_xml_content = File.read('test/project.xml')
design = UDSim::Design.new
design.parse!(project_xml_content)

puts "Jobs loaded:"
design.each_job do |job|
  puts "  #{job.name}: inputs=#{job.inputs.length}, outputs=#{job.outputs.length}, instances=#{job.instances.length}"
  metrics = job.complexity_metrics
  puts "    complexity: cyclo=#{metrics[:cyclo]}, loc=#{metrics[:loc]}"
end

# Test 3: Create initial TaskPlans
puts "\n3. Testing TaskPlan creation..."
initial_taskplans = design.create_initial_taskplans(task_config)

puts "Initial TaskPlans created:"
initial_taskplans.each do |taskplan|
  puts "  #{taskplan.source_job.name}.#{taskplan.task_name}: #{taskplan.required_hours} hours, next=#{taskplan.next_task_name}"
end

# Test 4: Test task workflow progression
puts "\n4. Testing task workflow progression..."
if initial_taskplans.any?
  test_taskplan = initial_taskplans.first
  puts "Testing workflow with: #{test_taskplan.source_job.name}.#{test_taskplan.task_name}"
  
  # Simulate task completion and progression
  job = test_taskplan.source_job
  current_task = test_taskplan.task_name
  
  3.times do |i|
    puts "  Step #{i+1}: Current task = #{current_task}"
    
    # Create taskplan for current step
    taskplan = UDSim::TaskPlan.new(job, current_task, task_config)
    puts "    TaskPlan: #{taskplan.name} (#{taskplan.required_hours} hours) -> #{taskplan.next_task_name}"
    
    # Move to next task
    current_task = taskplan.next_task_name
    break unless current_task && current_task != "done"
  end
end

# Test 5: Test WorkScheduler integration
puts "\n5. Testing WorkScheduler integration..."
work_scheduler = UDSim::WorkScheduler.instance

# Add some TaskPlans to the scheduler
initial_taskplans.each do |taskplan|
  work_scheduler.add_task(taskplan)
end

puts "Tasks added to WorkScheduler"
stats = work_scheduler.work_stats
puts "WorkScheduler stats: pending=#{stats[:pending]}, active=#{stats[:active]}, completed=#{stats[:completed]}"

puts "\n=== Integration Test Complete ==="
puts "All classes appear to work together correctly!"
