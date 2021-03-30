
module DesignSim

  # Company organization class.
  class Org

    def initialize()
    end

    # Parse the org.xml file to find the people available on the pool for hiring
    def parse!(xml)
    end

    # Look for a person with the best match to the following skills. All the
    # skills have the same importance
    def hire(skill)
    end

    # The project done by the person is done/cancelled. Add him/her again to the
    # pool of free people
    def fire(person)
    end
  end
end
