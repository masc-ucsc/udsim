require "Event"
require "Trend"

module UDSim
  # Person class. There can be specializations like Manager, Designer, Verifier, Sabelotodo...
  class Person

    attr_accessor :name
    attr_accessor :type
    attr_reader   :effectiveness

    attr_accessor :trend
    attr_accessor :initial_productivity
    attr_accessor :skill

    attr_accessor :approx_projects_hours
    attr_accessor :unadjusted_hours
    attr_accessor :adjusted_hours
    attr_accessor :next_free_date

    attr_accessor :people_date  ### Used for keeping track of start & end date to generate gantt chart

    attr_accessor :boss
    attr_accessor :pending_projects # Employee's list of tasks to complete
    attr_accessor :dependants   # This will be flled only for managers/sub-managers
    attr_accessor :job_pool     # Pool from which the manager selects the task to assign

    @@people_date   = Hash.new {|k,v| k[v] = Array.new }
    @@rayleigh      = Hash.new {|k,v| k[v] = 0.0 }
    @@communication = Hash.new {|k,v| k[v] = 0.0 }
    @@meeting       = Hash.new {|k,v| k[v] = 0.0 }

    @@active_tasks  = Array.new
    @@gantt_people  = Array.new

    #-------------------------------------------
    def initialize(name, y, type)
      @trend_learn  = $trend_type.get_trend("learn")
      @trend_defect = $trend_type.get_trend("defect")
      # < Communication model >
      @trend_meeting= $trend_type.get_trend("meeting")
      @trend_async  = $trend_type.get_trend("async")
      @trend_sync   = $trend_type.get_trend("sync")
      @trend_productivity = $trend_type.get_trend("productivity")

      @name   = name
      @type = type
      @dependants = Array.new
      @boss     = self
      @job_pool = Array.new

      reset()
      @skill = Hash.new {|h,k| k = 0.0}
      y.elements.each("skill") {|e|
        type = e.attributes["type"]
        score = e.attributes["score"]
        @skill[type] = score.to_f
      }
    end

    #-------------------------------------------
    def Person.rayleigh
      return @@rayleigh
    end

    #-------------------------------------------
    def Person.communication
      return @@communication
    end

    #-------------------------------------------
    def Person.meeting
      return @@meeting
    end
    #------------------------------------------

    def reset()
      @experience            = 0.0
      @approx_projects_hours = 0.0
      @unadjusted_hours      = 0.0
      @adjusted_hours        = 0.0

      @effectiveness = 1.0

      @next_free_date = $timeline.workdate

      @dependants = Array.new
      @pending_projects = Array.new
      @new_job_pool = Array.new
      @initial_productivity = @trend_productivity.random_gaussian

      @initial_productivity = 0.1 if @initial_productivity <= 0.1 # Someone FIRE THIS SUCKER!!!!
    end

    #-------------------------------------------
    def pending_jobs(proj)
      @pending_projects << proj
    end

    #-------------------------------------------
    def remove_job
      @pending_projects.delete_at(0)
    end

    #-------------------------------------------
    def adjust_schedule()
      date = $timeline.workdate
      ##If person not started working yet, then condition is true
      @next_free_date = date if (@next_free_date < date)
    end

    #-------------------------------------------
    # Find the next hour available
    def schedule_hour()
      adjust_schedule()

      start = @next_free_date
      @next_free_date = @next_free_date.next_work_hour()
      return start
    end

    #-------------------------------------------
    def task_schedule(task)

      if $op_gantt
        print "for gantt.schedule ::", task.sub_project.name, "\n" if $op_debug
        @@people_date[task.sub_project.name] = @@people_date[task.sub_project.name] << task.name << task.person.name << $timeline.workdate.to_date
      end

      @@active_tasks << task

      x  = task.sub_project.raw_hours(task)

      @unadjusted_hours      = @unadjusted_hours      + x

      if task.name == "design" or task.name == "verification" or task.name == "coding" ## FIXME: change this
        @approx_projects_hours = @approx_projects_hours + x
        @adjusted_hours        = calc_finish_hour(task, x)
      else
        @adjusted_hours        = x
      end

      task.adjusted_hours    = @adjusted_hours
    end

    #-------------------------------------------
    def calc_finish_hour(task, raw_hours)   ## only for giving the estimate
#      factor = @trend_learn.get_working_up_trend(@approx_projects_hours, @initial_productivity, @target_productivity)
      factor = @trend_learn.adjust_skill(@experience)
      skill = @initial_productivity * get_skill(task.name)

      return (raw_hours / (factor*skill))
    end

    #-------------------------------------------
    def task_finish(task)
      puts "Task finish \"" + task.name +
        "\" for project \"" + task.sub_project.name +
        #"\" at " + $timeline.date.to_s +
        " unadjusted hours " + task.person.unadjusted_hours.to_s +
        " total approx hours " + task.person.approx_projects_hours.to_s+
        " raw hours of project " + task.sub_project.raw_hours(task).to_s+
        " adjusted hours " + task.person.adjusted_hours.to_s +
        " person " + name if $op_verbose

      remove_job()
      @unadjusted_hours = (@unadjusted_hours - task.sub_project.raw_hours(task))

      if $op_gantt
        print "for gantt.do work::", task.sub_project.name, "\n" if $op_verbose
        @@people_date[task.sub_project.name] = @@people_date[task.sub_project.name] << $timeline.workdate.to_date
      end

      @@active_tasks.delete(task)
    end

    #-------------------------------------------
    def approximate_finish_date(task, raw_hours)
      adjust_schedule()

      adjusted_hours = calc_finish_hour(task, raw_hours)
      adjusted_hours = 1.0 if adjusted_hours < 1.0

      return @next_free_date+(adjusted_hours*2.0/24.0) #Scotti rule?
    end

    #-------------------------------------------
    # Timestep on the simulator. All the objects get registered, and
    # advance_hour is called.
    def do_work(task)

      print "Person.rb ",self.name , ": is working on ", task.name, " " , task.sub_project.name, " " ,task.hours, " ", task.adjusted_hours, " today's date ", $timeline.workdate.to_date, "\n" if $op_verbose

      task.do_work(@effectiveness)

#       @@rayleigh[$timeline.workdate.to_month] = @@rayleigh[$timeline.workdate.to_month] << @name
      if ((task.hours > 0.0 && task.hours <2.0 )  && task.flag == 0 )  ## Needed only if generating gantt chart
        task.flag = 1
        if $op_gantt
          print "for gantt.do work::", task.sub_project.name, "\n" if $op_verbose
          @@people_date[task.sub_project.name] = @@people_date[task.sub_project.name] << $timeline.workdate.to_date
        end
      end

      ## BEGIN ADJUST TIME PENDING
      task.hours =  task.hours + 1.0

      @experience = @experience + 1.0

      @@rayleigh[$timeline.workdate.day] = @@rayleigh[$timeline.workdate.day] + 1 if $op_rayleigh

      undo_due_to_defect(task) if $op_defect
      undo_due_to_comm(task)

      ## END ADJUST TIME PENDING

      return 0 if @pending_projects.length > 0 and @pending_projects.first.sub_project.name != task.sub_project.name
      unless (task.hours > task.adjusted_hours)
        $timeline.add_work(task)
        return 1
      end

      if @pending_projects.length > 1
        t = @pending_projects[1]
        $timeline.add_work(t)
      end

      task_finish(task)
      if $op_verbose && task.name == "sub_partition" && task.hours > task.adjusted_hours
        print task.name, "  of person ", task.person.name, " is going to finish ", $timeline.workdate.to_date, "\n"
      end

      task.finish_work(@effectiveness)

      plot_gantt_chart() if $op_gantt

      return 1
    end

    #-------------------------------------------
    def undo_due_to_defect(task)
      task.hours = task.hours-@trend_defect.random_gaussian()
      task.hours = 1 if task.hours < 1 # Even if a bug solves a problem, it should not be magic

      return unless rand(16) < 2

      each_related(task, @@active_tasks) { |t|
        next if t.hours <= 0
        t.hours = t.hours - @trend_defect.random_gaussian()*4
        t.hours = 1 if t.hours < 1 # Even if a bug solves a problem, it should not be magic
      }
    end

    #-------------------------------------------
    def undo_due_to_comm(task)
      #print "task hours", task.hours, "\n"
      ## Setup overhead, annoy anyone randomly inside the company

      one2one(task, @trend_async.random_gaussian()) if $op_comm
      compiletime(task)

      ## Just pester related projects (sync time). Needs the % of task done
      return unless $op_meet

      meeting_size = boss.dependants.size()
      return if meeting_size < 2 ## No reson to meet. Not enough work

      comm =  @trend_sync.random_gaussian()/meeting_size #/@@active_tasks.size

#      puts "jojo2 Comm:" + comm.to_s + " : " + meeting_size.to_s + " : "  + @@active_tasks.size.to_s

      @@active_tasks.each { |t|
        next if t.hours < 0

        t.hours = t.hours-comm
        t.hours = 1 if t.hours < 1

        @@communication[$timeline.workdate.day] = @@communication[$timeline.workdate.day] + comm if $op_overhead
        @@meeting[$timeline.workdate.day] = @@meeting[$timeline.workdate.day] + comm if $op_meeting
      }
    end

    #-------------------------------------------
    def meeting(list_of_task)
      list_of_task.each{ |p|
        yield p if (p.person.boss.name == boss.name)
      }
    end

    def compiletime(task)
      think_time = 5
      ratio = 60.0/(think_time+$op_compile_time)
      ratio = (ratio+1).to_i
      ratio = 1 if ratio < 0
      ratio = ratio + 1
      ncompilation = Random.new.rand(0..ratio)
      overhead = ncompilation * $op_compile_time/60
      overhead = 0.99 if overhead > 1

      # Delay current task
      task.hours = task.hours-overhead
      task.hours = 0 if task.hours < 0 # Even if a bug solves a problem, it should not be magic

      @@communication[$timeline.workdate.day] = @@communication[$timeline.workdate.day]+overhead  if $op_overhead
    end
    #-------------------------------------------
    def one2one(task, overhead)

      # Delay current task
      task.hours = task.hours-overhead
      task.hours = 0 if task.hours < 0 # Even if a bug solves a problem, it should not be magic

      @@communication[$timeline.workdate.day] = @@communication[$timeline.workdate.day]+overhead  if $op_overhead

      # Same delay for a random task of the communication recipient
#      t = @@active_tasks[rand(@@active_tasks.size())];
#      t.hours =  t.hours-overhead
#      @@communication[$timeline.workdate.day] = @@communication[$timeline.workdate.day]+overhead  if $op_overhead

      # Same delay for a random task of the communication recipient only if active
#      t = @@active_tasks[rand(@@active_tasks.size())];
#      t.hours =  t.hours-overhead
#      @@communication[$timeline.workdate.day] = @@communication[$timeline.workdate.day]+overhead  if $op_overhead

#       id =  rand(9)  # generate a random id and call
#       pester = "engineer_"+id.to_s
#       x_flg = 0

#       return if pester == @name # Do not pester yoursel

#       @@active_tasks.each { |t|
#         if (t.person.name == pester && t.hours > 0)
#           x_flg = 1
#           puts "Pestering someone...." if $op_debug
#           t.hours =  t.hours-overhead
#           @@communication[$timeline.workdate.day] = @@communication[$timeline.workdate.day]+overhead  if $op_overhead
#         end
#       }

#       if x_flg == 1 then
#         @@active_tasks.each{ |t|
#           if (t.person.name == self.name )
#             t.hours = t.hours-overhead
#             @@communication[$timeline.workdate.day] = @@communication[$timeline.workdate.day]+overhead  if $op_overhead
#           end
#         }
#       end
#       x_flg = 0
    end

    #-------------------------------------------
    def each_related(task, list_of_tasks)
      neighbors = task.sub_project.get_key(task.sub_project)

      list_of_tasks.each { |p|
        next if (p.equal?(task))

        neighbors2 = p.sub_project.get_key(p.sub_project)
        return if neighbors2.empty?
        neighbors.each { |elem|
          if neighbors2.include?(elem)
            yield p
        #    break
          end
        }
      }
    end

    #-------------------------------------------
    def add_dependants(person)
      if person.instance_of?(Person)
        @dependants.push(person)
        person.boss = self
        @@gantt_people << person if $op_gantt
      else
        if $op_gantt
          person.each{|p| p.boss.name = self.name
            @@gantt_people << p
          }
        end
        @dependants.push(person)
        @dependants.flatten!   #if we push array into it...
      end
    end

    #-------------------------------------------
    def get_skill(type)
      return (@skill[type])/100.0
    end

    def plot_gantt_chart
      File.open("#{$op_gantt}", "w") do |aFile|
        aFile.puts "<?php"
        aFile.puts " require_once \"BURAK_Gantt.class.php\" ;"
        aFile.puts " $g = new BURAK_Gantt();"
        aFile.puts " $g->setGrid(3);"
        aFile.puts " $g->setLoc(\"de_DE\");"
        aFile.puts " $g->setColor(\"group\",\"000000\");"
        aFile.puts " $g->setColor(\"progress\",\"00FF00\");"

        aFile.puts '$g->addGroup("' + $people.project_manager.name  + '","' + $people.project_manager.name + '","' + $people.project_manager.boss.name + '" );' + "\n"

        i = 0
        while i < @@gantt_people.length do
          #aFile.puts '$g->addGroup("' + @@gantt_people[i].name  + '","' + @@gantt_people[i].name+ '","' + @@gantt_people[i].boss.name + '" );' + "\n"
          #aFile.puts '$g->addGroup("' + @@gantt_people[i].name  + '","' +  @@gantt_people[i].boss.name + '" );' + "\n"
          aFile.puts '$g->addGroup("' + @@gantt_people[i].name  + '","' +  @@gantt_people[i].name + '" );' + "\n"
          i = i + 1
        end
        #while i < $people.idle_people.length do
        #  aFile.puts '$g->addGroup("' + $people.idle_people[i].name  +  '","' + $people.idle_people[i].name + '");'
        #  i = i + 1
        #end
        #aFile << " ***********************************"<< @gantt_people[0].name <<@gantt_people[2].boss.name << "\n"
        # design
        @@people_date.each {|k,v|
          next unless v[0]
          aFile << "$g->addNewTask(\"" << k << "_" << v[0] << "\",\"" << v[2] << "\",\"" << v[3] << "\"," << "\"" << v[4] << "\"," << "\"100\"," << "\"" << v[0] << "_" << k << "\",\"" << v[1] << "\");" << "\n"
        }
        # coding
        @@people_date.each {|k,v|
          next unless v[5]
          aFile << "$g->addNewTask(\"" << k << "_" << v[5] << "\",\"" << v[7] << "\",\"" << v[8] << "\"," << "\"" << v[9] << "\"," << "\"100\"," << "\"" << v[5] << "_" << k << "\",\"" << v[6] << "\");" << "\n"

        }
        #verification
        @@people_date.each {|k,v|
          next unless v[10]
          aFile << "$g->addNewTask(\"" << k << "_" << v[10] << "\",\"" << v[12] << "\",\"" << v[13] << "\"," << "\"" << v[14] << "\"," << "\"100\"," << "\"" << v[10] << "_" << k << "\",\"" << v[11] << "\");" << "\n"

        }

        aFile.puts " $g->outputGantt();"
        aFile.puts " ?> "
      end # end for file
    end
  end # End of Person

end    # End of module
