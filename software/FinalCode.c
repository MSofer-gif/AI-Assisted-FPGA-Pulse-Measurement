/*
 * main.c
 * Author: Win10 (Restored Base Code + Fixed STACK Mode + Audio + Melodies + Voice PCM)
 */

#include <stdio.h>
#include <unistd.h>      // For usleep() delays
#include <stdint.h>      // Library that recognizes the uint32_t variable type
#include "system.h"      // Contains the hardware memory map (BASE addresses)
#include "altera_avalon_pio_regs.h" // Contains read/write macros (IORD / IOWR)

#define MAX_HISTORY 10 // Maximum number of saved measurements

// --- Audio Frequencies (Counter Limits for 50MHz Clock) ---
#define TONE_START      28409  // High Pitch (~1760Hz)
#define TONE_SUCCESS_1  56818  // Mid Pitch (~880Hz)
#define TONE_SUCCESS_2  42631  // Higher Pitch (~1174Hz)
#define TONE_CLICK      113636 // Low Pitch (~440Hz)

// --- Musical Notes for Melodies ---
#define NOTE_C4  191570
#define NOTE_E4  151975
#define NOTE_G4  127551
#define NOTE_A4  113636
#define NOTE_C5  95602
#define NOTE_D5  85150  // <-- NEW NOTE
#define NOTE_E5  75872
#define NOTE_F5  71592  // <-- NEW NOTE
#define NOTE_G5  63856
#define REST     0      // Silence

// --- Note Structure ---
typedef struct {
    uint32_t freq_limit;
    uint32_t duration_ms;
} Note;

// --- IDEA 1: Beethoven - Ode to Joy (Classical Easter Egg) ---
Note classical_melody[] = {
    {NOTE_E5, 250}, {NOTE_E5, 250}, {NOTE_F5, 250}, {NOTE_G5, 250},
    {NOTE_G5, 250}, {NOTE_F5, 250}, {NOTE_E5, 250}, {NOTE_D5, 250},
    {NOTE_C5, 250}, {NOTE_C5, 250}, {NOTE_D5, 250}, {NOTE_E5, 250},
    {NOTE_E5, 350}, {NOTE_D5, 150}, {NOTE_D5, 500}
};

// --- IDEA 3: Overflow Warning Melody (Descending Error Tone) ---
Note overflow_melody[] = {
    {NOTE_E5, 200}, {NOTE_C5, 200}, {NOTE_G4, 400}
};

// =========================================================
// PCM VOICE SAMPLE DATA
// =========================================================


// --- Speaker Control Function (Melody/Beep Mode) ---
void play_tone(uint32_t freq_limit, uint32_t duration_ms) {
    // Bit 31 is Enable (1 << 31). Bit 30 is 0 (Tone Mode).
    uint32_t command = (1 << 31) | (freq_limit & 0x1FFFF);
    IOWR_ALTERA_AVALON_PIO_DATA(PIO_SPEAKER_CONFIG_BASE, command); // Turn ON
    usleep(duration_ms * 1000);                                    // Wait
    IOWR_ALTERA_AVALON_PIO_DATA(PIO_SPEAKER_CONFIG_BASE, 0);       // Turn OFF
}



// --- Function to play a sequence of notes ---
void play_melody(Note melody[], int length) {
    for (int i = 0; i < length; i++) {
        if (melody[i].freq_limit == REST) {
            IOWR_ALTERA_AVALON_PIO_DATA(PIO_SPEAKER_CONFIG_BASE, 0);
            usleep(melody[i].duration_ms * 1000);
        } else {
            play_tone(melody[i].freq_limit, melody[i].duration_ms);
        }
        usleep(20000); // 20ms pause between notes for articulation
    }
}

// --- Function to send a single character to the LCD ---
void send_char(char c) {
    while (IORD_ALTERA_AVALON_PIO_DATA(PIO_BUSY_BASE) == 1) {}
    IOWR_ALTERA_AVALON_PIO_DATA(PIO_DATA_BASE, c);
    IOWR_ALTERA_AVALON_PIO_DATA(PIO_START_BASE, 1);
    usleep(10);
    IOWR_ALTERA_AVALON_PIO_DATA(PIO_START_BASE, 0);
}

// --- Function to send a complete string ---
void send_string(const char* str) {
    int i = 0;
    while (str[i] != '\0') {
        send_char(str[i]);
        i++;
    }
}

// --- Function to clear the LCD screen ---
void clear_lcd() {
    send_char(0xFE);
    send_char(0x01);
    usleep(10000);
}

// --- Specific formatting for STACK Memory Browse Mode ---
void print_memory_lcd(int index, uint32_t ms_value) {
    uint32_t total_seconds = ms_value / 1000;
    uint32_t milliseconds  = ms_value % 1000;
    char lcd_message[64];

    if (total_seconds >= 300) {
        sprintf(lcd_message, "M%d: Overflow", index);
    } else if (total_seconds >= 60) {
        uint32_t minutes = total_seconds / 60;
        uint32_t remaining_seconds = total_seconds % 60;
        sprintf(lcd_message, "M%d: %lu.%02lu.%03lu [m]", index, minutes, remaining_seconds, milliseconds);
    } else {
        sprintf(lcd_message, "M%d: %lu.%03lu [s]", index, total_seconds, milliseconds);
    }
    clear_lcd();
    send_string(lcd_message);
}

int main() {
    printf("NIOS II System Started. Waiting for pulse...\n");

    // Play Startup Sound (Fast arpeggio)
    play_tone(113636, 100);
    play_tone(56818, 100);
    play_tone(28409, 150);

    // Memory Stack Variables
    uint32_t history[MAX_HISTORY] = {0};
    int history_count = 0;
    int current_view_index = 0;

    uint32_t ms_value = 0;
    uint32_t total_seconds = 0;
    uint32_t milliseconds = 0;
    uint32_t minutes = 0;
    uint32_t remaining_seconds = 0;
    char lcd_message[64];

    // State tracking variables
    int last_run_state = IORD_ALTERA_AVALON_PIO_DATA(PIO_RUN_BASE);
    int last_stack_mode = 0;
    int last_key0 = 0;
    int last_key1 = 0;


    IOWR_ALTERA_AVALON_PIO_DATA(PIO_START_BASE, 0);

    // RESTORE BACKLIGHT
    send_char(0x7C);
    send_char(0x9D);
    usleep(10000);

    // Setup initial LCD and say "Ready"
    clear_lcd();
    send_string("Ready for pulse!");


    while (1) {
        // =========================================================
        // READ INPUTS (FSM State & Stack Control)
        // =========================================================
        int current_run_state = IORD_ALTERA_AVALON_PIO_DATA(PIO_RUN_BASE);
        int stack_ctrl = IORD_ALTERA_AVALON_PIO_DATA(PIO_STACK_CONTROL_BASE);

        int sw7_mode   = stack_ctrl & 0x01;
        int key0_press = (stack_ctrl >> 1) & 0x01;
        int key1_press = (stack_ctrl >> 2) & 0x01;

        // =========================================================
        // MODE SELECTION: STACK vs NORMAL
        // =========================================================
        if (sw7_mode == 1) {
            // -----------------------------------------------------
            // 1. STACK MEMORY BROWSE MODE
            // -----------------------------------------------------

            // Detect entry into STACK mode
            if (last_stack_mode == 0) {
                play_tone(TONE_CLICK, 50); // Sound feedback for entering menu
                if (history_count == 0) {
                    clear_lcd();
                    send_string("Memory Empty");
                } else {
                    current_view_index = (history_count - 1) % MAX_HISTORY;
                    print_memory_lcd(current_view_index + 1, history[current_view_index]);
                }
            }

            // Browse logic (With Software Debounce & Delete Mode)
            if (history_count > 0) {
                int total_saved = (history_count < MAX_HISTORY) ? history_count : MAX_HISTORY;

                // --- NEW: DELETE ALL (Both KEY0 and KEY1 pressed) ---
                if (key0_press == 1 && key1_press == 1) {
                    play_tone(TONE_START, 400); // Delete sound (long beep)

                    history_count = 0;      // Reset measurement counter
                    current_view_index = 0; // Reset screen pointer

                    // Physical reset of the memory array (optional but recommended)
                    for(int i = 0; i < MAX_HISTORY; i++) {
                        history[i] = 0;
                    }

                    // Print delete message to LCD
                    clear_lcd();
                    send_string("Memory Cleared!");
                    usleep(1000000); // Wait 1 second for the user to read

                    clear_lcd();
                    send_string("Memory Empty");

                    // Blocking: Wait until the user releases at least one button to prevent duplicates
                    while (1) {
                        int check = IORD_ALTERA_AVALON_PIO_DATA(PIO_STACK_CONTROL_BASE);
                        if (((check >> 1) & 0x01) == 0 || ((check >> 2) & 0x01) == 0) {
                            break;
                        }
                    }
                    usleep(50000); // Final debounce delay
                }
                // KEY0: Forward Browse (Only if both aren't pressed)
                else if (key0_press == 1 && last_key0 == 0) {
                    play_tone(TONE_CLICK, 30); // Menu click sound
                    current_view_index = (current_view_index + 1) % total_saved;
                    print_memory_lcd(current_view_index + 1, history[current_view_index]);
                    usleep(50000); // 50ms software debounce block
                }
                // KEY1: Backward Browse (Only if both aren't pressed)
                else if (key1_press == 1 && last_key1 == 0) {
                    play_tone(TONE_CLICK, 30); // Menu click sound
                    current_view_index = (current_view_index - 1 + total_saved) % total_saved;
                    print_memory_lcd(current_view_index + 1, history[current_view_index]);
                    usleep(50000); // 50ms software debounce block
                }
            }
        }

        else {
            // -----------------------------------------------------
            // 2. NORMAL STOPWATCH MODE
            // -----------------------------------------------------

            // Detect exit from STACK mode -> back to Normal
            if (last_stack_mode == 1) {
                play_tone(TONE_CLICK, 50); // Sound feedback for exiting menu
                clear_lcd();
                send_string("Ready for pulse!");

            }

            // --- IDEA 1: Easter Egg (Hold KEY1 in IDLE for 3 seconds) ---
            if (current_run_state == 0 && last_run_state == 0 && key1_press == 1 && key0_press == 0) {
                int hold_counter = 0;

                // Loop 30 times with 100ms delay = total 3 seconds
                for (hold_counter = 0; hold_counter < 30; hold_counter++) {
                    usleep(100000); // Wait 100ms

                    // Re-read inputs physically from hardware
                    int check_ctrl = IORD_ALTERA_AVALON_PIO_DATA(PIO_STACK_CONTROL_BASE);
                    int current_run = IORD_ALTERA_AVALON_PIO_DATA(PIO_RUN_BASE);

                    // Extract KEY1 current state
                    int current_key1 = (check_ctrl >> 2) & 0x01;

                    // ABORT CONDITION: If KEY1 is released, or a pulse suddenly starts!
                    if (current_key1 == 0 || current_run == 1) {
                        break;
                    }
                }

                // If the loop successfully completed all 30 iterations -> 3 full seconds!
                if (hold_counter == 30) {
                    clear_lcd();
                    send_string("FINAL PROJECT:  Yehonatan&Moshe");
                    play_melody(classical_melody, sizeof(classical_melody)/sizeof(classical_melody[0]));
                    usleep(5000000);
                    clear_lcd();
                    send_string("Ready for pulse!");

                    // Blocking loop: Wait for the user to physically release KEY1 before continuing
                    while (1) {
                        int final_check = IORD_ALTERA_AVALON_PIO_DATA(PIO_STACK_CONTROL_BASE);
                        if (((final_check >> 2) & 0x01) == 0) { // Wait for KEY1 to be 0
                            break;
                        }
                    }
                }
            }

            // =========================================================
            // EVENT 1: Detect START of Run
            // =========================================================
            if (current_run_state == 1 && last_run_state == 0) {

                // Debounce: Wait 50ms to verify it's a real press and not a switch glitch
                usleep(50000);
                if (IORD_ALTERA_AVALON_PIO_DATA(PIO_RUN_BASE) == 1) {
                    play_tone(TONE_START, 100);
                    printf("Running...\n");
                    clear_lcd();
                    send_string("Running...");
                } else {
                    // It was a glitch! Reset the state so we don't accidentally Abort later
                    current_run_state = 0;
                }
            }

            // =========================================================
            // EVENT 2: Detect END of Run (It MUST be either Success OR Abort)
            // =========================================================
            if (current_run_state == 0 && last_run_state == 1) {

                int timeout_counter = 0;
                int found_ready = 0;

                // Poll for up to 50ms to see if READY rises
                while (timeout_counter < 5000) {
                    if (IORD_ALTERA_AVALON_PIO_DATA(PIO_READY_BASE) == 1) {
                        found_ready = 1;
                        break;
                    }
                    usleep(10);
                    timeout_counter++;
                }

                if (found_ready == 1) {
                    // -----------------------------------------------------
                    // PATH A: SUCCESSFUL MEASUREMENT
                    // -----------------------------------------------------
                    ms_value = IORD_ALTERA_AVALON_PIO_DATA(PIO_INPUT_BASE);

                    total_seconds = ms_value / 1000;
                    milliseconds = ms_value % 1000;
                    int is_overflow = 0;

                    if (total_seconds >= 300) {
                        sprintf(lcd_message, "Overflow");
                        is_overflow = 1;
                    } else if (total_seconds >= 60) {
                        minutes = total_seconds / 60;
                        remaining_seconds = total_seconds % 60;
                        sprintf(lcd_message, "Pulse Length is: %lu.%02lu.%03lu [min]", minutes, remaining_seconds, milliseconds);
                    } else {
                        sprintf(lcd_message, "Pulse Length is: %lu.%03lu [sec]", total_seconds, milliseconds);
                    }

                    printf("Captured! %s\n", lcd_message);
                    clear_lcd();
                    send_string(lcd_message);

                    // Save to Circular Buffer
                    history[history_count % MAX_HISTORY] = ms_value;
                    history_count++;

                    // Audio Feedback
                    if (is_overflow == 1) {
                        play_melody(overflow_melody, sizeof(overflow_melody)/sizeof(overflow_melody[0]));
                    } else {
                        play_tone(TONE_SUCCESS_1, 100);
                        usleep(20000);
                        play_tone(TONE_SUCCESS_2, 150);
                    }

                    // Block until READY drops to prevent double-reads
                    while (IORD_ALTERA_AVALON_PIO_DATA(PIO_READY_BASE) == 1) {}

                } else {
                    // -----------------------------------------------------
                    // PATH B: ABORTED
                    // -----------------------------------------------------
                    // Verify RUN is still 0 to completely ignore hardware bounces
                    if (IORD_ALTERA_AVALON_PIO_DATA(PIO_RUN_BASE) == 0) {
                        play_tone(TONE_CLICK, 400);
                        printf("Aborted!\n");
                        clear_lcd();
                        send_string("Aborted!");
                        usleep(1500000);
                        clear_lcd();
                        send_string("Ready for pulse!");
                    }
                }
            }

        }
        // Update states
        last_run_state  = current_run_state;
        last_stack_mode = sw7_mode;
        last_key0       = key0_press;
        last_key1       = key1_press;
    }

    return 0;
}