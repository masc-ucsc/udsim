#!/bin/bash

for a in 0 1 2 4 6 8 10 12 14 18 20 30; do
  RUBYLIB=. ruby -I../lib ../lib/UDSim.rb --seed 3 -k ${a} -n 10 -c -q -s 2.6 ../test/ivm.xml ../test/trend.xml ../test/people1.xml ../test/task.xml >pp
  echo -n $a"  " >>pp2
  grep average pp
  grep average pp >>pp2
done
