
module UDSim

  class Event
    attr_accessor:person;
    attr_accessor:task;
    attr_accessor:start_date;

    def initialize(person, task, start_date)
      @person     = person
      @task       = task
      @start_date = start_date
    end
  end

end
