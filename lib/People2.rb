require_relative 'Person2'

module UDSim
  # People2 - Simple collection of Person2 instances
  # Replaces the complex People class with basic functionality
  # No XML parsing needed - creates standard set of people
  class People2
    def initialize
      @people = []
    end

    def add_person(person)
      @people << person
    end

    def all_people
      @people
    end

    def reset
      @people.each { |person| person.current_task = nil }
    end

    # Create a standard set of people for simulation
    def create_standard_people(count = 4)
      @people.clear
      count.times do |i|
        person = Person2.new("Engineer#{i+1}")
        @people << person
      end
      puts "People2: Created #{@people.length} people" if $op_verbose
    end

    # Compatibility methods for existing code
    def manager_hierarchy
      # No hierarchy in simplified model
    end

    def length
      @people.length
    end
    
    def empty?
      @people.empty?
    end

    # Class methods for compatibility with existing People class usage
    def self.active_people
      # In simplified model, all people are active
      []
    end

    def self.num_of_people
      4 # Default number of people
    end
  end
end