module top_tb;
    /*
        verifies top design, mesh + bank
    */

    // Standard testbench variables----
    timeunit 1ns;
    timeprecision 1ns;

    bit clk;
    initial clk = 1'b1;
    always #1 clk = ~clk;

    bit rst;
    task do_reset();
        rst = 1'b1;
        repeat (4) @(posedge clk);
        rst <= 1'b0;
    endtask : do_reset

    int timeout = 5500;
    //----------------------------------

    import types::*;
    import parameters::*;

    // Global variables for program loading
    int node_ctr;
    int name_map[string]; // xxx -> node id
    int num_children [string];
    string r_adj_list [string][$];

    // for verification/debugging
    int v_num_children [string]; // should start out as num_children. then decrement for every valid/ready handshake
    bit v_started_sending_out[string];
    string v_rname_map[int];

    logic io_valid_in;
    logic io_ready_in;
    pkt_t io_in_pkt;
    logic io_valid_out;
    logic io_ready_out;
    pkt_t io_out_pkt;

    top dut (
        .*
    );

    function automatic void parse_file(input string filename);
        int fd;
        string line;
        string cur_node, children, cur_child;
        string edges[$];
        int status;

        // variable for graph normalization
        int num_temps;

        fd = $fopen(filename, "r");
        if (fd == 0) begin
            $error("Failed to open file: %s", filename);
            return;
        end

        while (!$feof(fd)) begin
            line = "";
            status = $fgets(line, fd);

            if (status <= 0) begin
                $error("Failed to read line from file: %s", filename);
                break;
            end
            if (status == 0) break;

            cur_node = line.substr(0, 2);

            // remove trailing \n if it exists
            children = line.substr(4);
            if (children.len() > 0 && children[children.len()-1] == "\n") begin
                children = children.substr(0, children.len()-2);
            end

            // tokenize children by space
            for(int i = 0; i < children.len(); i++) begin
                if (children[i] == " ") begin
                    if (cur_child.len() > 0) begin
                        edges.push_back(cur_child);
                        cur_child = "";
                    end
                end else begin
                    cur_child = {cur_child, children.getc(i)};
                end
            end

            edges.push_back(cur_child); cur_child = ""; // add last child

            // Process the line as needed
            // $display("Read line: %s", line);
            // $display("Current Node: %s", cur_node);
            if(name_map.exists(cur_node) == 0) begin
                name_map[cur_node] = node_ctr;
                node_ctr = node_ctr + 1;
            end
            foreach (edges[i]) begin
                num_children[cur_node] += 1;
                r_adj_list[edges[i]].push_back(cur_node);
                // $display("  Edge to: %s", edges[i]);
                if(name_map.exists(edges[i]) == 0) begin
                    name_map[edges[i]] = node_ctr;
                    node_ctr = node_ctr + 1;
                end
            end
            edges.delete();
        end

        // normalize graph, if more than MAX_EDGES_IOO neighbours, add intermediary node
        // pop first MAX_EDGES_IOO in queue, add as parents/"child" of intermediary node, queue back intermediary node into the original node. repeat until original node has MAX_EDGES_IOO or less
        foreach(r_adj_list[node]) begin
            num_temps = 0;
            while(r_adj_list[node].size() > MAX_EDGES_IOO) begin
                string temp_name = $sformatf("temp_%s_%0d", node, num_temps);
                for(int i = 0; i < MAX_EDGES_IOO; i++) begin
                    r_adj_list[temp_name].push_back(r_adj_list[node].pop_front());
                end
                num_children[temp_name] = 1; // the only child is the current node
                name_map[temp_name] = node_ctr; node_ctr += 1;

                r_adj_list[node].push_back(temp_name);
                num_temps += 1;
            end
        end
    endfunction

    function automatic void print_name_map();
        int fd;
        string key;

        // Open file for writing
        fd = $fopen("../name_map_output_NORMALIZED.txt", "w");
        if (fd == 0) begin
            $display("Error: Could not open file for writing");
        end else begin
            // Iterate through associative array
            if (name_map.first(key)) begin
                do begin
                    $fdisplay(fd, "%s: %0d (%0d,%0d,%0d)", key, name_map[key], name_map[key] / (MESH_DIMENSION * NODES_PER_BANK), (name_map[key] / NODES_PER_BANK) % MESH_DIMENSION, name_map[key] % NODES_PER_BANK);
                end while (name_map.next(key));
            end else begin
                $fdisplay(fd, "name_map is empty");
            end
            
            $fclose(fd);
            $display("name_map contents written to file");
        end
    endfunction

    function automatic void print_r_adj_list();
        int fd;
        string key;

        // Open file for writing
        fd = $fopen("../r_adj_list_output_NORMALIZED.txt", "w");
        if (fd == 0) begin
            $display("Error: Could not open file for writing");
        end else begin
            // Iterate through associative array
            foreach(r_adj_list[key]) begin
                $fwrite(fd, "%s: ", key);
                foreach (r_adj_list[key][i]) begin
                    if (i > 0) $fwrite(fd, " ");
                    $fwrite(fd, "%s", r_adj_list[key][i]);
                end
                $fwrite(fd, " number of children: %0d", num_children[key]);
                $fdisplay(fd, "");  // Newline after each key's values
            end
            
            $fclose(fd);
            $display("r_adj_list contents written to file");
        end
    endfunction

    task send_pkt(input pkt_t pkt);
        io_in_pkt <= pkt;
        io_valid_in <= 1'b1;
        @(posedge clk);
        while(!io_ready_in) @(posedge clk);
        io_valid_in <= 1'b0;
    endtask

    task prog_load_node(string key);
        pkt_t load_pkt;
        int child_idx;
        load_pkt = '0;

        load_pkt.addr.x = name_map[key] / (NODES_PER_BANK * MESH_DIMENSION);
        load_pkt.addr.y = (name_map[key] / NODES_PER_BANK) % MESH_DIMENSION;
        load_pkt.addr.z = name_map[key];
        load_pkt.ctrl = CTRL_PARENTS;
        load_pkt.data.parents_t.num_edges = 0;

        // load parents in batches
        for(child_idx = 0; child_idx < r_adj_list[key].size(); child_idx++) begin
            load_pkt.data.parents_t.edges[child_idx % MAX_EDGES_PER_LOAD].node_id = name_map[r_adj_list[key][child_idx]];
            load_pkt.data.parents_t.num_edges += 1;
            if(child_idx % MAX_EDGES_PER_LOAD == MAX_EDGES_PER_LOAD - 1 || child_idx == r_adj_list[key].size() - 1) begin
                send_pkt(load_pkt);
                load_pkt.data.parents_t.num_edges = 0;
            end
        end

        // load config
        load_pkt.ctrl = CTRL_CONFIG;
        load_pkt.data = '0;
        load_pkt.addr.x = name_map[key] / (NODES_PER_BANK * MESH_DIMENSION);
        load_pkt.addr.y = (name_map[key] / NODES_PER_BANK) % MESH_DIMENSION;
        load_pkt.addr.z = name_map[key] % NODES_PER_BANK;
        load_pkt.data.config_t.is_you = key == "you";
        load_pkt.data.config_t.num_children = num_children[key];
        send_pkt(load_pkt);
        $display("finished prog load for node %s at time %t", key, $time);
    endtask

    task prog_load();
        foreach (name_map[key]) begin
            // set parents array for this node
            if(key != "out") begin prog_load_node(key); end
        end
        prog_load_node("out");
        $display("finished prog load at time %t", $time);
    endtask

    logic [63:0] cycle_count, prog_start_cycle, prog_end_cycle;
    initial begin
        cycle_count = 0;
        forever begin
            @(posedge clk);
            cycle_count = cycle_count + 1;
        end
    end
        
    initial begin
        $fsdbDumpfile("dump.fsdb");
        $fsdbDumpvars(0, "+all");

        // reset global variables
        name_map.delete();
        num_children.delete();
        r_adj_list.delete();
        node_ctr = 0;

        parse_file("../../testcases/puzzle_input_2.txt");
        print_name_map();
        print_r_adj_list();

        // fill verification variables
        foreach(name_map[node]) begin
            v_num_children[node] = num_children[node];
            v_started_sending_out[node] = 0;
            v_rname_map[name_map[node]] = node;
        end

        io_valid_in <= 1'b0;
        io_ready_out <= 1'b0;
        do_reset();
        io_ready_out <= 1'b1;
        prog_load();
        prog_start_cycle = cycle_count;
        @(posedge io_ready_out && io_valid_out);
        prog_end_cycle = cycle_count;
        $display("Output packet received:");
        $display("  Ctrl: %0d", io_out_pkt.ctrl);
        $display("  Data: %0d", io_out_pkt.data.sum_t.value);
        $display("Program completed in %0d cycles", prog_end_cycle - prog_start_cycle);
        $display("Prog start at cycle: %0d", prog_start_cycle);
        $display("Prog end at cycle: %0d", prog_end_cycle);
        $finish;
    end

    genvar row, col, node;
    generate
        for(row = 0; row < MESH_DIMENSION; row++) begin
            for(col = 0; col < MESH_DIMENSION; col++) begin
                for(node = 0; node < NODES_PER_BANK; node++) begin
                    initial begin
                        @(negedge rst);
                        forever begin
                            @(posedge clk);
                            if(dut.bank_row[row].bank_col[col].bank_inst.nodes[node].node_inst.valid_out && dut.bank_row[row].bank_col[col].bank_inst.nodes[node].node_inst.ready_out) begin
                                $display("%0d,%0d,%0d sending path at time %t", row, col, node, $time);
                                // if(dut.bank_row[row].bank_col[col].bank_inst.out_pkt.ctrl == CTRL_SUM) $finish;
                                v_num_children[v_rname_map[(dut.bank_row[row].bank_col[col].bank_inst.nodes[node].node_inst.out_pkt.addr.x * MESH_DIMENSION + dut.bank_row[row].bank_col[col].bank_inst.nodes[node].node_inst.out_pkt.addr.y) * NODES_PER_BANK + dut.bank_row[row].bank_col[col].bank_inst.nodes[node].node_inst.out_pkt.addr.z]] -= 1;
                            end
                            if(dut.bank_row[row].bank_col[col].bank_inst.nodes[node].node_inst.valid_out) begin
                                // $display("%0d,%0d,%0d trying to send path at time %t", row, col, node, $time);
                                v_started_sending_out[v_rname_map[(col*MESH_DIMENSION+row)*NODES_PER_BANK+node]] = 1;
                            end
                        end
                    end
                end
            end
        end
    endgenerate

    int fd_fump;
    initial begin
        @(posedge clk);
        repeat (timeout) @(posedge clk);
        $display("Testbench timed out after %0d cycles", timeout);
        $display("Nodes that should be trying to send out something but aren't");
        foreach(name_map[name]) begin
            if(v_num_children[name] == 0 && !v_started_sending_out[name]) begin
                $display("  %0s should be trying to send children", name);
            end
        end

        // // Open file for writing
        // fd) = $fopen("../r_adj_list_output_NORMALIZED.txt", "w");
        // if (fd == 0) begin
        //     $display("Error: Could not open file for writing");
        // end else begin
        //     // Iterate through associative array
        //     foreach(r_adj_list[key]) begin
        //         $fwrite(fd, "%s: ", key);
        //         foreach (r_adj_list[key][i]) begin
        //             if (i > 0) $fwrite(fd, " ");
        //             $fwrite(fd, "%s", r_adj_list[key][i]);
        //         end
        //         $fwrite(fd, " number of children: %0d", num_children[key]);
        //         $fdisplay(fd, "");  // Newline after each key's values
        //     end
            
        //     $fclose(fd);
        //     $display("r_adj_list contents written to file");
        // end
        $finish;
    end

endmodule