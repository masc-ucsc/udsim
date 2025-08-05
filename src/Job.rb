require 'ostruct'
require_relative 'TaskPlan'

module UDSim
  class Job
    attr_accessor :name
    attr_accessor :inputs
    attr_accessor :outputs
    attr_accessor :instances
    attr_accessor :current_task_name
    attr_reader :design

    def initialize(block_xml, design = nil)
      @design = design
      @current_task_name = nil
      @inputs = []
      @outputs = []
      @instances = []
      @complexity = {}

      parse_block(block_xml) if block_xml

      puts "Job: Created #{@name} with #{@inputs.length} inputs, #{@outputs.length} outputs, #{@instances.length} instances" if $op_verbose
    end

    def create_initial_taskplan(task_type_config)
      # Find the first task in the workflow (usually "start")
      initial_task_name = task_type_config.task_names.first || "start"
      @current_task_name = initial_task_name

      TaskPlan.new(self, initial_task_name, task_type_config)
    end

    def create_next_taskplan(completed_taskplan, task_type_config)
      next_task_name = completed_taskplan.next_task_name
      return nil unless next_task_name && next_task_name != "done"

      @current_task_name = next_task_name
      TaskPlan.new(self, next_task_name, task_type_config)
    end

    def advance_task(completed_task_name, next_task_name)
      @current_task_name = next_task_name
      puts "Job: #{@name} advanced from #{completed_task_name} to #{next_task_name}" if $op_verbose
    end

    def complexity_metrics
      @complexity
    end

    def estimated_hours(task_name, effort = 100)
      base_hours = 0.0

      if @complexity[:cyclo] && $op_cyclo
        base_hours = 6 * @complexity[:cyclo]
      elsif @complexity[:loc]
        base_hours = @complexity[:loc]
      else
        base_hours = 40.0
      end

      # Adjust for effort
      base_hours = base_hours / (effort.to_f / 100.0) if effort > 0

      # Apply coding style factor
      base_hours = base_hours * $op_coding_style if $op_coding_style

      # Task-specific multipliers
      case task_name
      when "start"
        base_hours *= 0.1
      when "partition"
        base_hours *= 0.5
      when "design"
        base_hours *= 1.0
      when "coding"
        base_hours *= 1.2
      when "verification"
        base_hours *= 0.8
      end

      [base_hours, 1.0].max
    end

    # Compatibility methods for existing code
    def cyclo
      @complexity[:cyclo] || 0
    end

    def each_loc
      @complexity[:loc] || 0
    end

    def each_id
      @id ||= object_id
    end

    def nname
      @name
    end

    def each_instance
      @instances.each { |instance| yield instance }
    end

    private

    def parse_block(block)
      @name = block.attributes["name"] if block.respond_to?(:attributes)

      if block.respond_to?(:elements)
        # Parse inputs
        block.elements.each("input") do |input|
          input_name = input.attributes["name"]
          @inputs << input_name if input_name
        end

        # Parse outputs
        block.elements.each("output") do |output|
          output_name = output.attributes["name"]
          @outputs << output_name if output_name
        end

        # Parse instances
        block.elements.each("instance") do |instance|
          instance_name = instance.attributes["name"]
          @instances << instance_name if instance_name
        end

        # Parse complexity metrics
        block.elements.each("complexity") do |complexity|
          # @complexity[:cyclo] = complexity.attributes["cyclo1"]&.to_i || 0
          @complexity[:cyclo] = complexity.attributes["cyclo2"]&.to_i || 0
          @complexity[:nIfStmts] = complexity.attributes["nIfStmts"]&.to_i || 0
          @complexity[:nCaseStmts] = complexity.attributes["nCaseStmts"]&.to_i || 0
          @complexity[:nCaseItems] = complexity.attributes["nCaseItems"]&.to_i || 0
          @complexity[:nLoops] = complexity.attributes["nLoops"]&.to_i || 0
        end

        # Parse volume metrics
        block.elements.each("volume") do |volume|
          @complexity[:nNodes] = volume.attributes["nNodes"]&.to_i || 0
          @complexity[:nStmts] = volume.attributes["nStmts"]&.to_i || 0
          @complexity[:nAlwaysClocks] = volume.attributes["nAlwaysClocks"]&.to_i || 0
          @complexity[:nBAssign] = volume.attributes["nBAssign"]&.to_i || 0
          @complexity[:nNBAssign] = volume.attributes["nNBAssign"]&.to_i || 0
          @complexity[:nWAssign] = volume.attributes["nWAssign"]&.to_i || 0
          @complexity[:nOthers] = volume.attributes["nOther"]&.to_i || 0
        end

        # Calculate total LOC
        @complexity[:loc] = (@complexity[:nStmts] || 0) +
                           (@complexity[:nAlwaysClocks] || 0) +
                           (@complexity[:nBAssign] || 0) +
                           (@complexity[:nNBAssign] || 0) +
                           (@complexity[:nWAssign] || 0) +
                           (@complexity[:nCaseStmts] || 0) +
                           (@complexity[:nIfStmts] || 0) +
                           (@complexity[:nOthers] || 0) +
                           (@complexity[:nCaseItems] || 0) +
                           (@complexity[:nLoops] || 0)
      end
    end
  end
end
