# AI-Driven FPGA Pulse Measurement System

**A high-precision, real-time digital pulse measurement system implemented on an Intel MAX 10 FPGA (DE10-Lite board)[cite: 1, 2]. This project blends concurrent Verilog hardware logic with C-based software running on a Nios II soft-core processor, developed extensively using AI-driven debugging methodologies[cite: 1].**

**Developers:** Moshe Simha Sofer & Yehonatan Ilan[cite: 1, 2]  
**Institution:** Tel Aviv University, The Iby and Aladar Fleischman Faculty of Engineering[cite: 1, 2]

---

## 📖 Project Overview

This system provides a robust solution for measuring digital pulse widths in real-time with precise millisecond resolution. By utilizing the parallel processing capabilities of FPGA logic for critical time-counting and the flexibility of an embedded Nios II processor for UI and data management, the system achieves strict timing accuracy without software overhead[cite: 1]. Generative AI was integrated throughout the RTL design and physical debugging phases to resolve complex hardware-software interface challenges[cite: 1, 5].

## ✨ Key Features

* **High-Precision Timing:** Hardware-level clock cycle counting (50MHz) scaled via a prescaler to achieve exact 1ms resolution[cite: 1].
* **Dual Operation Modes:**
  * *Normal Stopwatch Mode:* Measures pulses triggered by physical push-buttons (`KEY[0]`/`KEY[1]`) or a level-detected switch (`SW[9]`)[cite: 1].
  * *Stack Memory Mode:* A software circular buffer stores the last 10 measurements, allowing the user to browse history via an external LCD[cite: 1].
* **Rich User Interface:** Real-time BCD 7-segment display for live counting, coupled with an external 16x2 UART LCD for detailed status and memory readouts[cite: 1, 2].
* **Audio Feedback (PWM):** Hardware speaker module controlled by the Nios II processor to generate specific tones (e.g., success, error/overflow, and classical melodies via an Easter Egg)[cite: 1, 2, 7, 11].
* **Fast Test Mode:** A dedicated switch (`SW[3]`) accelerates the hardware counting speed by 5x for rapid functional verification of long measurements[cite: 1, 2].

---

## 🏗️ System Architecture

[כאן יש להעלות תמונה: "איור 8 - מבנה המערכת" מתוך ספר הפרויקט `book_3422.docx` בעמוד 10, או משקופית 5 במצגת `Final_final_pres_3422.pdf`]

### 1. Hardware Layer (Verilog RTL)
* **Debouncers & Edge Detectors:** Custom saturating-counter debouncers clean mechanical bounce from switches and buttons, ensuring stable logical signals[cite: 1, 6].
* **Finite State Machine (FSM):** The core unit managing measurement states (`IDLE`, `RUN`, `DONE`), enforcing mode-locking, and controlling the counter[cite: 1, 8].
* **Measurement Unit:** Combines a 32-bit counter, a shadow register to prevent race conditions, and a pulse stretcher to safely alert the Nios II processor across clock domains[cite: 1, 10].
* **UART TX Driver:** A hardware 9600 Baud serial driver transmitting data to the external SerLCD display[cite: 1, 9].

### 2. Software Layer (Nios II & Qsys Integration)
* **Event-Driven C Code:** Runs on the Nios II processor, polling Avalon PIO registers to read FSM states, button presses, and switches, and writing to the LCD and audio peripherals[cite: 1, 7].

[כאן יש להעלות תמונה: `לכידה.PNG` או `לכידה2.PNG` המציגות את ה-Address Map של ה-PIO ב-Platform Designer]

---

## 🤖 AI-Assisted Hardware Debugging 

During hardware testing on the DE10-Lite, physical phenomena such as switch bouncing and processor polling bottlenecks caused system instability. AI tools were utilized to analyze the hardware behavior and refactor the RTL and C code[cite: 1, 5].

### Case Study 1: Resolving Hardware Bouncing & State Locking (`SW[9]`)
**The Problem:** Adding `SW[9]` as a measurement trigger caused the FSM to jump uncontrollably between `RUN` and `STOP` states due to mechanical bouncing and continuous high-level inputs[cite: 5].  
**The Solution:** AI analysis guided the implementation of a robust MUX and locking mechanism inside `Top_System.v`. We implemented a custom `Level-Debouncer` followed by an Edge Detector, and a **Mode Locking** logic block that forces the FSM to strictly ignore all other inputs once a measurement has started[cite: 5, 13].

[כאן יש להעלות תמונה: קוד ה-Level Debouncer וה-MUX מתוך המסמך `פרק AI.docx` - תמונות `final1.jpg` ו-`final2.png`]

### Case Study 2: Event-Driven LCD Communication
**The Problem:** Reading the `STACK` mode toggle switch (`SW[7]`) directly inside the fast `while(1)` software loop overwhelmed the UART driver, causing the system to freeze while waiting for the LCD's `uart_busy` flag to drop[cite: 5].  
**The Solution:** The C code was refactored using AI into a state-change tracker. The processor now detects transitions (e.g., `last_stack_mode != sw7_mode`) rather than continuous levels, sending screen update commands only when an event occurs, ensuring stable UART communication[cite: 5, 7].

[כאן יש להעלות תמונה: הדיאלוג עם ה-AI או פונקציית העיצוב מתוך המסמך `פרק AI.docx` - תמונה `צילום מסך 2026-07-03 ב-16.41.07.png`]

---

## 🔬 Performance & Hardware Verification

The system was rigorously validated using a Keysight Mixed Signal Oscilloscope (MSO-X 3034A) as the ground truth.

* **Timing Accuracy:** Over 30 pulse measurements ranging up to ~5 minutes, the system exhibited a **0% error rate** with a maximum deviation of only 24ms, easily passing the ±50ms project requirement[cite: 1].
* **Resource Utilization:** The RTL design is highly optimized, utilizing only ~5% of the MAX 10 FPGA logic elements and 63% of memory (primarily for the Nios II processor)[cite: 1].
* **Timing Analysis:** Multicorner Timing Analysis confirmed a Total Negative Slack (TNS) of 0.0 with an $F_{max}$ of 81.26 MHz (running safely on the 50MHz global clock)[cite: 1].

[כאן יש להעלות תמונה: `WhatsApp Image 2026-07-21 at 12.57.44 (1).jpg` ו-`12.57.43.jpg` המציגות את אות ה-UART באוסילוסקופ]

*Oscilloscope verification: The capture above shows a 9600 Baud UART transmission burst from the FPGA to the LCD, validating exact hardware timing across the transmission period[cite: 1].*

---

## 🎛️ Hardware Interface & UI

* **DE10-Lite Board:** Interacts via `KEY[0:1]` and `SW[0:9]`. Features real-time 7-Segment measurement displays[cite: 1].
* **External SerLCD:** Connected via Arduino headers to display formatted times, memory stacks, and status messages[cite: 1].
* **Audio Module:** A custom-built speaker amplification circuit driven by the FPGA's `ARDUINO_IO_11` pin to play frequencies generated by `Nios_Speaker_Ctrl.v`[cite: 11, 13].

[כאן יש להעלות תמונה: "איור 9 - ממשק המשתמש החומרתי" מתוך עמוד 14 בספר הפרויקט `book_3422.docx` או משקופית 12 במצגת]
[כאן יש להעלות תמונה: המעגל המודפס של הרמקול `צילום מסך 2026-05-07 ב-11.31.31.jpg` ו-`11.31.11.png`]

---

## 🚀 Getting Started & Board Flashing

To run this project on a physical Intel DE10-Lite board, follow these steps to program the hardware and software:

1. **Hardware Synthesis:** Open the Quartus Prime project and run a full compilation to generate the `.sof` (SRAM Object File).
2. **Qsys/Platform Designer:** Ensure the Nios II system is generated and the memory map is up to date.
3. **Software Build:** Open the Nios II Software Build Tools (SBT) for Eclipse, generate the BSP (Board Support Package), and build `FinalCode.c` to generate the `.hex` or `.elf` file.
4. **Flashing the Board:** 
   * Connect the DE10-Lite board via the USB-Blaster.
   * Open the **Quartus Programmer**.
   * Load the generated `.sof` file and click **Start** to burn the hardware logic onto the MAX 10 FPGA[cite: 2].
5. **Running the Processor:** Use the Nios II Eclipse IDE to Run/Debug the software as Nios II Hardware, which will load the C code into the on-chip memory and begin execution.

[כאן יש להעלות תמונה: שקופית 27 מתוך המצגת `Final_final_pres_3422.pdf` המציגה את מסך ה-Quartus Programmer ותהליך הצריבה]

---

## 📁 Repository Structure

* `rtl/` - Contains all Verilog hardware modules (`Top_System10.5.v`, `Measurement_Unit.v`, `FSM2.0.v`, `Debouncer.v`, `LCD_Driver.v`, etc.).
* `software/` - Contains the embedded C code (`FinalCode.c`) executed on the Nios II processor.
* `docs/` - Contains the complete Project Book (`book_3422.pdf`), Final Presentation, and AI Debugging logs.
* `assets/` - Images and diagrams used in this README.
