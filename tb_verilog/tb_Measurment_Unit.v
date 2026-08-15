`timescale 1ns / 1ps

module tb_Measurement_Unit();
    reg clk;
    reg rst_n;
    reg test_mode_fast;
    reg Pulse_on;
    reg cnt_reset;
    reg shadow_en;
    reg ready_in;
    
    wire timeout_flag;
    wire [31:0] Shadow_out;
    wire Nios_ready;

    // חיבור המודול
    Measurement_Unit uut (
        .clk(clk),
        .rst_n(rst_n),
        .test_mode_fast(test_mode_fast),
        .Pulse_on(Pulse_on),
        .cnt_reset(cnt_reset),
        .shadow_en(shadow_en),
        .ready_in(ready_in),
        .timeout_flag(timeout_flag),
        .Shadow_out(Shadow_out),
        .Nios_ready(Nios_ready)
    );

    // יצירת שעון 50MHz (מחזור של 20ns)
    always #10 clk = ~clk;

    initial begin
        // אתחול - הפעם test_mode_fast מכובה (0) כדי לעבוד בזמן אמיתי
        clk = 0; rst_n = 0; test_mode_fast = 0; 
        Pulse_on = 0; cnt_reset = 1; shadow_en = 0; ready_in = 0;
        
        #100 rst_n = 1;
        #50 cnt_reset = 0;
        
        // --- תחילת מדידה ---
        Pulse_on = 1; // נאפשר למונה לרוץ
        
        // המתנה של 1.22 שניות
        #1220000000;
        
        // --- סיום מדידה ושמירת נתונים ---
        Pulse_on = 0;
        
        // שליחת אות דגימה מה-FSM ל-Shadow Register
        shadow_en = 1; #20; shadow_en = 0;
        
        // --- שליחת טריגר Ready ל-NIOS ---
        ready_in = 1; #20; ready_in = 0;
        
        // המתנה של 1.5 מילי-שניות נוספות (1,500,000 ns)
        // נרצה לראות את Nios_ready נמתח בדיוק ל-1 מילי-שנייה ונופל
        #1500000;
        
        $stop;
    end
endmodule