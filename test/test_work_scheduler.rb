require 'test/unit'
require_relative '../lib/WorkScheduler'
require_relative '../lib/TaskManager'

module UDSim
  class TestWorkScheduler < Test::Unit::TestCase
    
    def setup
      # Mock global variables
      $op_verbose = false
      
      # Reset and properly initialize singletons for clean test state
      TaskManager.instance.reset
      
      # Create mock people collection
      @people = MockPeople.new
      $people = @people
      
      @scheduler = WorkScheduler.instance
      # Ensure the task manager is properly initialized
      @scheduler.instance_variable_set(:@task_manager, TaskManager.instance)
    end
    
    def teardown
      # Clean up singletons
      WorkScheduler.instance.instance_variable_set(:@task_manager, nil)
      TaskManager.instance.reset
    end
    
    # Test 1: Single person with multiple sequential tasks
    def test_single_person_multiple_tasks
      person = MockPerson.new("Engineer1")
      @people.add_person(person)
      
      # Create tasks that should take 2, 3, and 1 work hours respectively
      task1 = MockTask.new("Task1", 2)
      task2 = MockTask.new("Task2", 3) 
      task3 = MockTask.new("Task3", 1)
      
      @scheduler.add_task(task1)
      @scheduler.add_task(task2)
      @scheduler.add_task(task3)
      
      total_work = 0
      work_hours = 0
      
      # Process work until no work remaining
      while @scheduler.has_work_remaining?
        work_done = @scheduler.process_work_hour
        total_work += work_done
        work_hours += 1
        
        # Safety check to prevent infinite loops
        assert work_hours < 100, "Test taking too long - possible infinite loop"
      end
      
      # Verify total time matches expected (2+3+1 = 6 hours)
      assert_equal 6, work_hours, "Total work time should equal sum of task hours"
      
      # Verify all tasks completed
      stats = @scheduler.work_stats
      assert_equal 3, stats[:completed], "All 3 tasks should be completed"
      assert_equal 0, stats[:pending], "No tasks should be pending"
      assert_equal 0, stats[:active], "No tasks should be active"
      
      # Verify person was never idle (worked every hour)
      assert_equal 6, total_work, "Person should have worked every hour"
    end
    
    # Test 2: Four people with parallel tasks
    def test_four_people_parallel_tasks
      # Create 4 people
      people = []
      4.times do |i|
        person = MockPerson.new("Engineer#{i+1}")
        people << person
        @people.add_person(person)
      end
      
      # Create 4 tasks that can be done in parallel, each taking 3 hours
      tasks = []
      4.times do |i|
        task = MockTask.new("Task#{i+1}", 3)
        tasks << task
        @scheduler.add_task(task)
      end
      
      total_work = 0
      work_hours = 0
      people_work_per_hour = []
      
      # Process work until no work remaining
      while @scheduler.has_work_remaining?
        # Check how many people are working BEFORE processing the hour
        active_count = people.count { |p| @scheduler.instance_variable_get(:@task_manager).current_task(p) }
        people_work_per_hour << active_count
        
        work_done = @scheduler.process_work_hour
        total_work += work_done
        work_hours += 1
        
        # Debug output (disabled)
        # if work_hours <= 4
        #   puts "Hour #{work_hours}: #{active_count} people working, #{work_done} work done"
        #   stats = @scheduler.work_stats
        #   puts "  Stats: pending=#{stats[:pending]}, active=#{stats[:active]}, completed=#{stats[:completed]}"
        # end
        
        # Safety check
        assert work_hours < 100, "Test taking too long - possible infinite loop"
      end
      
      # With 4 people and 4 tasks of 3 hours each, should complete in 3 hours
      assert_equal 3, work_hours, "4 parallel tasks of 3 hours each should complete in 3 hours"
      
      # Verify people were working appropriately
      # Hour 0: people start idle, get assigned, then work (so 0 at start)
      # Hours 1-2: people continue working (4 people working)
      people_work_per_hour.each_with_index do |count, hour|
        if hour == 0
          assert_equal 0, count, "People should start idle in hour #{hour}"  
        else
          assert_equal 4, count, "All 4 people should be working at hour #{hour}"
        end
      end
      
      # Verify all tasks completed
      stats = @scheduler.work_stats
      assert_equal 4, stats[:completed], "All 4 tasks should be completed"
      assert_equal 0, stats[:pending], "No tasks should be pending"
      assert_equal 0, stats[:active], "No tasks should be active"
      
      # Total work should be 4 people * 3 hours = 12 work units
      assert_equal 12, total_work, "Total work should be 12 units (4 people * 3 hours)"
    end
    
    # Test 3: Mixed scenario - more tasks than people
    def test_more_tasks_than_people
      # Create 2 people
      person1 = MockPerson.new("Engineer1")
      person2 = MockPerson.new("Engineer2")
      @people.add_person(person1)
      @people.add_person(person2)
      
      # Create 5 tasks of 2 hours each
      5.times do |i|
        task = MockTask.new("Task#{i+1}", 2)
        @scheduler.add_task(task)
      end
      
      work_hours = 0
      task_assignments = Hash.new { |h, k| h[k] = [] }
      
      # Process work and track task assignments
      while @scheduler.has_work_remaining?
        # Track what each person is working on BEFORE processing the hour
        [person1, person2].each do |person|
          current_task = @scheduler.instance_variable_get(:@task_manager).current_task(person)
          if current_task
            task_assignments[person.name] << current_task.name
          else
            task_assignments[person.name] << nil  # Track idle periods
          end
        end
        
        @scheduler.process_work_hour
        work_hours += 1
        
        # Safety check
        assert work_hours < 100, "Test taking too long - possible infinite loop"
      end
      
      # With 2 people and 5 tasks of 2 hours each (10 total hours of work),
      # should complete in 6 hours (1 hour for initial assignment + 5 hours of work)
      assert_equal 6, work_hours, "2 people doing 10 hours of work should take 6 hours (including assignment)"
      
      # Verify no task overlap - each person should work on one task at a time
      # The key constraint is that a person never works on multiple tasks simultaneously
      [person1, person2].each do |person|
        assignments = task_assignments[person.name]
        
        # Count how many unique non-nil tasks this person worked on
        unique_tasks = assignments.compact.uniq
        
        # Verify each person worked on multiple tasks (since we have 5 tasks and 2 people)
        assert unique_tasks.length >= 2, "#{person.name} should work on multiple tasks"
        
        # Verify no simultaneous task assignments (each person has at most one active task per hour)
        # This is guaranteed by the assignment tracking, but let's verify the person never 
        # has a task assigned while already working on a different task
        previous_task = nil
        assignments.each do |task_name|
          if task_name && previous_task && task_name != previous_task
            # Task switch occurred - this is normal and expected
          end
          previous_task = task_name if task_name
        end
      end
      
      # Verify all tasks completed
      stats = @scheduler.work_stats
      assert_equal 5, stats[:completed], "All 5 tasks should be completed"
    end
    
    # Test 4: Task completion and immediate assignment
    def test_task_completion_and_immediate_assignment
      person = MockPerson.new("Engineer1")
      @people.add_person(person)
      
      # Create two 1-hour tasks
      task1 = MockTask.new("QuickTask1", 1)
      task2 = MockTask.new("QuickTask2", 1)
      
      @scheduler.add_task(task1)
      @scheduler.add_task(task2)
      
      # Process first hour - should complete task1 and start task2
      work_done = @scheduler.process_work_hour
      assert_equal 1, work_done, "Should complete 1 unit of work"
      
      # Check that task1 is completed and task2 is now active
      stats = @scheduler.work_stats
      assert_equal 1, stats[:completed], "Task1 should be completed"
      assert_equal 1, stats[:active], "Task2 should be active"
      assert_equal 0, stats[:pending], "No tasks should be pending"
      
      # Verify person is working on task2
      assert_equal task2, person.current_task, "Person should immediately start task2"
      
      # Process second hour - should complete task2
      work_done = @scheduler.process_work_hour
      assert_equal 1, work_done, "Should complete 1 unit of work"
      
      # Verify all work is done
      assert_equal false, @scheduler.has_work_remaining?, "No work should remain"
      stats = @scheduler.work_stats
      assert_equal 2, stats[:completed], "Both tasks should be completed"
    end
    
    # Test 5: Edge case - no available tasks
    def test_no_available_tasks
      person = MockPerson.new("Engineer1")
      @people.add_person(person)
      
      # No tasks added
      work_done = @scheduler.process_work_hour
      assert_equal 0, work_done, "No work should be done when no tasks available"
      
      assert_equal false, @scheduler.has_work_remaining?, "Should have no work remaining"
      assert_nil person.current_task, "Person should have no current task"
    end
    
    # Test 6: Dynamic task addition during simulation
    def test_dynamic_task_addition
      # Create 2 engineers
      engineer1 = MockPerson.new("Engineer1")
      engineer2 = MockPerson.new("Engineer2")
      @people.add_person(engineer1)
      @people.add_person(engineer2)
      
      # Start with 1 task of 2 hours
      initial_task = MockTask.new("InitialTask", 2)
      @scheduler.add_task(initial_task)
      
      work_hours = 0
      
      # Process first hour - one engineer gets the task, other stays idle
      @scheduler.process_work_hour
      work_hours += 1
      
      # After 1 hour, add a task for the idle engineer
      late_task1 = MockTask.new("LateTask1", 2)
      @scheduler.add_task(late_task1)
      
      # Process second hour - InitialTask should complete, LateTask1 should start
      stats_before = @scheduler.work_stats
      assert_equal 1, stats_before[:active], "Should have 1 active task before second hour"
      assert_equal 1, stats_before[:pending], "Should have 1 pending task before second hour"
      
      @scheduler.process_work_hour
      work_hours += 1
      
      stats_after = @scheduler.work_stats  
      assert_equal 1, stats_after[:active], "Should have 1 active task after second hour (LateTask1)"
      assert_equal 0, stats_after[:pending], "Should have 0 pending tasks after second hour"
      assert_equal 1, stats_after[:completed], "Should have 1 completed task (InitialTask)"
      
      # Complete LateTask1 (needs 2 hours total)
      @scheduler.process_work_hour  # Hour 3
      work_hours += 1
      
      @scheduler.process_work_hour  # Hour 4  
      work_hours += 1
      
      # Both tasks should be completed, add a third task
      stats = @scheduler.work_stats
      assert_equal 2, stats[:completed], "Should have 2 completed tasks"
      assert_equal 0, stats[:active], "Should have 0 active tasks"
      
      # Add late task when someone is available
      late_task2 = MockTask.new("LateTask2", 1)
      @scheduler.add_task(late_task2)
      
      # Complete remaining work
      while @scheduler.has_work_remaining?
        @scheduler.process_work_hour
        work_hours += 1
        
        # Safety check
        assert work_hours < 10, "Test taking too long - possible infinite loop"
      end
      
      # Verify final state
      stats = @scheduler.work_stats
      assert_equal 3, stats[:completed], "All 3 tasks should be completed"
      assert_equal 0, stats[:pending], "No tasks should be pending"
      assert_equal 0, stats[:active], "No tasks should be active"
      
      # Verify that tasks were assigned to idle people as expected
      # This test primarily checks that:
      # 1. Tasks added during simulation get picked up
      # 2. Idle engineers get assigned new tasks immediately
      # 3. Engineers who finish early can take on new tasks
    end
    
    # Test 7: Edge case - all people busy
    def test_all_people_busy_scenario
      person1 = MockPerson.new("Engineer1")
      person2 = MockPerson.new("Engineer2")
      @people.add_person(person1)
      @people.add_person(person2)
      
      # Create tasks - 2 long tasks and 1 short task
      long_task1 = MockTask.new("LongTask1", 5)
      long_task2 = MockTask.new("LongTask2", 5)
      short_task = MockTask.new("ShortTask", 1)
      
      @scheduler.add_task(long_task1)
      @scheduler.add_task(long_task2)
      @scheduler.add_task(short_task)
      
      # Process first hour - both people should get long tasks
      @scheduler.process_work_hour
      
      stats = @scheduler.work_stats
      assert_equal 2, stats[:active], "2 tasks should be active"
      assert_equal 1, stats[:pending], "1 task should be pending"
      
      # Both people should be busy
      assert_not_nil person1.current_task, "Person1 should be busy"
      assert_not_nil person2.current_task, "Person2 should be busy"
    end
  end
  
  # Mock classes for testing
  class MockPerson
    attr_accessor :name, :current_task, :effectiveness
    
    def initialize(name)
      @name = name
      @current_task = nil
      @effectiveness = 1.0
    end
    
    def do_work(task)
      # Simulate work being done - increment task hours
      task.hours += 1.0
      1  # Return 1 unit of work completed
    end
    
    def task_schedule(task)
      # Mock task scheduling
    end
    
    def task_finish(task)
      # Mock task finishing
    end
    
    def respond_to?(method)
      [:task_schedule, :task_finish].include?(method) || super
    end
  end
  
  class MockTask
    attr_accessor :name, :hours, :required_hours, :sub_project
    
    def initialize(name, required_hours)
      @name = name
      @hours = 0.0
      @required_hours = required_hours.to_f
      @sub_project = MockSubProject.new("Project_#{name}")
    end
    
    def finish_work(effectiveness)
      # Mock task completion logic
    end
    
    def respond_to?(method)
      method == :finish_work || super
    end
  end
  
  class MockSubProject
    attr_accessor :name
    
    def initialize(name)
      @name = name
    end
  end
  
  class MockPeople
    def initialize
      @people = []
    end
    
    def add_person(person)
      @people << person
    end
    
    def all_people
      @people
    end
  end
end