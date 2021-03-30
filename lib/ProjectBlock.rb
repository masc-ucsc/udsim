#ProjectBlock.rb
# Project Node state

module UDSim
  class ProjectBlock
    attr_accessor :name
    attr_accessor :cyclo
    attr_accessor :nNodes
    attr_accessor :nCaseStmts
    attr_accessor :nCaseItems
    attr_accessor :nStmts
    attr_accessor :nLoops
    attr_accessor :nIfStmts
    attr_accessor :nAlwaysClocks
    attr_accessor :nBAssign
    attr_accessor :nNBAssign
    attr_accessor :nWAssign

    attr_accessor :loc

    attr_accessor :id
    #    attr_accessor :num_ports
    attr_accessor :is_assigned
    attr_accessor :tot_loc
    attr_accessor :tot_cyclo

    @@counter = 1
    @@tot_loc = 0
    @@tot_cyclo = 0
    def initialize(block)
      @name = block.attributes["name"]
      @id = @@counter
      @@counter+=1
      #      @num_ports = 0

      #      @input = Array.new
      #      block.elements.each("input") { |input|
      #        @input << input.attributes["name"]
      #      }

      #      @output = Array.new
      #      block.elements.each("output") { |input|
      #        @output << input.attributes["name"]
      #      }

      @instance = Array.new
      block.elements.each("instance") {|input|
        @instance << input.attributes["name"]
      }

      #      @param = Array.new
      #      block.elements.each("param") { |input|
      #        @param << input.attributes["name"]
      #      }

      @cyclo = nil
      block.elements.each("complexity") { |input|
        UDSim::error "Multiple complexity sections on block #{@name}" if @cyclo
        ## @cyclo = input.attributes["cyclo1"].to_i + input.attributes["cyclo2"].to_i
        @cyclo = input.attributes["cyclo2"].to_i
        @nIfStmts = input.attributes["nIfStmts"].to_i
        @nCaseStmts = input.attributes["nCaseStmts"].to_i
        @nCaseItems = input.attributes["nCaseItems"].to_i
        @nLoops = input.attributes["nLoops"].to_i
      }

      @nNodes = nil
      block.elements.each("volume") { |input|
        UDSim::error "Multiple volume sections on block #{@name}" if @nNodes
        @nNodes = input.attributes["nNodes"].to_i
        @nStmts = input.attributes["nStmts"].to_i
        @nAlwaysClocks = input.attributes["nAlwaysClocks"].to_i
        @nBAssign = input.attributes["nBAssign"].to_i
        @nNBAssign = input.attributes["nNBAssign"].to_i
        @nWAssign = input.attributes["nWAssign"].to_i
        @nOthers = input.attributes["nOther"].to_i

        #        nInputs  = input.attributes["nInputs"].to_i
        #        if nInputs != @input.size()
        #          UDSim::error "number inputs do not match #{nInputs} vs #{@input.size()} on block #{@name}"
        #        else
        #          @num_ports = @num_ports+nInputs
        #        end
        #        nOutputs = input.attributes["nOutputs"].to_i
        #        if nOutputs != @output.size()
        #          UDSim::error "number outputs do not match #{nOutputs} vs #{@output.size()} on block #{@name}"
        #        else
        #          @num_ports = @num_ports+nOutputs
        #        end
      }

      @loc = @nStmts+@nAlwaysClocks+@nBAssign+@nNBAssign+@nWAssign+@nCaseStmts+@nIfStmts+@nOthers+@nCaseItems+@nLoops;

      @is_assigned = false;
      @@tot_cyclo = @@tot_cyclo+@cyclo
      @@tot_loc = @@tot_loc+each_loc  ## prints total loc or loc of the entire project
      #  print name , "    ", "total loc::", @@tot_loc, "tot cyclo::", @@tot_cyclo, "\n"
    end

    def each_loc()
      return @loc
    end

    def nname()
      @name
    end

    #   def each_input()
    #     @input.each { |i|
    #       yield i
    #      }
    #   end

    #   def each_output()
    #     @output.each { |i|
    #        yield i
    #      }
    #   end

    #   def each_param()
    #      @param.each { |i|
    #        yield i
    #      }
    #   end

    #    def each_nStmts()
    #      @nStmts
    #    end

    #    def each_num_ports()
    #        @num_ports
    #    end

    def each_instance()
      @instance.each { |i|
        yield i
      }
    end

    def each_id()
      @id
    end

    def ProjectBlock.tot_cyclo
      @@tot_cyclo
    end
    def ProjectBlock.tot_loc
      @@tot_loc
    end
  end
end
