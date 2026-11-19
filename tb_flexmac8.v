`timescale 1ns/1ps
// Self-checking Verilog-2001 testbench for FlexMAC-8.
// Works with Icarus Verilog: iverilog -g2005 -s tb_flexmac8 -o simv rtl/flexmac8.v tb/tb_flexmac8.v
module tb_flexmac8;
    reg clk;
    reg rst;
    reg [7:0] data_in;
    reg [1:0] cmd;
    reg [1:0] precision;
    reg start;
    reg read_hi;
    wire [7:0] data_out;
    wire busy;
    wire done;
    wire overflow;

    localparam [1:0] CMD_LOAD_A = 2'b00;
    localparam [1:0] CMD_LOAD_B = 2'b01;
    localparam [1:0] CMD_MAC    = 2'b10;
    localparam [1:0] CMD_CLEAR  = 2'b11;

    reg [7:0] model_a;
    reg [7:0] model_b;
    reg [15:0] model_acc;
    reg model_overflow;
    integer pass_count;
    integer error_count;
    integer seed;
    integer i;
    integer mode_i;

    flexmac8 dut (
        .clk(clk), .rst(rst), .data_in(data_in), .cmd(cmd),
        .precision(precision), .start(start), .read_hi(read_hi),
        .data_out(data_out), .busy(busy), .done(done), .overflow(overflow)
    );

    initial clk = 1'b0;

    // 100 ns clock period = 10 MHz, matching the maximum specified clock.
    always #50 clk = ~clk;

    // Waveform capture for GTKWave
    initial begin
        $dumpfile("flexmac8.vcd");
        $dumpvars(0, tb_flexmac8);
    end


    task fail;
        input [8*140-1:0] message;
        begin
            error_count = error_count + 1;
            $display("FAIL at %0t: %0s", $time, message);
            if (error_count >= 10) begin
                $display("Stopping after 10 failures");
                $finish;
            end
        end
    endtask

    task check_acc;
        begin
            read_hi = 1'b0;
            #1;
            if (data_out !== model_acc[7:0])
                fail("accumulator LOW byte mismatch");
            read_hi = 1'b1;
            #1;
            if (data_out !== model_acc[15:8])
                fail("accumulator HIGH byte mismatch");
            if (overflow !== model_overflow)
                fail("sticky overflow mismatch");
            read_hi = 1'b0;
            pass_count = pass_count + 1;
        end
    endtask

    task issue;
        input [1:0] opcode;
        input [7:0] din;
        input [1:0] pmode;
        begin
            @(negedge clk);
            cmd       = opcode;
            data_in   = din;
            precision = pmode;
            start     = 1'b1;
            @(posedge clk);
            #1;
            if (opcode == CMD_MAC) begin
                if (busy !== 1'b1 || done !== 1'b0)
                    fail("MAC must assert busy and deassert done at acceptance");
            end else begin
                if (busy !== 1'b0 || done !== 1'b1)
                    fail("LOAD/CLEAR must generate immediate one-cycle done pulse");
            end
            @(negedge clk);
            start = 1'b0;
        end
    endtask

    task load_a;
        input [7:0] a;
        begin
            issue(CMD_LOAD_A, a, 2'b00);
            model_a = a;
        end
    endtask

    task load_b;
        input [7:0] b;
        begin
            issue(CMD_LOAD_B, b, 2'b00);
            model_b = b;
        end
    endtask

    task clear_all;
        begin
            issue(CMD_CLEAR, 8'd0, 2'b00);
            model_a = 8'd0;
            model_b = 8'd0;
            model_acc = 16'd0;
            model_overflow = 1'b0;
            check_acc;
        end
    endtask

    task mac_check;
        input [1:0] mode;
        reg [7:0] effective_b;
        reg [15:0] product;
        reg [16:0] sum;
        integer n;
        integer j;
        begin
            case (mode)
                2'b01: begin effective_b = model_b & 8'hFC; n = 6; end
                2'b10: begin effective_b = model_b & 8'hF0; n = 4; end
                default: begin effective_b = model_b; n = 8; end
            endcase
            product = {8'b0, model_a} * {8'b0, effective_b};
            sum = {1'b0, model_acc} + {1'b0, product};
            model_acc = sum[15:0];
            model_overflow = model_overflow | sum[16];

            issue(CMD_MAC, 8'd0, mode);
            for (j = 1; j <= n; j = j + 1) begin
                @(posedge clk);
                #1;
                if (j < n) begin
                    if (busy !== 1'b1 || done !== 1'b0)
                        fail("MAC completed too early");
                end else begin
                    if (busy !== 1'b0 || done !== 1'b1)
                        fail("MAC completion cycle incorrect");
                end
            end
            check_acc;
        end
    endtask

    task check_reset;
        begin
            @(negedge clk);
            rst = 1'b1;
            #1;
            model_a = 8'd0;
            model_b = 8'd0;
            model_acc = 16'd0;
            model_overflow = 1'b0;
            if (busy !== 1'b0 || done !== 1'b0 || overflow !== 1'b0)
                fail("asynchronous reset flag mismatch");
            check_acc;
            @(negedge clk);
            rst = 1'b0;
        end
    endtask

    initial begin
        rst = 1'b1;
        data_in = 8'd0;
        cmd = CMD_CLEAR;
        precision = 2'd0;
        start = 1'b0;
        read_hi = 1'b0;
        model_a = 8'd0;
        model_b = 8'd0;
        model_acc = 16'd0;
        model_overflow = 1'b0;
        pass_count = 0;
        error_count = 0;
        seed = 32'h02468ACE;
        repeat (2) @(negedge clk);
        rst = 1'b0;

        // Functional boundary and regression vectors.
        clear_all;
        load_a(8'd5); load_b(8'd7);
        mac_check(2'b00); // 35
        mac_check(2'b00); // 70, accumulation
        load_a(8'd255); load_b(8'd255);
        mac_check(2'b00); // 65025, 16-bit wrap and sticky overflow
        mac_check(2'b01); // truncates 2 LSBs of B
        mac_check(2'b10); // truncates 4 LSBs of B
        mac_check(2'b11); // reserved mode maps to exact
        clear_all;
        load_a(8'd0); load_b(8'd255);
        mac_check(2'b00);
        load_a(8'd255); load_b(8'd0);
        mac_check(2'b01);
        load_a(8'd1); load_b(8'd1);
        mac_check(2'b10);
        mac_check(2'b00);

        // Reset asserted while an arithmetic command is active.
        load_a(8'd17); load_b(8'd23);
        issue(CMD_MAC, 8'd0, 2'b00);
        @(posedge clk); #1;
        check_reset;
        load_a(8'd9); load_b(8'd11);
        mac_check(2'b00);

        // Repeatable pseudo-random test vectors across all precision modes.
        for (mode_i = 0; mode_i < 3; mode_i = mode_i + 1) begin
            clear_all;
            for (i = 0; i < 150; i = i + 1) begin
                load_a($random(seed));
                load_b($random(seed));
                mac_check(mode_i[1:0]);
            end
        end
        if (error_count == 0)
            $display("PASS: %0d arithmetic/readback checks, no mismatches", pass_count);
        else
            $display("FAIL: %0d mismatches", error_count);
        $finish;
    end

    initial begin
        #5000000;
        $display("FAIL: watchdog timeout");
        $finish;
    end
endmodule
