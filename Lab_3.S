# ------------------------------------------------------------------
# Student Information
# ------------------------------------------------------------------
# Lab number            : 3
# Group number          : 17
# Section number        : 202
# Student-1 name        : Daniel Khataiepour
# Student-2 name        : George Chen
# ------------------------------------------------------------------
# -------------- YOUR CODE MUST BE WELL COMMENTED ------------------
# -------------- YOU MAY REMOVE UNNECESSARY COMMENTS ---------------
# ------------------------------------------------------------------


.section .text
.align 2
.globl _start


_start:

    # GPIO Control Registers Memory Mapping
    # Refer to lab manual or SiFive FE310-G002 Manual v1p5
    
    
    # GPIO Control Registers Memory Mapping
    # Refer to lab manual or SiFive FE310-G002 Manual v1p5
    # Define the GPIO control register base address and offsets
    # (Output enable, output value, input enable, input value, etc.)
    # -----------------------------write the instructions here-----------------------------

    .equ GPIO_BASE_CTRL_ADDR,   0x10012000      # Base address for GPIO control registers
    .equ GPIO_OUTPUT_EN,        0x08            # Offset to enable GPIO outputs
    .equ GPIO_OUTPUT_VAL,       0x0C            # Offset to write GPIO outputs
    
    # Define GPIO Pin Mapping for LEDs (8 LEDs in LED bar, LED6)
    # Optional: you may also configure the 7-segment display pins
    # -----------------------------write the instructions here-----------------------------

    # LED Pin Masks
    .equ GPIO_7SEGLED_PINS, 0x0000023F          # Seven Segment LED Display Pins (7)
    .equ GPIO_LEDBAR_PINS,  0x00FC0C00          # LED Bar Pins (8)
    .equ GPIO_ALL_LED_PINS, 0x00FC0E3F          # All LED Pins (15)
    .equ GPIO_LEDBAR_LED_6, 0x00400000          # LEDBAR LED6 (Bit 22)
    .equ GPIO_LEDBAR_LED_7, 0x00800000

    # Configure the GPIO Outputs for all LEDs
    # -----------------------------write the instructions here-----------------------------
    li s0, GPIO_BASE_CTRL_ADDR 
    li s1, GPIO_OUTPUT_EN
    li s2, GPIO_OUTPUT_VAL

    li s3, GPIO_ALL_LED_PINS
    li s4, GPIO_LEDBAR_PINS
    li s5, GPIO_LEDBAR_LED_6

    sw s3, 0x08(s0)

    # Define GPIO Pin Mapping for Pushbuttons (S1, S2, and both)
    # -----------------------------write the instructions here-----------------------------

    .equ GPIO_PUSHBUTTON_1, 0x1000
    .equ GPIO_PUSHBUTTON_2, 0x2000
    .equ GPIO_PUSHBUTTON_12, 0x3000

    # Configure the GPIO Inputs for the pushbuttons used (S1, S2, or both)
    # -----------------------------write the instructions here-----------------------------

    li s7, GPIO_PUSHBUTTON_1
    li s8, GPIO_PUSHBUTTON_2
    li s9, GPIO_PUSHBUTTON_12

    sw s9, 0x04(s0)

    # Turn off all LEDs
    # -----------------------------write the instructions here-----------------------------
    li s10, 0x00000000
    sw s10, 0x0C(s0)                          # Store zero into the GPIO_OUTPUT_VAL address.            
    li s11, 0xFFFF

# ----------------------Initialize the pseudo-random number generator-----------------------
InitRandomNum:
    # Sets a7 to a 16-bit non-zero value; only the PRNG subroutine should modify a7
    li a7, 0xABCD

# -------------------Task 1: LED Binary Counter and GPIO Verification----------------------
Task_1:
    sw s10, 0x0C(s0)        # turn LEDS off.            

    lw t5, 0x0(s0)          # get active low state of all push buttons
    and t5, t5, s8          # get active low state of pb1 only
    xor t5, t5, s8          # get active high state of pb1
    bnez t5, Task_2         # Branch to Task_2 if register t5 is equal to zero. 

    li t1, 0xff             # load 255 into t1. Bit mask for the 2 bytes. 

    sw s10, 0x0C(s0)        # Turn LEDs OFF. 

    li t2, 0                # load zero into register t2. t2 is the counter for the while loop.

    binary_counter_increment:

        lw t5, 0x0(s0)          # get active low state of all push buttons
        and t5, t5, s8          # get active low state of pb1 only
        xor t5, t5, s8          # get active high state of pb1
        bnez t5, Task_2         # Go to reflux meter if pb2 is pressed. 
        
        bgt t2, t1, Task_1      # checks to see if the pb is pressed. 

        andi t3, t2, 0x0000003  # Get the 2 lsb of the counter then store it into t3. 
        mv t4, t2               # move the counter into t4 register. 
        srli t4, t4, 2          # shift t4 to the right by 2
        slli t4, t4, 8          # shift t4 to the left by 8
        or t4, t4, t3           # Add the two lsb of counter into t4.  
        slli t4, t4, 10         # shift left by 10 to get the 32 bit number. 

        sw t4, 0xC(s0)          # Store the 8 bits of the counter into the LED Bar. 
        jal ra, delay_01        # delay by 0.1 second 
        
        addi t2, t2, 1          # Increment counter by 1
        j binary_counter_increment #  jump back to the loop.




# ----------------------------------Task 2: Reflex Meter-----------------------------------
Task_2:
    # -----------------------------write the instructions here-----------------------------
    sw s10, 0x0C(s0)        # turn LEDS off.            

    jal ra, RandomNum       # call pseudorandom number subroutine

    and a7, a7, s11         # Store least significant 16 bits into a7

    li a1, 0xF42400         # register for scaled randomized delay
    jal ra, Scale           # scale a7 and store value in a1

    jal ra, random_delay    # randomized wait between 2 - 10 seconds
    
    reflex:

        sw s5, 0x0C(s0)         # turn on LED 6

        li t1, 0                # Counter set to 0
        li t5, 4                # Counter to display the reflex meter 32 bit counter. 

        timer:
            lw t2, 0x0(s0)          # get active low state of all push buttons
            and t2, t2, s7          # get active low state of pb1 only
            xor t2, t2, s7          # get active high state of pb1

            bnez t2, display        # branch if pb 1 is pressed
            jal ra, delay_01mSec    # else wait 0.1 msec
            addi t1, t1, 1          # increment counter
            j timer                 # loop


        display:
            andi t3, t1, 0x0000003  # Get the 2 lsb of the counter then store it into t3. 
            mv t4, t1               # move the counter into t4 register. 
            srli t4, t4, 2          # shift t4 to the right by 2
            slli t4, t4, 8          # shift t4 to the left by 8
            or t4, t4, t3           # Add the two lsb of counter into t4.
            slli t4, t4, 10         # shift left by 10 to get the 32 bit number.
            sw t4, 0xC(s0)          # Store the 8 bits of the counter into the LED Bar.

            jal ra, delay_2         # Delay by 2 seconds
            srli t1, t1, 8          # shifted counter right by 8 bits to get next 8 bits on the LED Bar

            addi t5, t5, -1         # Decrement by 1
            bnez t5, display        # If all 32 bits have not been displayed, jump back to above. 

        sw s10, 0x0C(s0)        # turn LEDS off.            
        jal ra, delay_5         # Delay by 5 seconds
        j reflex                # Restart reflex meter



# ----------------------------------------Scaling-------------------------------------------
# Scaling the randum number generated (a7) between 2 and 10 sec
Scale:

    li t0, 0x3D0 # 976

    loop_multiply: # multiply random number by 976, add 16 million
        addi t0, t0, -1                
        add a1, a1, a7
        bnez t0, loop_multiply

    ret


# -------------------------Pseudo-Random Number Generator------------------------------
# Register a7 will hold the generated random number
# You may read this register anywhere in your program.
# Important: Only this subroutine should write to a7.


    # --------------------------------Use the Stack Properly if needed---------------------
RandomNum:
    addi sp, sp, -16
    sw ra, 12(sp)                  # Save return address

    li s6, 0x8000                  # Select bit 15 of a7
    and t1, a7, s6                 # Extract bit 15

    li s6, 0x2000                  # Select bit 13 of a7
    and t3, a7, s6                 # Extract bit 13

    slli t3, t3, 2                 # Shift extracted bit 13 left by 2
    xor t3, t1, t3                 # Combine with extracted bit 15

    li s6, 0x1000                  # Select bit 12 of a7
    and t1, a7, s6                 # Extract bit 12

    slli t1, t1, 3                 # Shift extracted bit 12 left by 3
    xor t3, t3, t1                 # Combine with previous result

    andi t1, a7, 0x0400            # Select bit 10 of a7
    slli t1, t1, 5                 # Shift bit 10 left by 5
    xor t3, t3, t1                 # Combine with previous result

    srli t3, t3, 15                # Shift result right by 15
    slli a7, a7, 1                 # Shift a7 left by 1
    or a7, a7, t3                  # Update a7 with new pseudo-random value

    lw ra, 12(sp)                  # Restore return address
    addi sp, sp, 16                # Restore stack pointer
    ret                            # Return from subroutine



# ---------------------------- DELAY ROUTINES -----------------------

delay_01:                   # 0.1 second delay
    li t0, 0xC3500          #  4,000,000
                       
    loop01:
        addi t0, t0, -1  
        bnez t0, loop01
    ret

delay_01mSec:             # 0.1 milli-second delay
    li t0, 0x320          #  800
                       
    loop_01m:
        addi t0, t0, -1     
        bnez t0, loop_01m
    ret

random_delay:          # 2 - 10 second delay
    mv t0, a1          #  load randomized delay
                       
    loop_random:
        addi t0, t0, -1
        bnez t0, loop_random
    ret

delay_2:                    # 2 second delay
    li t0, 0xF42400         #  16,000,000
                       
    loop2:
        addi t0, t0, -1
        bnez t0, loop2
    ret

delay_5:                    # 5 second delay
    li t0, 0x2625A00        #  40,000,000
                       
    loop5:
        addi t0, t0, -1     
        bnez t0, loop5

    ret

End:
    .end



# LAB REPORT

# a)
# scaling max possible PRNG value: 65,535 or 0xFF
# 0xFF to 79962160 or 0x4C42030
# max = 65,535*976 + 16,000,000 
# seconds = (max/16,000,000)x2 = 9.99527 seconds
# (|9.99527-10|/10)*100 = 0.0473% error
#
# scaling min possible PRNG value: 0
# scale 0x0 to 16,000,000 or 0xF42400
# min = 0*976 + 16,000,000
# seconds = (min/16,000,000)x2 = 2 seconds
# (|2-2|/2)*100 = 0% error
#
# therefore max and min values are within the acceptable error range
# as every other value is within the minimum and maximum possible values in the random number generator, the time is therefore within 5% of 2 to 10 seconds.

# b) 
# 11111111 = 255 in decimal
# 255*0.0001 = 0.0255 seconds
#
# 1111111111111111 = 65,535 in decimal
# 65,535 * 0.0001 = 6.5535 seconds
#
# 111111111111111111111111 = 16777215 in decimal
# 16777215 * 0.0001 = 1677.7215 seconds = 27.962025 minutes
#
# 11111111111111111111111111111111 = 4294967295
# 4294967295* 0.0001 = 429496.73 seconds = 7158.27883 minutes = 119.304647 hours

# c) 
# 16 bits would make the most sense, since most people's reaction time is approximately 0.25 seconds, which is larger than the maximum for 8 bits.
# 32 bits is way to long to reach, so 16 bits would be most applicable