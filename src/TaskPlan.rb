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

      # Create next task in the workflow if we have a next task
      if @next_task_name
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
      base_hours = 1.0 # Base unit of work

      # Use job complexity metrics if available
      raise "complexity must be set" unless job.respond_to?(:complexity_metrics)

      metrics = job.complexity_metrics
      if $op_cyclo && metrics[:cyclo]
        base_hours = metrics[:cyclo]
      elsif metrics[:loc]
        base_hours = metrics[:loc] / 100.0 # Scale LOC to reasonable hours
      else
        base_hours = 1.0 # Default fallback
      end

      # Apply task type effort multiplier from XML configuration
      if effort && effort > 0
        base_hours = base_hours * (effort.to_f / 100.0)
      end

      # Apply coding style factor if available
      base_hours = base_hours * $op_coding_style if $op_coding_style

      # Special handling for partition tasks
      if task_name == "partition" && $op_instant_partition
        base_hours = 8.0 # Fast partition override
      end

      # Minimum task time
      base_hours = [base_hours, 1.0].max

      base_hours
    end
  end
end
