require_relative 'WorkScheduler'

module UDSim
  class TaskPlan
    attr_accessor :source_job
    attr_accessor :task_name
    attr_accessor :next_task_name
    attr_accessor :hours
    attr_accessor :required_hours
    attr_accessor :sub_project
    attr_accessor :effort

    @@task_type_config = nil

    def initialize(job, task_name, task_type_config)
      @source_job = job
      @task_name = task_name
      @task_type_config = task_type_config
      @hours = 0.0
      @effort = task_type_config.get_effort(task_name)
      @next_task_name = task_type_config.get_next_task_name(task_name)

      # Create a compatible sub_project reference
      @sub_project = OpenStruct.new(name: job.name) if job

      # Calculate required hours based on job complexity and task type
      @required_hours = calculate_required_hours(job, task_name, @effort)

      puts "TaskPlan: Created #{task_name} for #{job&.name} (#{@required_hours} hours required)" if $op_verbose
    end

    def self.set_task_type_config(config)
      @@task_type_config = config
    end

    def name
      @task_name
    end

    def finish_work(effectiveness = 1.0)
      puts "TaskPlan: Finishing #{@task_name} for #{@source_job.name}" if $op_verbose

      # Update job's current task progression
      @source_job.advance_task(@task_name, @next_task_name) if @source_job.respond_to?(:advance_task)

      # Create next task in the workflow if not at the end
      if @next_task_name && !@task_type_config.is_final_task?(@next_task_name) && @next_task_name != "done"
        next_taskplan = @source_job.create_next_taskplan(self, @task_type_config)
        if next_taskplan
          WorkScheduler.instance.add_task(next_taskplan)
          puts "TaskPlan: Created next task #{@next_task_name} for #{@source_job.name}" if $op_verbose
        end
      else
        puts "TaskPlan: Completed workflow for #{@source_job.name}" if $op_verbose
      end
    end

    def person=(person)
      @person = person
    end

    def person
      @person
    end

    private

    def calculate_required_hours(job, task_name, effort)
      base_hours = 0.0

      # Use job complexity metrics if available
      raise "complexity must be set" unless job.respond_to?(:complexity_metrics)

      metrics = job.complexity_metrics
      if $op_cyclo && metrics[:cyclo]
        base_hours = 6 * metrics[:cyclo]
      elsif metrics[:loc]
        base_hours = metrics[:loc]
      else
        base_hours = 40.0 # Default fallback
      end

      # Adjust for effort level
      if effort && effort > 0
        base_hours = base_hours / (effort.to_f / 100.0)
      end

      # Apply coding style factor if available
      base_hours = base_hours * $op_coding_style if $op_coding_style

      # Task-specific adjustments
      case task_name
      when "start"
        base_hours *= 0.1 # Start tasks are quick
      when "partition"
        if $op_instant_partition
          base_hours = 8.0 # Fast partition
        else
          base_hours *= 0.5 # Moderate partition time
        end
      when "design"
        base_hours *= 1.0 # Full design time
      when "coding"
        base_hours *= 1.2 # Coding takes a bit more
      when "verification"
        base_hours *= 0.8 # Verification is faster than coding
      end

      # Minimum task time
      base_hours = [base_hours, 1.0].max

      base_hours
    end
  end
end
