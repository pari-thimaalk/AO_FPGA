module router
import types::*;
import parameters::*;
#(
    parameter X_POS = 0,
    parameter Y_POS = 0
)(
    input logic clk,
    input logic rst,

    input logic valid_in[NUM_PORTS],
    output logic ready_in[NUM_PORTS],
    input pkt_t in_pkt[NUM_PORTS],
    output logic valid_out[NUM_PORTS],
    input logic ready_out[NUM_PORTS],
    output pkt_t out_pkt[NUM_PORTS]
);
    pkt_t in_pkts [NUM_PORTS]; // rx buffers for each cardinal direction + local
    pkt_t in_pkts_next [NUM_PORTS]; // rx buffers for each cardinal direction + local

    logic rx_valid [NUM_PORTS]; // rx valid signals
    logic rx_valid_next [NUM_PORTS]; // rx valid signals

    logic [$clog2(NUM_PORTS)-1:0] last_svced_dir; // last serviced direction
    logic [$clog2(NUM_PORTS)-1:0] dir_idx;

    logic [NUM_PORTS-1:0] pending_send_to; // which directions have packets pending to send
    logic [NUM_PORTS-1:0] pending_send_from;
    logic [$clog2(NUM_PORTS)-1:0] outgoing_dir; // temp signal

    always_ff @(posedge clk) begin
        if(rst) begin
            for(int i = 0; i < NUM_PORTS; i += 1) rx_valid[i] <= 1'b0;
            last_svced_dir <= '0;
        end else begin
            for(int i = 0; i < NUM_PORTS; i += 1) begin
                rx_valid[i] <= rx_valid_next[i];
                in_pkts[i] <= in_pkts_next[i];
            end
            last_svced_dir <= dir_idx;
        end
    end

    // try to send anything out first
    // then see if anything new can be received
    always_comb begin
        for (int i = 0; i < NUM_PORTS; i = i + 1) begin
            valid_out[i] = 1'b0;
            out_pkt[i] = '0;
            ready_in[i] = 1'b0;
        end

        for(int i = 0; i < NUM_PORTS; i += 1) begin
            in_pkts_next = in_pkts;
            rx_valid_next = rx_valid;
        end

        pending_send_to = '0;
        pending_send_from = '0;
        dir_idx = last_svced_dir;

        // send out packets if possible, until 1 no more or 
        // 2 a direction that wants to send but cannot
        for (int i = 0; i < NUM_PORTS; i = i + 1) begin
            dir_idx = (last_svced_dir + i) % NUM_PORTS;

            if(rx_valid[dir_idx]) begin
                // compute the outgoing direction
                if(in_pkts[dir_idx].ctrl == CTRL_DONE && X_POS == '0 && Y_POS == '0) begin outgoing_dir = NORTH; end
                else if(in_pkts[dir_idx].addr.x < X_POS) begin outgoing_dir = WEST; end
                else if(in_pkts[dir_idx].addr.x > X_POS) begin outgoing_dir = EAST; end
                else if(in_pkts[dir_idx].addr.y < Y_POS) begin outgoing_dir = NORTH; end
                else if(in_pkts[dir_idx].addr.y > Y_POS) begin outgoing_dir = SOUTH; end
                else begin outgoing_dir = LOCAL; end

                // if outgoing direction not ready or we are already
                // sending something to this direction, then break;
                if(pending_send_to[outgoing_dir]) continue;

                valid_out[outgoing_dir] = 1'b1;
                out_pkt[outgoing_dir] = in_pkts[dir_idx];

                if(ready_out[outgoing_dir]) begin
                    pending_send_from[dir_idx] = 1'b1;
                    pending_send_to[outgoing_dir] = 1'b1;
                end else begin
                    continue;
                end
            end
        end

        // check if in_pkts can be populated with anything new
        for(int i = 0; i < NUM_PORTS; i = i + 1) begin
            if(!rx_valid[i]) begin
                ready_in[i] = 1'b1;
                if(valid_in[i]) begin
                    in_pkts_next[i] = in_pkt[i];
                    rx_valid_next[i] = 1'b1;
                end
            end else begin
                // if(pending_send_from[i]) begin
                //     if(valid_in[i]) begin
                //         in_pkts_next[i] = in_pkt[i];
                //         ready_in[i] = 1'b1;
                //     end else begin
                if(pending_send_from[i]) begin
                    rx_valid_next[i] = 1'b0;
                end
                //     end
                // end
            end
        end
    end

    
endmodule