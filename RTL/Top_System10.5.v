module Top_System (
    input  wire        MAX10_CLK1_50, // Global 50MHz Clock (CLK)
    
    // Physical Inputs from DE10-Lite
    input  wire [1:0]  KEY,           // Buttons: KEY[0]=start, KEY[1]=stop (Active Low on DE10)
    // *** ADDED: Expanded SW from [1:0] to [3:0] to include SW[3] ***
    input  wire [9:0]  SW,            // Switches: SW[0]=Reset, SW[1]=Logic Rst, SW[3]=Fast, SW[9]=Pulse Mode
    // Physical Outputs
    output wire [9:0]  LEDR,          // Debug LEDs for FSM state
    output wire        ARDUINO_IO_10, // Tx_out to External UART LCD
	 output wire        ARDUINO_IO_11, // Speaker 
	 
	 // *** ADDED: 7-Segment Displays ***
    output wire [6:0]  HEX0,
    output wire [6:0]  HEX1,
    output wire [6:0]  HEX2,
    output wire [6:0]  HEX3,
    output wire [6:0]  HEX4,
    output wire [6:0]  HEX5,
    
    // Oscilloscope Test Points (Arduino Uno R3 Bottom Pins)
    output wire        ARDUINO_IO_2,  // Test Point: Pulse_on
    output wire        ARDUINO_IO_3,  // Test Point: uart_busy
    output wire        ARDUINO_IO_4,  // Test Point: uart_write
    output wire        ARDUINO_IO_5,  // Test Point: nios_ready
    output wire        ARDUINO_IO_7,   // Test Point: Tx_out (Scope duplicate)
	 output wire        ARDUINO_IO_8,
	 output wire        ARDUINO_IO_9	//Test Point: Measure Debouncer Delay (~KEY[0])
);



    // ========================================================
    // Internal Wires (Nets) for interconnecting the blocks
    // ========================================================
    
    // Resets and Modes
    wire system_reset_n = SW[0];        // Sw[0]=0 -> System reset (Active Low)
    wire sw_mode        = SW[1];        // Sw[1]=0 -> counter = 0 (Logic reset to FSM)
    // *** ADDED: Wire for the fast test mode switch ***
    wire test_mode_fast = SW[3];        // Sw[3]=1 -> Enable fast counting mode
	
	
	
    // Debouncer outputs (Filter X2)
    wire w_pulse_start;
    wire w_pulse_stop;

    // FSM Outputs
    wire w_Pulse_on;
    wire w_cnt_reset;
    wire w_shadow_en;
    wire w_ready_fsm;

    // Measurement Unit Outputs (Unified)
    wire        w_timeout_flag;
    wire [31:0] w_shadow_out;
    wire        w_nios_ready_1ms;

    // QSYS <-> LCD Driver Wires
    wire [7:0]  w_uart_data;
    wire        w_uart_write;
    wire        w_uart_busy;
	 
	 // QSYS <-> Speaker Wire
    wire [31:0] w_nios_speaker_data;
    
    // Wire to split the Tx output to two physical pins
    wire        w_Tx_serial;

    // ========================================================
    // 1. Filter X2 (Debouncers for physical buttons)
    // ========================================================
    // Note: KEYs on DE10-Lite are 1 when unpressed, 0 when pressed.
    // We invert them (~KEY) so the debouncer sees a '1' when pressed.
    Debouncer u_deb_start (
        .clk            (MAX10_CLK1_50),
        .input_unstable (~KEY[0]),        // Inverted KEY0
        .output_stable  (w_pulse_start)   // Goes to FSM
    );

    Debouncer u_deb_stop (
        .clk            (MAX10_CLK1_50),
        .input_unstable (~KEY[1]),        // Inverted KEY1
        .output_stable  (w_pulse_stop)    // Goes to FSM
    );

// ========================================================
    // SW[7] Custom Level-Debouncer (STACK Mode Toggle)
    // ========================================================
    reg [15:0] sw7_debounce_cnt;
    reg sw7_stable_level;

    always @(posedge MAX10_CLK1_50 or negedge system_reset_n) begin
        if (!system_reset_n) begin
            sw7_debounce_cnt <= 16'd0;
            sw7_stable_level <= 1'b0;
        end else begin
            if (SW[7] == sw7_stable_level) begin
                sw7_debounce_cnt <= 16'd0; 
            end else begin
                sw7_debounce_cnt <= sw7_debounce_cnt + 1'b1;
                if (sw7_debounce_cnt >= 16'd50000) begin // ~1ms stable time
                    sw7_stable_level <= SW[7];
                    sw7_debounce_cnt <= 16'd0;
                end
            end
        end
    end

// ========================================================
    // NEW: SW[9] Custom Level-Debouncer & Robust MUX
    // MUST BE BEFORE THE FSM!
    // ========================================================
    reg [15:0] sw9_debounce_cnt;
    reg sw9_stable_level;

    // 1. Custom Level-Debouncer for SW[9] 
    // (Keeps the signal continuous, ignores noise, no 1-cycle drops)
    always @(posedge MAX10_CLK1_50 or negedge system_reset_n) begin
        if (!system_reset_n) begin
            sw9_debounce_cnt <= 16'd0;
            sw9_stable_level <= 1'b0;
        end else begin
            if (SW[9] == sw9_stable_level) begin
                sw9_debounce_cnt <= 16'd0; // Reset counter if no change
            end else begin
                sw9_debounce_cnt <= sw9_debounce_cnt + 1'b1;
                if (sw9_debounce_cnt >= 16'd50000) begin // ~1ms stable time
                    sw9_stable_level <= SW[9];
                    sw9_debounce_cnt <= 16'd0;
                end
            end
        end
    end

    // 2. Edge Detection & Mode Locking
    reg sw9_d1, sw9_d2;
    reg active_mode; // 0 = KEY mode, 1 = SW[9] mode

    always @(posedge MAX10_CLK1_50 or negedge system_reset_n) begin
        if (!system_reset_n) begin
            sw9_d1      <= 1'b0;
            sw9_d2      <= 1'b0;
            active_mode <= 1'b0;
        end else begin
            // Pipeline for edge detection using the STABLE LEVEL
            sw9_d1 <= sw9_stable_level;
            sw9_d2 <= sw9_d1;
            
            // 3. MODE LOCKING
            // Lock the mode ONLY when the FSM is in IDLE (w_cnt_reset == 1)
            if (w_cnt_reset == 1'b1) begin
                if (sw9_d1 & ~sw9_d2) begin       // If SW[9] rising edge detected
                    active_mode <= 1'b1;
                end else if (w_pulse_start) begin // If KEY[0] press detected
                    active_mode <= 1'b0;
                end
            end
        end
    end

    // Detect Rising and Falling edges of the stable level
    wire sw9_rise = (sw9_d1 & ~sw9_d2); // Start pulse
    wire sw9_fall = (~sw9_d1 & sw9_d2); // Stop pulse

   // ========================================================
    // MUX Logic with STACK Mode Isolation
    // ========================================================
    
    // When STACK mode is active (sw7_stable_level == 1), we "mask" the keys
    // so they don't reach the FSM. 
    wire fsm_key_start = w_pulse_start & ~sw7_stable_level;
    wire fsm_key_stop  = w_pulse_stop  & ~sw7_stable_level;

    // Start/Stop signals for the FSM
    wire final_pulse_start = sw9_rise | fsm_key_start;
    wire final_pulse_stop  = active_mode ? sw9_fall : fsm_key_stop;

    // Bundle signals for the NIOS PIO (3 bits)
    // Bit 0: Mode (SW[7]), Bit 1: Forward (KEY[0]), Bit 2: Backward (KEY[1])
    wire [2:0] w_stack_control = {~KEY[1], ~KEY[0], sw7_stable_level};
    
    // ========================================================
    // 2. FSM (Finite State Machine)
    // ========================================================
    FSM_Control u_fsm (
        .clk            (MAX10_CLK1_50),
        .rst_n          (system_reset_n),
        .pulse_start    (final_pulse_start), // Changed from w_pulse_start
        .pulse_stop     (final_pulse_stop),  // Changed from w_pulse_stop
        .timeout_flag   (w_timeout_flag),
        .sw_mode        (sw_mode),
        
        // Outputs
        .Pulse_on       (w_Pulse_on),
        .cnt_reset      (w_cnt_reset),
        .shadow_en      (w_shadow_en),
        .ready          (w_ready_fsm),
        
        // Debug LEDs
        .LEDR9          (LEDR[9]), // IDLE
        .LEDR8          (LEDR[8]), // RUN
        .LEDR7          ()  // DONE (Disconnected intentionally)
    );

    // ========================================================
    // 3. Unified Measurement Unit 
    // (Replaces Counter, Shadow Reg, and Pulse Stretcher)
    // ========================================================
    Measurement_Unit u_measure (
        .clk            (MAX10_CLK1_50),
        .rst_n          (system_reset_n),
        
        // *** ADDED: Fast mode control from SW[3] ***
        .test_mode_fast (test_mode_fast),
        
        // Control signals from FSM
        .Pulse_on       (w_Pulse_on),
        .cnt_reset      (w_cnt_reset),
        .shadow_en      (w_shadow_en),
        .ready_in       (w_ready_fsm),
        
        // Outputs to FSM and QSYS
        .timeout_flag   (w_timeout_flag),   // Back to FSM
        .Shadow_out     (w_shadow_out),     // To QSYS
        .Nios_ready     (w_nios_ready_1ms)  // To QSYS
    );

    // ========================================================
    // 4. QSYS System (Nios II) 
    // ========================================================
    // Note: QSYS auto-appends "_export" to the conduit names we defined.
    nios_system u_nios (
        .clk_clk                (MAX10_CLK1_50),    // Clock
        .reset_reset_n          (system_reset_n),   // Reset
        
        // Connections to custom hardware (Inputs to Nios)
        .shadow_out_export      (w_shadow_out),     // From Measurement Unit
        .nios_ready_export      (w_nios_ready_1ms), // From Measurement Unit
        .uart_busy_export       (w_uart_busy),      // From LCD Driver
        .fsm_run_state_export   (w_Pulse_on),

        .stack_control_export   (w_stack_control), // STACK mode 3 bits

        // Connections from Nios to hardware (Outputs from Nios)
        .uart_data_export       (w_uart_data),      // To LCD Driver 8 bits
        .uart_write_export      (w_uart_write),     // To LCD Driver
		  .speaker_config_export (w_nios_speaker_data)
    );

    // ========================================================
    // 5. LCD UART Driver
    // ========================================================
    LCD_Driver u_lcd (
        .clk            (MAX10_CLK1_50),
        .reset_n        (system_reset_n),
        
        // Interface with QSYS (Nios)
        .uart_data      (w_uart_data),
        .uart_write     (w_uart_write),
        .uart_busy      (w_uart_busy),
        
        // Physical Tx Pin
        .Tx_out         (w_Tx_serial) // Output to internal wire instead of directly to pin
    );

    // ========================================================
    // LED Routing
    // ========================================================
    assign LEDR[7]   = sw7_stable_level; // STACK mode indicator (ON when SW[7] is UP)
    assign LEDR[6:4] = 3'b000;           // Turn off unused LEDs (including the old DONE LED)
    assign LEDR[3]   = test_mode_fast;   // Fast mode indicator (Connected to SW[3])
    assign LEDR[2]   = 1'b0;             // Turn off unused LED
    assign LEDR[1]   = SW[1];            // Turn ON LEDR1 when SW1 is UP
    assign LEDR[0]   = SW[0];            // Turn ON LEDR0 when SW0 is UP
	 
    // ========================================================
    // 6. Routing (LCD Output & Oscilloscope Test Points)
    // ========================================================
    // Split the Tx_out signal to both the LCD and the Scope
    assign ARDUINO_IO_10 = w_Tx_serial; // To external LCD screen
    assign ARDUINO_IO_7  = w_Tx_serial; // To Oscilloscope Test Point
    
    // Other test points
    assign ARDUINO_IO_2  = w_Pulse_on;
    assign ARDUINO_IO_3  = w_uart_busy;
    assign ARDUINO_IO_4  = w_uart_write;
    assign ARDUINO_IO_5  = w_nios_ready_1ms;
	 assign ARDUINO_IO_8  = ~KEY[0] ; 
	 assign ARDUINO_IO_9  = w_pulse_start ;
	 
	 // ========================================================
    // 7. Visual Real-Time Stopwatch (7-Segment)
    // ========================================================
    Stopwatch_display u_stopwatch (
        .clk            (MAX10_CLK1_50),
        .rst_n          (system_reset_n),
        .cnt_en         (w_Pulse_on),      // Runs only when FSM is in RUN state
        .cnt_reset      (w_cnt_reset),     // Resets when a new measurement starts
        .test_mode_fast (test_mode_fast),  // Uses SW[3] for 5x speed
        
        .HEX0           (HEX0),
        .HEX1           (HEX1),
        .HEX2           (HEX2),
        .HEX3           (HEX3),
        .HEX4           (HEX4),
        .HEX5           (HEX5)
    );

// ========================================================
    // 8. System Audio UI (Controlled by Nios II)
    // ========================================================
    Nios_Speaker_Ctrl speaker_unit (
        .clk        (MAX10_CLK1_50),
        .pio_data   (w_nios_speaker_data),
        .audio_out  (ARDUINO_IO_11)  // Physical speaker pin
    
    );

endmodule