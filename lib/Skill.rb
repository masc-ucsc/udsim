
module DesignSim

  # Skill that a person has or that a task requires
  class Skill

    # Skill type :PARTITION, :UNDERSTAND, :SPECIFY, :RTL_DESIGN, :RTL_VERIFY,
    # :BACK_DESIGN, :BACK_VERIFY
    attr_reader :type

    # Skill level. 1 is average on the industry for people that knows this, 0
    # sucks big time, 3 (x3 as productive as someone that knows)
    attr_reader :level

    def initialize()
    end

  end

end
