require 'rexml/document'

module UDSim
  class TaskTypeConfig
    def initialize(task_xml = nil)
      @task_definitions = {}
      @task_order = []
      
      if task_xml
        parse!(task_xml)
      end
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
      
      # Find tasktype element (could be root or nested)
      tasktype_element = doc.root
      if tasktype_element.name != "tasktype"
        tasktype_element = doc.elements["tasktype"] || doc.elements["//tasktype"]
        raise ArgumentError, "No tasktype element found in XML" unless tasktype_element
      end
      
      # Parse each task definition
      tasktype_element.elements.each("task") do |task_element|
        task_name = task_element.attributes["name"]
        next unless task_name
        
        task_def = {
          name: task_name,
          partition: task_element.attributes["partition"] == "true",
          max_hours: task_element.attributes["max_hours"]&.to_i,
          skills: [],
          subtasks: []
        }
        
        # Parse skill requirements
        task_element.elements.each("skill") do |skill_element|
          skill_def = {
            type: skill_element.attributes["type"],
            effort: skill_element.attributes["effort"]&.to_i
          }
          task_def[:skills] << skill_def
        end
        
        # Parse subtasks (next tasks in workflow)
        task_element.elements.each("subtask") do |subtask_element|
          subtask_name = subtask_element.attributes["name"]
          task_def[:subtasks] << subtask_name if subtask_name
        end
        
        @task_definitions[task_name] = task_def
        @task_order << task_name unless @task_order.include?(task_name)
      end
      
      puts "TaskTypeConfig: Parsed #{@task_definitions.length} task definitions" if $op_verbose
    end
    
    def get_task_config(task_name)
      @task_definitions[task_name]
    end
    
    def get_next_task_name(current_task_name)
      task_def = @task_definitions[current_task_name]
      return nil unless task_def
      
      # Return first subtask, or nil if no subtasks
      task_def[:subtasks].first
    end
    
    def get_skill_requirements(task_name)
      task_def = @task_definitions[task_name]
      return [] unless task_def
      
      task_def[:skills]
    end
    
    def get_effort(task_name)
      task_def = @task_definitions[task_name]
      return 100 unless task_def
      
      # Return effort from first skill requirement, or default
      first_skill = task_def[:skills].first
      first_skill ? first_skill[:effort] : 100
    end
    
    def is_partition_task?(task_name)
      task_def = @task_definitions[task_name]
      return false unless task_def
      
      task_def[:partition]
    end
    
    def get_max_hours(task_name)
      task_def = @task_definitions[task_name]
      return nil unless task_def
      
      task_def[:max_hours]
    end
    
    def is_final_task?(task_name)
      task_def = @task_definitions[task_name]
      return true unless task_def
      
      task_def[:subtasks].empty? || task_def[:subtasks].include?("done")
    end
    
    def task_names
      @task_order.dup
    end
    
    def has_task?(task_name)
      @task_definitions.has_key?(task_name)
    end
    
    def each_task
      @task_order.each do |task_name|
        yield task_name, @task_definitions[task_name]
      end
    end
  end
end