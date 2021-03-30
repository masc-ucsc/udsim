require 'rexml/document'
require 'singleton'

module UDSim

  # A task is a sub-project being performed by a single person
  class Trend
    #-------------------------------------------
    #-------------------------------------------
    private

    #-------------------------------------------
    def gaussian_rand
      #      begin
      u1 = u2 = w = g1 = g2 = 0  # declare
      begin
        u1 = 2 * rand - 1
        u2 = 2 * rand - 1
        w = u1 * u1 + u2 * u2
      end while w >= 1

      w = Math::sqrt( ( -2 * Math::log(w)) / w )
      g2 = u1 * w;
      g1 = u2 * w;
      #      end while (g1 < 0)
      return g1
    end

    #-------------------------------------------
    #-------------------------------------------
    public

    attr_accessor :trigger
    attr_accessor :up
    attr_accessor :down
    attr_accessor :set

    #-------------------------------------------
    def initialize(block)
      @trigger   = block.attributes["trigger"]
      if (@trigger == "learn")
        block.elements.each('up') {|up|
          @hours = up.attributes["hours"].to_f
          @max   = up.attributes["max"].to_f
        }
      elsif(@trigger == "sync" || @trigger == "async" || @trigger == "defect" )
        block.elements.each('set_mu') {|set|
          @mu    = set.attributes["mu"].to_f
          @sigma = set.attributes["sigma"].to_f
        }
        if @mu > 1
          puts "ERROR: this is never going to finish. Undo due to defects should be under 1 hour per hour"
          exit(-3)
        end
      elsif(@trigger=="productivity" || @trigger == "meeting" || @trigger == "teamsize")
        block.elements.each('set_mu') {|set|
          @mu    = set.attributes["mu"].to_f
          @sigma = set.attributes["sigma"].to_f
        }
      else
        puts "ERROR: unknown trend to track " + @trigger
        exit(-3)
      end
    end

    def adjust_skill(experience)
      return 1 if ($op_dummy)
      return @max if (experience > @hours or not $op_learn)

      return (1+(@max-1)*experience/@hours)
    end

    def random_gaussian
      return (gaussian_rand * @sigma + @mu)
    end

  end


  class TrendType

    def initialize()
      @@trend  = Hash.new
    end

    def parse!(xml)
      # Each block
      xml.elements.each("trend/trendtype"){ |y|
        att =  Trend.new(y)
        @@trend[att.trigger] = att
      }
      puts "Trend: done"  if $op_verbose
    end

    def get_trend(trigger)
      return @@trend[trigger]
    end
  end
end
