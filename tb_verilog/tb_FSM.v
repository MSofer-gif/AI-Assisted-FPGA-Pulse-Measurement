`timescale 1ns / 1ps

module tb_FSM();
    reg clk;
    reg rst_n;
    reg pulse_start;
    reg pulse_stop;
    reg timeout_flag;
    reg sw_mode;
    
    wire Pulse_on;
    wire cnt_reset;
    wire shadow_en;
    wire ready;
    wire LEDR9;
    wire LEDR8;
    wire LEDR7;

    // חיבור המודול המעודכן
    FSM_Control uut (
        .clk(clk),
        .rst_n(rst_n),
        .pulse_start(pulse_start),
        .pulse_stop(pulse_stop),
        .timeout_flag(timeout_flag),
        .sw_mode(sw_mode),
        .Pulse_on(Pulse_on),
        .cnt_reset(cnt_reset),
        .shadow_en(shadow_en),
        .ready(ready),
        .LEDR9(LEDR9),
        .LEDR8(LEDR8),
        .LEDR7(LEDR7)
    );

    always #10 clk = ~clk;

    initial begin
        // אתחול המערכת במצב ריצה רגיל (sw_mode = 1)
        clk = 0; rst_n = 0; pulse_start = 0; pulse_stop = 0; timeout_flag = 0; sw_mode = 1;
        
        #100 rst_n = 1;
        #100;
        
        // --- תרחיש 1: מדידה תקינה (Start -> Stop) ---
        pulse_start = 1; #20; pulse_start = 0;
        #500; 
        pulse_stop = 1; #20; pulse_stop = 0;   
        #500; 
        
        // --- תרחיש 2: מדידה שמסתיימת ב-Timeout ---
        pulse_start = 1; #20; pulse_start = 0;
        #500;
        timeout_flag = 1; #20; timeout_flag = 0; 
        #500;

        // --- תרחיש 3: התערבות Logic Reset (sw_mode) באמצע מדידה ---
        pulse_start = 1; #20; pulse_start = 0; // מתחילים מדידה (נכנסים ל-RUN)
        #300;
        sw_mode = 0; // מורידים את מתג ה-Reset הלוגי
        #100;        // מוודאים ש-Pulse_on נופל מיד ו-cnt_reset עולה
        sw_mode = 1; // מחזירים למצב תקין
        
        #500;
        $stop;
    end
endmodule