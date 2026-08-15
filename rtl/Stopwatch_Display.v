module Stopwatch_display (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       cnt_en,         // Connect to Pulse_on (starts/stops counting)
    input  wire       cnt_reset,      // Connect to reset logic
    input  wire       test_mode_fast, // Connect to SW[3] for fast visual counting
    
    output wire [6:0] HEX0, // Centiseconds (0.01s) Units
    output wire [6:0] HEX1, // Centiseconds (0.01s) Tens
    output wire [6:0] HEX2, // Seconds Units
    output wire [6:0] HEX3, // Seconds Tens
    output wire [6:0] HEX4, // Minutes Units
    output wire [6:0] HEX5  // Minutes Tens
);

    // Timing Parameters (50MHz Clock)
    localparam NORMAL_10MS = 19'd500_000 - 1; // 10ms in real time
    localparam FAST_10MS   = 19'd100_000 - 1; // 10ms in 5x fast forward
    
    wire [18:0] max_cycles = test_mode_fast ? FAST_10MS : NORMAL_10MS;
    
    reg [18:0] tick_counter;
    reg        tick_10ms;

    // Registers for individual digits
    reg [3:0] cs_0, cs_1;   // Centiseconds
    reg [3:0] sec_0, sec_1; // Seconds
    reg [3:0] min_0, min_1; // Minutes

    // 1. Generate 10ms Tick
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Asynchronous reset must be checked alone
            tick_counter <= 19'd0;
            tick_10ms    <= 1'b0;
        end else if (cnt_reset) begin
            // Synchronous reset separated
            tick_counter <= 19'd0;
            tick_10ms    <= 1'b0;
        end else if (cnt_en) begin
            if (tick_counter >= max_cycles) begin
                tick_counter <= 19'd0;
                tick_10ms    <= 1'b1;
            end else begin
                tick_counter <= tick_counter + 1'b1;
                tick_10ms    <= 1'b0;
            end
        end else begin
            tick_10ms <= 1'b0; // Stop ticking when not enabled
        end
    end

    // 2. Cascade BCD Counters
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cs_0 <= 4'd0; cs_1 <= 4'd0;
            sec_0 <= 4'd0; sec_1 <= 4'd0;
            min_0 <= 4'd0; min_1 <= 4'd0;
        end else if (cnt_reset) begin
            cs_0 <= 4'd0; cs_1 <= 4'd0;
            sec_0 <= 4'd0; sec_1 <= 4'd0;
            min_0 <= 4'd0; min_1 <= 4'd0;
        end else if (tick_10ms) begin
            // Centiseconds logic (0-99)
            if (cs_0 == 9) begin
                cs_0 <= 0;
                if (cs_1 == 9) begin
                    cs_1 <= 0;
                    
                    // Seconds logic (0-59)
                    if (sec_0 == 9) begin
                        sec_0 <= 0;
                        if (sec_1 == 5) begin
                            sec_1 <= 0;
                            
                            // Minutes logic (0-99)
                            if (min_0 == 9) begin
                                min_0 <= 0;
                                if (min_1 < 9) min_1 <= min_1 + 1;
                            end else begin
                                min_0 <= min_0 + 1;
                            end
                            
                        end else begin
                            sec_1 <= sec_1 + 1;
                        end
                    end else begin
                        sec_0 <= sec_0 + 1;
                    end
                    
                end else begin
                    cs_1 <= cs_1 + 1;
                end
            end else begin
                cs_0 <= cs_0 + 1;
            end
        end
    end

    // 3. Instantiate the 7-Segment Decoders for each digit
    Seven_Seg_Decoder d0 (.bin_in(cs_0),  .seg_out(HEX0));
    Seven_Seg_Decoder d1 (.bin_in(cs_1),  .seg_out(HEX1));
    Seven_Seg_Decoder d2 (.bin_in(sec_0), .seg_out(HEX2));
    Seven_Seg_Decoder d3 (.bin_in(sec_1), .seg_out(HEX3));
    Seven_Seg_Decoder d4 (.bin_in(min_0), .seg_out(HEX4));
    Seven_Seg_Decoder d5 (.bin_in(min_1), .seg_out(HEX5));

endmodule