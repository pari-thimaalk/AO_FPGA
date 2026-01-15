module mesh_tb;
    /*
    this testbench verifies the transmission within a mesh,
    by verifying arbitrary packets get from point to point without
    hangs or distortion

    need some editting after I added an io interface to the mesh
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

    int timeout = 10000;
    //----------------------------------

    import types::*;
    import parameters::*;

    logic valid_in[MESH_DIMENSION][MESH_DIMENSION];
    logic ready_in[MESH_DIMENSION][MESH_DIMENSION];
    pkt_t in_pkt[MESH_DIMENSION][MESH_DIMENSION];
    logic valid_out[MESH_DIMENSION][MESH_DIMENSION];
    logic ready_out[MESH_DIMENSION][MESH_DIMENSION];
    pkt_t out_pkt[MESH_DIMENSION][MESH_DIMENSION];

    mesh dut (
        .clk(clk),
        .rst(rst),
        .valid_in(valid_in),
        .ready_in(ready_in),
        .in_pkt(in_pkt),
        .valid_out(valid_out),
        .ready_out(ready_out),
        .out_pkt(out_pkt)
    );

    function automatic pkt_t gen_pkt();
        pkt_t pkt;
        pkt.ctrl = ctrl_t'($urandom_range(0, 3));
        pkt.addr.x = $urandom_range(0,MESH_DIMENSION-1);
        pkt.addr.y = $urandom_range(0,MESH_DIMENSION-1);
        pkt.data = $urandom();
        return pkt;
    endfunction

    function automatic void gen_src_addr(input pkt_t load, output int src_x, output int src_y);
        src_x = $urandom_range(0,MESH_DIMENSION-1);
        src_y = $urandom_range(0,MESH_DIMENSION-1);

        if(src_x == load.addr.x) src_x = (src_x + $urandom_range(0, MESH_DIMENSION-2)) % MESH_DIMENSION;
        if(src_y == load.addr.y) src_y = (src_y + $urandom_range(0, MESH_DIMENSION-2)) % MESH_DIMENSION;
    endfunction

    task drive_pkt(input pkt_t load, input int src_x, input int src_y);
        valid_in[src_y][src_x] <= 1'b1;
        in_pkt[src_y][src_x] <= load;
        @(posedge clk);
        while(!ready_in[src_y][src_x]) @(posedge clk);
        valid_in[src_y][src_x] <= 1'b0;
    endtask

    pkt_t expected_transactions [MESH_DIMENSION][MESH_DIMENSION][$];

    task gen_and_drive_pkt();
        pkt_t rand_pkt;
        int src_x, src_y;

        // generate a single random pkt and wait for it to be sent
        rand_pkt = gen_pkt();
        gen_src_addr(rand_pkt, src_x, src_y);

        $display("dest (x,y) = (%d,%d), src (x,y) = (%0d,%0d) at time %t", rand_pkt.addr.x, rand_pkt.addr.y, src_x, src_y, $time);

        drive_pkt(rand_pkt, src_x, src_y);

        expected_transactions[rand_pkt.addr.y][rand_pkt.addr.x].push_back(rand_pkt);
    endtask

    bit flag = 1;

    initial begin
        $fsdbDumpfile("dump.fsdb");
        $fsdbDumpvars(0, "+all");

        // signal defaults
        for(int i = 0; i < MESH_DIMENSION; i+=1) begin
            for(int j = 0; j < MESH_DIMENSION; j+=1) begin
                valid_in[i][j] = '0;
                ready_out[i][j] = '0;
            end
        end

        do_reset();

        for(int i = 0; i < MESH_DIMENSION; i+=1) begin
            for(int j = 0; j < MESH_DIMENSION; j+=1) begin
                ready_out[i][j] = '1;
            end
        end

        for(int num_pkts = 0; num_pkts < 1000; num_pkts ++) begin
            gen_and_drive_pkt();
        end


        // wait till all packets have been received (or timeout)
        forever begin
            @(posedge clk);
            for(int row = 0; row < MESH_DIMENSION; row++) begin
                for(int col = 0; col < MESH_DIMENSION; col++) begin
                    if(expected_transactions[row][col].size() != 0) flag = 0;
                end
            end

            if(flag) break;
            else flag = 1;
        end

        $finish;
    end

    // receiver block
    bit found = 0;
    initial begin
        @(negedge rst);
        forever begin
            @(posedge clk);
            for (int row = 0; row < MESH_DIMENSION; row ++) begin
                for(int col = 0; col < MESH_DIMENSION; col ++) begin
                    if(valid_out[row][col] && ready_out[row][col]) begin
                        // find appropriate entry in queue
                        found = 0;
                        foreach(expected_transactions[row][col][trn]) begin
                            if(out_pkt[row][col] === expected_transactions[row][col][trn]) begin
                                found = 1;
                                expected_transactions[row][col].delete(trn);
                                $display("received pkt for (%0d,%0d) at time %t", col, row, $time);
                                break;
                            end
                        end
                        if(!found) begin
                            $error();
                            $display("Unexpected packet %p", out_pkt[row][col]);
                            foreach(expected_transactions[row][col][trn]) begin
                                $display("  expected packet %d : %p", trn, expected_transactions[row][col][trn]);
                            end
                            $finish;
                        end
                    end
                end
            end
        end
    end

    initial begin
        forever begin
            @(posedge clk);
            timeout <= timeout - 1;
            if(timeout == 0) begin
                $display("Testbench timed out");
                $finish;
            end
        end
    end


endmodule