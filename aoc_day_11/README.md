# AOC Day 11 Solution (Part 1 only)
### Test Instructions
The testbench is located in ```hvl/top_tb.sv```. Other files within the ```hvl/``` folder are testbenches I used for unit testing individual components. To run the testbench:

```bash
    cd aoc_day_11/sim
    make run_top_tb
```

There are 3 testcases in this repo - one is the small example given, the other two are inputs given on the Advent of Code website for two separate accounts that I created.

### Tools
I used Synopsys VCS to run RTL simulations and Spyglass to check for lint errors such as combination loops. The linter scripts (in ```lint/```) are adapted from template code from UIUC's ECE411 class, all other scripts are my own. All HDL sources and testbenches are my own work.

I synthesized my design by copying all the files in ```hdl/``` and ```pkg/types.sv``` into Vivado.

### Algorithm
My architecture essentially does topological traversal of the vertices in the DAG. I chose this approach over DFS traversal as it naturally supports more parallel computations, and because it scales better as the number of paths in the graph increases. A DFS approach scales badly as the graph becomes more dense, with a runtime complexity to the tune of O(V!) in the worst case. A topological sort traversal scales better as each vertice is only crossed once, once all its parent vertices have been crossed, giving approximately a O(V) runtime in the worst case. Furthermore, vertices that are at the same topological level in the graph can have their paths counted independently, as they are not dependent on each other.

A small tweak I do is that I construct a reverse DAG by making a reverse adjacency list and then do topological traversal. This is because "out" is the only sink in the original graph, making it easier and faster to start the algorithm from, as opposed to "you" which is a vertice in the middle of the graph. Starting from "out", we do a topological traversal, and at each vertice do the following calculation

$ P(n) =  \sum_{i=1}^{c} P(n_i) $

where P(n) is the number of paths from vertice n to "out", and $n_i$ is the ith child (child in the original graph, parent in the reverse graph) of vertice n. We repeat this process until we reach "you", at which point the design outputs the solution.

The design supports the construction of a reverse graph in hardware (with some minor tweaks to the functional units), but I chose to do this in the testbench to reduce program loading time.

### Architecture

The architecture consists of nodes/functional units in a network on chip (NOC) organized at two levels of hierarchy - bank level and router level. Each node represents a vertice in the graph, and nodes within the same bank are connected by a "bus". Banks are connected to one another via a 2d-mesh of routers. This is done to reduce fanout at the node level, and address timing/dynamic power concerns as the scale of the graph increases. Ideally, all the nodes would be connected on a single wide bus to maximize parallelism and reduce latency but this is not practical.

The design is parametrizable, currently it is sized as a 5x5 mesh, and each router in it has a local port connecting to a bank of 32 nodes. This supports 25*32 = 800 nodes, which supports the ~500 nodes that are given in the problem with some additional space for normalization.

Each node contains the following information about the vertice
- a counter representing the number of children it needs to hear from
- an array of parents to which it needs to send its path count to, once it has heard from all its children
- a bit representing whether the node is "you", in which case it needs to send a packet to the i/o interface with the path count instead of sending to its parents

Each router has 4 ports in the cardinal directions, and a local port to its bank of nodes. (0,0) is at the top left corner and (n-1,n-1) is at the bottom right, where n is the dimension length of the square mesh. The I/O interface is tied to the North port of the router at (0,0), since this port would be unused otherwise anyways.

### Testbench
The testbench does a single pass through the puzzle input and constructs a reverse adjacency list. It also does normalization, by introducing "intermediary" vertices for vertices that have too many incoming parents - this is done to cap the number of parent edges into any vertice, and allowing for efficient sizing/usage of the parent array in the node.

It then passes the reverse adjacency list into the design, one node at a time. In theory, there is enough I/O bandwidth on most FPGAs to insert an additional I/O port to halve the program loading time.

### Improvements
As there is no register at the bank stage, the combinational path from the router's local port to the functional units is quite long and hurts the WNS significantly. The number of functional units at the bank level also needs to be reduced to further improve timing on this path.

The current design does not use BRAM, which results in poor resource utilization if synthesized on an FPGA (high LUT utilization and low BRAM utilization) as opposed to an ASIC. For an FPGA centred design, the parent array inside a functional unit could be stored in BRAM instead, since a vertice only sends its sum to one parent at a time.

To solve Part 2, the FSM of the node needs to be tweaked slightly, but the mesh router and bank architecture can be preserved wholesale.
