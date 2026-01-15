package parameters;
    localparam int NODES_PER_BANK = 32;
    localparam int MESH_DIMENSION = 5;

    localparam int MAX_NODES = NODES_PER_BANK * MESH_DIMENSION * MESH_DIMENSION;
    localparam int MAX_NODES_BITS = $clog2(MAX_NODES);

    localparam int MAX_EDGES_PER_LOAD = 4;

    localparam int MAX_PATHS_BITS = MAX_NODES_BITS * MAX_EDGES_PER_LOAD + $clog2(MAX_EDGES_PER_LOAD);
    localparam int MAX_PATHS = 2 ** MAX_PATHS_BITS;

    localparam int MAX_EDGES_IOO = 8; // this should be renamed to max_num_parents
    localparam int MAX_CHILDREN = 36; // no real limit on this beyond pure area concerns in storing the number of children

    localparam int NUM_PORTS = 5; // nsew + local

    localparam int NORTH = 0;
    localparam int SOUTH = 1;
    localparam int EAST  = 2;
    localparam int WEST  = 3;
    localparam int LOCAL = 4;
endpackage

package types;
    import parameters::*;

    typedef enum logic [1:0]{
        CTRL_CONFIG,
        CTRL_PARENTS,
        CTRL_SUM,
        CTRL_DONE
    } ctrl_t;

    typedef struct packed {
        logic [MAX_NODES_BITS-1:0] node_id;
    } edge_channel_t;

    typedef union packed {
        struct packed {
            logic [MAX_PATHS_BITS-1:0] value;
        } sum_t;

        struct packed {
            logic is_you;
            logic [MAX_PATHS_BITS-2:0] num_children; // all union members need to be same bit length in packed type
        } config_t;

        struct packed {
            edge_channel_t [MAX_EDGES_PER_LOAD-1:0] edges;
            logic [$clog2(MAX_EDGES_PER_LOAD)-1:0] num_edges;
        } parents_t;  // max edges per load * max_nodes_bits + num_edges bits
    } data_u;

    typedef struct packed {
        logic [$clog2(MESH_DIMENSION)-1:0] x;
        logic [$clog2(MESH_DIMENSION)-1:0] y;
        logic [$clog2(NODES_PER_BANK)-1:0] z;
    } addr_t;

    typedef struct packed {
        addr_t addr;
        ctrl_t ctrl;
        data_u data;
    } pkt_t;
    
endpackage