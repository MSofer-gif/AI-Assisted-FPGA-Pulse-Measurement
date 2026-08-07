module FSM_Control (
    // Inputs
    input  wire clk,            // Global 50MHz Clock
    input  wire rst_n,          // Global System Reset (Active Low)
    input  wire pulse_start,    // From Filter X2 (start measurement)
    input  wire pulse_stop,     // From Filter X2 (end measurement)
    input  wire timeout_flag,   // From Counter (max time reached)
    input  wire sw_mode,        // Switch 1 (Logic Reset: 1 = Run, 0 = Reset)

    // Outputs (Format: {Pulse_on, cnt_reset, shadow_en, ready})
    output wire Pulse_on,       // Enable counter
    output wire cnt_reset,      // Reset counter
    output wire shadow_en,      // Enable shadow register sampling
    output wire ready,          // Ready flag to Pulse Stretcher/NIOS

    // Debug LEDs
    output wire LEDR9,          // Indicates IDLE state
    output wire LEDR8,          // Indicates RUN state
    output wire LEDR7           // Indicates DONE state
);

    // ========================================================
    // FSM State Encoding
    // ========================================================
    localparam [1:0] IDLE = 2'b00,
                     RUN  = 2'b01,
                     DONE = 2'b10;

    reg [1:0] current_state, next_state;

    // ========================================================
    // 1. State Register (Sequential Logic)
    // ========================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // ========================================================
    // 2. Next State Logic (Combinational Logic)
    // ========================================================
    always @(*) begin
        // Default: stay in current state unless a condition is met
        next_state = current_state;

        // Global condition: If sw_mode is 0 (Logic Reset), force to IDLE
        // This covers the "***0" transition from any state
        if (sw_mode == 1'b0) begin
            next_state = IDLE;
        end else begin
            case (current_state)
                IDLE: begin
                    // Transition: 1**1 -> Go to RUN
                    if (pulse_start == 1'b1) begin
                        next_state = RUN;
                    end
                end

                RUN: begin
                    // Transition: **11 -> Timeout reached, go to DONE
                    if (timeout_flag == 1'b1) begin
                        next_state = DONE;
                    end
                    // Transition: *101 -> Normal pulse stop, go to DONE
                    else if (pulse_stop == 1'b1) begin
                        next_state = DONE;
                    end
                end

                DONE: begin
                    // Transition: **** -> Unconditional return to IDLE next clock
                    next_state = IDLE;
                end

                default: begin
                    next_state = IDLE;
                end
            endcase
        end
    end

    // ========================================================
    // 3. Output Logic (Combinational - with Logic Reset Override)
    // ========================================================
    
    // Pulse_on will be strictly 0 if sw_mode is 0, instantly killing the signal to NIOS
    assign Pulse_on  = (current_state == RUN) && (sw_mode == 1'b1);
    
    // cnt_reset should be 1 if we are in IDLE, OR instantly if sw_mode is 0 (forced reset)
    assign cnt_reset = (current_state == IDLE) || (sw_mode == 1'b0);
    
    // Other outputs should also be strictly gated by sw_mode to prevent false triggers
    assign shadow_en = (current_state == DONE) && (sw_mode == 1'b1);
    assign ready     = (current_state == DONE) && (sw_mode == 1'b1);

    // ========================================================
    // 4. Debug LED Assignments
    // ========================================================
    assign LEDR9 = (current_state == IDLE);
    assign LEDR8 = (current_state == RUN);
    assign LEDR7 = (current_state == DONE);

endmodule