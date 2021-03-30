
require 'rexml/document'

require 'singleton'

module UDSim

  # A task is a sub-project being performed by a single person
  class Task
    #attr_reader   :name
    attr_reader   :max_hours

    attr_accessor :name
    attr_accessor :person

    attr_accessor :skill
    attr_accessor :effort
    attr_accessor :subtask
    attr_accessor :sub_project
    attr_accessor :partition
    attr_accessor :sub_partition   # if this is true, then creates tasks for sub managers
    attr_accessor :sub_partition2  # if true, then creates sub_partitions for sub_managers
    attr_accessor :hours
    attr_accessor :flag 	   # Only if we want to generate the gantt charts
    attr_accessor :adjusted_hours
    attr_accessor :next_phase
    attr_accessor :neighbors
    attr_accessor :percent
    attr_accessor :sub_percent

    def initialize(block)
      @neighbors = Array.new
      @sub_project = nil
      @sub_partition = false
      @sub_partition2 = false
      @effort = nil
      @@percent =1.00
      @@sub_percent =1.00
      @name   = block.attributes["name"]
      if block.attributes["partition"]
        @max_hours = block.attributes["max_hours"].to_f
        @partition = block.attributes["partition"] == "true"
      else
        @max_hours = 0.0
        @partition = false
      end
      @skill = Array.new
      block.elements.each('skill') { |skill|
        type   = skill.attributes["type"]
        effort = skill.attributes["effort"]
        @effort = effort
        # FIXME: create a Skill object and insert on the list of skill required
        puts "skill " + type + "with effort " + effort if $op_verbose
      }

      @subtask = Array.new
      block.elements.each('subtask') { |skill|
        name   = skill.attributes["name"]
        @subtask << name
      }
    end
    #
    def Task.percent(percent)
      @@percent = percent
    end
    def Task.sub_percent(percent)
      @@sub_percent = percent
    end
    def assign_task()
      @sub_project.block.each { |v|
        v.is_assigned=true
      }
      @person.task_schedule(self)
      $timeline.add_work(self)
    end

    def do_work(effectiveness)
      ## Called from Person.do_work
      ## Engineers begin working after manager has
      ## finished partitioning certain % of project

      do_work2(effectiveness)
      return unless @partition #or @sub_partition

      if @hours > (@adjusted_hours*@@percent/@sub_project.sub_project_length())
        if @sub_partition
          ##create tasks for sub_managers
          @sub_project.work_sub_managers(self, effectiveness)
          @@percent = @@percent+0.95
          return
        end
      end
      if !@sub_partition
        if @hours > (@adjusted_hours*@@percent/@sub_project.sub_project_length())
          @subtask.each { |st_name|
            @sub_project.each_subproject(@max_hours, st_name, effectiveness) { |t|
              t.assign_task()
              break
            }
            break
          }
        end
      end
    end

    def do_work2(effectiveness) # called only by sub manager
      return unless @sub_partition2
      @sub_project.create_sub_jobs(self, effort)  # called for each sub manager

      if @hours > (@adjusted_hours*@@sub_percent/@sub_project.sub_project_length())
        @subtask.each { |st_name|
          @sub_project.each_subproject(@max_hours, st_name, effectiveness) { |t|
            @@sub_percent = @@sub_percent+0.75
            t.assign_task()
            break
          }
          break
        }
      end
    end

    def add_work(st_name, effectiveness)

      person.task_schedule(self)
      $timeline.add_work(self)

      if @partition
        @sub_project.create_jobpool(@max_hours, self,@effort, effectiveness)
      end
    end

    def create_submanager_task(person, project, effort, effectiveness)
      t = $task_type.duplicate_task(self, person, project, effort, effectiveness)

      puts "Creating the sub task " + t.name +
        " effort " + t.effort.to_s +
        " sub_project " + t.sub_project.name +
        " person " + t.person.name +
        " sub_task " + t.subtask.to_s if $op_debug

      t.person.pending_jobs(t)
      t.add_work(t.name, effectiveness)
    end

    def finish_work(effectiveness)
      @subtask.each { |st_name|
        if @partition or @sub_partition2
          @sub_partition2 = false if @sub_partition2
          @sub_project.each_subproject(@max_hours, st_name, effectiveness) { |t|
            t.assign_task()
          }
        else
          t = $task_type.new_task(st_name , @sub_project, effectiveness)
          t.add_work(st_name, effectiveness)
        end
      }
    end
  end


  class TaskType
    attr_reader :num_tasks
    def initialize()
      @@task  = Hash.new
      reset()
    end

    def reset()
      @num_tasks = 0
    end

    def parse!(xml)

      # Each block
      xml.elements.each("tasktype/task"){ |y|
        att =  Task.new(y)
        @@task[att.name] = att
      }
      puts "Task: done" if $op_verbose
      print @@task.inspect if $op_verbose
    end

    def new_task(name, prj, effectiveness)
      t = @@task[name].clone   # pops the name of the current phase from the Taskblock class
      @num_tasks = @num_tasks + 1
      t.sub_project = prj
      t.hours  = 0
      t.adjusted_hours = 0
      t.flag = 0
      raw_hours  = prj.raw_hours(t)
      person = prj.find_person(t, raw_hours, effectiveness)
      t.person = person
      return t
    end

    def duplicate_task(task, person, project, effort, effectiveness)
      @num_tasks=@num_tasks+1
      t = task.clone
      t.name = task.name
      t.name = "sub_partition"

      t.sub_partition2 = true
      t.partition = false

      t.person = person
      t.person.pending_projects = Array.new

      t.sub_project = project
      t.sub_project.name = project.name
      t.effort = 50

      t.hours = 0.0
      t.adjusted_hours =0.0
      t.subtask = task.subtask
      return t
    end
  end
end
