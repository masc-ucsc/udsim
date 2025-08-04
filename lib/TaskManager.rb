require 'singleton'

module UDSim
  # TaskManager - Single point for all task operations
  # Manages global task queue, assignments, and task states
  class TaskManager
    include Singleton

    def initialize
      reset
    end

    def reset
      @pending_tasks = []      # Global queue of tasks waiting to be assigned
      @active_tasks = {}       # person -> current task mapping
      @completed_tasks = []    # Completed tasks for tracking
      @task_dependencies = {}  # task -> [prerequisite tasks] mapping
    end

    # Add a task to the global pending queue
    def add_task(task)
      @pending_tasks << task
      puts "TaskManager: Added task #{task.name} for #{task.sub_project.name}" if $op_verbose
    end

    # Get the next available task for a specific person
    def assign_next_task(person)
      # Find first task the person can work on (has skills, dependencies met)
      available_task = @pending_tasks.find do |task|
        can_person_work_on_task?(person, task) && dependencies_met?(task)
      end

      if available_task
        @pending_tasks.delete(available_task)
        @active_tasks[person] = available_task
        puts "TaskManager: Assigned #{available_task.name} #{available_task.sub_project.name} to #{person.name}" if $op_verbose
        return available_task
      end

      return nil # No available tasks for this person
    end

    # Mark a task as completed and handle dependencies
    def complete_task(person, task)
      if @active_tasks[person] == task
        @active_tasks.delete(person)
        @completed_tasks << task
        puts "TaskManager: Completed #{task.name} #{task.sub_project.name} by #{person.name}" if $op_verbose

        # Check if any pending tasks are now unblocked
        check_unblocked_tasks
      end
    end

    # Get current task for a person
    def current_task(person)
      @active_tasks[person]
    end

    # Check if person is currently working on a task
    def person_busy?(person)
      @active_tasks.has_key?(person)
    end

    # Get all people who are currently idle
    def idle_people
      all_people = $people.all_people
      all_people.select { |person| !person_busy?(person) }
    end

    # Add task dependency (task depends on prerequisite)
    def add_dependency(task, prerequisite_task)
      @task_dependencies[task] ||= []
      @task_dependencies[task] << prerequisite_task
    end

    # Get statistics
    def stats
      {
        pending: @pending_tasks.length,
        active: @active_tasks.length,
        completed: @completed_tasks.length
      }
    end

    private

    # Check if person has the skills to work on this task
    def can_person_work_on_task?(person, task)
      # For now, simplified - everyone can work on any task
      # TODO: Add skill checking logic if needed
      true
    end

    # Check if all dependencies for a task are completed
    def dependencies_met?(task)
      prerequisites = @task_dependencies[task] || []
      prerequisites.all? { |prereq| @completed_tasks.include?(prereq) }
    end

    # Check for tasks that may now be unblocked
    def check_unblocked_tasks
      # This could trigger notifications or priority changes
      # For now, just a placeholder
    end
  end
end
