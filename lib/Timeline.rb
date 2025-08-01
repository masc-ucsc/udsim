
require 'date'
require "Person"
require "thread"
require "Event"
require "People"
require "singleton"

module UDSim

  class WorkDate
    attr_reader :day

    def adjust()
      while @hour > 17
        @hour = @hour - 8 ## 8 hour working day
        @day = @day + 1
      end
# No need to worry about weekends. Just report "Worked days ~20 month"
#         wday = @day % 7
#         if wday == 5
#           @day = @day + 2
#           @hour = 9
#         elsif wday == 6
#           ## Just in the weird case that someone skipped the Saturday test (new worker?)
#           @day = @day + 1
#           @hour = 9
#         end
#       end
#      while @hour < 0
#        @hour = @hour + 24
#        @day = @day - 1
#        if @day < 0
#          @day = 5
#        end
#      end
    end

    def initialize(d=0,h=0)
      @day  = d
      @hour = h
      adjust()
    end

    def next_work_hour()
      t=WorkDate.new(@day,@hour+1)
      return(t)
    end

    def to_date()
      ## "%Y-%m-%d"
      start_date = Date.parse("Mon Nov 12 9:00:00 PST 2007")
      d = start_date + @day
      return d.strftime("%Y-%m-%d")
    end

    def to_month
      start_date = Date.parse("Mon Nov 12 9:00:00 PST 2007")
      d = start_date + @day
      return d.strftime("%Y-%m")
    end

    def to_s()
      return "#{@day} #{@hour}"
    end

    def to_i()
      return (@day*8+@hour).to_i
    end

    def to_f()
      return @day*8.0+@hour
    end

    def <(ndate)
      return to_i() < ndate.to_i()
    end

    def <=(ndate)
      return to_i() <= ndate.to_i()
    end

    def >(ndate)
      return to_i() > ndate.to_i()
    end

    def <=>(ndate)
      return  1 if to_i() > ndate.to_i()
      return -1 if to_i() < ndate.to_i()
      return  0
    end

    def +(val)
      return(WorkDate.new(@day,@hour+val))
    end

    def -(val)
      return(WorkDate.new(@day,@hour-val.to_f))
    end
  end

  class Timeline
    include Singleton

    def initialize
      @current_date = WorkDate.new
      @list         = Array.new
      # Choose a random (but systematic) starting date
      @active_tasks = Array.new
      reset()
    end

    def to_s()
      return "date:#{@current_date} list:#{@list.lenght}"
    end

    def reset

      @current_date = WorkDate.new
      @current_date = @current_date + 1.0
      @start_date   = @current_date
    end
    def workdate
      return @current_date
    end

   def add_work(task)
     time = task.person.schedule_hour()
     event = Event.new(task.person, task, time)
     @list.push(event);
     @list = @list.sort_by { |k|
       k.start_date
     }
##     puts @current_date.strftime("%d/%m/%y %I%p") + "----" + time.strftime("%d/%m/%y %I%p")
   end

   def do_next_event()

     event = @list.first
     return 0 unless event.start_date <= @current_date
     @list.delete_at(0)
     conta = 0
     while true
       conta = conta + event.person.do_work(event.task)
       event = @list.first
       break unless event and event.start_date <= @current_date
       @list.delete_at(0)
     end

     #$people.add_people_late
     return conta
   end

   def run(limit_hours)
     conta = 0
     while limit_hours > @current_date.to_i
       conta = conta + do_next_event()
#       if conta > 0 and !@list.empty?() and @current_date.day != @list.first.start_date.day
##         puts @current_date.to_s +  ",#{conta}"
#         conta = 0
#       end

       ## Simulation finished
       break if (@list.empty?())

       event = @list.first
       @current_date = event.start_date
     end

     return conta
   end
  end
end
