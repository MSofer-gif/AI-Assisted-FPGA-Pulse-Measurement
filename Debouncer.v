timescale 1ns/10p  \\\\ לבדוק אם רלוונטי


module Debouncer #(parameter COUNTER_BITS = 16) (
    input clk,
    input input_unstable,
    output reg output_stable
);
    // An N-bit saturated counter [cite: 279]
    reg [COUNTER_BITS-1:0] counter;
    reg state;

    always @(posedge clk) begin
        // Increment if input is 1, decrement if 0, without wrap-around 
        if (input_unstable && counter < {COUNTER_BITS{1'b1}}) 
            counter <= counter + 1'b1;
        else if (!input_unstable && counter > 0) 
            counter <= counter - 1'b1;

        // Change internal state based on counter saturation
        if (counter == {COUNTER_BITS{1'b1}}) state <= 1'b1;
        else if (counter == 0) state <= 1'b0;
    end

    // Pulse generator: rising edge detection to create a single-cycle pulse [cite: 265, 266]
    reg state_delayed;
    always @(posedge clk) state_delayed <= state;
    
    always @(*) begin
        // Stable output rises for only a single clock cycle [cite: 265, 266]
        output_stable = state && !state_delayed;
    end
endmodule
