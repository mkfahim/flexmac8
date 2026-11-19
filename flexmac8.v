// FlexMAC-8: Precision-adaptive 8-bit unsigned MAC for Silicluster v3.
// Synthesizable IEEE 1364-2001 Verilog. No external IP or vendor primitives.
// Reset is asynchronous, active high.
// All inputs and outputs are in the 1.8 V digital domain when integrated.
module flexmac8 (
    input  wire       clk,
    input  wire       rst,
    input  wire [7:0] data_in,
    input  wire [1:0] cmd,
    input  wire [1:0] precision,
    input  wire       start,
    input  wire       read_hi,
    output wire [7:0] data_out,
    output reg        busy,
    output reg        done,
    output reg        overflow
);

    localparam [1:0] CMD_LOAD_A = 2'b00;
    localparam [1:0] CMD_LOAD_B = 2'b01;
    localparam [1:0] CMD_MAC    = 2'b10;
    localparam [1:0] CMD_CLEAR  = 2'b11;

    reg [7:0]  operand_a;
    reg [7:0]  operand_b;
    reg [15:0] accumulator;
    reg [15:0] working_accumulator;
    reg        working_overflow;
    reg [15:0] multiplicand;
    reg [7:0]  multiplier;
    reg [3:0]  cycles_left;

    wire [15:0] addend;
    wire [16:0] next_accumulator;

    assign addend = multiplier[0] ? multiplicand : 16'd0;
    assign next_accumulator = {1'b0, working_accumulator} + {1'b0, addend};
    assign data_out = read_hi ? accumulator[15:8] : accumulator[7:0];

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            operand_a        <= 8'd0;
            operand_b        <= 8'd0;
            accumulator      <= 16'd0;
            working_accumulator <= 16'd0;
            working_overflow    <= 1'b0;
            multiplicand     <= 16'd0;
            multiplier       <= 8'd0;
            cycles_left      <= 4'd0;
            busy             <= 1'b0;
            done             <= 1'b0;
            overflow         <= 1'b0;
        end else begin
            // One-clock completion pulse for every accepted command.
            done <= 1'b0;
            if (busy) begin
                // Fold the product into a private running accumulator.
                // This uses one 16-bit arithmetic adder per clock cycle.
                if (cycles_left == 4'd1) begin
                    // Final addend is included; commit result atomically.
                    accumulator <= next_accumulator[15:0];
                    overflow    <= overflow | working_overflow | next_accumulator[16];
                    busy        <= 1'b0;
                    done        <= 1'b1;
                    cycles_left <= 4'd0;
                end else begin
                    working_accumulator <= next_accumulator[15:0];
                    working_overflow    <= working_overflow | next_accumulator[16];
                    multiplicand    <= multiplicand << 1;
                    multiplier      <= multiplier >> 1;
                    cycles_left     <= cycles_left - 4'd1;
                end
            end else if (start) begin
                case (cmd)
                    CMD_LOAD_A: begin
                        operand_a <= data_in;
                        done      <= 1'b1;
                    end
                    CMD_LOAD_B: begin
                        operand_b <= data_in;
                        done      <= 1'b1;
                    end
                    CMD_MAC: begin
                        working_accumulator <= accumulator;
                        working_overflow    <= 1'b0;
                        busy            <= 1'b1;
                        case (precision)
                            2'b01: begin
                                // Drop B[1:0], compute A * (B & 8'hFC).
                                multiplicand <= {6'd0, operand_a, 2'b00};
                                multiplier   <= {2'b00, operand_b[7:2]};
                                cycles_left  <= 4'd6;
                            end
                            2'b10: begin
                                // Drop B[3:0], compute A * (B & 8'hF0).
                                multiplicand <= {4'd0, operand_a, 4'b0000};
                                multiplier   <= {4'b0000, operand_b[7:4]};
                                cycles_left  <= 4'd4;
                            end
                            default: begin
                                // precision=00 is exact; 11 is exact fallback.
                                multiplicand <= {8'd0, operand_a};
                                multiplier   <= operand_b;
                                cycles_left  <= 4'd8;
                            end
                        endcase
                    end
                    CMD_CLEAR: begin
                        operand_a   <= 8'd0;
                        operand_b   <= 8'd0;
                        accumulator <= 16'd0;
                        overflow    <= 1'b0;
                        done        <= 1'b1;
                    end
                    default: begin
                        // All two-bit command codes are covered.
                    end
                endcase
            end
        end
    end
endmodule
