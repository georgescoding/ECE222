
.section .text
.align 2
.globl _start

_start:

# --------------------------------------------------------------------------------------------------------------
# Constants and Register Definitions
# --------------------------------------------------------------------------------------------------------------

      .equ GPIO_BASE_CTRL_ADDR,   0x10012000      # Base address for GPIO control registers
      .equ GPIO_OUTPUT_EN,        0x08            # Offset to enable GPIO outputs
      .equ GPIO_OUTPUT_VAL,       0x0C            # Offset to write GPIO outputs

      .equ GPIO_LEDBAR_PINS,  0x00FC0C00          # LED Bar Pins
      .equ GPIO_ALL_LED_PINS, 0x00FC0E3F          # All LED Pins

      .equ GPIO_PUSHBUTTON_1, 0x1000              # push button 1 mask        GPIO12         

      # Set up mtvec with the address of the interrupt vector (S1_interrupt)
      la t0, S1_interrupt                 # Load the address of the interrupt handler 'S1_interrupt' into t0
                                          # S1_interrupt represents the Interrupt Service Routine (ISR) found at the bottom of the code
      csrw mtvec, t0                      # csrw: CSR write,  writes the value in register t0 (which is the 
                                          # address of the interrupt handler) to the mtvec register.                        
                                          # Set the mtvec register to th e address in t0 (S1_interrupt)
      # Enable "External" machine interrupts in the mie register
      li t0, (1 << 11)                    # Set bit 11 to "1" and write it to t0
                                          # This bit (bit 11) corresponds to the external interrupt enable
      csrs mie, t0                        # csrs: CSR Set, it performs a bitwise OR between the current 
                                          # value of mie and the value in t0
                                          # Set bit 11 in the mie register (enable external interrupts)
      # mtvec: Machine Trap Vector register, it stores the address of the interrupt handler
      # directing the processor to jump to this address, S1_interrupt, when an interrupt occurs.

      # Enable global machine interrupts (MIE, bit 3 of mstatus)
      csrr t0, mstatus                    # read the value of the mstatus into t0
      li t1, (1 << 3)                     # Set MIE (Machine Interrupt Enable)
                                          # (1<<3): this instruction puts "1" at the 3rd bit 
      or t0, t0, t1                       # add t0 "mstatus" to t1, where we actually are setting bit 3 to "1"
                                          # This sets the 3rd bit (MIE) in t0 without modifying other bits
      csrw mstatus, t0                    # Write the modified value in t0 back to the mstatus register


      li s0, GPIO_BASE_CTRL_ADDR          

# ------------------------------Configure SW1 as an input------------------------------
# -----------------------------write the instructions here-----------------------------
      li s3, GPIO_PUSHBUTTON_1
      sw s3, 0x04(s0)

# -----------------------Configure GPIO LEDs pins as an output-------------------------
# -----------------------------write the instructions here-----------------------------
      li s1, GPIO_ALL_LED_PINS
      li s2, GPIO_LEDBAR_PINS
      sw s1, 0x08(s0)

# ----------------------------Turn Off all LEDs in LED Bar-----------------------------
# -----------------------------write the instructions here-----------------------------
      li s4, 0x00000000
      sw s4, 0x0C(s0)

# ------------Enable Falling edge for S1: Remember S1 is a GPIO and not PLIC-----------
# -----------------------------write the instructions here-----------------------------
      sw s3, 0x20(s0)

# ----------------------------Enable PLIC for S1 interrupt-----------------------------
# -----------------------------write the instructions here-----------------------------
      # SW1 = GPIO12
      # GPIO12 = PLIC20
      # interrupt enable register offset = 0x2000
      li s5, 0x0C002000 # load base address of PLIC Interrupt Enable base Register
      li t0, (1 << 20)
      sw t0, 0(s5) # load SW1 mask into PLIC interrupt enable

# ----------------Set PLIC priority for S1 interrupt to 7 "Highest Priority"-----------
# -----------The address is calculated according to: PLIC_BASE + 4 × S1_PLIC_ID--------
# -----------------------------write the instructions here-----------------------------
      # S1_PLIC_ID = 20
      # 20 * 4 = 80 = 0x50
      li s6, 0x0C000000 # PLIC register base address
      li t0, 0x7
      sw t0, 0x50(s6)

# -------------------------------Set PLIC threshold to 6-------------------------------
# -----------------------------write the instructions here-----------------------------
      li t0, 0x6
      li s7, 0x0C200000 # PLIC Interrupt Threshold base Register 
      sw t0, 0(s7)


      # Initialize pseudo-random generator and countdown timer
      li a7, 0xABCD

main_program:                             
# -------------------Flashing the LEDS at a rate of 10 Hz (0.1 seconds)----------------
# -----------------------------write the instructions here----------------------------- 
      jal RandomNum           # compute a random number
      sw s2, 0x0C(s0)         # turn LEDs on
      jal delay_01            # delay 0.1 seconds
      sw x0, 0x0C(s0)         # turn LEDs off
      jal delay_01            # delay 0.1 seconds
      j main_program          # jump back to main_program


# Interrupt Service Routine (ISR) for S1 interrupt
S1_interrupt:

# ----------------------------- Save Registers to Stack -----------------------------
      addi sp, sp, -36              # allocate stack pointer
      sw t0, 0(sp)
      sw t1, 4(sp)
      sw t2, 8(sp)
      sw t3, 12(sp)
      sw t4, 16(sp)
      sw t5, 20(sp)
      sw a4, 24(sp)
      sw a7, 28(sp)
      sw ra, 32(sp)                 # store return address in stack

# -------------------------- Acknowledge Interrupt in PLIC --------------------------
      li t6, 0x0C200004
      lw t1, 0(t6)
# ------------------------ Clear the falling interrupt pending in the GPIO ---------------
      sw s3, 0x24(s0)

# ----------------------------- Scale a7 and save it in a4 ---------------------------
      Scale:
            li t2, 28 # 28
            andi a7, a7, 0xFF             # Store least significant 8 bits into a7
            mv t5, a7
            srli t5, t5, 5 # divide random number by 32

            li a4, 0x32             # load a4 with 50

            loop_multiply: # multiply random number by 28, add 50
                  addi t2, t2, -1                
                  add a4, a4, t5
                  bnez t2, loop_multiply
      
      # highest - 246
      # lowest - 0
      display:
            andi t3, a4, 0x0000003  # Get the 2 lsb of the counter then store it into t3. 
            mv t4, a4               # move the counter into t4 register. 
            srli t4, t4, 2          # shift t4 to the right by 2
            slli t4, t4, 8          # shift t4 to the left by 8
            or t4, t4, t3           # Add the two lsb of counter into t4.
            slli t4, t4, 10         # shift left by 10 to get the 32 bit number.
            sw t4, 0xC(s0)          # Store the 8 bits of the counter into the LED Bar.

            li t0, 0x7A1200         # 8,000,000
                              
            delay_1:
                  addi t0, t0, -1
                  bnez t0, delay_1     
                   
            addi a4, a4, -10         # Decrement by 10    

            bgtz a4, display

            sw t1, 0(t6)

# ----------------------------- Restore Registers & Return --------------------------
            lw t0, 0(sp)
            lw t1, 4(sp)
            lw t2, 8(sp)
            lw t3, 12(sp)
            lw t4, 16(sp)
            lw t5, 20(sp)
            lw a4, 24(sp)
            lw a7, 28(sp)
            lw ra, 32(sp)                 # store return address in stack

            addi sp, sp, 36                       # restore stack pointer
            mret                                  # Return from interrupt


RandomNum:
      addi sp, sp, -20               # allocate stack pointer

      sw ra, 16(sp)                  # Save return address
      sw t1, 4(sp)                   # save t1
      sw t2, 8(sp)                   # save t2     
      sw t3, 12(sp)                  # save t3

      li t2, 0x8000                  # Select bit 15 of a7
      and t1, a7, t2                 # Extract bit 15

      li t2, 0x2000                  # Select bit 13 of a7
      and t3, a7, t2                 # Extract bit 13

      slli t3, t3, 2                 # Shift extracted bit 13 left by 2
      xor t3, t1, t3                 # Combine with extracted bit 15

      li t2, 0x1000                  # Select bit 12 of a7
      and t1, a7, t2                 # Extract bit 12

      slli t1, t1, 3                 # Shift extracted bit 12 left by 3
      xor t3, t3, t1                 # Combine with previous result

      andi t1, a7, 0x0400            # Select bit 10 of a7
      slli t1, t1, 5                 # Shift bit 10 left by 5
      xor t3, t3, t1                 # Combine with previous result

      srli t3, t3, 15                # Shift result right by 15
      slli a7, a7, 1                 # Shift a7 left by 1
      or a7, a7, t3                  # Update a7 with new pseudo-random value
      
      lw t1, 4(sp)                   # restore t1
      lw t2, 8(sp)                   # restore t2
      lw t3, 12(sp)                  # restore t3
      lw ra, 16(sp)                  # Restore return address

      addi sp, sp, 20                # Restore stack pointer
      ret                            # Return from subroutine

# ---------------------------- DELAY ROUTINES -----------------------

delay_01:                   # 0.1 second delay
    li t0, 0xC3500          #  4,000,000
                       
    loop01:
        addi t0, t0, -1  
        bnez t0, loop01
    ret