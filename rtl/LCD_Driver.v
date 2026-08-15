module LCD_Driver (
    input  wire        clk,          // System Clock (50MHz)
    input  wire        reset_n,      // Active Low Reset
    
    // Interface to Nios II (via PIO)
    input  wire [7:0]  uart_data,    // Byte to transmit (from Nios)
    input  wire        uart_write,   // Start command (from Nios)
    output reg         uart_busy,    // Status: 1=Busy, 0=Ready (to Nios)

    // Physical Output to LCD
    output reg         Tx_out        // UART TX pin
);

    // ==========================================
    // UART Parameters (9600 Baud @ 50MHz)
    // ==========================================
    parameter CLK_FREQ   = 50000000;
    parameter BAUD_RATE  = 9600;
    parameter BIT_PERIOD = CLK_FREQ / BAUD_RATE;  // ~5208 cycles

    // Internal Registers
    reg [15:0] bit_timer;
    reg [3:0]  bit_index;
    reg [7:0]  shifter;
    reg        running;

    // Init values
    initial begin
        Tx_out    = 1'b1; // Idle state is High
        uart_busy = 1'b0;
        running   = 1'b0;
    end

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            // Async Reset
            Tx_out    <= 1'b1;
            uart_busy <= 1'b0;
            running   <= 1'b0;
            bit_timer <= 0;
            bit_index <= 0;
        end else begin
            
            // --- IDLE STATE: Wait for start signal ---
            if (!running) begin
                uart_busy <= 1'b0;
                bit_timer <= 0;
                bit_index <= 0;
                Tx_out    <= 1'b1;

                if (uart_write) begin
                    // Latch data and start transmission
                    running   <= 1'b1;
                    uart_busy <= 1'b1; // Tell Nios we are busy
                    shifter   <= uart_data;
                    Tx_out    <= 1'b0; // Start Bit (Low)
                end
            end 
            
            // --- RUNNING STATE: Transmit bits ---
            else begin
                if (bit_timer < BIT_PERIOD - 1) begin
                    bit_timer <= bit_timer + 1;
                end else begin
                    bit_timer <= 0; // Reset timer for next bit
                    
                    case (bit_index)
                        // Bits 0-7: Data
                        0,1,2,3,4,5,6,7: begin
                            Tx_out <= shifter[0];
                            shifter <= {1'b0, shifter[7:1]}; // Shift right
                            bit_index <= bit_index + 1;
                        end

                        // Bit 8: Stop Bit (High)
                        8: begin
                            Tx_out <= 1'b1;
                            bit_index <= bit_index + 1;
                        end

                        // End of transmission
                        9: begin
                            running <= 1'b0;   // Go back to IDLE
                            uart_busy <= 1'b0; // Release busy flag
                        end
                    endcase
                end
            end
        end
    end

endmodule
