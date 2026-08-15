module Nios_Speaker_Ctrl (
    input  wire        clk,        // Global 50MHz Clock
    input  wire [31:0] pio_data,   // 32-bit data from the Nios PIO (speaker_config)
    output reg         audio_out   // Connected to physical pin ARDUINO_IO_11
);

    // Internal counter for tone generation
    reg [17:0] tone_counter = 0;
    
    // Wire mapping for the 32-bit PIO register
    // Bits [16:0]: Counter limit (controls the frequency/pitch)
    // Bit  [31]  : Enable/Mute bit (1 = Play, 0 = Silence)
    wire [16:0] freq_limit = pio_data[16:0];
    wire        enable     = pio_data[31];

    always @(posedge clk) begin
        if (enable && freq_limit > 0) begin
            // Frequency Divider Logic
            if (tone_counter >= freq_limit) begin
                tone_counter <= 18'd0;
            end else begin
                tone_counter <= tone_counter + 18'd1;
            end
            
            // Fixed Duty Cycle (2000 cycles) for clear audio amplification
            audio_out <= (tone_counter < 18'd2000);
        end else begin
            // Reset state when disabled or limit is zero
            audio_out <= 1'b0;
            tone_counter <= 18'd0;
        end
    end

endmodule