module UDSim
  # Person2 - Simplified person class based on MockPerson
  # Replaces the complex Person class with basic functionality
  # All Person2 instances have equal skills and performance
  class Person2
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
      # Mock task scheduling - simplified interface for compatibility
    end

    def task_finish(task)
      # Mock task finishing - simplified interface for compatibility
    end

    def respond_to?(method)
      [:task_schedule, :task_finish].include?(method) || super
    end
  end
end