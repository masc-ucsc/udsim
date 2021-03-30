#!/usr/bin/ruby -w

require "rexml/document"
require 'optparse'
require "fileutils"
require "Project"
module BugParse
  
  class XMLBase < REXML::Document
    attr_accessor :filename
    
    def initialize(filename)
      @filename = filename
      BugParse::error "xml file #{filename} does not exit" unless FileTest.exists?(filename)
      
      super(File.new(filename))
    end
  end

  def BugParse.error(msg)
    puts "ERROR: #{msg}"
    exit(-1)
  end
 

  def BugParse.setup(argv)

    $op_verbose   = false

    argv.options { |opts|
      opts.banner = ""
      opts.on("-h", "--help", "help message") { puts opts; exit; }
      
      opts.on("-v", "--[no-]verbose=[FLAG]", TrueClass, "run verbosly") { |$op_verbose| }
      
      if argv.empty?
        puts "Usage: ruby #{$0} [OPTIONS] project.xml"
        puts "\nOPTIONS:"
        puts opts
        exit
      end
      
      opts.parse!
    }
    
    # Begin to process parameters
    @filename = ""
    @project = Project.new()
    argv.each { |option|
      if option =~ /.xml$/
        puts option
     @filename=option
    @project.read!(option) 
    
     @project.generate_tmp_dat_file(@filename)
    end
    }

    @project.hier_graph_create(@filename)
    #@project.conn_graph_create(@filename)
    #@project.generate_hash_from_file(@filename)
    #@project.generate_cyclo_dat_file(@filename)
    
 end
  
end

BugParse::setup(ARGV)
