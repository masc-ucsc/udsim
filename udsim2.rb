#!/usr/bin/ruby -w
#udsim2.rb - Updated UDSim using new architecture

require 'rubygems'
require 'rexml/document'
require 'optparse'
require 'fileutils'
require_relative 'src/WorkScheduler'
require_relative 'src/Design'
require_relative 'src/Job'
require_relative 'src/TaskPlan'
require_relative 'src/TaskTypeConfig'
require_relative 'src/TaskManager'
require_relative 'src/People2'

module UDSim2

  def self.error(msg)
    puts "ERROR: #{msg}"
    exit(-1)
  end

  def self.show_options(opts)
    puts "Usage: ruby #{$0} [OPTIONS] project.xml task.xml [people.xml] [trend.xml]"
    puts "\nOPTIONS:"
    puts opts.to_s
    exit
  end

  def self.setup(argv)
    $op_verbose      = false
    $op_debug        = false
    $op_comm         = true
    $op_meet         = true
    $op_defect       = true
    $op_test         = false
    $op_gantt        = nil
    $op_rayleigh     = nil
    $op_overhead     = nil
    $op_meeting      = nil
    $op_cyclo        = false
    $op_learn        = true
    $op_dummy        = false
    $op_coding_style = 1
    $op_nsim         = 1
    $op_compile_time = 0.0
    $op_seed         = 1
    $op_instant_partition = false
    $op_people_count = nil

    argv.options do |opts|
      opts.banner = ''
      opts.on('-h', '--help', 'help message') { puts opts; exit }
      opts.on('-v', '--verbose', 'verbose') { $op_verbose = true }
      opts.on('-c', '--cyclo', 'verbose') { $op_cyclo = true }
      opts.on('-d', '--debug', 'debug') { $op_debug = true }
      opts.on('-t', '--test', 'test') { $op_test = true }
      opts.on('-l', '--learn', 'Assume that they have learn (VF)') { $op_learn = false }
      opts.on('-q', '--no-learn', 'no learn') { $op_dummy = true }
      opts.on('-x', '--comm', 'no async comm') { $op_comm = false }
      opts.on('-y', '--meet', 'no sync comm') { $op_meet = false }
      opts.on('-z', '--defect', 'no defect') { $op_defect = false }
      opts.on('-g', '--gantt=#filename', String, 'gantt file') { |v| $op_gantt = v }
      opts.on('-r', '--rayleigh=#filename', String, 'rayleigh file') { |v| $op_rayleigh = v }
      opts.on('-o', '--overhead=#filename', String, 'communication overhead file') { |v| $op_overhead = v }
      opts.on('-m', '--meeting=#filename', String, 'meeting communication overhead file') { |v| $op_meeting = v }
      opts.on('-k', '--compile=mins', String, 'compilation time overhead minutes') { |v| $op_compile_time = v.to_f }

      opts.on('-s', '--style=factor', Float, 'Coding Style') { |v| $op_coding_style = v }
      opts.on('-n', '--num-sims=value', Integer, 'Number of simulations') { |v| $op_nsim = v }
      opts.on('-e', '--seed=value', Integer, 'Random seed for reproducible results') { |v| $op_seed = v }
      opts.on('-p', '--people=count', Integer, 'Number of engineers to create') { |v| $op_people_count = v }
      opts.on('-i', '--instant-partition', 'Enable instantaneous partitioning without overhead') { $op_instant_partition = true }
      opts.on('-v', '--[no-]verbose=[FLAG]', TrueClass, 'run verbosly') { |v| $op_verbose = v }

      show_options(opts) if argv.empty?
      begin
        opts.parse!(ARGV)
      rescue Exception => e
        show_options(opts)
        puts e, '', opts
      end
    end

    srand($op_seed) ## Set random seed for repeatability

    # Initialize new architecture components
    $design = UDSim::Design.new
    $task_type_config = UDSim::TaskTypeConfig.new
    $people = UDSim::People2.new
    
    $project_file_name = File.basename(argv[0], '.xml') if argv[0]

    # Parse XML files
    argv.each do |option|
      if option =~ /.xml$/
        puts option
        xml = REXML::Document.new(File.new(option))
        
        # Try to parse as design/project
        begin
          $design.parse!(xml)
        rescue
          puts "Not a project file: #{option}" if $op_verbose
        end
        
        # Try to parse as task type configuration
        begin
          $task_type_config.parse!(xml)
        rescue
          puts "Not a task type file: #{option}" if $op_verbose
        end
        
        # Try to parse as people configuration
        begin
          $people.parse!(xml)
        rescue
          puts "Not a people file: #{option}" if $op_verbose
        end
        
      else
        puts "ERROR: Unknown option #{option}"
        exit(-2)
      end
    end

    # Create people based on CLI option or error if neither option nor XML provided
    if $people.empty?
      if $op_people_count
        $people.create_standard_people($op_people_count)
        puts "Created #{$op_people_count} engineers from CLI option" if $op_verbose
      else
        error("No people specified. Use -p/--people=N option or provide a people.xml file.")
      end
    end

    # Create initial taskplans from design
    initial_taskplans = $design.create_initial_taskplans($task_type_config)
    
    # Add initial taskplans to WorkScheduler
    scheduler = UDSim::WorkScheduler.instance
    initial_taskplans.each do |taskplan|
      scheduler.add_task(taskplan)
    end

    puts "Design has #{$design.job_count} jobs" if $op_verbose
    puts "Created #{initial_taskplans.length} initial taskplans" if $op_verbose

    # Bootstrap simulation
    tmin    = 1e10
    tmax    = 0
    tsum    = 0.0
    tsumsq  = 0.0

    emin    = 1e10
    emax    = 0
    esum    = 0.0
    esumsq  = 0.0

    $op_nsim.times do |sim_num|
      puts "Running simulation #{sim_num + 1} of #{$op_nsim}" if $op_verbose
      
      # Reset for new simulation
      UDSim::WorkScheduler.instance.instance_variable_get(:@task_manager).reset
      $people.reset
      
      # Re-create initial taskplans
      initial_taskplans = $design.create_initial_taskplans($task_type_config)
      initial_taskplans.each do |taskplan|
        scheduler.add_task(taskplan)
      end

      work_hours = 0
      total_effort = 0.0
      
      # Run simulation until no work remaining
      while scheduler.has_work_remaining?
        work_done = scheduler.process_work_hour
        total_effort += work_done
        work_hours += 1
        
        # Safety check to prevent infinite loops
        if work_hours > 10000
          puts 'WARNING: simulation taking too long, possible infinite loop'
          break
        end
      end

      time_days = work_hours / 8.0  # Convert hours to 8-hour work days
      effort_days = total_effort / 8.0
      
      puts "DONE Time   #{time_days} days"
      puts "DONE Effort #{effort_days} days"

      # Update statistics
      tmax    = time_days if time_days > tmax
      tmin    = time_days if time_days < tmin
      tsum   += time_days
      tsumsq += (time_days * time_days)

      emax    = effort_days if effort_days > emax
      emin    = effort_days if effort_days < emin
      esum   += effort_days
      esumsq += (effort_days * effort_days)
    end

    # Generate gantt chart if requested
    if $op_gantt
      UDSim::WorkScheduler.plot_gantt_chart($op_gantt)
      puts "Gantt chart generated: #{$op_gantt}"
    end

    # Calculate and display final statistics
    time_ave = tsum / $op_nsim
    time_stddev = Math.sqrt(tsumsq / $op_nsim - time_ave * time_ave)
    puts "time #{time_ave} #{time_stddev} #{tmax} #{tmin}"

    effort_ave = esum / $op_nsim
    effort_stddev = Math.sqrt(esumsq / $op_nsim - effort_ave * effort_ave)
    puts "effort #{effort_ave} #{effort_stddev} #{emax} #{emin}"

    total_tasks = initial_taskplans.length * $op_nsim
    puts "Tasks number #{total_tasks} average_size #{tsum / total_tasks}" if total_tasks > 0
  end
end

UDSim2::setup(ARGV)