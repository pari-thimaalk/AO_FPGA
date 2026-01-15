module bank
import types::*;
import parameters::*;
#(
    parameter X_POS = 0,
    parameter Y_POS = 0
)(
    input logic clk,
    input logic rst,

    // from router
    input router_valid_in,
    output logic router_ready_in,
    input pkt_t router_in_pkt,

    // to router
    output logic router_valid_out,
    input router_ready_out,
    output pkt_t router_out_pkt
);

    // intf signals for each fu
    logic [NODES_PER_BANK-1:0] valid_in;
    logic [NODES_PER_BANK-1:0] ready_in;
    pkt_t in_pkt [NODES_PER_BANK];
    logic [NODES_PER_BANK-1:0] valid_out;
    logic [NODES_PER_BANK-1:0] ready_out;
    pkt_t out_pkt [NODES_PER_BANK];

    logic [NODES_PER_BANK-1:0] rr_select_reg, rr_select_reg_next;   // registered value of the last svced node
    logic [NODES_PER_BANK-1:0] recvd;    // which nodes have received data this cycle

    logic [NODES_PER_BANK-1:0] rr_idx;

    always_ff @(posedge clk) begin
        if(rst) begin
            rr_select_reg <= '0;
        end else begin
            rr_select_reg <= rr_select_reg_next;
        end
    end

    // if there is something on router input, send that first
    // otherwise round robin between nodes
    always_comb begin
        router_ready_in = 1'b1; // ready not dependent on valid
        router_valid_out = 1'b0;
        router_out_pkt = '0;

        valid_in = '0;
        for(int i = 0; i < NODES_PER_BANK; i = i + 1) begin
            in_pkt[i] = '0;
        end
        ready_out = '0;

        recvd = '0;
        rr_select_reg_next = rr_select_reg;
        
        if(router_valid_in) begin
            valid_in[router_in_pkt.addr.z] = 1'b1;
            in_pkt[router_in_pkt.addr.z] = router_in_pkt;
            recvd[router_in_pkt.addr.z] = 1'b1;
        end 

        // stop when there is a fu trying to send but cannot bc a previous fu alr sent to the same address
        for(int i = 0; i < NODES_PER_BANK; i = i + 1) begin
            rr_idx = (i + rr_select_reg) % NODES_PER_BANK;
            if(valid_out[rr_idx]) begin
                rr_select_reg_next = rr_idx;
                if(out_pkt[rr_idx].ctrl == CTRL_DONE || out_pkt[rr_idx].addr.x != X_POS || out_pkt[rr_idx].addr.y != Y_POS) begin
                    if(router_valid_out) continue;
                    router_valid_out = 1'b1;
                    router_out_pkt = out_pkt[rr_idx];
                    if(!router_ready_out) continue; // we want to keep trying to send this until it succeeds so program can end swiftly
                    ready_out[rr_idx] = 1'b1;
                end else begin
                    if(recvd[out_pkt[rr_idx].addr.z]) break;
                    ready_out[rr_idx] = 1'b1;
                    valid_in[out_pkt[rr_idx].addr.z] = 1'b1;
                    in_pkt[out_pkt[rr_idx].addr.z] = out_pkt[rr_idx];
                    recvd[out_pkt[rr_idx].addr.z] = 1'b1;
                end
            end
        end
    end

    genvar i;
    generate
        for(i = 0; i < NODES_PER_BANK; i = i + 1) begin : nodes
            node node_inst (
                .clk        (clk),
                .rst        (rst),

                .valid_in   (valid_in[i]),
                .ready_in   (ready_in[i]),
                .in_pkt     (in_pkt[i]),

                .valid_out  (valid_out[i]),
                .ready_out  (ready_out[i]),
                .out_pkt    (out_pkt[i])
            );
        end
    endgenerate

endmodule