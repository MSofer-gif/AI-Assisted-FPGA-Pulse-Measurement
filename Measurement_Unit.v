module Measurement_Unit (
    // Clock and Global Reset
    input  wire        clk,           // 50MHz Global Clock
    input  wire        rst_n,         // Global Active-Low Reset
    
    // NEW: Test mode enable
    input  wire        test_mode_fast,// SW[3] input from top level
    
    // Control signals from FSM
    input  wire        Pulse_on,      // Enable counting
    input  wire        cnt_reset,     // Synchronous reset
    input  wire        shadow_en,     // Enable shadow register sampling
    input  wire        ready_in,      // 1-cycle ready pulse from FSM
    
    // Outputs to FSM and NIOS
    output reg         timeout_flag,  // Flag to FSM when max time reached
    output reg  [31:0] Shadow_out,    // 32-bit data to NIOS PIO
    output reg         Nios_ready     // Stretched 1ms ready pulse to NIOS PIO
);

    // ==========================================
    // Parameters
    // ==========================================
    parameter NORMAL_CYCLES  = 16'd50000;  // 1ms pulse in real time (50MHz)
    parameter FAST_CYCLES    = 16'd10000;  // 0.2ms pulse in test mode (5 times faster)
    parameter TIMEOUT_VAL    = 32'd300000; // 5 minutes in ms
    parameter STRETCH_CYCLES = 16'd50000;  // 1ms stretch for the ready signal

    // Dynamic threshold based on the test mode switch
    wire [15:0] current_max_cycles = test_mode_fast ? FAST_CYCLES : NORMAL_CYCLES;

    // ==========================================
    // Internal Registers
    // ==========================================
    reg [15:0] prescaler;
    reg [31:0] ms_counter; // Internal counter. Not exposed to Top Level.
    reg [15:0] stretch_counter;
    reg        stretching;

    // ==========================================
    // 1. Counter Logic
    // ==========================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            prescaler    <= 16'd0;
            ms_counter   <= 32'd0;
            timeout_flag <= 1'b0;
        end 
        else if (cnt_reset) begin
            prescaler    <= 16'd0;
            ms_counter   <= 32'd0;
            timeout_flag <= 1'b0;
        end 
        else if (Pulse_on) begin
            // CHANGED: Use >= instead of == for safety when switching modes dynamically
            if (prescaler >= current_max_cycles - 1) begin
                prescaler <= 16'd0;
                if (ms_counter < TIMEOUT_VAL) begin
                    ms_counter <= ms_counter + 1'b1;
                end
            end else begin
                prescaler <= prescaler + 1'b1;
            end

            // Timeout check: Raise flag if max value is reached
            if (ms_counter >= TIMEOUT_VAL) begin
                timeout_flag <= 1'b1;
            end
        end
    end

    // ==========================================
    // 2. Shadow Register Logic (Remains unchanged)
    // ==========================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            Shadow_out <= 32'd0;
        end else if (shadow_en) begin
            // Sample the internal counter value
            Shadow_out <= ms_counter;
        end
    end

    // ==========================================
    // 3. Pulse Stretcher Logic (Remains unchanged)
    // ==========================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            Nios_ready      <= 1'b0;
            stretch_counter <= 16'd0;
            stretching      <= 1'b0;
        end else begin
            // If a short ready pulse is received from the FSM
            if (ready_in) begin
                Nios_ready      <= 1'b1;
                stretching      <= 1'b1;
                stretch_counter <= 16'd0;
            end 
            // If we are currently in the process of stretching the pulse
            else if (stretching) begin
                if (stretch_counter < STRETCH_CYCLES - 1) begin
                    stretch_counter <= stretch_counter + 1'b1;
                end else begin
                    Nios_ready      <= 1'b0;
                    stretching      <= 1'b0;
                end
            end
        end
    end

endmodule