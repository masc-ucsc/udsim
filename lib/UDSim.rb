#!/usr/bin/ruby -w
#UDSim.rb

require 'rubygems'
require 'rexml/document'
require 'optparse'
require 'fileutils'
require 'Project'
require 'Person'
require 'Task'
require 'Timeline'
require 'Trend'

module UDSim

  def self.rayleigh_curve
    tmp = Person.rayleigh.sort

    File.open($op_rayleigh, 'w') do |file|
      tmp.each do |k, v|
        file.puts "#{k} #{v / $op_nsim}"
      end
    end
  end

  def self.overhead
    tmp = Person.communication.sort

    File.open($op_overhead, 'w') do |file|
      tmp.each do |k, v|
        file.puts "#{k} #{v / $op_nsim}"
      end
    end
  end

  def self.meeting_curve
    tmp = Person.meeting.sort
    File.open($op_meeting, 'w') do |file|
      tmp.each do |k, v|
        # v.uniq!
        # file.puts "#{k} #{v.length}"
        file.puts "#{k} #{v / $op_nsim}"
      end
    end
  end

  def self.error(msg)
    puts "ERROR: #{msg}"
    exit(-1)
  end

  def self.show_options(opts)
    puts "Usage: ruby #{$0} [OPTIONS] project.xml trend.xml people.xml task.xml"
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

    $timeline = Timeline.instance

    $project           = Project.new
    $trend_type        = TrendType.new
    $people            = People.new
    $task_type         = TaskType.new
    $project_file_name = File.basename(argv[0], '.xml')
    argv.each do |option|
      if option =~ /.xml$/
        puts option
        xml = REXML::Document.new(File.new(option))
        $project.parse!(xml)
        $trend_type.parse!(xml)
        $people.parse!(xml)
        $task_type.parse!(xml)
      else
        puts "ERROR: Unknown option #{option}"
        exit(-2)
      end
    end
    $people.manager_hierarchy
    $project.create_adjHash
    print 'length of active people', People.active_people.length

    # Bootstrap task

    tmin    = 1e10
    tmax    = 0
    tsum    = 0.0
    tsumsq  = 0.0

    emin    = 1e10
    emax    = 0
    esum    = 0.0
    esumsq  = 0.0

    $op_nsim.times do |x|
      task = $task_type.new_task('start', $project, 1)
      puts 'Bootstrapping start task' if $op_verbose

      task.person.task_schedule(task)
      $timeline.add_work(task)
      puts "project requires at least #{$project.max_raw_hours / 8.0} days"

      puts "project requires at least #{$project.raw_hours(task) / 8.0} days cyclo #{ProjectBlock.tot_cyclo}  loc #{ProjectBlock.tot_loc}"
      limit_hours = $project.max_raw_hours * 20000
      e = $timeline.run(limit_hours) / 8.0
      r = $timeline.workdate.to_f / 8.0 # 8 hours working day
      if limit_hours <= $timeline.workdate.to_i
        puts 'WARNING: too many people on the project, you have a time overrun (project canceled)'
      end
      puts "DONE Time   #{r}"

      tmax    = r if r > tmax
      tmin    = r if r < tmin
      tsum   += r
      tsumsq += (r * r)

      puts "DONE Effort #{e}"
      emax    = e if e > emax
      emin    = e if e < emin
      esum   += e
      esumsq += (e * e)

      $timeline.reset
      $people.reset
      $project.reset
      Task.sub_percent(1.00)
      Task.percent(1.00)
      # $task_type.reset
    end

    rayleigh_curve if $op_rayleigh
    overhead if $op_overhead
    meeting_curve if $op_meeting

    ave    = tsum / $op_nsim
    stddev = Math.sqrt(tsumsq / $op_nsim - ave * ave)
    puts "time #{ave} #{stddev} #{tmax} #{tmin}"

    ave    = esum / $op_nsim
    stddev = Math.sqrt(esumsq / $op_nsim - ave * ave)
    puts "effort #{ave} #{stddev} #{emax} #{emin}"

    puts "Tasks number #{$task_type.num_tasks} average_size #{tsum / $task_type.num_tasks}"

  end

end

UDSim::setup(ARGV)
