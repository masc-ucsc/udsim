require 'singleton'
require_relative 'TaskManager'

module UDSim
  # WorkScheduler - Single point for work coordination
  # Manages people working on tasks and simulation advancement
  class WorkScheduler
    include Singleton

    def initialize
      @task_manager = TaskManager.instance
    end

    # Main simulation work processing
    # Returns number of work units completed
    def process_work_hour
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
          puts "WorkScheduler: #{person.name} starting #{next_task.name} #{next_task.sub_project.name}" if $op_verbose
        end
      end
    end

    # Handle when a person completes their current task
    def handle_task_completion(person, completed_task)
      puts "WorkScheduler: #{person.name} completed #{completed_task.name} #{completed_task.sub_project.name}" if $op_verbose

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
  end
end
