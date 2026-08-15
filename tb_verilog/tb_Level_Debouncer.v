`timescale 1ns / 1ps

module tb_Level_Debouncer();
    reg clk;
    reg rst_n;
    reg unstable_in;
    wire stable_out;

    // חיבור המודול
    Level_Debouncer uut (
        .clk(clk),
        .rst_n(rst_n),
        .unstable_in(unstable_in),
        .stable_out(stable_out)
    );

    // יצירת שעון 50MHz
    always #10 clk = ~clk;

    initial begin
        // אתחול
        clk = 0;
        rst_n = 0;
        unstable_in = 0;

        // שחרור Reset
        #100;
        rst_n = 1;
        #100;

        // סימולציה של רעש וקפיצות מתג (Bounces)
        unstable_in = 1; #500;
        unstable_in = 0; #300;
        unstable_in = 1; #400;
        unstable_in = 0; #200;
        
        // התייצבות על 1
        unstable_in = 1;
        
        // המתנה של 1.2 מילי-שניות כדי לתת למונה להגיע ל-50,000
        #1200000; 

        // סימולציה של כיבוי עם רעש
        unstable_in = 0; #400;
        unstable_in = 1; #300;
        unstable_in = 0;
        
        #1200000;
        $stop;
    end
endmodule