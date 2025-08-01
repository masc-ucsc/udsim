
module UDSim

  #TEAMSIZE = '14'

  # People class is a container of Person
  class People
    require 'date'
    require 'singleton'
    attr_reader :idle_people;
    attr_reader :active_people;
    attr_reader :num_of_people;
    attr_reader :sub_managers;
    attr_reader :project_manager;
    attr_accessor :teamsize;

    @@sub_managers  = 0
    @@manager_pool  = Array.new
    @@active_people2  = Array.new
    @@num_of_people = 0
    @@teamsize = 0
    #-------------------------------------------
    def set_teamsize()
      @@teamsize = 0
      while @@teamsize < 2
        @@teamsize = $trend_type.get_trend("teamsize").random_gaussian.to_int
      end
      puts "Team size : " + @@teamsize.to_s
    end

    #-------------------------------------------
    def initialize()
      @idle_people   = Array.new
      @active_people = Array.new
      @employee_pool = Array.new
      @num_of_people = 0
    end

    #-------------------------------------------
    def parse!(xml)

      # Each block
      person_id = 0
      xml.elements.each("people/person") { |y|

        set_teamsize()

        num_people  = y.attributes["num"].to_i
        late = y.attributes["late"]
        num_people.times {
          att = Person.new(y.attributes["name"] + "_#{person_id}", y, y.attributes["name"])
          if late == "yes"
            @idle_people.push(att)
          else
            @active_people.push(att)

          end
          person_id = person_id + 1
          print "Length of active people", @active_people.length, "\n" if $op_verbose
        }
      }
      @employee_pool = Array.new(@active_people)
      @@active_people2 = Array.new(@active_people)
      puts "Person: done" if $op_verbose
      @num_of_people = @idle_people.length + @active_people.length
      @@num_of_people = @num_of_people
      puts @num_of_people if $op_verbose

      @project_manager = @employee_pool[0]
      exit(-4) if !(@active_people.eql?(@employee_pool))
      @employee_pool.delete_at(0)
    end

    #-------------------------------------------
    def self.sub_managers   ## Used in project.rb
      @@sub_managers
    end

    def self.project_manager
      @project_manager
    end

    #------------------------------------------
    def People.active_people
      @@active_people2
    end
    
    def People.num_of_people
      @@num_of_people
    end

    #-------------------------------------------
    def People.each_sub_mgr
      if @@manager_pool.empty?
        puts "ERROR:: Manager pool empty!"
        exit(-1)
      end

      @@manager_pool.each { |m|
        yield m
      }
    end

    #-------------------------------------------
    def People.manager_pool(num)
      @@manager_pool[num]
    end

    #-------------------------------------------
    def check_manager   #Since ceil is used, sometimes extra manager is created and no engineer is assigned, delete extra manager here
      i = 0
      flag = Array.new
      @@manager_pool.each{|m|
        puts "Manager name ", m.name if $op_verbose
        flag << i if m.dependants.length == 0
        i=i+1
      }
      flag.each{|v|
        puts "Deleting a manager" , @@manager_pool[v].name
        @@manager_pool[v] = nil
        @@manager_pool.delete(@@manager_pool[v])
        @@sub_managers = @@sub_managers-1
      }
    end

    #-------------------------------------------
    def reset()
      set_teamsize()

      @@sub_managers = 0
      @project_manager = nil
      @@manager_pool.clear
      @employee_pool.clear
      @idle_people = Array.new
      #######	/* Only if Brooks law is used */ #######################
      #if @idle_people.length != 1
      #			new_p = @active_people.pop
      #  		@idle_people << new_p
      #			@idle_people.each{|p| p.reset() } if @idle_people.length > 0
      #end
      ################################################################
      @active_people.each { |p|
        p.reset()
      }
      @@active_people2 = Array.new(@active_people)
      print "Length of active_people2 ", @@active_people2.length if $op_verbose

      @employee_pool = Array.new(@active_people)
      @project_manager = @employee_pool[0]
      @employee_pool.delete_at(0)
      #@@manager_pool<< @project_manager  #comment out if br law not used
      manager_hierarchy

    end

    #-------------------------------------------
    def sub_managers_reqd?
      #@@sub_managers = (@num_of_people/TEAMSIZE.to_f).ceil if @num_of_people > TEAMSIZE.to_i
      @@sub_managers = (@num_of_people/@@teamsize.to_f).ceil if @num_of_people >@@teamsize

      return @@sub_managers > 0
    end

    #-------------------------------------------
    def self.sub_managers_empty?
      return @@sub_managers == 0
    end

    #-------------------------------------------

    def People.teamsize(val)
      @@teamsize=val
    end
    #------------------------------------------
    def create_hierarchy
      #     case @@sub_managers
      #       ################################################################
      #     when 1..@@teamsize
      #     teamsize = @@teamsize
      #       @@sub_managers.times {|m|
      #         create_submanager(m,@project_manager)
      #       }   ## Creating the sub managers
      #       #dep_length = TEAMSIZE.to_i - @project_manager.dependants.length
      #       #@project_manager.add_dependants(@employee_pool.slice!(0,dep_length) )
      #
      #       @@manager_pool.each{ |sub_mgr|
      #         sub_mgr.add_dependants(@employee_pool.slice!(0, teamsize.to_i))
      #       }  ## Adding employees to the sub managers
      #
      #       #if (@employee_pool.length < TEAMSIZE.to_i)
      #       if (@employee_pool.length < @@teamsize)
      #         @@manager_pool.last.add_dependants(@employee_pool)
      #         @employee_pool.clear
      #       end
      #       @@manager_pool.insert(0,@project_manager)
      #
      #       ################################################################
      #     #when 8..(TEAMSIZE.to_i)**2  ### 7..49
      #     #when TEAMSIZE.to_i+1..(TEAMSIZE.to_i)**2  ### 7..49
      #     when @@teamsize+1..(@@teamsize)**2  ### 7..49
      #       @@teamsize.times {|m|
      #         create_submanager(m, @project_manager )
      #       }   # we have created 7 sub_managers each with 6 employees
      #       #rem_submanager = @@sub_managers-TEAMSIZE.to_i
      #       rem_submanager = @@sub_managers-@@teamsize
      #       while rem_submanager > 0 do
      #         @project_manager.dependants.each{|m|
      #           create_submanager((rem_submanager+@@teamsize), m)
      #           rem_submanager = rem_submanager-1
      #           break if (rem_submanager == 0)
      #         }     ## Adding the second level of managers
      #       end
      #       @@manager_pool.each{ |sub_mgr|
      #         sub_mgr.add_dependants(@employee_pool.slice!(0, @@teamsize))
      #       }  ## Adding the employees to sub managers
      #       if (@employee_pool.length < @@teamsize)  ## All additional employees adding to the last created manager, needs to be changed.
      #         @@manager_pool.last.add_dependants(@employee_pool)
      #         @employee_pool.clear
      #       end
      #       @@manager_pool.insert(0,@project_manager)
      #
      #       ################################################################
      #     #when (TEAMSIZE.to_i)**2+1..(TEAMSIZE.to_i)**3                             ### 7*7*7 = 343
      #     when (@@teamsize)**2+1..(@@teamsize)**3                             ### 7*7*7 = 343
      #
      #        print "This many number of employees not yet handled!"
      #        exit(-3)
      #      else                                                      ### default case for the case
      #        puts "Too many employees not yet handled!!"
      #        exit(-3)
      #      end
    end
    #-----------------------------------------------

    def create_hierarchy2()
      count = 0
      id = 0
      tmp = 0
      @@sub_managers.times{|m|
        new_manager = @project_manager.dup
        new_manager.type = "sub_manager"
        new_manager.name = "sub_manager_"+m.to_s
        new_manager.job_pool = Array.new
        new_manager.dependants = Array.new
        new_manager.pending_projects = Array.new
        @@manager_pool << new_manager
      }
      while count < @@sub_managers do
        while tmp < @@teamsize do
          create_submanager(tmp+id, @@manager_pool[id])
          tmp=tmp+1
        end
        count = count+@@teamsize
        id = id+1
        tmp = 0
      end
      @@manager_pool.each{|mgr|
        mgr.add_dependants(@employee_pool.slice!(0,@@teamsize))
      }

    end

    #-------------------------------------------
    def manager_hierarchy
      @project_manager.boss = @project_manager

      if sub_managers_reqd?
        create_hierarchy2()
        #create_hierarchy()
      else
        puts "Too small to create teams" if $op_debug
        @@manager_pool<< @project_manager
        @employee_pool.each { |p|
          next unless p.type == "engineer"
          p.boss = @project_manager
        }
        @project_manager.add_dependants(@employee_pool)
        @employee_pool.clear
      end

      check_manager()

      if $op_test
        if @employee_pool.empty?
          puts "All empoyees assigned "
        else
          puts "All emps not assinged ", @employee_pool.length , " remaining "
          exit(-3)
        end
      end

      output_tree() if $op_verbose
    end

    #-------------------------------------------
    def output_tree()
      return if @@manager_pool.empty?
      People.each_sub_mgr{ |p|

        next if p.boss.name != "manager_0"    #others already printed

        print p.name, "\t", p.boss.name, "\n"
        p.dependants.each{|d|
          print "\t" , d.name , "\t", d.boss.name, "\n"
          if d.type == "sub_manager" && d.boss.name != "manager_0"
            d.dependants.each{|dd|
              print "\t\t",dd.name, "\t" ,dd.boss.name, "\n"
            }
          end
        }
      }
    end

    #-------------------------------------------
    def create_submanager(id, superior)
      return if id >= @@manager_pool.length
      new_manager = @@manager_pool[id]
      new_manager.boss = new_manager
      new_manager.add_dependants(new_manager) # dependants of the manager are the sub_managers
      print "Created a new sub manager", new_manager.name, " BOSS ", new_manager.boss.name, "job pool" , new_manager.job_pool, "\n" if $op_verbose
    end

    #-------------------------------------------
    ### Method below used only with Brook's Law"

    #-------------------------------------------
    def add_people_late
      ### Adding at 50% of finished time

      #projected_completion_time = ProjectBlock.tot_cyclo*0.4
      current_work = ($timeline.workdate.day)
      #print "Current work days ", current_work, "\n"
      #print "Extimated finish time  ", projected_completion_time, "\n"
      if ((current_work  > (99.6)) and @idle_people.length > 0) then
        @active_people << @idle_people
        @@active_people2 << @idle_people
        @@active_people2.flatten!
        @active_people.flatten!
        print " +++++++++++++++++++++++++++++++++++++++++++++++++++", "\n"
        # print "Current Work days ", current_work_days/8.to_f, "\n"
        # print "Adding late arrival", $timeline.workdate.to_s, "\n"

        #@project_manager.add_dependants(@idle_people)

        @idle_people = Array.new
      end
    end

  end   # End of class

end    # End of module
