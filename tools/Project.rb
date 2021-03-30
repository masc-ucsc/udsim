OPENQ='"';
SINGLEQ = "'";
SEMIC   = ',' 
module BugParse 

  class ProjectBlock
    attr_accessor :name
    attr_accessor :cyclo
    attr_accessor :nNodes
    attr_accessor :nStmts
    attr_accessor :id
    
    @@counter = 1
    def initialize(block)
      @name = block.attributes["name"]
      @id = @@counter+1
      @@counter+=1 


    @instance = Array.new
     block.elements.each("instance") {|input|
        @instance << input.attributes["name"]
     }
  
    @input = Array.new
      block.elements.each("input") { |input|
        @input << input.attributes["name"]
      }

    @output = Array.new
      block.elements.each("output") { |input|
        @output << input.attributes["name"]
     }


     @cyclo = nil
     block.elements.each("complexity") { |input|
       UDSim::error "Multiple complexity sections on block #{@name}" if @cyclo
       @cyclo = input.attributes["cyclo1"].to_i
      }

    end

     def each_instance()
      @instance.each { |i|
          yield i
      }
    end

    def each_input()
      @input.each {|i|
        yield i
      } 
    end

    def each_output()
       @output.each { |i|
          yield i
    }
    end
    def each_cyclo()
        @cyclo
    end 

  end

  class Project
    def initialize()
      @block = Hash.new
    end
 
    #################################################
    ## Reading the xml file
    ##
    ################################################
 
    def read!(filename)
      
      puts "Project: parsing #{filename}" if $op_verbose

      xml = BugParse::XMLBase.new(filename)

      # Each block
      xml.elements.each("project/block") { |block|
        blk = ProjectBlock.new(block)
        @block[blk.name] = blk
      }
      puts "Project: done" if $op_verbose
    end
   

    #####################################
    ##  Give a good name to the filenames
    ## 
    ###################################
    
     def make_filename(filename)
     ### Making the filename
      bname=File.basename(filename,".xml")
      dname=File.dirname(filename)
      part=Array.new
      part=dname.split("/")
      tmp1=String.new
      if (!(part.empty?))  then 
       part.each{|ex| if (ex=~/^[0-9]/) then tmp1=ex end}
      end
      if (!(tmp1.empty?)) then  
        newfilename=bname+"_"+tmp1
      else 
        newfilename = bname
      end
      return newfilename
     end 

 
    ########################################
    ## Loads the cyclo number in the Hash
    ##
    ########################################
    def load_cycloHash()
      @cycloHash = Hash.new
     @block.each do|key,value|
          @cycloHash[key]=value.each_cyclo()
      end
    end


    ##########################################
    ### Makes the undirected connectivity graph
    ##
    ###########################################
    def conn_graph_create(filename) 
    ### Making the filename  
     newfilename=make_filename(filename)

     tmpInpHash=Hash.new
     tmpOutHash=Hash.new
     commonSet = Array.new 
     commonSet =commonSet.push("clk") 
     commonSet =commonSet.push("reset") 
     zero  = '0'
     load_cycloHash()  
     @block.each do |key,val|
         a = Array.new 
         b = Array.new
         val.each_input() { |i| a.push(i)}   
         tmpInpHash[key]  = a
         val.each_output() { |x| b.push(x)}
         tmpOutHash[key] = b
     end # end for @block.....
     keys     = @block.keys 
 
     count = 0
    
    primaryKey = keys[count]
    ### connectivity hash -- where the modules are connected by common input port names	
    @connInpHash = Hash.new { |k,v| v=Array.new}
    while (count <= keys.length) do
       for secondKey in  0... keys.length  do
         tmp1 =Array.new
         tmpA = Array.new
        
        #### Uncomment the following 4 lines to get Input-Output connectivity 
     #   if (primaryKey != keys[secondKey]) then 
     #    if (tmpOutHash[primaryKey] & tmpInpHash[keys[secondKey]])then
     #        tmp1 =tmpOutHash[primaryKey] & tmpInpHash[keys[secondKey]]   ### Set intersection operator
     #    end 
     #  end
        #### Uncomment the following 4 lines for Output-Output connetivity
        if (primaryKey != keys[secondKey] ) then   
        if (tmpOutHash[primaryKey] & tmpOutHash[keys[secondKey]])then
             tmp1 =tmpOutHash[primaryKey] & tmpOutHash[keys[secondKey]]
         end 
       end 
        ####Uncomment the following 4 lines to get Input-Input connectivity 
        #if (primaryKey != keys[secondKey])
         #if (tmpInpHash[primaryKey] & tmpInpHash[keys[secondKey]])then
         #    tmp1 =tmpInpHash[primaryKey] & tmpInpHash[keys[secondKey]]
         #end 
       #end
        #####   
        
         if (tmp1.length != 0 ) then 
           tmpA = tmp1 - commonSet    ## Set difference operator
         end
         if ( tmpA.length !=0  ) then 
             @connInpHash[primaryKey] = @connInpHash[primaryKey].push(keys[secondKey])
         end # end of if
       end  # end of for
     

      count = count+1
      primaryKey = keys[count]   
    end # end of while
    @connInpHash.each{|h,k| puts h, k.inspect, "\n"}
    #write_cyclo()
    write_und_file(newfilename)  ## drawing undirected graphs
    end


    ##############################################################    
    ## Makes the graph based on the modules instantiated
    #############################################################
    def hier_graph_create(filename)
   @@name_id = Hash.new 
    ### Making the name of the file from the parameter filename 
      newfilename= make_filename(filename) 
    ########################################################  

    ## Hierarchical Hash -- where the module are connected based on the instantiation
      load_cycloHash()  
      

      @hierHash=Hash.new
      @block.each do|key,value|
         @@name_id[value.name]= value.id 
         a=[]
         value.each_instance(){|y| a.push(y)}
         b = Array.new
         a.each {|val|  if(@block.has_key?(val)) then b.push(val) end}
         @hierHash[key] = b.uniq
      end # end of @lock.each do....
      xArr = Array.new
      @hierHash.each {|key, value|
      if (value.length > 0) then 
       xArr.concat(value) 
      end 
      }
      xArr.each{|key| 
       if (@hierHash.has_key?(key)) then 
         tmp =Array.new
          tmp = @hierHash[key]
          if (tmp.length === 0)  then
               @hierHash.delete(key) 
          end
       end  
     }

    write_file(newfilename)   ## Makes directed graph that must be called by dot
    @@name_id.each{|k,v| print k, ": ",v, "\n"}
    end
    
    #########################################################
    ##  Calls the dot command
    ##
    ########################################################
    def to_call_dot(filename)
        basename = File.basename(filename, ".dot")
        basename=basename+".ps"
       
       dot_command1="dot -Tps "+(filename)+ " -o "+basename
       system(dot_command1)
    end
    
    ##########################################################
    ## Depending on the cyclo complexity of the node, a color 
    ## is given to it.
    ######################################################### 
    

    def node_color(key)
    cyclo = @cycloHash[key] 
       case cyclo
          when 0..5  then color= "blue"
          when 6..10  then color= "green"
          when 11.. 20  then color="brown"
          when 21 .. 30  then color= "darkgreen"
          when 31 .. 40  then color= "yellow"
          when 41 .. 50  then color= "magenta"
          when 51 .. 100 then color= "cyan"
          else color = "red"
       end 
    return color 
    end
  
   #############################################################
   ## File to be called by dot for directed graph.
   ## dot -Tps filename.dot -o filename.ps
   ############################################################
   def write_file(filename)
    fname = filename
    filename=filename+".dot"
    File.open(filename, "w") do |aFile|

        aFile<<"digraph "<<fname<<"  {"<<("\n")
        aFile<<"size="<<OPENQ<<7.5<<","<<10<<OPENQ<<";"<<("\n")
        aFile<<"center="<<OPENQ<<"true"<<OPENQ<<";"<<("\n")
        #aFile<<"orientation="<<OPENQ<<"landscape"<<OPENQ<<";"<<("\n") 
        aFile<<"fontname="<<OPENQ<<"Helvetica"<<OPENQ<<";"<<("\n")
        @hierHash.each_pair do |key, val| 
               if (val.length == 0)  then 
                  aFile<<key+@@name_id[key].to_s<<";"<<("\n")
               else
                  # aFile<<" project"<<" -> "<<key+@@name_id[key].to_s<<";"<<("\n")
                   val.each{ |value| 
                             aFile <<key+@@name_id[key].to_s<<"->"<<value+@@name_id[value].to_s<<("\n")
                           } 
               end 
       end 
      aFile<<("}") 
    end 

    to_call_dot(filename)
   end  # end of write_file
   
   ##############################################################################
   ## Function that writes the .dot file for undirected graphs,
   ## to be used by neato
   #############################################################################


   def write_und_file(filename)
    fname = filename
    filename=filename+".dot"
    File.open(filename, "w") do |aFile|

        aFile<<"graph "<<fname<<"  {"<<("\n")
        aFile<<"size="<<OPENQ<<7.5<<","<<10<<OPENQ<<";"<<("\n")
        aFile<<"center="<<OPENQ<<"true"<<OPENQ<<";"<<("\n")
        aFile<<"overlap="<<OPENQ<<"scale"<<OPENQ<<";"<<("\n") 
        aFile<<"fontname="<<OPENQ<<"Helvetica"<<OPENQ<<";"<<("\n")
        @block.each_key do |key|
        aFile << key << "["<< "color" << "=" << node_color(key) <<","<<"style = filled"<<"]"<<("\n")
        end
        @connInpHash.each_pair do |key, val|
        print "From here"
               if (val.length == 0)  then
                  aFile<<key<<";"<<("\n")
              else
                   val.each{ |value|
                             aFile <<key<<"--"<<value<<("\n")
                           } 
               end 
       end 
      aFile<<("}")
    end 

    end
   

     ####################################################################################
     ##  Functions for gnuplot generation
     ##  Put all the module names, the year and cyclos in tmp file
     #####################################################################################
     def generate_tmp_dat_file(filename) 
       load_cycloHash()
       fname=make_filename(filename)	
       fname2 = fname 
       print "File name", fname, "\n"
       ##bname = fname.split(/_#\S#*/)
       #yname = bname[1].concat("_").concat(bname[2])
       #fname = bname[0].concat(".dat")
       fname = fname.concat(".dat")
       if (File.exist? fname) then
           mode = "a"
       else
           mode = "w"
       end 
       File.open(fname, mode) do |aFile|
              @cycloHash.each_pair do |key,val|
                  aFile<<key<<" "<<fname2<<" "<<val<<("\n")
              end # for the iterating through cycloHash

       end   ##closing the file 

     end

     #################################################################################
     ## Functions for gnuplot generation 2.
     ## From the above tmp dat file, make the hash for each module name and its key value will be 
     ## the year and corre. cyclo value.
     ################################################################################ 
     def generate_hash_from_file(filename) 
     @filehash = Hash.new { |h,k| k = String.new }
     fname = make_filename(filename)
     bname  = fname.split(/_\s*/)
     fname =  bname[0].concat(".dat")
      
       File.open(fname, "r") do |aFile|
                 # read each line
                 # get the year, cyclo and module name
                 # hash[module name] = year, cyclo
         while (line = aFile.gets)
              tmp = line.split()
           if (@filehash.has_key?(tmp[0])) then     
              @filehash[tmp[0]] = @filehash[tmp[0]]+","+(tmp[1]+","+tmp[2])
           else 
               @filehash[tmp[0]] = tmp[1]+","+tmp[2]
           end 
         tmp.clear()
         end  ##end of while  
       end    ## end for the file
     end

     ################################################################################
     ## Function for gnuplot generation 3 
     ## 
     ###############################################################################
     def generate_cyclo_dat_file(filename)
      yearArray = Array.new
       yearArray<<"2002_09"<<"2002_10"<<"2002_11"<<"2002_12"<<"2003_01"<<"2003_02"<<"2003_03"<<"2003_04"<<"2003_05"<<"2003_06"<<"2003_07"<<"2003_08"<<"2003_09"<<"2003_10"<<"2003_11"<<"2003_12"<<"2004_01"<<"2004_02"<<"2004_03"<<"2004_04"<<"2004_05"<<"2004_06"<<"2004_07"<<"2004_08"<<"2004_09"<<"2004_10"<<"2004_11"<<("2004_12")
         fname = make_filename(filename)
         bname = fname.split(/_\s*/)
         fname = bname[0].concat("_cyclo.dat")
         File.open(fname, "w") do |aFile|
         

          ##  First printed out the names of the modules in a comment statement

          aFile<<("#")
          @filehash.each_key{|k| aFile<<(" ")<<(k)}
          aFile<<("\n")   

          #Putting the cyclo complexity one by one 

         yrLength = yearArray.length
         count = 0
         valueCount = 0
         
       while (count <= yrLength )    
           aFile<<(count)
           @filehash.each_pair {|key,value| #print key, "\n"
            tmpvalue = String.new 
            tmpvalue=value.split(/,\s*/) 
            if (yearArray[count] == tmpvalue[valueCount]) then 
              #print "valueCount and count are equal::", key, ",",value[valueCount], yearArray[count], "\n" 
                 valueYr = tmpvalue[valueCount]  ## we take the year value and the cyclo value into variables.
                 tmpCount = valueCount+1
                 comp = tmpvalue[tmpCount]
                 tmpvalue.slice!(valueCount)
                 tmpvalue.slice!(valueCount)
                 value=tmpvalue.join(",") 
                 @filehash[key]=value 
                 aFile<<" "<<(comp)
           else 
              #print ":-(( valueCount and count are not equal::", key, ",", value[valueCount], yearArray[count], "\n" 
               aFile<<(" 0")
          end  #end for the if statement      
  
         } #end for the filehash
            count=count+1
            aFile<<("\n") 
       end  # end for while
     end #End of block for the file 
         
         generate_plot_command_file(fname)   ## This file should contain the gnuplot command, to copy paste from here :-) 
     end

    #########################################################################
    ## Second set of functions for gnuplot generation. 
    ## Prints out in a file that command that need to be used in gnuplot
    ########################################################################
    def generate_plot_command_file(filename) 
      hshLength = @filehash.length  
      hshKeys = Array.new
      hshKeys = @filehash.keys 
      keysCount =0
      count = 2
        File.open("plot_command.dat", "w") do |afile|
             
             afile<<"plot"<<SINGLEQ<<filename<<SINGLEQ<<" using 1:"<<count<<"  w linespoint ti "<<OPENQ<<hshKeys[keysCount]<<OPENQ<<(SEMIC)<<("\n")
             while (count <= hshLength)
               keysCount=keysCount+1
                  if (count == hshLength) then  
                     afile<<SINGLEQ<<filename<<SINGLEQ<<" using 1:"<<(count+1)<<" w linespoint ti "<<OPENQ<<hshKeys[keysCount]<<(OPENQ)
                  else
                     afile<<SINGLEQ<<filename<<SINGLEQ<<" using 1:"<<(count+1)<<" w linespoint ti "<<OPENQ<<hshKeys[keysCount]<<OPENQ<<(SEMIC)<<("\n")
                  end 
                  count = count+1
             end  ## end of while loop 
        end  ## end command for the file 
    end  ## plot command contained in this file
end  #Class Project End
end  # module BugParse end

