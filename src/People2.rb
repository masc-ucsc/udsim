require_relative 'Person2'
require 'rexml/document'

module UDSim
  # People2 - Simple collection of Person2 instances
  # Replaces the complex People class with basic functionality
  # Supports XML parsing to read people configuration
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

    # Parse people XML file
    def parse!(xml_doc)
      xml_doc.elements.each('people/person') do |person_element|
        name = person_element.attributes['name'] || 'Engineer'
        num = person_element.attributes['num']&.to_i || 1
        
        num.times do |i|
          person_name = num > 1 ? "#{name}#{i+1}" : name
          person = Person2.new(person_name)
          @people << person
        end
      end
      puts "People2: Parsed #{@people.length} people from XML" if $op_verbose
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