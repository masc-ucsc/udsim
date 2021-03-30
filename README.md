
## UDSim: User Design Simulator

This is the simulator used by [1] and [2]. The simulator includes data gathered from several projects. More details on the papers.


The simulation works like a montecarlo model. Each run, will randomly create some possible evolution. The goal is to run it many times and
see the project spread. A sample setup is create in the run directory. To execute it:

```
cd run
./getdata.sh
```

WARNING/TODO: The code includes a "precompiled" metis binary for Linux. It would be MUCH nicer if we patch metis to compile easily in the latest gcc compilers and remove the binaries.


[1]: uDSim, a Microprocessor Design Time Simulation Infrastructure. Sangeetha Sudhakrishnan, Francisco-Javier Mesa-Martinez, Jose Renau, Wild and Crazy Ideas VI (WACI) held in conjunction with ASPLOS, March 2008. 

[2]: A Design Time Simulator for Computer Architects, Sangeetha Sudhakrishnan, Francisco J. Mesa-Martinez, and Jose Renau, IEEE International Symposium on Quality Electronic Design (ISQED), March 2011. (Best paper award) 

