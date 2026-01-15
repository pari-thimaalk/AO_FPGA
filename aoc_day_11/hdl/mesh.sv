module mesh
import types::*;
import parameters::*;
(
    input logic clk,
    input logic rst,

    // local ports to banks
    input logic valid_in[MESH_DIMENSION][MESH_DIMENSION],
    output logic ready_in[MESH_DIMENSION][MESH_DIMENSION],
    input pkt_t in_pkt[MESH_DIMENSION][MESH_DIMENSION],
    output logic valid_out[MESH_DIMENSION][MESH_DIMENSION],
    input logic ready_out[MESH_DIMENSION][MESH_DIMENSION],
    output pkt_t out_pkt[MESH_DIMENSION][MESH_DIMENSION],

    // insert additional i/o port to [0][0] later
    input logic io_valid_in,
    output logic io_ready_in,
    input pkt_t io_in_pkt,
    output logic io_valid_out,
    input logic io_ready_out,
    output pkt_t io_out_pkt
);

    // internal signals between routers
    // only nsew, local handled via mesh i/o signals
    // [x][y][z] used for signals coming out of router at (x,y) from direction z
    logic valid_internal[MESH_DIMENSION][MESH_DIMENSION][NUM_PORTS-1];
    logic ready_internal[MESH_DIMENSION][MESH_DIMENSION][NUM_PORTS-1];
    pkt_t pkt_internal[MESH_DIMENSION][MESH_DIMENSION][NUM_PORTS-1];

    // instantiate mesh nodes
    genvar row, col;
    generate
        for (row = 0; row < MESH_DIMENSION; row = row + 1) begin : row_loop
            for (col = 0; col < MESH_DIMENSION; col = col + 1) begin : col_loop
                // Intermediate wires for this router instance
                logic router_valid_in[NUM_PORTS];
                logic router_ready_in[NUM_PORTS];
                pkt_t router_in_pkt[NUM_PORTS];
                logic router_valid_out[NUM_PORTS];
                logic router_ready_out[NUM_PORTS];
                pkt_t router_out_pkt[NUM_PORTS];
                
                // Connect inputs
                assign router_valid_in[NORTH] = (row > 0) ? valid_internal[row-1][col][SOUTH] : ((col == 0) ? io_valid_in : 1'b0);
                assign router_ready_out[NORTH] = (row > 0) ? ready_internal[row-1][col][SOUTH] : ((col == 0) ? io_ready_out : 1'b1);
                assign router_in_pkt[NORTH] = (row > 0) ? pkt_internal[row-1][col][SOUTH] : ((col == 0) ? io_in_pkt : '0);
                
                assign router_valid_in[SOUTH] = (row < MESH_DIMENSION-1) ? valid_internal[row+1][col][NORTH] : 1'b0;
                assign router_ready_out[SOUTH] = (row < MESH_DIMENSION-1) ? ready_internal[row+1][col][NORTH] : 1'b1;
                assign router_in_pkt[SOUTH] = (row < MESH_DIMENSION-1) ? pkt_internal[row+1][col][NORTH] : '0;
                
                assign router_valid_in[EAST] = (col < MESH_DIMENSION-1) ? valid_internal[row][col+1][WEST] : 1'b0;
                assign router_ready_out[EAST] = (col < MESH_DIMENSION-1) ? ready_internal[row][col+1][WEST] : 1'b1;
                assign router_in_pkt[EAST] = (col < MESH_DIMENSION-1) ? pkt_internal[row][col+1][WEST] : '0;
                
                assign router_valid_in[WEST] = (col > 0) ? valid_internal[row][col-1][EAST] : 1'b0;
                assign router_ready_out[WEST] = (col > 0) ? ready_internal[row][col-1][EAST] : 1'b1;
                assign router_in_pkt[WEST] = (col > 0) ? pkt_internal[row][col-1][EAST] : '0;
                
                assign router_valid_in[LOCAL] = valid_in[row][col];
                assign router_ready_out[LOCAL] = ready_out[row][col];
                assign router_in_pkt[LOCAL] = in_pkt[row][col];
                
                // Connect outputs
                assign valid_internal[row][col][NORTH] = router_valid_out[NORTH];
                assign ready_internal[row][col][NORTH] = router_ready_in[NORTH];
                assign pkt_internal[row][col][NORTH] = router_out_pkt[NORTH];

                if(row == 0 && col == 0) begin : if_loop
                    assign io_valid_out = router_valid_out[NORTH];
                    assign io_ready_in = router_ready_in[NORTH];
                    assign io_out_pkt = router_out_pkt[NORTH];
                end
                
                assign valid_internal[row][col][SOUTH] = router_valid_out[SOUTH];
                assign ready_internal[row][col][SOUTH] = router_ready_in[SOUTH];
                assign pkt_internal[row][col][SOUTH] = router_out_pkt[SOUTH];
                
                assign valid_internal[row][col][EAST] = router_valid_out[EAST];
                assign ready_internal[row][col][EAST] = router_ready_in[EAST];
                assign pkt_internal[row][col][EAST] = router_out_pkt[EAST];
                
                assign valid_internal[row][col][WEST] = router_valid_out[WEST];
                assign ready_internal[row][col][WEST] = router_ready_in[WEST];
                assign pkt_internal[row][col][WEST] = router_out_pkt[WEST];
                
                assign valid_out[row][col] = router_valid_out[LOCAL];
                assign ready_in[row][col] = router_ready_in[LOCAL];
                assign out_pkt[row][col] = router_out_pkt[LOCAL];
                
                router #(
                    .X_POS(col),
                    .Y_POS(row)
                ) router_inst (
                    .clk(clk),
                    .rst(rst),
                    .valid_in(router_valid_in),
                    .ready_in(router_ready_in),
                    .in_pkt(router_in_pkt),
                    .valid_out(router_valid_out),
                    .ready_out(router_ready_out),
                    .out_pkt(router_out_pkt)
                );
            end
        end
    endgenerate

    

endmodule