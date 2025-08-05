require 'rexml/document'
require_relative 'Job'

module UDSim
  class Design
    attr_accessor :name
    attr_reader :jobs

    def initialize(name = nil)
      @name = name || "main"
      @jobs = []
    end

    def parse!(xml)
      if xml.is_a?(String)
        doc = REXML::Document.new(xml)
      elsif xml.is_a?(REXML::Document)
        doc = xml
      elsif xml.respond_to?(:elements)
        doc = xml
      else
        raise ArgumentError, "Expected XML string, REXML::Document, or REXML::Element"
      end

      # Find project element (could be root or nested)
      project_element = doc.root
      if project_element.name != "project"
        project_element = doc.elements["project"] || doc.elements["//project"]
        raise ArgumentError, "No project element found in XML" unless project_element
      end

      # Parse each block into a Job
      project_element.elements.each("block") do |block_element|
        job = Job.new(block_element, self)
        @jobs << job if job.name
      end

      puts "Design: Parsed #{@jobs.length} jobs from project XML" if $op_verbose
    end

    def each_job
      @jobs.each { |job| yield job }
    end

    def find_job(name)
      @jobs.find { |job| job.name == name }
    end

    def job_count
      @jobs.length
    end

    def total_complexity
      total_cyclo = 0
      total_loc = 0

      @jobs.each do |job|
        metrics = job.complexity_metrics
        total_cyclo += metrics[:cyclo] || 0
        total_loc += metrics[:loc] || 0
      end

      { cyclo: total_cyclo, loc: total_loc }
    end

    def create_initial_taskplans(task_type_config)
      taskplans = []

      @jobs.each do |job|
        taskplan = job.create_initial_taskplan(task_type_config)
        taskplans << taskplan if taskplan
      end

      puts "Design: Created #{taskplans.length} initial taskplans" if $op_verbose
      taskplans
    end

    # Compatibility methods for existing code patterns
    def max_raw_hours
      total = 0.0
      @jobs.each do |job|
        total += job.estimated_hours("start", 100)
      end
      total
    end

    def block
      @jobs
    end

    def reset
      @jobs.clear
    end

    # Iterator for compatibility with existing Project usage
    def each_subproject(max_hours, task_name, effectiveness)
      # This is a simplified version - in the new architecture,
      # WorkScheduler handles work distribution instead
      @jobs.each do |job|
        # Create a mock task-like object for compatibility
        task = OpenStruct.new(
          name: task_name,
          sub_project: OpenStruct.new(name: job.name),
          effort: effectiveness
        )
        yield task
      end
    end
  end
end
