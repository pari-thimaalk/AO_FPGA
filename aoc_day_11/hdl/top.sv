module top 
import parameters::*;
import types::*;
(
    input logic clk,
    input logic rst,
    input logic io_valid_in,
    output logic io_ready_in,
    input pkt_t io_in_pkt,
    output logic io_valid_out,
    input logic io_ready_out,
    output pkt_t io_out_pkt
);

    logic mesh_valid_in[MESH_DIMENSION][MESH_DIMENSION];
    logic mesh_ready_in[MESH_DIMENSION][MESH_DIMENSION];
    pkt_t mesh_in_pkt[MESH_DIMENSION][MESH_DIMENSION];
    logic mesh_valid_out[MESH_DIMENSION][MESH_DIMENSION];
    logic mesh_ready_out[MESH_DIMENSION][MESH_DIMENSION];
    pkt_t mesh_out_pkt[MESH_DIMENSION][MESH_DIMENSION];

    genvar row,col;
    generate
        for(row = 0; row < MESH_DIMENSION; row++) begin : bank_row
            for(col = 0; col < MESH_DIMENSION; col++) begin : bank_col
                bank #(
                    .X_POS(col),
                    .Y_POS(row)
                    ) bank_inst (
                    .clk,
                    .rst,

                    // bank router output = mesh local input
                    .router_valid_out(mesh_valid_in[row][col]),
                    .router_ready_out(mesh_ready_in[row][col]),
                    .router_out_pkt(mesh_in_pkt[row][col]),

                    // mesh local output = bank router input
                    .router_valid_in(mesh_valid_out[row][col]),
                    .router_ready_in(mesh_ready_out[row][col]),
                    .router_in_pkt(mesh_out_pkt[row][col])
                );
            end
        end
    endgenerate

    mesh mesh_inst(
        .clk,
        .rst,

        .valid_in(mesh_valid_in),
        .ready_in(mesh_ready_in),
        .in_pkt(mesh_in_pkt),
        .valid_out(mesh_valid_out),
        .ready_out(mesh_ready_out),
        .out_pkt(mesh_out_pkt),

        .io_valid_in,
        .io_ready_in,
        .io_in_pkt,
        .io_valid_out,
        .io_ready_out,
        .io_out_pkt
    );

endmodule