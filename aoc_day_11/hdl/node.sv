module node
import types::*;
import parameters::*;
(
    input logic clk,
    input logic rst,

    input valid_in,
    output logic ready_in,
    input pkt_t in_pkt,

    output logic valid_out,
    input ready_out,
    output pkt_t out_pkt
);
    logic you;
    logic start;

    logic [MAX_PATHS_BITS-1:0] sum_reg;

    // +1 for num_children/parent to distinguish zero vs full case
    logic [$clog2(MAX_CHILDREN)-1:0] num_children_pending, num_children_pending_next;
    
    logic [$clog2(MAX_EDGES_IOO+1)-1:0] num_parents, num_parents_next;
    logic [MAX_EDGES_IOO-1:0] parents_pending, parents_pending_next;
    logic [MAX_NODES_BITS-1:0] parent_array [MAX_EDGES_IOO];
    logic [MAX_NODES_BITS-1:0] parent_array_next [MAX_EDGES_IOO];

    // need state to keep track of which parents have been sent to
    typedef enum logic {
        WAITING_FOR_CHILDREN,
        SENDING_TO_PARENTS
    } state_t;
    
    state_t state, state_next;

    always_ff @(posedge clk) begin
        if(rst) begin
            state <= WAITING_FOR_CHILDREN;
            sum_reg <= '0;

            num_children_pending <= '0;
            num_parents <= '0;
            parents_pending <= '0;

            you <= 1'b0;
            start <= '0;
        end else begin
            state <= state_next;
            sum_reg <= sum_reg + ((state == WAITING_FOR_CHILDREN && valid_in && in_pkt.ctrl == CTRL_SUM) ? in_pkt.data.sum_t.value : ((valid_in && in_pkt.ctrl == CTRL_CONFIG && in_pkt.data.config_t.num_children == 0) ? {{MAX_PATHS_BITS-1{1'b0}}, 1'b1} : {MAX_PATHS_BITS{1'b0}}));

            if(you == 0 && valid_in && (in_pkt.ctrl == CTRL_CONFIG) && in_pkt.data.config_t.is_you) you <= 1'b1;

            num_children_pending <= num_children_pending_next;
            num_parents <= num_parents_next;
            parents_pending <= parents_pending_next;
            start <= start | (valid_in && in_pkt.ctrl == CTRL_CONFIG);

            for(int i = 0; i < MAX_EDGES_IOO; i = i + 1) begin
                parent_array[i] <= parent_array_next[i];
            end
        end
    end

    always_comb begin
        state_next = state;

        num_children_pending_next = num_children_pending;
        num_parents_next = num_parents;
        parents_pending_next = parents_pending;

        for(int i = 0; i < MAX_EDGES_IOO; i = i + 1) begin
            parent_array_next[i] = parent_array[i];
        end

        ready_in = 1'b0;
        valid_out = 1'b0;
        out_pkt = '0;

        case(state)
            WAITING_FOR_CHILDREN: begin
                ready_in = 1'b1;

                if(valid_in) begin
                    case(in_pkt.ctrl)
                        CTRL_CONFIG: begin
                            num_children_pending_next = in_pkt.data.config_t.num_children;
                        end

                        CTRL_PARENTS: begin
                            num_parents_next = num_parents + (in_pkt.data.parents_t.num_edges == 0 ? MAX_EDGES_PER_LOAD : in_pkt.data.parents_t.num_edges);

                            for(int i = 0; i < MAX_EDGES_PER_LOAD; i = i + 1) begin
                                if(in_pkt.data.parents_t.num_edges == 0 || (i < in_pkt.data.parents_t.num_edges)) begin // if num_edges == 0, is an overflow case
                                    parent_array_next[num_parents + i] = in_pkt.data.parents_t.edges[i].node_id;
                                    parents_pending_next[num_parents + i] = 1'b1;
                                end
                            end
                        end

                        CTRL_SUM: begin
                            num_children_pending_next = (num_children_pending > 0) ? num_children_pending - 1 : 0;
                        end

                        default: begin
                            // sum is handled in sequential block
                        end
                    endcase
                end

                if(num_children_pending_next == 0 && start) begin
                    state_next = SENDING_TO_PARENTS;
                end
            end

            SENDING_TO_PARENTS: begin
                if(you) begin
                    // send out solution
                    valid_out = 1'b1;
                    out_pkt.ctrl = CTRL_DONE;
                    out_pkt.data.sum_t.value = sum_reg;
                end else if(num_parents > 0) begin
                    valid_out = 1'b1;
                    out_pkt.ctrl = CTRL_SUM;
                    out_pkt.addr.x = parent_array[num_parents - 1] / (NODES_PER_BANK * MESH_DIMENSION);
                    out_pkt.addr.y = (parent_array[num_parents - 1] / NODES_PER_BANK) % MESH_DIMENSION;
                    out_pkt.addr.z = parent_array[num_parents - 1] % NODES_PER_BANK;
                    out_pkt.data.sum_t.value = sum_reg;

                    if(ready_out == 1'b1) begin
                        num_parents_next = num_parents - 1;
                    end
                end
            end
        endcase
    end
endmodule