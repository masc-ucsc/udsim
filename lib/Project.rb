
require 'tempfile'
require 'ProjectBlock'
require 'MetisBalancedPartitioner'

module UDSim

  FMT = '10'
  NCON = '1'
  SPACE = ' '
  NODE1 = '1'

  class Project
    attr_accessor :name
    attr_accessor :block
    attr_accessor :max_raw_hours
    attr_accessor :k


    @@job_pool       = Array.new
    @@sub_job_pool   = Array.new
    #@@create_adjHash = "false"
    @@module_key     = Hash.new  ## this is for finding the experience.
    @@main_block     = Hash.new
    @@partition      = Hash.new {|h,k| h[k] = Array.new}
    @@n_sub_job_count = 0
    @@i = 1    #Tasks not created for main manager, who is stored in location 0
    @@j = 0    #Tasks not created for main manager, who is stored in location 0
    @@job_array = Array.new
    @@test_flag = 1
    def initialize()
      @block          = Array.new
      @n_sub_projects = 0
      @max_raw_hours = 0
    end

    def reset()
      @@partition.each {| key, value|
        value.each { |id|
          job = @@name_idHash.key(id)
          job.is_assigned = false if job  #FIXME: for SCALE
        }
      }
      @@job_pool.clear
      @n_sub_projects = 0
      @@n_sub_job_count = 0
      @@sub_job_pool.clear
      @@i= 1
      @@j = 1    #Tasks not created for main manager, who is stored in location 0
      @@job_array = Array.new
    end

    def parse!(xml)
      xml.elements.each("project/block") { |block|
        blk = ProjectBlock.new(block)
        @@main_block[blk.name] = blk

        @max_raw_hours = @max_raw_hours + calc_raw_hours(blk,"start", 100)

        @block.push(blk)
      }

      @name = "main"
      puts "Project parsing done" if $op_verbose
    end

    def find_person(task, raw_hours, quality)

      person = nil

      People.each_sub_mgr { |m|
        next unless m.job_pool.include?(task.sub_project.name)
        # Find a person qualified and not already working for this tasks
        # m.dependants.each { |p|
        print "Length of active people" ,People.active_people.length, "\n" if $op_verbose
        People.active_people.each{  |p|
          next if p.get_skill(task.name) <= 0.01
          if person == nil
            person = p
            next
          end

          if (person.approximate_finish_date(task, raw_hours) > p.approximate_finish_date(task, raw_hours))
            if not p.pending_projects.length > person.pending_projects.length
              person = p
            end
          elsif (person.approximate_finish_date(task, raw_hours) == p.approximate_finish_date(task, raw_hours))
            if p.pending_projects.length  < person.pending_projects.length
              person = p
            end
          elsif(person.approximate_finish_date(task, raw_hours) < p.approximate_finish_date(task, raw_hours))
            if person.pending_projects.length > p.pending_projects.length
              person = p
            end
          end
          # }
        }
      }

      if person == nil && task.name == "partition" or task.name == "start" then
        print "Task name ", task.name, "\n" if $op_debug
        person = $people.project_manager
      elsif person == nil
        puts "ERROR: remember to add a person with skill " + task.name
        exit(-3)
      end
      person.next_free_date = person.approximate_finish_date(task, raw_hours)

      person.pending_jobs(task)
      puts "using " + person.name + " during PHASE: " + task.name + " project name " + task.sub_project.name if $op_debug
      return person
    end

    def sub_project_length()
      return @@job_pool.length
    end

    def each_subproject(max_hours, task_name, effectiveness)
      if People.sub_managers == 0
        return if @@job_pool.empty?
        prj = @@job_pool.pop
      else
        return if @@sub_job_pool.empty?
        puts "length " if not @@sub_job_pool.empty? if $op_verbose
        #puts "Length of sub job pool" + @@sub_job_pool.length
        prj = @@sub_job_pool.pop
        puts "Name of current job" + prj.name if $op_verbose
      end

      task = $task_type.new_task(task_name, prj, effectiveness)
      yield task

    end

    def create_jobpool(max_hours, task, effort, effectiveness)
      task_name = task.name
      for_jobpool(max_hours, task_name, effort, effectiveness)
      if People.sub_managers_empty?
        task.sub_partition = false
        @@job_pool.each{|p|
          $people.project_manager.job_pool << p.name
        }
      else
        task.sub_partition = true
      end
    end


    def for_jobpool(max_hours, task_name, effort, effectiveness)
      prj = Project.new
      prj.name = @name + ".#{@n_sub_projects}"

      @n_sub_projects += 1
      hours = 0
      k = 0

      @@partition.each {|key, value| value.uniq!}
      @@partition.each {|key, value|
        inserted = false
        value.each { |id|
          job = @@name_idHash.key(id)
          if job
            if ((job.is_assigned == false))
              hours = hours + calc_raw_hours(job, task_name, effort)
              prj.block.push(job)
            end
          else
            k += 1
          end

          if hours >= max_hours
            @@job_pool << prj
            prj  = Project.new
            prj.name = @name + ".#{@n_sub_projects}"

            @n_sub_projects = @n_sub_projects + 1
            hours = 0
            inserted = true
          end
        }
        if hours >= 0 && (!inserted)
          @@job_pool << prj
          prj  = Project.new
          prj.name = @name + ".#{@n_sub_projects}"
          @n_sub_projects = @n_sub_projects + 1
          hours = 0
        end
      }

      @@job_pool << prj if hours>0
      puts("Num sub jobs #{@n_sub_projects} job_pool:#{@@job_pool.length} k:#{k}") if $op_verbose
    end


    def work_sub_managers(task, effectiveness)
      effort = task.effort
      assign_jobs_submgrs(task, effort, effectiveness)
    end

    def assign_jobs_submgrs(task, effort, effectiveness)
      if @@i > 1 then
        manager_task(task, effort, effectiveness)
        if @@i == People.sub_managers
          task.sub_partition =false    # used to call work_sub_managers
        end
        return
      end

      if People.sub_managers_empty?
        puts "Only one manager...small team :)"
        $people.project_manager.job_pool = @@job_pool
        @@sub_job_pool = @@job_pool
      else
        jobs = Array.new(@@job_pool)
        if $op_verbose
          print "# sub managers", People.sub_managers, "\n"

          puts "##############################"
          puts "DETAILS OF JOB POOL..............."
          jobs.each{|t|
            puts t.name
            t.block.each{|b| print b.name, "\t"}
            print "\n"
          }
          puts "##############################"
        end
        sub_count = 0
        count = People.sub_managers # does not include the main manager.
        #count = count + 1 if count < 9

        z= Array.new
        tmp_length = (jobs.length.to_f/count.to_f)
        mod = jobs.length % count
        count.times{ |i|
          prj = Project.new
          prj.name = "sub_main_"+"#{sub_count}"
          sub_count = sub_count+1
          z <<  jobs.slice!(0, tmp_length)
          if mod > 0
            z << jobs.slice!(0,1)
            mod = mod - 1
          end
          z.flatten!
          z.each{|p|
            p.block.each{|v|
              prj.block.push(v)
            }
          }
          @@job_array << prj
          z =Array.new
        }  ### Assign jobs to all first lvl managers
        #print "Are all jobs assigned?", jobs.length, "\n" if $op_debug
        i = 0
        while !jobs.empty? do
          z <<  jobs.slice!(0,1)
          z.flatten!
          z.each{|p|
            p.block.each{|v|
              @@job_array[i].block.push(v)
            }

          }
          i= i+1 if i < @@job_array.length
        end
        print "Original # of jobs ", @@job_array.length, "All jobs should be assigned: Checking length of job_array: it should be 0 & it is : ", jobs.length,"\n" if $op_debug
        manager_task(task, effort, effectiveness)
      end
    end

    def manager_task(task, effort, effectiveness)
      return if @@j >= People.sub_managers or @@job_array.length == 0

      print "Length of job_array ", @@job_array.length, "\n" if $op_debug

      m  = People.manager_pool(@@j)
      prj = Project.new
      prj = @@job_array.pop

      task.create_submanager_task(m,  prj, effort, effectiveness)
      @@j =@@j+1
      @@job_array.each{|job| print job.name, "\t"}  if $op_verbose

      if (@@j == People.sub_managers) then
        if @@job_array.length > 0
          # means that all from job pool are not assigned to sub managers"
          # if main manager has some dependants who are engineers then
          # assigning the remaining jobs to main manager
          flag = false
          $people.project_manager.dependants.each{|dep|
            if dep.type =="engineer"
              flag = true
            end
          }
          if flag == true  # if flag is true then all sub projects are assigned
            $people.project_manager.job_pool << @@job_array
            $people.project_manager.job_pool << @@job_array
          else
            #	print "Length of job array ", @@job_array.length,  "\n"
            #       		print "WARNING: All sub jobs not assigned!\n"
            #exit(-3)
            # TODO: Find a way to assign the remaining jobs in job_array to lvl1 manager
          end
        end
      end

    end

    def create_sub_jobs(task, effort) #partitioning the project into individual jobs for sub manager
      return if task.person.type != "sub_manager"
      return if task.person.job_pool.length != 0

      task_name = task.name
      #    puts "Creating sub jobs " + task.name +
      #      " sub_project " + task.sub_project.name +
      #      " person " + task.person.name

      max_hours = 10 # FIXME: DONT hardcode the value here
      prj = Project.new
      hours = 0
      prj.name = "sub_prj"+ ".#{@@n_sub_job_count}"
      hours = 0
      inserted = false
      p  = task.person
      task.sub_project.block.each{|x| #print x.name, x.class, "\n"# iterating over each main_project
        hours =  hours + calc_raw_hours(x, task_name, effort)
        prj.block.push(x)
        if hours > max_hours  then
          p.job_pool << prj.name
          @@sub_job_pool << prj
          #        print "length", @@sub_job_pool.length
          hours = 0
          inserted = true
          @@n_sub_job_count = @@n_sub_job_count+1
          prj = Project.new
          prj.name = "sub_prj"+ ".#{@@n_sub_job_count}"
          #        puts "Creating sub job " + prj.name
          inserted = false
        end
      }
      if hours > 0  and (!inserted) then
        p.job_pool << prj.name
        @@sub_job_pool << prj
        @@n_sub_job_count = @@n_sub_job_count+1
        inserted = false
        hours = 0
        prj = Project.new
        prj.name = "sub_prj"+ ".#{@@n_sub_job_count}"
      end
      if hours > 0  and (!inserted) then
        p.job_pool << prj.name
        @@sub_job_pool << prj
        @@n_sub_job_count = @@n_sub_job_count+1
        inserted = false
        hours = 0
        prj = Project.new
        prj.name = "sub_prj"+ ".#{@@n_sub_job_count}"
      end

      print "# sub jobs after partition by sub_managers (CUMMULATIVE)", @@n_sub_job_count, "\n" if $op_debug
      if $op_test
        #### Job Partitioning ###
        puts "##############################"
        puts "JOB PARTITIONING......................"
        People.each_sub_mgr { |m|
          print "NAME OF MANAGER: ", m.name,  " his boss is : ", m.boss, "\n"
          #cyclo = 0
          puts "JOB POOL OF  ", m.name, " IS THE FOLL: "
          m.job_pool.each{|job|
            print job ,"\n"
            #job.block.each{|mod| cyclo = cyclo + mod.cyclo
            #print mod.name, ","
            #}
          }
          #print "\n"
          #uts "TOTAL CYCLO "+ cyclo.to_s
          #print "\n"
          print "DEPENDENTS OF ", m.name ," ARE: "
          m.dependants.each {|dep| print dep.name, ","}
          print "\n"
        }
        puts "################################"
      end
    end

    def raw_hours(task)
      raw_hours = 0
      task_name = task.name
      effort = task.effort
      
      # For partition tasks with instant partitioning enabled, return much smaller but reasonable time
      if $op_instant_partition && (task_name == "partition" || task_name == "sub_partition")
        return 8.0  # 8 hours (1 day) instead of the normal much longer duration
      end
      
      task.sub_project.block.each { |blk|
        raw_hours = raw_hours + calc_raw_hours(blk, task_name, effort)
      }
      raw_hours = 24 if raw_hours < 24 # 24 hours work is the min
      return raw_hours
    end

    private
    ## Depending on the cyclo it returns the  number of days required to complete the job
    def calc_raw_hours(job, task_name, effort)
      if $op_cyclo
        ## The cyclo can be used instead of cyclo, the relationship depends on the coding style, but
        ## a linear seems to hold
        hour = 6*job.cyclo()
      else
        hour = job.each_loc()
      end

      hour = hour/effort.to_f

      ## Adjust to each product/company coding style (flatness)
      hour = hour * $op_coding_style

      #hour = 1.5 if hour < 1.5 # .5 hour work is the min for each file
      hour = 0.1 if hour < 0.1 # .5 hour work is the min for each file

      return hour
    end

    public
    def create_adjHash()
      @@cycloHash   = Hash.new
      @@locHash     = Hash.new
      @@adjHash     = Hash.new {|h, k| h[k] = Array.new }
      @@name_idHash = Hash.new
      @@main_block.each { |key,value|
        @@name_idHash[value]=value.each_id()
      }

      @@main_block.each do |key, value|
        a=[]
        value.each_instance(){|y|
          tmp = @@main_block[y];
          if (tmp.instance_of?(ProjectBlock) )
            a.push(tmp)
          end
        }

        @@cycloHash[key] = value.cyclo   ### 1
        @@locHash[key] = value.each_loc()   ### 1

        b=Array.new
        a.each { |val|
          if(@@main_block.has_key?(val.nname()))
            tmp = @@main_block[val.nname()]
            b.push(tmp)  if (tmp.instance_of?(ProjectBlock))
          end
        }

        c=Array.new
        b=b.uniq
        b.each { |val|
          tmp = @@main_block[val.nname()]
          c.push(tmp) if tmp.kind_of?(ProjectBlock) and (tmp != value)
        }

        @@adjHash[@@name_idHash[value]] = c

        xArr = Array.new
        @@adjHash.each { |k,v|
          xArr.concat(v) if (v.length > 0)
        }

        xArr.each{|k|
          if (@@adjHash.has_key?(@@name_idHash[k]))
            tmp =Array.new
            tmp = @@adjHash[@@name_idHash[k]]
            if (tmp.length === 0)
              @@adjHash.delete(@@name_idHash[k])
            end
          end
        }
      end

      @@adjHash.each { |key, value|
        value.each{|val|
          @@module_key[val] = @@name_idHash.key(key)
        }
        @@module_key[@@name_idHash.key(key)] = @@name_idHash.key(key)
      }

      do_partition()
    end

    def get_key(project)
      tmp = Array.new
      project.block.each{|job|
        tmp << @@module_key[job].name if @@module_key[job] #FIXME: if condition added for SCALE
      }
      tmp.uniq!
      return tmp
    end

    ##############################################
    ##   Making the files for the hmetis program.
    ##   The input file is: mytest.hgr
    ##   The output file is:mytest.hgr.part.4  ( tested only for 4 employees.)
    ##   Not yet using all this.
    ############################################
    private
    def vertices()
      return @@cycloHash.length
    end

    def edges()
      length = 0
      for i in 1 .. @@cycloHash.length do
        if (@@adjHash.has_key?(i))  # for each member check whether it is the key to a se of values.
          val = @@adjHash.fetch(i)
          key = @@adjHash.select{|k,v| v == val}   ## sometimes the same set of values can have 2 diff keys, so we index the hash using val
          key.each {|a|
            key.delete(a) if not a.first ==  i # If delete here, counting edges fails
          }
          length += val.length
          if key[0]
            key_name = @@name_idHash.index(key[0].first)     # key stored as number, so get sts name
            ### check if this key is value for some one else
            for j in 1 .. @@cycloHash.length do
              if ( j.to_i != i.to_i && @@adjHash.has_key?(j))
                valx = @@adjHash.fetch(j)
                if (valx.include?(key_name))
                  length += 1
                end
              end
            end
          end
        end
      end
      return length
    end

    def do_partition()
      num_tasks = vertices()  # Number of available tasks
      desired_partitions = ((People.num_of_people).to_i - 1) * 2
      desired_partitions = 2 if desired_partitions < 2
      
      # Don't create more partitions than tasks available
      num_partitions = [desired_partitions, num_tasks].min
      
      # If we have more people than tasks, do simple 1:1 assignment
      if num_partitions >= num_tasks
        puts("Simple 1:1 task assignment - #{num_tasks} tasks for #{People.num_of_people} people")
        # Create simple 1:1 assignment - each partition gets exactly 1 task
        (1..num_tasks).each do |i|
          @@partition[i] = [i]
          puts("partition #{i-1} has 1 jobs")
        end
        return
      end

      # Use MetisPartitioner for complex partitioning when we have fewer people than tasks
      puts("Using MetisPartitioner - #{num_partitions} partitions for #{num_tasks} tasks")
      metis_data = generate_metis_format()
      partitioner = MetisBalancedPartitioner.new(metis_data)
      algorithms = [:multilevel, :fast_bfs, :fast_hash, :fast_random]
      result = partitioner.partition(num_partitions, algorithm: algorithms.sample)

      result[:partitions].each_with_index do |part, idx|
        puts("partition #{idx} has #{part.length} jobs")
        @@partition[idx + 1] = part
      end
    end

    private

    def generate_metis_format
      lines = []

      # Header: vertices edges format ncon
      lines << "#{vertices} #{edges} #{FMT} #{NCON}"

      @mem = Hash.new { |h, k| h[k] = Array.new }
      conta = 0

      (1..@@cycloHash.length).each do |i|
        line_parts = []
        flag = false

        if @@adjHash.has_key?(i)  # for each member check whether it is the key to a set of values.
          val = @@adjHash.fetch(i)
          key = @@adjHash.select { |k, v| v == val }   # sometimes the same set of values can have 2 diff keys
          key.each { |a| key.delete(a) if a.first != i }

          if key[0]
            key_name = @@name_idHash.index(key[0].first)     # key stored as number, so get its name

            # check if this key is value for some one else
            (1..@@cycloHash.length).each do |j|
              if j.to_i != i.to_i && @@adjHash.has_key?(j)
                valx = @@adjHash.fetch(j)
                if valx.include?(key_name)
                  if flag
                    line_parts << j
                  else
                    flag = true
                    line_parts << @@locHash[key_name.name] << j
                  end
                end
              end
            end
          end

          # check the val.length in the adjHash, go through that and put all the connections
          if val.length > 0
            # put all these connections
            unless flag
              line_parts << @@locHash[@@name_idHash.key(i).name]
              conta += 1
            end
            val.each do |v|
              id = @@name_idHash[v]
              if @@adjHash.has_key?(id)
                @mem[id] = @mem[id].push(i)
              end
              line_parts << id
              conta += 1
            end
          else
            line_parts << @@cycloHash[@@name_idHash.key(i).name]    # val.length == 0
          end
        else  # for members that are not keys in the adjHash...stored in the value part of the hash
          if !@@name_idHash.key(i)
            print "NOTWORKING:  i", i, "\n"
            next
          else
            # FIXME: Added for SCALE
            member = @@name_idHash.key(i).name
            flag1 = false
            @@adjHash.each do |k, v|
              v.each do |x|
                if x.name == member
                  unless flag1
                    line_parts << @@locHash[member]
                    flag1 = true
                  end
                  line_parts << k
                end
              end
            end
          end
        end

        lines << line_parts.join(' ')
      end

      lines.join("\n")
    end

  end  #Class Project End

end  # module UDSim end

